create table public.advertising_enquiries (
  enquiry_id uuid primary key default gen_random_uuid(), profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  contact_email text not null check (contact_email ~* '^[^@ ]+@[^@ ]+\.[^@ ]+$'), message text not null check (char_length(btrim(message)) between 10 and 500),
  created_at timestamptz not null default now()
);
alter table public.advertising_enquiries enable row level security;

create or replace function public.is_contributor() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles where auth_user_id=auth.uid() and role='contributor' and status='active')
$$;
create or replace function public.update_my_display_name(p_display_name text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_contributor() then raise exception 'Only active Contributors can update this profile'; end if;
 if char_length(btrim(p_display_name)) not between 2 and 80 then raise exception 'Display name must be 2 to 80 characters'; end if;
 update public.profiles set display_name=btrim(p_display_name),updated_at=now() where auth_user_id=auth.uid();
end $$;

create or replace function public.contributor_get_feedback(p_event_slug text,p_public_id text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 if not public.is_contributor() then return null; end if; actor:=public.current_profile_id();
 select jsonb_build_object('rating',r.rating_value,'comment',coalesce(c.comment_text,''),'can_submit',now() between e.start_at and e.lock_at,'lock_at',e.lock_at)
 into result from public.exhibitors x join public.events e on e.event_id=x.event_id
 left join public.ratings r on r.exhibitor_id=x.exhibitor_id and r.profile_id=actor and r.invalidated_at is null
 left join public.comments c on c.exhibitor_id=x.exhibitor_id and c.profile_id=actor and c.deleted_at is null
 where lower(e.slug)=lower(p_event_slug) and x.public_id=p_public_id;
 return result;
end $$;

create or replace function public.contributor_submit_feedback(p_event_slug text,p_public_id text,p_rating smallint,p_comment text default '') returns void language plpgsql security definer set search_path='' as $$
declare actor uuid; exhibitor_ref uuid; event_ref uuid; event_zone text; is_new boolean; display_name text; day_start timestamptz; day_end timestamptz; used bigint;
begin
 if not public.is_contributor() then raise exception 'Only active Contributors can submit feedback'; end if;
 if p_rating not between 1 and 5 then raise exception 'Rating must be between 1 and 5'; end if;
 if char_length(btrim(coalesce(p_comment,'')))>200 then raise exception 'Comment cannot exceed 200 characters'; end if;
 actor:=public.current_profile_id(); select x.exhibitor_id,e.event_id,e.timezone,not exists(select 1 from public.ratings r where r.exhibitor_id=x.exhibitor_id and r.profile_id=actor),p.display_name
 into exhibitor_ref,event_ref,event_zone,is_new,display_name from public.exhibitors x join public.events e on e.event_id=x.event_id join public.profiles p on p.profile_id=actor
 where lower(e.slug)=lower(p_event_slug) and x.public_id=p_public_id and x.status='active' and e.status='active' and now() between e.start_at and e.lock_at;
 if exhibitor_ref is null then raise exception 'Feedback is not available for this Exhibitor'; end if;
 day_start:=date_trunc('day',now() at time zone event_zone) at time zone event_zone; day_end:=day_start+interval '1 day';
 if is_new then select (select count(*) from public.ratings where profile_id=actor and created_at>=day_start and created_at<day_end)+(select count(*) from public.advertising_enquiries where profile_id=actor and created_at>=day_start and created_at<day_end) into used; if used>=5 then raise exception 'Daily submission limit reached'; end if; end if;
 insert into public.ratings(exhibitor_id,profile_id,rating_value) values(exhibitor_ref,actor,p_rating) on conflict(exhibitor_id,profile_id) do update set rating_value=excluded.rating_value,updated_at=now(),invalidated_at=null,invalidated_by_profile_id=null,invalidation_reason=null;
 if nullif(btrim(coalesce(p_comment,'')),'') is null then update public.comments set deleted_at=now() where exhibitor_id=exhibitor_ref and profile_id=actor and deleted_at is null;
 else insert into public.comments(exhibitor_id,profile_id,comment_text,author_name_snapshot) values(exhibitor_ref,actor,btrim(p_comment),display_name)
   on conflict(exhibitor_id,profile_id) where deleted_at is null do update set comment_text=excluded.comment_text,author_name_snapshot=excluded.author_name_snapshot,hidden_at=null,hidden_by_profile_id=null; end if;
 insert into public.event_contributors(event_id,profile_id,first_contribution_type) values(event_ref,actor,case when nullif(btrim(coalesce(p_comment,'')),'') is null then 'rating' else 'comment' end) on conflict do nothing;
end $$;

create or replace function public.contributor_my_feedback() returns table(event_name text,event_slug text,public_id text,company_name text,rating_value smallint,comment_text text,updated_at timestamptz,can_edit boolean)
language plpgsql stable security definer set search_path='' as $$ begin
 if not public.is_contributor() then raise exception 'Not authorized'; end if;
 return query select e.name,e.slug,x.public_id,x.company_name,r.rating_value,c.comment_text,r.updated_at,now() between e.start_at and e.lock_at
 from public.ratings r join public.exhibitors x on x.exhibitor_id=r.exhibitor_id join public.events e on e.event_id=x.event_id left join public.comments c on c.exhibitor_id=x.exhibitor_id and c.profile_id=r.profile_id and c.deleted_at is null
 where r.profile_id=public.current_profile_id() order by r.updated_at desc; end $$;

create or replace function public.contributor_submit_enquiry(p_email text,p_message text) returns void language plpgsql security definer set search_path='' as $$
declare actor uuid; used bigint; begin
 if not public.is_contributor() then raise exception 'Only active Contributors can send enquiries'; end if; actor:=public.current_profile_id();
 select (select count(*) from public.ratings where profile_id=actor and created_at>=date_trunc('day',now()) and created_at<date_trunc('day',now())+interval '1 day')+(select count(*) from public.advertising_enquiries where profile_id=actor and created_at>=date_trunc('day',now()) and created_at<date_trunc('day',now())+interval '1 day') into used;
 if used>=5 then raise exception 'Daily submission limit reached'; end if;
 insert into public.advertising_enquiries(profile_id,contact_email,message) values(actor,btrim(p_email),btrim(p_message));
end $$;

create or replace function public.manage_moderation_queue() returns table(comment_id uuid,event_name text,company_name text,author_name text,comment_text text,created_at timestamptz,is_hidden boolean)
language plpgsql stable security definer set search_path='' as $$ begin
 if not(public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if;
 return query select c.comment_id,e.name,x.company_name,c.author_name_snapshot,c.comment_text,c.created_at,c.hidden_at is not null from public.comments c join public.exhibitors x on x.exhibitor_id=c.exhibitor_id join public.events e on e.event_id=x.event_id where c.deleted_at is null and c.purged_at is null order by c.created_at desc; end $$;
create or replace function public.manage_set_comment_hidden(p_comment_id uuid,p_hidden boolean,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare actor uuid; event_ref uuid; begin
 if not(public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if; if char_length(btrim(p_reason))<3 then raise exception 'A moderation reason is required'; end if; actor:=public.current_profile_id();
 update public.comments c set hidden_at=case when p_hidden then now() end,hidden_by_profile_id=case when p_hidden then actor end from public.exhibitors x where c.comment_id=p_comment_id and x.exhibitor_id=c.exhibitor_id returning x.event_id into event_ref;
 if event_ref is null then raise exception 'Comment not found'; end if; insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information) values(actor,case when p_hidden then 'comment.hidden' else 'comment.restored' end,'comment',p_comment_id,event_ref,jsonb_build_object('reason',btrim(p_reason))); end $$;

revoke all on public.advertising_enquiries from anon,authenticated;
grant execute on function public.update_my_display_name(text),public.contributor_get_feedback(text,text),public.contributor_submit_feedback(text,text,smallint,text),public.contributor_my_feedback(),public.contributor_submit_enquiry(text,text) to authenticated;
grant execute on function public.manage_moderation_queue(),public.manage_set_comment_hidden(uuid,boolean,text) to authenticated;
