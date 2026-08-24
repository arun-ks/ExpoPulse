-- ExpoPulse greenfield schema foundation.
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

create type public.app_role as enum ('contributor', 'editor', 'admin');
create type public.profile_status as enum ('active', 'suspended', 'anonymized');
create type public.event_status as enum ('draft', 'active', 'archived');
create type public.exhibitor_status as enum ('active', 'archived');
create type public.tag_status as enum ('active', 'archived');

create table public.profiles (
  profile_id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  display_name text not null check (char_length(btrim(display_name)) between 2 and 80),
  role public.app_role not null default 'contributor',
  status public.profile_status not null default 'active',
  is_protected_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  anonymized_at timestamptz,
  constraint protected_admin_shape check (not is_protected_admin or (role = 'admin' and status = 'active')),
  constraint privileged_not_suspended check (role = 'contributor' or status <> 'suspended')
);

create unique index one_protected_admin on public.profiles (is_protected_admin) where is_protected_admin;
create index profiles_auth_user on public.profiles(auth_user_id) where auth_user_id is not null;

create table public.events (
  event_id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 160),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  location text not null check (char_length(btrim(location)) between 2 and 240),
  asset_path text check (asset_path is null or asset_path ~ '^/assets/events/[A-Za-z0-9_./-]+$'),
  timezone text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  lock_at timestamptz not null,
  visible_until timestamptz not null,
  status public.event_status not null default 'draft',
  slug_locked_at timestamptz,
  created_by_profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  updated_by_profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_time_order check (start_at < end_at and end_at <= lock_at and lock_at <= visible_until)
);
create unique index events_slug_ci on public.events(lower(slug));
create index events_visibility on public.events(status, start_at, visible_until);

create table public.exhibitors (
  exhibitor_id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(event_id) on delete restrict,
  public_id text not null check (public_id ~ '^[a-z0-9]+-[a-hj-km-np-z2-9]{5}$'),
  company_name text not null check (char_length(btrim(company_name)) between 1 and 180),
  website_url text check (website_url is null or website_url ~ '^https?://'),
  description text,
  asset_path text check (asset_path is null or asset_path ~ '^/assets/exhibitors/[A-Za-z0-9_./-]+$'),
  status public.exhibitor_status not null default 'active',
  created_by_profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  updated_by_profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by_profile_id uuid references public.profiles(profile_id) on delete restrict
);
create unique index exhibitors_public_id on public.exhibitors(event_id, public_id);
create unique index exhibitors_company_ci on public.exhibitors(event_id, lower(btrim(company_name)));
create index exhibitors_company_search on public.exhibitors using gin (company_name gin_trgm_ops);

create table public.exhibitor_booths (
  booth_assignment_id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(event_id) on delete restrict,
  exhibitor_id uuid not null references public.exhibitors(exhibitor_id) on delete restrict,
  booth_id text not null check (booth_id ~ '^[A-Z0-9#.-]{2,12}$'),
  created_by_profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  created_at timestamptz not null default now(),
  unique(event_id, booth_id),
  unique(exhibitor_id, booth_id)
);

create table public.event_tags (
  tag_id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(event_id) on delete restrict,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  status public.tag_status not null default 'active',
  created_by_profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  updated_by_profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);
create unique index event_tags_name_ci on public.event_tags(event_id, lower(btrim(name)));

create table public.exhibitor_tags (
  exhibitor_id uuid not null references public.exhibitors(exhibitor_id) on delete restrict,
  tag_id uuid not null references public.event_tags(tag_id) on delete restrict,
  assigned_by_profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(exhibitor_id, tag_id)
);

create table public.ratings (
  rating_id uuid primary key default gen_random_uuid(),
  exhibitor_id uuid not null references public.exhibitors(exhibitor_id) on delete restrict,
  profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  rating_value smallint not null check (rating_value between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  invalidated_at timestamptz,
  invalidated_by_profile_id uuid references public.profiles(profile_id) on delete restrict,
  invalidation_reason text,
  unique(exhibitor_id, profile_id)
);

create table public.comments (
  comment_id uuid primary key default gen_random_uuid(),
  exhibitor_id uuid not null references public.exhibitors(exhibitor_id) on delete restrict,
  profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  comment_text text not null check (char_length(comment_text) between 1 and 200),
  display_anonymously boolean not null default false,
  author_name_snapshot text not null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  hidden_at timestamptz,
  hidden_by_profile_id uuid references public.profiles(profile_id) on delete restrict,
  purged_at timestamptz,
  purged_by_profile_id uuid references public.profiles(profile_id) on delete restrict
);
create unique index comments_one_active on public.comments(exhibitor_id, profile_id) where deleted_at is null;

create table public.comment_reports (
  report_id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comments(comment_id) on delete restrict,
  reporter_profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  created_at timestamptz not null default now(),
  unique(comment_id, reporter_profile_id)
);

create table public.event_contributors (
  event_id uuid not null references public.events(event_id) on delete restrict,
  profile_id uuid not null references public.profiles(profile_id) on delete restrict,
  first_contributed_at timestamptz not null default now(),
  first_contribution_type text not null check (first_contribution_type in ('rating','comment')),
  primary key(event_id, profile_id)
);

create table public.audit_log (
  audit_id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles(profile_id) on delete restrict,
  action text not null,
  entity_type text not null,
  entity_id uuid not null,
  event_id uuid references public.events(event_id) on delete restrict,
  occurred_at timestamptz not null default now(),
  change_information jsonb not null default '{}'::jsonb,
  request_reference uuid
);
create index audit_entity_history on public.audit_log(entity_type, entity_id, occurred_at desc);

create or replace function public.current_profile_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select profile_id from public.profiles where auth_user_id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where auth_user_id = auth.uid() and role = 'admin' and status = 'active' and is_protected_admin)
$$;

