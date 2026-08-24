create index if not exists exhibitor_booths_search on public.exhibitor_booths using gin (booth_id gin_trgm_ops);
create index if not exists event_tags_search on public.event_tags using gin (name gin_trgm_ops);

create or replace function public.public_list_visible_events()
returns table(event_id uuid,name text,slug text,location text,asset_path text,timezone text,start_at timestamptz,end_at timestamptz,lock_at timestamptz,visible_until timestamptz)
language sql stable security definer set search_path='' as $$
  select e.event_id,e.name,e.slug,e.location,e.asset_path,e.timezone,e.start_at,e.end_at,e.lock_at,e.visible_until
  from public.events e
  where e.status='active' and now()>=e.start_at-interval '7 days' and now()<e.visible_until
  order by e.start_at,e.name
$$;

create or replace function public.public_get_event(p_slug text)
returns table(event_id uuid,name text,slug text,location text,asset_path text,timezone text,start_at timestamptz,end_at timestamptz,lock_at timestamptz,visible_until timestamptz)
language sql stable security definer set search_path='' as $$
  select e.event_id,e.name,e.slug,e.location,e.asset_path,e.timezone,e.start_at,e.end_at,e.lock_at,e.visible_until
  from public.events e where lower(e.slug)=lower(p_slug) and e.status='active' and now()>=e.start_at-interval '7 days' and now()<e.visible_until
$$;

create or replace function public.public_event_state(p_slug text)
returns text language sql stable security definer set search_path='' as $$
  select coalesce((select case when e.status='archived' then 'archived' when e.status='draft' then 'unavailable' when now()<e.start_at-interval '7 days' then 'not_yet_available' when now()>=e.visible_until then 'expired' else 'available' end from public.events e where lower(e.slug)=lower(p_slug)),'invalid')
$$;

create or replace function public.public_search_exhibitors(p_event_slug text,p_query text default '',p_limit integer default 25,p_offset integer default 0)
returns table(exhibitor_id uuid,public_id text,company_name text,website_url text,description text,asset_path text,booth_ids text[],tag_names text[],average_rating numeric,rating_count bigint,comment_count bigint,total_count bigint)
language sql stable security definer set search_path='' as $$
  with eligible as (
    select x.*,
      case when btrim(coalesce(p_query,''))='' then 5
        when exists(select 1 from public.exhibitor_booths b where b.exhibitor_id=x.exhibitor_id and lower(b.booth_id)=lower(btrim(p_query))) then 1
        when exists(select 1 from public.exhibitor_booths b where b.exhibitor_id=x.exhibitor_id and b.booth_id ilike '%'||btrim(p_query)||'%') then 2
        when x.company_name ilike '%'||btrim(p_query)||'%' then 3
        else 4 end as relevance
    from public.exhibitors x join public.events e on e.event_id=x.event_id
    where lower(e.slug)=lower(p_event_slug) and e.status='active' and now()>=e.start_at-interval '7 days' and now()<e.visible_until and x.status='active'
      and (btrim(coalesce(p_query,''))='' or x.company_name ilike '%'||btrim(p_query)||'%'
        or exists(select 1 from public.exhibitor_booths b where b.exhibitor_id=x.exhibitor_id and b.booth_id ilike '%'||btrim(p_query)||'%')
        or exists(select 1 from public.exhibitor_tags et join public.event_tags t on t.tag_id=et.tag_id where et.exhibitor_id=x.exhibitor_id and t.status='active' and t.name ilike '%'||btrim(p_query)||'%'))
  )
  select x.exhibitor_id,x.public_id,x.company_name,x.website_url,x.description,x.asset_path,
    coalesce((select array_agg(b.booth_id order by b.booth_id) from public.exhibitor_booths b where b.exhibitor_id=x.exhibitor_id),'{}'),
    coalesce((select array_agg(t.name order by t.name) from public.exhibitor_tags et join public.event_tags t on t.tag_id=et.tag_id where et.exhibitor_id=x.exhibitor_id and t.status='active'),'{}'),
    (select round(avg(r.rating_value)::numeric,1) from public.ratings r where r.exhibitor_id=x.exhibitor_id and r.invalidated_at is null),
    (select count(*) from public.ratings r where r.exhibitor_id=x.exhibitor_id and r.invalidated_at is null),
    (select count(*) from public.comments c where c.exhibitor_id=x.exhibitor_id and c.deleted_at is null and c.hidden_at is null and c.purged_at is null),
    count(*) over()
  from eligible x order by x.relevance,lower(x.company_name),x.exhibitor_id limit greatest(1,least(p_limit,100)) offset greatest(p_offset,0)
$$;

create or replace function public.public_get_exhibitor(p_event_slug text,p_public_id text)
returns jsonb language sql stable security definer set search_path='' as $$
  select to_jsonb(result) from (
    select e.name as event_name,e.slug as event_slug,e.timezone,e.lock_at,x.public_id,x.company_name,x.website_url,x.description,x.asset_path,
      coalesce((select array_agg(b.booth_id order by b.booth_id) from public.exhibitor_booths b where b.exhibitor_id=x.exhibitor_id),'{}') as booth_ids,
      coalesce((select array_agg(t.name order by t.name) from public.exhibitor_tags et join public.event_tags t on t.tag_id=et.tag_id where et.exhibitor_id=x.exhibitor_id and t.status='active'),'{}') as tag_names,
      (select round(avg(r.rating_value)::numeric,1) from public.ratings r where r.exhibitor_id=x.exhibitor_id and r.invalidated_at is null) as average_rating,
      (select count(*) from public.ratings r where r.exhibitor_id=x.exhibitor_id and r.invalidated_at is null) as rating_count,
      (select count(*) from public.comments c where c.exhibitor_id=x.exhibitor_id and c.deleted_at is null and c.hidden_at is null and c.purged_at is null) as comment_count
    from public.exhibitors x join public.events e on e.event_id=x.event_id
    where lower(e.slug)=lower(p_event_slug) and x.public_id=p_public_id and x.status='active' and e.status='active' and now()>=e.start_at-interval '7 days' and now()<e.visible_until
  ) result
$$;

grant execute on function public.public_list_visible_events(),public.public_get_event(text),public.public_event_state(text),public.public_search_exhibitors(text,text,integer,integer),public.public_get_exhibitor(text,text) to anon,authenticated;
