alter table public.comment_reports add column if not exists resolved_at timestamptz;
alter table public.comment_reports add column if not exists resolved_by_profile_id uuid references public.profiles(profile_id) on delete restrict;
alter table public.comment_reports add column if not exists resolution text check (resolution is null or resolution in ('hidden','dismissed'));

create or replace function public.admin_set_contributor_status(p_profile_id uuid,p_status public.profile_status)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid;old_status public.profile_status;old_name text;
begin
 if not public.is_admin() then raise exception 'Not authorized';end if;
 if p_status not in ('active','suspended','anonymized') then raise exception 'Invalid status';end if;
 actor:=public.current_profile_id();select status,display_name into old_status,old_name from public.profiles where profile_id=p_profile_id and role='contributor' and not is_protected_admin for update;
 if old_status is null then raise exception 'Only Contributor profiles can be changed';end if;
 if old_status='anonymized' then raise exception 'Anonymized profiles cannot be restored';end if;
 update public.profiles set status=p_status,display_name=case when p_status='anonymized' then 'Deleted Contributor' else display_name end,auth_user_id=case when p_status='anonymized' then null else auth_user_id end,anonymized_at=case when p_status='anonymized' then now() else null end,updated_at=now() where profile_id=p_profile_id;
 if p_status='anonymized' then update public.comments set author_name_snapshot='Deleted Contributor',display_anonymously=true where profile_id=p_profile_id;end if;
 insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,change_information) values(actor,'profile.status_changed','profile',p_profile_id,jsonb_build_object('from',old_status,'to',p_status,'previous_name',case when p_status='anonymized' then old_name end));
end $$;

create or replace function public.manage_resolve_comment_reports(p_comment_id uuid,p_resolution text,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid;event_ref uuid;
begin
 if not(public.is_admin() or public.is_editor()) then raise exception 'Not authorized';end if;
 if p_resolution not in ('hidden','dismissed') then raise exception 'Invalid resolution';end if;if char_length(btrim(p_reason))<3 then raise exception 'A reason is required';end if;
 actor:=public.current_profile_id();select x.event_id into event_ref from public.comments c join public.exhibitors x on x.exhibitor_id=c.exhibitor_id where c.comment_id=p_comment_id;
 if event_ref is null then raise exception 'Comment not found';end if;
 if p_resolution='hidden' then update public.comments set hidden_at=coalesce(hidden_at,now()),hidden_by_profile_id=actor where comment_id=p_comment_id;end if;
 update public.comment_reports set resolved_at=now(),resolved_by_profile_id=actor,resolution=p_resolution where comment_id=p_comment_id and resolved_at is null;
 insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information) values(actor,'comment.reports_resolved','comment',p_comment_id,event_ref,jsonb_build_object('resolution',p_resolution,'reason',btrim(p_reason)));
end $$;

create or replace function public.manage_invalidate_comment_rating(p_comment_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid;rating_ref uuid;event_ref uuid;
begin
 if not(public.is_admin() or public.is_editor()) then raise exception 'Not authorized';end if;if char_length(btrim(p_reason))<3 then raise exception 'A reason is required';end if;actor:=public.current_profile_id();
 select r.rating_id,x.event_id into rating_ref,event_ref from public.comments c join public.ratings r on r.exhibitor_id=c.exhibitor_id and r.profile_id=c.profile_id join public.exhibitors x on x.exhibitor_id=c.exhibitor_id where c.comment_id=p_comment_id;
 if rating_ref is null then raise exception 'Associated rating not found';end if;
 update public.ratings set invalidated_at=now(),invalidated_by_profile_id=actor,invalidation_reason=btrim(p_reason),updated_at=now() where rating_id=rating_ref;
 insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information) values(actor,'rating.invalidated','rating',rating_ref,event_ref,jsonb_build_object('reason',btrim(p_reason)));
end $$;

create or replace function public.manage_moderation_queue_v2(p_filter text default 'reported')
returns table(comment_id uuid,event_name text,company_name text,author_name text,comment_text text,created_at timestamptz,is_hidden boolean,report_count bigint)
language plpgsql stable security definer set search_path='' as $$ begin if not(public.is_admin() or public.is_editor()) then raise exception 'Not authorized';end if;return query select c.comment_id,e.name,x.company_name,c.author_name_snapshot,c.comment_text,c.created_at,c.hidden_at is not null,(select count(*) from public.comment_reports r where r.comment_id=c.comment_id and r.resolved_at is null) from public.comments c join public.exhibitors x on x.exhibitor_id=c.exhibitor_id join public.events e on e.event_id=x.event_id where c.deleted_at is null and c.purged_at is null and (p_filter='all' or p_filter='reported' and exists(select 1 from public.comment_reports r where r.comment_id=c.comment_id and r.resolved_at is null) or p_filter='hidden' and c.hidden_at is not null or p_filter='visible' and c.hidden_at is null) order by c.created_at desc;end $$;

create or replace function public.manage_event_feedback_stats(p_event_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin if not(public.is_admin() or public.is_editor()) then raise exception 'Not authorized';end if;return jsonb_build_object('contributors',(select count(*) from public.event_contributors where event_id=p_event_id),'ratings',(select count(*) from public.ratings r join public.exhibitors x on x.exhibitor_id=r.exhibitor_id where x.event_id=p_event_id and r.invalidated_at is null),'comments',(select count(*) from public.comments c join public.exhibitors x on x.exhibitor_id=c.exhibitor_id where x.event_id=p_event_id and c.deleted_at is null and c.purged_at is null),'average_rating',(select round(avg(r.rating_value)::numeric,1) from public.ratings r join public.exhibitors x on x.exhibitor_id=r.exhibitor_id where x.event_id=p_event_id and r.invalidated_at is null),'hidden',(select count(*) from public.comments c join public.exhibitors x on x.exhibitor_id=c.exhibitor_id where x.event_id=p_event_id and c.hidden_at is not null),'reported',(select count(distinct cr.comment_id) from public.comment_reports cr join public.comments c on c.comment_id=cr.comment_id join public.exhibitors x on x.exhibitor_id=c.exhibitor_id where x.event_id=p_event_id and cr.resolved_at is null));end $$;

grant execute on function public.admin_set_contributor_status(uuid,public.profile_status),public.manage_resolve_comment_reports(uuid,text,text),public.manage_invalidate_comment_rating(uuid,text) to authenticated;