create or replace function public.is_editor()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where auth_user_id = auth.uid() and role = 'editor' and status = 'active')
$$;

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare candidate_name text;
begin
  candidate_name := coalesce(nullif(btrim(new.raw_user_meta_data->>'display_name'), ''), nullif(btrim(new.raw_user_meta_data->>'full_name'), ''), split_part(new.email, '@', 1), 'Visitor');
  if char_length(candidate_name) < 2 then candidate_name := 'Visitor'; end if;
  insert into public.profiles(auth_user_id, display_name) values (new.id, left(candidate_name, 80));
  return new;
end $$;

create trigger create_profile_after_signup after insert on auth.users for each row execute function public.handle_new_auth_user();

create or replace function public.get_my_profile()
returns table(profile_id uuid, auth_user_id uuid, display_name text, role public.app_role, status public.profile_status, is_protected_admin boolean, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select p.profile_id, p.auth_user_id, p.display_name, p.role, p.status, p.is_protected_admin, p.created_at
  from public.profiles p where p.auth_user_id = auth.uid()
$$;

create or replace function public.admin_list_profiles()
returns table(profile_id uuid, auth_user_id uuid, display_name text, role public.app_role, status public.profile_status, is_protected_admin boolean, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'Not authorized'; end if;
  return query select p.profile_id, p.auth_user_id, p.display_name, p.role, p.status, p.is_protected_admin, p.created_at from public.profiles p order by p.is_protected_admin desc, lower(p.display_name);
end $$;

create or replace function public.admin_set_user_role(target_profile_id uuid, new_role public.app_role)
returns void language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; old_role public.app_role;
begin
  if not public.is_admin() then raise exception 'Not authorized'; end if;
  if new_role = 'admin' then raise exception 'Additional Admin accounts are not permitted'; end if;
  select profile_id into actor_id from public.profiles where auth_user_id = auth.uid();
  select role into old_role from public.profiles where profile_id = target_profile_id and not is_protected_admin for update;
  if not found then raise exception 'Protected or unknown profile'; end if;
  update public.profiles set role = new_role, status = 'active', updated_at = now() where profile_id = target_profile_id;
  insert into public.audit_log(actor_profile_id, action, entity_type, entity_id, change_information)
  values(actor_id, 'profile.role_changed', 'profile', target_profile_id, jsonb_build_object('from', old_role, 'to', new_role));
end $$;

create or replace function public.manage_list_events()
returns setof public.events language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.is_admin() or public.is_editor()) then raise exception 'Not authorized'; end if;
  return query select * from public.events order by start_at desc;
end $$;

create or replace function public.bootstrap_protected_admin(admin_email text, admin_display_name text default 'Admin')
returns uuid language plpgsql security definer set search_path = '' as $$
declare user_uuid uuid; result_id uuid;
begin
  if session_user not in ('postgres', 'supabase_admin') then raise exception 'Run only from the trusted SQL console'; end if;
  if exists(select 1 from public.profiles where is_protected_admin) then raise exception 'Protected Admin already exists'; end if;
  select id into user_uuid from auth.users where lower(email) = lower(admin_email);
  if user_uuid is null then raise exception 'Create the Auth user first'; end if;
  update public.profiles set display_name = btrim(admin_display_name), role = 'admin', status = 'active', is_protected_admin = true, updated_at = now() where auth_user_id = user_uuid returning profile_id into result_id;
  return result_id;
end $$;

alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.exhibitors enable row level security;
alter table public.exhibitor_booths enable row level security;
alter table public.event_tags enable row level security;
alter table public.exhibitor_tags enable row level security;
alter table public.ratings enable row level security;
alter table public.comments enable row level security;
alter table public.comment_reports enable row level security;
alter table public.event_contributors enable row level security;
alter table public.audit_log enable row level security;

create policy profiles_self_read on public.profiles for select to authenticated using (auth_user_id = auth.uid());
create policy profiles_admin_read on public.profiles for select to authenticated using (public.is_admin());
create policy events_public_read on public.events for select to anon, authenticated using (status = 'active' and now() >= start_at - interval '7 days' and now() < visible_until);
create policy events_management_read on public.events for select to authenticated using (public.is_admin() or public.is_editor());

revoke all on all tables in schema public from anon, authenticated;
grant select on public.events, public.exhibitors, public.exhibitor_booths, public.event_tags, public.exhibitor_tags to anon, authenticated;
grant select on public.profiles to authenticated;
grant execute on function public.get_my_profile() to authenticated;
grant execute on function public.admin_list_profiles() to authenticated;
grant execute on function public.admin_set_user_role(uuid, public.app_role) to authenticated;
grant execute on function public.manage_list_events() to authenticated;
revoke execute on function public.bootstrap_protected_admin(text, text) from public, anon, authenticated;

