-- Avoid collision between the loop variable and event_tags.tag_id.
create or replace function public.manage_save_exhibitor(
  p_event_id uuid,p_exhibitor_id uuid,p_company_name text,p_website_url text,
  p_description text,p_asset_path text,p_booth_ids text[],p_tag_ids uuid[]
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid;
  result_id uuid;
  item text;
  v_tag_id uuid;
begin
  if not public.can_manage_exhibitors(p_event_id) then raise exception 'Not authorized for this Event'; end if;
  if p_exhibitor_id is null and not public.is_admin() then raise exception 'Only Admin can create Exhibitors'; end if;
  if nullif(btrim(p_company_name),'') is null then raise exception 'Company Name is required'; end if;
  if nullif(btrim(p_website_url),'') is not null and btrim(p_website_url) !~ '^https?://' then raise exception 'Website must use HTTP or HTTPS'; end if;
  select p.profile_id into actor from public.profiles p where p.auth_user_id=auth.uid();

  if p_exhibitor_id is null then
    insert into public.exhibitors(event_id,public_id,company_name,website_url,description,asset_path,created_by_profile_id,updated_by_profile_id)
    values(p_event_id,public.generate_exhibitor_public_id(p_event_id,p_company_name),btrim(p_company_name),nullif(btrim(p_website_url),''),nullif(btrim(p_description),''),nullif(btrim(p_asset_path),''),actor,actor)
    returning exhibitor_id into result_id;
  else
    update public.exhibitors x set company_name=btrim(p_company_name),website_url=nullif(btrim(p_website_url),''),description=nullif(btrim(p_description),''),asset_path=nullif(btrim(p_asset_path),''),updated_by_profile_id=actor,updated_at=now()
    where x.exhibitor_id=p_exhibitor_id and x.event_id=p_event_id returning x.exhibitor_id into result_id;
    if result_id is null then raise exception 'Exhibitor not found'; end if;
    delete from public.exhibitor_booths b where b.exhibitor_id=result_id;
    delete from public.exhibitor_tags et where et.exhibitor_id=result_id;
  end if;

  foreach item in array coalesce(p_booth_ids,'{}') loop
    item:=upper(btrim(item));
    if item !~ '^[A-Z0-9#.-]{2,12}$' then raise exception 'Invalid Booth ID: %',item; end if;
    insert into public.exhibitor_booths(event_id,exhibitor_id,booth_id,created_by_profile_id)
    values(p_event_id,result_id,item,actor);
  end loop;

  foreach v_tag_id in array coalesce(p_tag_ids,'{}') loop
    if not exists(
      select 1 from public.event_tags t
      where t.tag_id=v_tag_id and t.event_id=p_event_id and t.status='active'
    ) then raise exception 'Invalid or archived Tag: %',v_tag_id; end if;
    insert into public.exhibitor_tags(exhibitor_id,tag_id,assigned_by_profile_id)
    values(result_id,v_tag_id,actor);
  end loop;

  insert into public.audit_log(actor_profile_id,action,entity_type,entity_id,event_id,change_information)
  values(actor,case when p_exhibitor_id is null then 'exhibitor.created' else 'exhibitor.updated' end,'exhibitor',result_id,p_event_id,jsonb_build_object('company_name',btrim(p_company_name)));
  return result_id;
end $$;

grant execute on function public.manage_save_exhibitor(uuid,uuid,text,text,text,text,text[],uuid[]) to authenticated;
