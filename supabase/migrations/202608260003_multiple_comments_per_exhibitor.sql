drop index if exists public.comments_one_active;

create index if not exists comments_exhibitor_profile
  on public.comments (exhibitor_id, profile_id);

create or replace function public.contributor_get_feedback_v2(
  p_event_slug text,
  p_public_id text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid;
  result jsonb;
begin
  if not public.is_contributor() then
    return null;
  end if;

  actor := public.current_profile_id();
  select jsonb_build_object(
    'rating', r.rating_value,
    'comment_count', (
      select count(*)
      from public.comments c
      where c.exhibitor_id = x.exhibitor_id
        and c.profile_id = actor
    ),
    'can_submit', now() between e.start_at and e.lock_at,
    'lock_at', e.lock_at
  )
  into result
  from public.exhibitors x
  join public.events e on e.event_id = x.event_id
  left join public.ratings r
    on r.exhibitor_id = x.exhibitor_id
   and r.profile_id = actor
   and r.invalidated_at is null
  where lower(e.slug) = lower(p_event_slug)
    and x.public_id = p_public_id;

  return result;
end
$$;

create or replace function public.contributor_get_feedback(
  p_event_slug text,
  p_public_id text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid;
  result jsonb;
begin
  if not public.is_contributor() then
    return null;
  end if;

  actor := public.current_profile_id();
  select jsonb_build_object(
    'rating', r.rating_value,
    'comment', coalesce((
      select c.comment_text
      from public.comments c
      where c.exhibitor_id = x.exhibitor_id
        and c.profile_id = actor
      order by c.created_at desc
      limit 1
    ), ''),
    'comment_count', (
      select count(*)
      from public.comments c
      where c.exhibitor_id = x.exhibitor_id
        and c.profile_id = actor
    ),
    'can_submit', now() between e.start_at and e.lock_at,
    'lock_at', e.lock_at
  )
  into result
  from public.exhibitors x
  join public.events e on e.event_id = x.event_id
  left join public.ratings r
    on r.exhibitor_id = x.exhibitor_id
   and r.profile_id = actor
   and r.invalidated_at is null
  where lower(e.slug) = lower(p_event_slug)
    and x.public_id = p_public_id;

  return result;
end
$$;

create or replace function public.contributor_submit_feedback(
  p_event_slug text,
  p_public_id text,
  p_rating smallint,
  p_comment text,
  p_anonymous boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid;
  exhibitor_ref uuid;
  event_ref uuid;
  display_name text;
  normalized_comment text;
  used_comments bigint;
begin
  if not public.is_contributor() then
    raise exception 'Only active Contributors can submit feedback';
  end if;
  if p_rating is not null and p_rating not between 1 and 5 then
    raise exception 'Rating must be between 1 and 5';
  end if;

  normalized_comment := nullif(btrim(coalesce(p_comment, '')), '');
  if char_length(coalesce(normalized_comment, '')) > 200 then
    raise exception 'Comment cannot exceed 200 characters';
  end if;
  if p_rating is null and normalized_comment is null then
    raise exception 'Select a rating or enter a comment';
  end if;

  actor := public.current_profile_id();
  select x.exhibitor_id, e.event_id, p.display_name
  into exhibitor_ref, event_ref, display_name
  from public.exhibitors x
  join public.events e on e.event_id = x.event_id
  join public.profiles p on p.profile_id = actor
  where lower(e.slug) = lower(p_event_slug)
    and x.public_id = p_public_id
    and x.status = 'active'
    and e.status = 'active'
    and now() between e.start_at and e.lock_at;

  if exhibitor_ref is null then
    raise exception 'Feedback is not available for this Exhibitor';
  end if;

  if normalized_comment is not null then
    perform pg_advisory_xact_lock(
      hashtextextended(actor::text || ':' || exhibitor_ref::text, 0)
    );

    select count(*)
    into used_comments
    from public.comments
    where exhibitor_id = exhibitor_ref
      and profile_id = actor;

    if used_comments >= 5 then
      raise exception 'You can post at most 5 comments for this Exhibitor';
    end if;
  end if;

  if p_rating is not null then
    insert into public.ratings (exhibitor_id, profile_id, rating_value)
    values (exhibitor_ref, actor, p_rating)
    on conflict (exhibitor_id, profile_id) do update
    set rating_value = excluded.rating_value,
        updated_at = now(),
        invalidated_at = null,
        invalidated_by_profile_id = null,
        invalidation_reason = null;
  end if;

  if normalized_comment is not null then
    insert into public.comments (
      exhibitor_id,
      profile_id,
      comment_text,
      display_anonymously,
      author_name_snapshot
    )
    values (
      exhibitor_ref,
      actor,
      normalized_comment,
      p_anonymous,
      display_name
    );
  end if;

  insert into public.event_contributors (
    event_id,
    profile_id,
    first_contribution_type
  )
  values (
    event_ref,
    actor,
    case when normalized_comment is null then 'rating' else 'comment' end
  )
  on conflict do nothing;
end
$$;

create or replace function public.contributor_submit_feedback(
  p_event_slug text,
  p_public_id text,
  p_rating smallint,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.contributor_submit_feedback(
    p_event_slug,
    p_public_id,
    p_rating,
    p_comment,
    false
  );
end
$$;

create or replace function public.contributor_my_feedback()
returns table(
  event_name text,
  event_slug text,
  public_id text,
  company_name text,
  rating_value smallint,
  comment_text text,
  updated_at timestamptz,
  can_edit boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_contributor() then
    raise exception 'Not authorized';
  end if;

  return query
  with activity as (
    select r.exhibitor_id, r.profile_id
    from public.ratings r
    where r.profile_id = public.current_profile_id()
    union
    select c.exhibitor_id, c.profile_id
    from public.comments c
    where c.profile_id = public.current_profile_id()
  )
  select
    e.name,
    e.slug,
    x.public_id,
    x.company_name,
    r.rating_value,
    latest_comment.comment_text,
    greatest(
      coalesce(r.updated_at, '-infinity'::timestamptz),
      coalesce(latest_comment.created_at, '-infinity'::timestamptz)
    ),
    now() between e.start_at and e.lock_at
  from activity a
  join public.exhibitors x on x.exhibitor_id = a.exhibitor_id
  join public.events e on e.event_id = x.event_id
  left join public.ratings r
    on r.exhibitor_id = a.exhibitor_id
   and r.profile_id = a.profile_id
  left join lateral (
    select c.comment_text, c.created_at
    from public.comments c
    where c.exhibitor_id = a.exhibitor_id
      and c.profile_id = a.profile_id
    order by c.created_at desc
    limit 1
  ) latest_comment on true
  order by greatest(
    coalesce(r.updated_at, '-infinity'::timestamptz),
    coalesce(latest_comment.created_at, '-infinity'::timestamptz)
  ) desc;
end
$$;

grant execute on function public.contributor_get_feedback_v2(text, text) to authenticated;
grant execute on function public.contributor_get_feedback(text, text) to authenticated;
grant execute on function public.contributor_submit_feedback(text, text, smallint, text, boolean) to authenticated;
grant execute on function public.contributor_submit_feedback(text, text, smallint, text) to authenticated;
grant execute on function public.contributor_my_feedback() to authenticated;
