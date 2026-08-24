alter table public.exhibitors
  add column if not exists initials text
  check (initials is null or initials ~ '^[A-Z0-9]{1,3}$');

create or replace function public.manage_set_exhibitor_tags(p_exhibitor_id uuid,p_tag_ids uuid[])
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid; event_ref uuid; selected_tag_id uuid;
begin
  if not (public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if;
  actor:=public.current_profile_id();
  select x.event_id into event_ref from public.exhibitors x where x.exhibitor_id=p_exhibitor_id;
  if event_ref is null then raise exception 'Exhibitor not found'; end if;
  foreach selected_tag_id in array coalesce(p_tag_ids,'{}'::uuid[]) loop
    if not exists(select 1 from public.event_tags t where t.tag_id=selected_tag_id and t.event_id=event_ref and t.status='active') then raise exception 'Invalid or archived Tag'; end if;
  end loop;
  delete from public.exhibitor_tags et where et.exhibitor_id=p_exhibitor_id;
  insert into public.exhibitor_tags(exhibitor_id,tag_id,assigned_by_profile_id)
    select p_exhibitor_id,tag_id,actor from unnest(coalesce(p_tag_ids,'{}'::uuid[])) tag_id;
  update public.exhibitors set updated_by_profile_id=actor,updated_at=now() where exhibitor_id=p_exhibitor_id;
  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information)
    values(actor,'exhibitor.tags_updated','exhibitor',p_exhibitor_id,event_ref,jsonb_build_object('tag_ids',coalesce(p_tag_ids,'{}'::uuid[])));
end $$;

create or replace function public.manage_set_exhibitor_initials(p_exhibitor_id uuid,p_initials text)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid; event_ref uuid; normalized text;
begin
  if not (public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if;
  actor:=public.current_profile_id(); normalized:=nullif(upper(btrim(coalesce(p_initials,''))), '');
  if normalized is not null and normalized !~ '^[A-Z0-9]{1,3}$' then raise exception 'Initials must be 1 to 3 letters or numbers'; end if;
  update public.exhibitors set initials=normalized,updated_by_profile_id=actor,updated_at=now() where exhibitor_id=p_exhibitor_id returning event_id into event_ref;
  if event_ref is null then raise exception 'Exhibitor not found'; end if;
  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information)
    values(actor,'exhibitor.initials_updated','exhibitor',p_exhibitor_id,event_ref,jsonb_build_object('initials',normalized));
end $$;

create or replace function public.public_get_initials_map(p_event_slug text)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_object_agg(x.public_id,x.initials),'{}'::jsonb)
  from public.exhibitors x join public.events e on e.event_id=x.event_id
  where lower(e.slug)=lower(p_event_slug) and x.status='active' and x.initials is not null and e.status='active' and now()>=e.start_at-interval '7 days' and now()<e.visible_until
$$;

create or replace function public.public_get_exhibitor(p_event_slug text,p_public_id text)
returns jsonb language sql stable security definer set search_path='' as $$
  select to_jsonb(result) from (
    select e.name as event_name,e.slug as event_slug,e.timezone,e.lock_at,x.public_id,x.company_name,x.website_url,x.description,x.asset_path,x.initials,
      coalesce((select array_agg(b.booth_id order by b.booth_id) from public.exhibitor_booths b where b.exhibitor_id=x.exhibitor_id),'{}') as booth_ids,
      coalesce((select array_agg(t.name order by t.name) from public.exhibitor_tags et join public.event_tags t on t.tag_id=et.tag_id where et.exhibitor_id=x.exhibitor_id and t.status='active'),'{}') as tag_names,
      (select round(avg(r.rating_value)::numeric,1) from public.ratings r where r.exhibitor_id=x.exhibitor_id and r.invalidated_at is null) as average_rating,
      (select count(*) from public.ratings r where r.exhibitor_id=x.exhibitor_id and r.invalidated_at is null) as rating_count,
      (select count(*) from public.comments c where c.exhibitor_id=x.exhibitor_id and c.deleted_at is null and c.hidden_at is null and c.purged_at is null) as comment_count
    from public.exhibitors x join public.events e on e.event_id=x.event_id
    where lower(e.slug)=lower(p_event_slug) and x.public_id=p_public_id and x.status='active' and e.status='active' and now()>=e.start_at-interval '7 days' and now()<e.visible_until
  ) result
$$;

grant execute on function public.manage_set_exhibitor_tags(uuid,uuid[]),public.manage_set_exhibitor_initials(uuid,text) to authenticated;
grant execute on function public.public_get_initials_map(text),public.public_get_exhibitor(text,text) to anon,authenticated;
