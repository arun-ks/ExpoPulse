create or replace function public.public_list_comments(p_event_slug text,p_public_id text,p_limit integer default 10,p_offset integer default 0)
returns table(comment_id uuid,author_name text,comment_text text,created_at timestamptz,total_count bigint)
language sql stable security definer set search_path='' as $$
 select c.comment_id,case when c.display_anonymously then 'Anonymous Contributor' else c.author_name_snapshot end,c.comment_text,c.created_at,count(*) over()
 from public.comments c join public.exhibitors x on x.exhibitor_id=c.exhibitor_id join public.events e on e.event_id=x.event_id
 where lower(e.slug)=lower(p_event_slug) and x.public_id=p_public_id and x.status='active' and e.status='active' and now()<e.visible_until and c.deleted_at is null and c.hidden_at is null and c.purged_at is null
 order by c.created_at desc limit greatest(1,least(p_limit,50)) offset greatest(p_offset,0)
$$;

create or replace function public.contributor_submit_feedback(p_event_slug text,p_public_id text,p_rating smallint,p_comment text,p_anonymous boolean)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid; exhibitor_ref uuid; event_ref uuid; event_zone text; is_new boolean; display_name text; day_start timestamptz; day_end timestamptz; used bigint;
begin
 if not public.is_contributor() then raise exception 'Only active Contributors can submit feedback'; end if;
 if p_rating not between 1 and 5 then raise exception 'Rating must be between 1 and 5'; end if;
 if char_length(btrim(coalesce(p_comment,'')))>200 then raise exception 'Comment cannot exceed 200 characters'; end if;
 actor:=public.current_profile_id(); select x.exhibitor_id,e.event_id,e.timezone,not exists(select 1 from public.ratings r where r.exhibitor_id=x.exhibitor_id and r.profile_id=actor),p.display_name
 into exhibitor_ref,event_ref,event_zone,is_new,display_name from public.exhibitors x join public.events e on e.event_id=x.event_id join public.profiles p on p.profile_id=actor
 where lower(e.slug)=lower(p_event_slug) and x.public_id=p_public_id and x.status='active' and e.status='active' and now() between e.start_at and e.lock_at;
 if exhibitor_ref is null then raise exception 'Feedback is not available for this Exhibitor'; end if;
 day_start:=date_trunc('day',now() at time zone event_zone) at time zone event_zone;day_end:=day_start+interval '1 day';
 if is_new then select (select count(*) from public.ratings where profile_id=actor and created_at>=day_start and created_at<day_end)+(select count(*) from public.advertising_enquiries where profile_id=actor and created_at>=day_start and created_at<day_end) into used;if used>=5 then raise exception 'Daily submission limit reached';end if;end if;
 insert into public.ratings(exhibitor_id,profile_id,rating_value) values(exhibitor_ref,actor,p_rating) on conflict(exhibitor_id,profile_id) do update set rating_value=excluded.rating_value,updated_at=now(),invalidated_at=null,invalidated_by_profile_id=null,invalidation_reason=null;
 if nullif(btrim(coalesce(p_comment,'')),'') is null then update public.comments set deleted_at=now() where exhibitor_id=exhibitor_ref and profile_id=actor and deleted_at is null;
 else insert into public.comments(exhibitor_id,profile_id,comment_text,display_anonymously,author_name_snapshot) values(exhibitor_ref,actor,btrim(p_comment),p_anonymous,display_name)
 on conflict(exhibitor_id,profile_id) where deleted_at is null do update set comment_text=excluded.comment_text,display_anonymously=excluded.display_anonymously,author_name_snapshot=excluded.author_name_snapshot,hidden_at=null,hidden_by_profile_id=null;end if;
 insert into public.event_contributors(event_id,profile_id,first_contribution_type) values(event_ref,actor,case when nullif(btrim(coalesce(p_comment,'')),'') is null then 'rating' else 'comment' end) on conflict do nothing;
end $$;

