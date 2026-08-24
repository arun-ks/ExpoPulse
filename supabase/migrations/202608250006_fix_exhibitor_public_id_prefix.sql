-- Keep the readable prefix strictly alphanumeric so it satisfies the
-- permanent public-ID constraint even for multi-word company names.
create or replace function public.generate_exhibitor_public_id(p_event_id uuid, p_company_name text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  prefix text;
  candidate text;
begin
  prefix := left(regexp_replace(public.slugify_event_name(p_company_name), '[^a-z0-9]', '', 'g'), 5);
  if prefix = '' then prefix := 'exhib'; end if;
  loop
    candidate := prefix || '-' || translate(substr(md5(gen_random_uuid()::text), 1, 5), '01', '23');
    exit when not exists(
      select 1 from public.exhibitors x
      where x.event_id=p_event_id and x.public_id=candidate
    );
  end loop;
  return candidate;
end $$;
