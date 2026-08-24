create or replace function public.manage_list_enquiries()
returns table(enquiry_id uuid,display_name text,contact_email text,message text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$ begin
 if not public.is_admin() then raise exception 'Not authorized'; end if;
 return query select a.enquiry_id,p.display_name,a.contact_email,a.message,a.created_at from public.advertising_enquiries a join public.profiles p on p.profile_id=a.profile_id order by a.created_at desc; end $$;
create or replace function public.manage_event_contributor_count(p_event_id uuid) returns bigint language plpgsql stable security definer set search_path='' as $$
begin if not(public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if; return(select count(*) from public.event_contributors where event_id=p_event_id); end $$;
grant execute on function public.manage_list_enquiries(),public.manage_event_contributor_count(uuid) to authenticated;
