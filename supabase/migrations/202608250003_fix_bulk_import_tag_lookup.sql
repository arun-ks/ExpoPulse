-- The import function uses an empty search_path for security. Qualify the
-- unknown-Tag helper explicitly so PostgreSQL can resolve it at runtime.
create or replace function public.admin_bulk_import_exhibitors(p_event_id uuid,p_records jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare record jsonb; imported integer:=0; tag_ids uuid[]; booth_ids text[]; tag_name text;
begin
  if not public.is_admin() then raise exception 'Only Admin can bulk import'; end if;
  if jsonb_typeof(p_records)<>'array' or jsonb_array_length(p_records)=0 then raise exception 'Import must be a non-empty JSON array'; end if;
  for record in select * from jsonb_array_elements(p_records) loop
    tag_ids:='{}'; booth_ids:=array(select jsonb_array_elements_text(coalesce(record->'boothIds','[]'::jsonb)));
    for tag_name in select jsonb_array_elements_text(coalesce(record->'tags','[]'::jsonb)) loop
      tag_ids:=tag_ids || coalesce(
        (select tag_id from public.event_tags where event_id=p_event_id and lower(name)=lower(btrim(tag_name)) and status='active'),
        public.raise_unknown_tag(tag_name)
      );
    end loop;
    perform public.manage_save_exhibitor(
      p_event_id,null,record->>'companyName',coalesce(record->>'website',''),
      coalesce(record->>'description',''),coalesce(record->>'assetPath',''),booth_ids,tag_ids
    );
    imported:=imported+1;
  end loop;
  return imported;
end $$;

grant execute on function public.admin_bulk_import_exhibitors(uuid,jsonb) to authenticated;
