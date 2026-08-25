create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate_name text;
begin
  candidate_name := coalesce(
    nullif(btrim(new.raw_user_meta_data->>'display_name'), ''),
    nullif(btrim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data->>'name'), ''),
    nullif(
      btrim(
        concat_ws(
          ' ',
          nullif(btrim(new.raw_user_meta_data->>'given_name'), ''),
          nullif(btrim(new.raw_user_meta_data->>'family_name'), '')
        )
      ),
      ''
    ),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Visitor'
  );

  if char_length(candidate_name) < 2 then
    candidate_name := 'Visitor';
  end if;

  insert into public.profiles(auth_user_id, display_name)
  values (new.id, left(candidate_name, 80));

  return new;
end
$$;
