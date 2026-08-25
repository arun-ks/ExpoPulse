alter table public.events
  add column if not exists website_url text,
  add column if not exists description text;

alter table public.events drop constraint if exists events_website_url_check;
alter table public.events add constraint events_website_url_check
  check (website_url is null or website_url ~ '^https?://');

alter table public.events drop constraint if exists events_description_check;
alter table public.events add constraint events_description_check
  check (description is null or char_length(description) between 1 and 200);

create or replace function public.admin_create_event_v2(
  p_name text, p_slug text, p_location text, p_website_url text, p_description text,
  p_asset_path text, p_timezone text, p_start_local timestamp, p_end_local timestamp,
  p_lock_local timestamp, p_visible_until_local timestamp, p_status public.event_status default 'draft'
)
returns setof public.events language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; new_event public.events; normalized_slug text; start_value timestamptz; end_value timestamptz; lock_value timestamptz; visible_value timestamptz;
begin
  if not public.is_admin() then raise exception 'Only the protected Admin can create Events'; end if;
  select profile_id into actor_id from public.profiles where auth_user_id = auth.uid();
  if not exists(select 1 from pg_timezone_names where name = p_timezone) then raise exception 'Invalid IANA timezone'; end if;
  if nullif(btrim(p_website_url),'') is not null and btrim(p_website_url) !~ '^https?://' then raise exception 'Website must use HTTP or HTTPS'; end if;
  if char_length(btrim(coalesce(p_description,''))) > 200 then raise exception 'Description must be 200 characters or fewer'; end if;
  normalized_slug := public.slugify_event_name(p_slug);
  if normalized_slug = '' then raise exception 'A valid slug is required'; end if;
  start_value := p_start_local at time zone p_timezone; end_value := p_end_local at time zone p_timezone;
  lock_value := p_lock_local at time zone p_timezone; visible_value := p_visible_until_local at time zone p_timezone;
  if not (start_value < end_value and end_value <= lock_value and lock_value <= visible_value) then raise exception 'Dates must satisfy Start < End <= Lock <= Visible until'; end if;
  insert into public.events(name,slug,location,website_url,description,asset_path,timezone,start_at,end_at,lock_at,visible_until,status,slug_locked_at,created_by_profile_id,updated_by_profile_id)
  values(btrim(p_name),normalized_slug,btrim(p_location),nullif(btrim(p_website_url),''),nullif(btrim(p_description),''),nullif(btrim(p_asset_path),''),p_timezone,start_value,end_value,lock_value,visible_value,p_status,
    case when p_status='active' and now()>=start_value-interval '7 days' then now() end,actor_id,actor_id) returning * into new_event;
  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information)
  values(actor_id,'event.created','event',new_event.event_id,new_event.event_id,jsonb_build_object('name',new_event.name,'status',new_event.status,'website_url',new_event.website_url,'description',new_event.description));
  return next new_event;
end $$;

create or replace function public.manage_update_event_v2(
  p_event_id uuid, p_name text, p_slug text, p_location text, p_website_url text,
  p_description text, p_asset_path text, p_timezone text, p_start_local timestamp,
  p_end_local timestamp, p_lock_local timestamp, p_visible_until_local timestamp,
  p_status public.event_status
)
returns setof public.events language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; old_event public.events; updated_event public.events; normalized_slug text; start_value timestamptz; end_value timestamptz; lock_value timestamptz; visible_value timestamptz;
  admin_user boolean := public.is_admin(); editor_user boolean := public.is_editor(); has_contributions boolean; currently_public boolean;
begin
  if not (admin_user or editor_user) then raise exception 'Not authorized'; end if;
  select * into old_event from public.events where event_id=p_event_id for update;
  if not found then raise exception 'Event not found'; end if;
  currently_public := old_event.status='active' and now()>=old_event.start_at-interval '7 days' and now()<old_event.visible_until;
  if editor_user and not currently_public then raise exception 'Editors may edit Event fields only while the Event is visible'; end if;
  if not exists(select 1 from pg_timezone_names where name=p_timezone) then raise exception 'Invalid IANA timezone'; end if;
  if nullif(btrim(p_website_url),'') is not null and btrim(p_website_url) !~ '^https?://' then raise exception 'Website must use HTTP or HTTPS'; end if;
  if char_length(btrim(coalesce(p_description,''))) > 200 then raise exception 'Description must be 200 characters or fewer'; end if;
  normalized_slug := public.slugify_event_name(p_slug);
  if normalized_slug='' then raise exception 'A valid slug is required'; end if;
  if normalized_slug<>old_event.slug and (old_event.slug_locked_at is not null or currently_public) then raise exception 'The public Event slug is permanently locked'; end if;
  start_value:=p_start_local at time zone p_timezone; end_value:=p_end_local at time zone p_timezone;
  lock_value:=p_lock_local at time zone p_timezone; visible_value:=p_visible_until_local at time zone p_timezone;
  if editor_user and (p_status<>old_event.status or visible_value<>old_event.visible_until) then raise exception 'Editors cannot change Event status or public visibility end'; end if;
  if not (start_value<end_value and end_value<=lock_value and lock_value<=visible_value) then raise exception 'Dates must satisfy Start < End <= Lock <= Visible until'; end if;
  select exists(select 1 from public.event_contributors where event_id=p_event_id) into has_contributions;
  if editor_user and has_contributions and (start_value<>old_event.start_at or end_value<>old_event.end_at or lock_value<>old_event.lock_at) then raise exception 'Only Admin can change dates after the first contribution'; end if;
  select profile_id into actor_id from public.profiles where auth_user_id=auth.uid();
  update public.events set name=btrim(p_name),slug=normalized_slug,location=btrim(p_location),website_url=nullif(btrim(p_website_url),''),description=nullif(btrim(p_description),''),asset_path=nullif(btrim(p_asset_path),''),timezone=p_timezone,
    start_at=start_value,end_at=end_value,lock_at=lock_value,visible_until=visible_value,status=p_status,
    slug_locked_at=case when slug_locked_at is not null then slug_locked_at when currently_public or (p_status='active' and now()>=start_value-interval '7 days') then now() end,
    updated_by_profile_id=actor_id,updated_at=now() where event_id=p_event_id returning * into updated_event;
  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information)
  values(actor_id,'event.updated','event',p_event_id,p_event_id,jsonb_build_object('name_from',old_event.name,'name_to',updated_event.name,'status_from',old_event.status,'status_to',updated_event.status,'website_url_from',old_event.website_url,'website_url_to',updated_event.website_url,'description_from',old_event.description,'description_to',updated_event.description));
  return next updated_event;
end $$;

create or replace function public.public_list_visible_events_v2()
returns table(event_id uuid,name text,slug text,location text,website_url text,description text,asset_path text,timezone text,start_at timestamptz,end_at timestamptz,lock_at timestamptz,visible_until timestamptz)
language sql stable security definer set search_path='' as $$
  select e.event_id,e.name,e.slug,e.location,e.website_url,e.description,e.asset_path,e.timezone,e.start_at,e.end_at,e.lock_at,e.visible_until
  from public.events e where e.status='active' and now()>=e.start_at-interval '7 days' and now()<e.visible_until order by e.start_at,e.name
$$;

grant execute on function public.admin_create_event_v2(text,text,text,text,text,text,text,timestamp,timestamp,timestamp,timestamp,public.event_status) to authenticated;
grant execute on function public.manage_update_event_v2(uuid,text,text,text,text,text,text,text,timestamp,timestamp,timestamp,timestamp,public.event_status) to authenticated;
grant execute on function public.public_list_visible_events_v2() to anon,authenticated;
