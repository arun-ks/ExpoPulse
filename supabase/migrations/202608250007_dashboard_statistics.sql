create or replace function public.manage_dashboard_stats()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not (public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if;
  select jsonb_build_object(
    'event_count', (select count(*) from public.events),
    'active_event_count', (select count(*) from public.events e where e.status='active'),
    'people_count', (select count(*) from public.profiles p where p.status<>'anonymized'),
    'editor_count', (select count(*) from public.profiles p where p.role='editor' and p.status='active'),
    'report_count', (
      select count(distinct r.comment_id)
      from public.comment_reports r
      join public.comments c on c.comment_id=r.comment_id
      where c.deleted_at is null and c.hidden_at is null and c.purged_at is null
    )
  ) into result;
  return result;
end $$;

grant execute on function public.manage_dashboard_stats() to authenticated;