create or replace function public.contributor_get_feedback_v2(p_event_slug text,p_public_id text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;result jsonb;begin if not public.is_contributor() then return null;end if;actor:=public.current_profile_id();select jsonb_build_object('rating',r.rating_value,'comment',coalesce(c.comment_text,''),'anonymous',coalesce(c.display_anonymously,false),'can_submit',now() between e.start_at and e.lock_at,'lock_at',e.lock_at) into result from public.exhibitors x join public.events e on e.event_id=x.event_id left join public.ratings r on r.exhibitor_id=x.exhibitor_id and r.profile_id=actor and r.invalidated_at is null left join public.comments c on c.exhibitor_id=x.exhibitor_id and c.profile_id=actor and c.deleted_at is null where lower(e.slug)=lower(p_event_slug) and x.public_id=p_public_id;return result;end $$;

create or replace function public.contributor_report_comment(p_comment_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin if not public.is_contributor() then raise exception 'Only Contributors can report comments';end if;if not exists(select 1 from public.comments where comment_id=p_comment_id and deleted_at is null and hidden_at is null and purged_at is null) then raise exception 'Comment unavailable';end if;insert into public.comment_reports(comment_id,reporter_profile_id) values(p_comment_id,public.current_profile_id()) on conflict do nothing;end $$;

create or replace function public.manage_moderation_queue_v2(p_filter text default 'reported')
returns table(comment_id uuid,event_name text,company_name text,author_name text,comment_text text,created_at timestamptz,is_hidden boolean,report_count bigint)
language plpgsql stable security definer set search_path='' as $$ begin if not(public.is_admin() or public.is_editor()) then raise exception 'Not authorized';end if;return query select c.comment_id,e.name,x.company_name,c.author_name_snapshot,c.comment_text,c.created_at,c.hidden_at is not null,(select count(*) from public.comment_reports r where r.comment_id=c.comment_id) from public.comments c join public.exhibitors x on x.exhibitor_id=c.exhibitor_id join public.events e on e.event_id=x.event_id where c.deleted_at is null and c.purged_at is null and (p_filter='all' or p_filter='reported' and exists(select 1 from public.comment_reports r where r.comment_id=c.comment_id) or p_filter='hidden' and c.hidden_at is not null or p_filter='visible' and c.hidden_at is null) order by c.created_at desc;end $$;

create or replace function public.admin_audit_log(p_limit integer default 100)
returns table(action text,entity_type text,entity_id uuid,event_name text,actor_name text,occurred_at timestamptz,change_information jsonb)
language plpgsql stable security definer set search_path='' as $$ begin if not public.is_admin() then raise exception 'Not authorized';end if;return query select a.action,a.entity_type,a.entity_id,e.name,p.display_name,a.occurred_at,a.change_information from public.audit_log a left join public.events e on e.event_id=a.event_id left join public.profiles p on p.profile_id=a.actor_profile_id order by a.occurred_at desc limit greatest(1,least(p_limit,500));end $$;

create or replace function public.manage_event_feedback_stats(p_event_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin if not(public.is_admin() or public.is_editor()) then raise exception 'Not authorized';end if;return jsonb_build_object('contributors',(select count(*) from public.event_contributors where event_id=p_event_id),'ratings',(select count(*) from public.ratings r join public.exhibitors x on x.exhibitor_id=r.exhibitor_id where x.event_id=p_event_id and r.invalidated_at is null),'comments',(select count(*) from public.comments c join public.exhibitors x on x.exhibitor_id=c.exhibitor_id where x.event_id=p_event_id and c.deleted_at is null and c.purged_at is null),'average_rating',(select round(avg(r.rating_value)::numeric,1) from public.ratings r join public.exhibitors x on x.exhibitor_id=r.exhibitor_id where x.event_id=p_event_id and r.invalidated_at is null),'hidden',(select count(*) from public.comments c join public.exhibitors x on x.exhibitor_id=c.exhibitor_id where x.event_id=p_event_id and c.hidden_at is not null),'reported',(select count(distinct cr.comment_id) from public.comment_reports cr join public.comments c on c.comment_id=cr.comment_id join public.exhibitors x on x.exhibitor_id=c.exhibitor_id where x.event_id=p_event_id));end $$;

grant execute on function public.public_list_comments(text,text,integer,integer) to anon,authenticated;
grant execute on function public.contributor_submit_feedback(text,text,smallint,text,boolean),public.contributor_get_feedback_v2(text,text),public.contributor_report_comment(uuid) to authenticated;
grant execute on function public.manage_moderation_queue_v2(text),public.admin_audit_log(integer),public.manage_event_feedback_stats(uuid) to authenticated;
