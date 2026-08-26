-- A rating and its optional comment are one feedback submission. Updates to an
-- existing Exhibitor feedback item do not consume another daily allowance.
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
  event_zone text;
  is_new boolean;
  display_name text;
  day_start timestamptz;
  day_end timestamptz;
  used bigint;
begin
  if not public.is_contributor() then
    raise exception 'Only active Contributors can submit feedback';
  end if;
  if p_rating not between 1 and 5 then
    raise exception 'Rating must be between 1 and 5';
  end if;
  if char_length(btrim(coalesce(p_comment, ''))) > 200 then
    raise exception 'Comment cannot exceed 200 characters';
  end if;

  actor := public.current_profile_id();
  select
    x.exhibitor_id,
    e.event_id,
    e.timezone,
    not exists (
      select 1
      from public.ratings r
      where r.exhibitor_id = x.exhibitor_id
        and r.profile_id = actor
    ),
    p.display_name
  into exhibitor_ref, event_ref, event_zone, is_new, display_name
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

  day_start := date_trunc('day', now() at time zone event_zone) at time zone event_zone;
  day_end := day_start + interval '1 day';

  if is_new then
    select count(*)
    into used
    from public.ratings
    where profile_id = actor
      and created_at >= day_start
      and created_at < day_end;

    if used >= 2000 then
      raise exception 'Daily feedback submission limit reached';
    end if;
  end if;

  insert into public.ratings (exhibitor_id, profile_id, rating_value)
  values (exhibitor_ref, actor, p_rating)
  on conflict (exhibitor_id, profile_id) do update
  set rating_value = excluded.rating_value,
      updated_at = now(),
      invalidated_at = null,
      invalidated_by_profile_id = null,
      invalidation_reason = null;

  if nullif(btrim(coalesce(p_comment, '')), '') is null then
    update public.comments
    set deleted_at = now()
    where exhibitor_id = exhibitor_ref
      and profile_id = actor
      and deleted_at is null;
  else
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
      btrim(p_comment),
      p_anonymous,
      display_name
    )
    on conflict (exhibitor_id, profile_id) where deleted_at is null do update
    set comment_text = excluded.comment_text,
        display_anonymously = excluded.display_anonymously,
        author_name_snapshot = excluded.author_name_snapshot,
        hidden_at = null,
        hidden_by_profile_id = null;
  end if;

  insert into public.event_contributors (
    event_id,
    profile_id,
    first_contribution_type
  )
  values (
    event_ref,
    actor,
    case
      when nullif(btrim(coalesce(p_comment, '')), '') is null then 'rating'
      else 'comment'
    end
  )
  on conflict do nothing;
end
$$;

-- Keep the older RPC overload aligned for clients that have not yet adopted
-- the anonymous-display option.
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

-- Advertising enquiries retain their independent five-per-day allowance.
create or replace function public.contributor_submit_enquiry(
  p_email text,
  p_message text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid;
  used bigint;
begin
  if not public.is_contributor() then
    raise exception 'Only active Contributors can send enquiries';
  end if;

  actor := public.current_profile_id();
  select count(*)
  into used
  from public.advertising_enquiries
  where profile_id = actor
    and created_at >= date_trunc('day', now())
    and created_at < date_trunc('day', now()) + interval '1 day';

  if used >= 5 then
    raise exception 'Daily advertising enquiry limit reached';
  end if;

  insert into public.advertising_enquiries (profile_id, contact_email, message)
  values (actor, btrim(p_email), btrim(p_message));
end
$$;

grant execute on function public.contributor_submit_feedback(text, text, smallint, text, boolean) to authenticated;
grant execute on function public.contributor_submit_feedback(text, text, smallint, text) to authenticated;
grant execute on function public.contributor_submit_enquiry(text, text) to authenticated;
