create or replace function public.generate_exhibitor_public_id(p_event_id uuid, p_company_name text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare prefix text; candidate text;
begin
  prefix := left(public.slugify_event_name(p_company_name), 5); if prefix = '' then prefix := 'exhib'; end if;
  loop
    candidate := prefix || '-' || translate(substr(md5(gen_random_uuid()::text), 1, 5), '01', '23');
    exit when not exists(select 1 from public.exhibitors where event_id=p_event_id and public_id=candidate);
  end loop;
  return candidate;
end $$;

create or replace function public.can_manage_exhibitors(p_event_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_admin() or (public.is_editor() and exists(select 1 from public.events where event_id=p_event_id and status in ('draft','active') and now()<end_at))
$$;

create or replace function public.manage_list_exhibitors(p_event_id uuid)
returns table(exhibitor_id uuid,event_id uuid,public_id text,company_name text,website_url text,description text,asset_path text,status public.exhibitor_status,created_at timestamptz,booth_ids text[],tag_names text[])
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if;
  return query select x.exhibitor_id,x.event_id,x.public_id,x.company_name,x.website_url,x.description,x.asset_path,x.status,x.created_at,
    coalesce((select array_agg(b.booth_id order by b.booth_id) from public.exhibitor_booths b where b.exhibitor_id=x.exhibitor_id),'{}'),
    coalesce((select array_agg(t.name order by t.name) from public.exhibitor_tags et join public.event_tags t on t.tag_id=et.tag_id where et.exhibitor_id=x.exhibitor_id),'{}')
  from public.exhibitors x where x.event_id=p_event_id order by lower(x.company_name);
end $$;

create or replace function public.manage_get_exhibitor(p_exhibitor_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not (public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if;
  select to_jsonb(x) || jsonb_build_object('booth_ids',coalesce((select jsonb_agg(b.booth_id order by b.booth_id) from public.exhibitor_booths b where b.exhibitor_id=x.exhibitor_id),'[]'::jsonb),'tag_ids',coalesce((select jsonb_agg(et.tag_id) from public.exhibitor_tags et where et.exhibitor_id=x.exhibitor_id),'[]'::jsonb)) into result
  from public.exhibitors x where x.exhibitor_id=p_exhibitor_id;
  return result;
end $$;

create or replace function public.manage_save_exhibitor(p_event_id uuid,p_exhibitor_id uuid,p_company_name text,p_website_url text,p_description text,p_asset_path text,p_booth_ids text[],p_tag_ids uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor uuid; result_id uuid; item text; tag_id uuid;
begin
  if not public.can_manage_exhibitors(p_event_id) then raise exception 'Not authorized for this Event'; end if;
  if p_exhibitor_id is null and not public.is_admin() then raise exception 'Only Admin can create Exhibitors'; end if;
  if nullif(btrim(p_company_name),'') is null then raise exception 'Company Name is required'; end if;
  if nullif(btrim(p_website_url),'') is not null and btrim(p_website_url) !~ '^https?://' then raise exception 'Website must use HTTP or HTTPS'; end if;
  select profile_id into actor from public.profiles where auth_user_id=auth.uid();
  if p_exhibitor_id is null then
    insert into public.exhibitors(event_id,public_id,company_name,website_url,description,asset_path,created_by_profile_id,updated_by_profile_id)
    values(p_event_id,public.generate_exhibitor_public_id(p_event_id,p_company_name),btrim(p_company_name),nullif(btrim(p_website_url),''),nullif(btrim(p_description),''),nullif(btrim(p_asset_path),''),actor,actor) returning exhibitor_id into result_id;
  else
    update public.exhibitors set company_name=btrim(p_company_name),website_url=nullif(btrim(p_website_url),''),description=nullif(btrim(p_description),''),asset_path=nullif(btrim(p_asset_path),''),updated_by_profile_id=actor,updated_at=now()
    where exhibitor_id=p_exhibitor_id and event_id=p_event_id returning exhibitor_id into result_id;
    if result_id is null then raise exception 'Exhibitor not found'; end if;
    delete from public.exhibitor_booths where exhibitor_id=result_id; delete from public.exhibitor_tags where exhibitor_id=result_id;
  end if;
  foreach item in array coalesce(p_booth_ids,'{}') loop
    item:=upper(btrim(item)); if item !~ '^[A-Z0-9#.-]{2,12}$' then raise exception 'Invalid Booth ID: %',item; end if;
    insert into public.exhibitor_booths(event_id,exhibitor_id,booth_id,created_by_profile_id) values(p_event_id,result_id,item,actor);
  end loop;
  foreach tag_id in array coalesce(p_tag_ids,'{}') loop
    if not exists(select 1 from public.event_tags where event_tags.tag_id=tag_id and event_id=p_event_id and status='active') then raise exception 'Invalid or archived Tag'; end if;
    insert into public.exhibitor_tags(exhibitor_id,tag_id,assigned_by_profile_id) values(result_id,tag_id,actor);
  end loop;
  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information) values(actor,case when p_exhibitor_id is null then 'exhibitor.created' else 'exhibitor.updated' end,'exhibitor',result_id,p_event_id,jsonb_build_object('company_name',btrim(p_company_name)));
  return result_id;
end $$;

create or replace function public.admin_set_exhibitor_status(p_exhibitor_id uuid,p_status public.exhibitor_status)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid; event_ref uuid;
begin
  if not public.is_admin() then raise exception 'Only Admin can archive Exhibitors'; end if;
  select profile_id into actor from public.profiles where auth_user_id=auth.uid();
  update public.exhibitors set status=p_status,archived_at=case when p_status='archived' then now() end,archived_by_profile_id=case when p_status='archived' then actor end,updated_by_profile_id=actor,updated_at=now() where exhibitor_id=p_exhibitor_id returning event_id into event_ref;
  if event_ref is null then raise exception 'Exhibitor not found'; end if;
  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information) values(actor,'exhibitor.status_changed','exhibitor',p_exhibitor_id,event_ref,jsonb_build_object('status',p_status));
end $$;

create or replace function public.manage_list_tags(p_event_id uuid)
returns setof public.event_tags language plpgsql stable security definer set search_path = '' as $$
begin if not (public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if; return query select * from public.event_tags where event_id=p_event_id order by status,lower(name); end $$;

create or replace function public.admin_create_tag(p_event_id uuid,p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor uuid; result uuid;
begin if not public.is_admin() then raise exception 'Only Admin can create Tags'; end if; select profile_id into actor from public.profiles where auth_user_id=auth.uid();
  insert into public.event_tags(event_id,name,created_by_profile_id,updated_by_profile_id) values(p_event_id,btrim(p_name),actor,actor) returning tag_id into result;
  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information) values(actor,'tag.created','tag',result,p_event_id,jsonb_build_object('name',btrim(p_name))); return result; end $$;

create or replace function public.admin_set_tag_status(p_tag_id uuid,p_status public.tag_status)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid; event_ref uuid;
begin if not public.is_admin() then raise exception 'Only Admin can archive Tags'; end if; select profile_id into actor from public.profiles where auth_user_id=auth.uid();
  if p_status='archived' then delete from public.exhibitor_tags where tag_id=p_tag_id; end if;
  update public.event_tags set status=p_status,archived_at=case when p_status='archived' then now() end,updated_by_profile_id=actor,updated_at=now() where tag_id=p_tag_id returning event_id into event_ref;
  if event_ref is null then raise exception 'Tag not found'; end if; insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information) values(actor,'tag.status_changed','tag',p_tag_id,event_ref,jsonb_build_object('status',p_status)); end $$;

create or replace function public.raise_unknown_tag(p_name text)
returns uuid language plpgsql immutable set search_path='' as $$ begin raise exception 'Unknown Event Tag: %',p_name; end $$;

create or replace function public.admin_bulk_import_exhibitors(p_event_id uuid,p_records jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare record jsonb; imported integer:=0; tag_ids uuid[]; booth_ids text[]; tag_name text;
begin
  if not public.is_admin() then raise exception 'Only Admin can bulk import'; end if;
  if jsonb_typeof(p_records)<>'array' or jsonb_array_length(p_records)=0 then raise exception 'Import must be a non-empty JSON array'; end if;
  for record in select * from jsonb_array_elements(p_records) loop
    tag_ids:='{}'; booth_ids:=array(select jsonb_array_elements_text(coalesce(record->'boothIds','[]'::jsonb)));
    for tag_name in select jsonb_array_elements_text(coalesce(record->'tags','[]'::jsonb)) loop
      tag_ids:=tag_ids || coalesce((select tag_id from public.event_tags where event_id=p_event_id and lower(name)=lower(btrim(tag_name)) and status='active'),raise_unknown_tag(tag_name));
    end loop;
    perform public.manage_save_exhibitor(p_event_id,null,record->>'companyName',coalesce(record->>'website',''),coalesce(record->>'description',''),coalesce(record->>'assetPath',''),booth_ids,tag_ids); imported:=imported+1;
  end loop; return imported;
end $$;

grant execute on function public.manage_list_exhibitors(uuid),public.manage_get_exhibitor(uuid),public.manage_save_exhibitor(uuid,uuid,text,text,text,text,text[],uuid[]),public.admin_set_exhibitor_status(uuid,public.exhibitor_status),public.manage_list_tags(uuid),public.admin_create_tag(uuid,text),public.admin_set_tag_status(uuid,public.tag_status),public.admin_bulk_import_exhibitors(uuid,jsonb) to authenticated;
