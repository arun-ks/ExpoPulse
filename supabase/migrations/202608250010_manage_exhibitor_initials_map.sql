create or replace function public.manage_get_exhibitor_initials_map(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not (public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if;
  return (select coalesce(jsonb_object_agg(x.exhibitor_id,x.initials),'{}'::jsonb)
    from public.exhibitors x where x.event_id=p_event_id and x.initials is not null);
end $$;

grant execute on function public.manage_get_exhibitor_initials_map(uuid) to authenticated;
