create or replace function public.normalized_tag_name(p_value text)
returns text language sql stable set search_path = '' as $$
  select lower(public.unaccent(btrim(regexp_replace(replace(coalesce(p_value,''), chr(160), ' '), '[[:space:]]+', ' ', 'g'))))
$$;

create or replace function public.admin_bulk_import_exhibitors(p_event_id uuid,p_records jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  record jsonb;
  imported integer:=0;
  tag_ids uuid[];
  booth_ids text[];
  tag_name text;
  resolved_tag_id uuid;
  available_tags text;
begin
  if not public.is_admin() then raise exception 'Only Admin can bulk import'; end if;
  if jsonb_typeof(p_records)<>'array' or jsonb_array_length(p_records)=0 then raise exception 'Import must be a non-empty JSON array'; end if;
  if not exists(select 1 from public.events e where e.event_id=p_event_id) then raise exception 'Selected Event does not exist: %',p_event_id; end if;

  select string_agg(t.name, ', ' order by lower(t.name)) into available_tags
  from public.event_tags t where t.event_id=p_event_id and t.status='active';

  for record in select * from jsonb_array_elements(p_records) loop
    tag_ids:='{}';
    booth_ids:=array(select jsonb_array_elements_text(coalesce(record->'boothIds','[]'::jsonb)));
    for tag_name in select jsonb_array_elements_text(coalesce(record->'tags','[]'::jsonb)) loop
      resolved_tag_id:=null;
      select t.tag_id into resolved_tag_id
      from public.event_tags t
      where t.event_id=p_event_id
        and t.status='active'
        and public.normalized_tag_name(t.name)=public.normalized_tag_name(tag_name)
      limit 1;
      if resolved_tag_id is null then
        raise exception 'Unknown active Event Tag "%" for Event %. Available active Tags: %',tag_name,p_event_id,coalesce(available_tags,'(none)');
      end if;
      tag_ids:=tag_ids || resolved_tag_id;
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
