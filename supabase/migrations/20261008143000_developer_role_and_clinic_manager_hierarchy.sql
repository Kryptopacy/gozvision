-- =============================================================================
-- Migration: 20261008143000_developer_role_and_clinic_manager_hierarchy.sql
-- Description:
--   1. Expands profiles.role to include 'Developer' and 'ClinicManager'.
--   2. Grants 'Developer' role to platform owner (kryptopacy@gmail.com).
--   3. Establishes hierarchy:
--        - Developer (Global Platform Orchestrator - kryptopacy@gmail.com)
--        - ClinicManager (Practice Owner / Business Head of Clinic)
--        - Practitioner (Doctor / Optometrist / Clinical care)
--        - Staff (Front Desk / Optician / Operations)
--        - Patient (Multimodal Voice Copilot)
--        - Caregiver (Independent Family Member / Guardian)
--   4. Creates platform_config table for dynamic, no-code runtime business tuning.
-- =============================================================================

-- 1. Update profiles table role check constraint
alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('Developer', 'ClinicManager', 'Owner', 'Practitioner', 'Staff', 'Patient', 'Caregiver'));

-- Automatically promote kryptopacy@gmail.com to Developer if profile exists
update public.profiles
  set role = 'Developer'
  where lower(email) = 'kryptopacy@gmail.com';

-- Automatically migrate legacy 'Owner' to 'ClinicManager'
update public.profiles
  set role = 'ClinicManager'
  where role = 'Owner' and lower(email) != 'kryptopacy@gmail.com';

-- 2. Update auth user creation trigger to automatically assign Developer to dev email
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, internal
as $$
declare
  user_email text;
  user_role text;
  user_name text;
begin
  user_email := lower(coalesce(new.email, ''));
  user_name := coalesce(new.raw_user_meta_data->>'name', split_part(user_email, '@', 1));

  -- If developer email, strictly set Developer role
  if user_email = 'kryptopacy@gmail.com' then
    user_role := 'Developer';
  else
    user_role := coalesce(new.raw_user_meta_data->>'role', 'Patient');
    if user_role not in ('Developer', 'ClinicManager', 'Owner', 'Practitioner', 'Staff', 'Patient', 'Caregiver') then
      user_role := 'Patient';
    end if;
  end if;

  insert into public.profiles (id, email, name, role, created_at)
  values (new.id, user_email, user_name, user_role, now())
  on conflict (id) do update set
    email = excluded.email,
    name = case when public.profiles.name = '' then excluded.name else public.profiles.name end,
    role = case when user_email = 'kryptopacy@gmail.com' then 'Developer' else public.profiles.role end;

  return new;
end;
$$;

-- 3. Security Definer Role Check Functions in schema 'internal'
create or replace function internal.is_developer()
returns boolean
language sql stable security definer
set search_path = public, internal
as $$
  select coalesce(
    (select role = 'Developer' or lower(email) = 'kryptopacy@gmail.com' from internal.my_profile()),
    false
  );
$$;

create or replace function internal.is_clinic_manager()
returns boolean
language sql stable security definer
set search_path = public, internal
as $$
  select coalesce(
    (select role in ('ClinicManager', 'Owner', 'Developer') from internal.my_profile()),
    false
  );
$$;

create or replace function internal.is_practitioner()
returns boolean
language sql stable security definer
set search_path = public, internal
as $$
  select coalesce(
    (select role in ('Practitioner', 'ClinicManager', 'Owner', 'Developer') from internal.my_profile()),
    false
  );
$$;

create or replace function internal.is_staff()
returns boolean
language sql stable security definer
set search_path = public, internal
as $$
  select coalesce(
    (select role in ('Practitioner', 'Staff', 'ClinicManager', 'Owner', 'Developer') from internal.my_profile()),
    false
  );
$$;

-- Developers bypass single-clinic tenancy so they can monitor all clinics
create or replace function internal.same_clinic(target uuid)
returns boolean
language sql stable security definer
set search_path = public, internal
as $$
  select case
    when internal.is_developer() then true
    else (target is not null and target = internal.my_clinic_id())
  end;
$$;

-- 4. Dynamic Platform Configuration Table (No-code runtime business tuning)
create table if not exists public.platform_config (
  key text primary key,
  value jsonb not null,
  category text not null default 'general',
  description text,
  updated_at timestamptz not null default now(),
  updated_by text not null default 'kryptopacy@gmail.com'
);

alter table public.platform_config enable row level security;

-- Developer has full read & write permissions on platform_config
drop policy if exists "platform_config_developer_all" on public.platform_config;
create policy "platform_config_developer_all"
  on public.platform_config
  for all
  using (internal.is_developer())
  with check (internal.is_developer());

-- Authenticated clinic and patient apps can read platform configuration
drop policy if exists "platform_config_read" on public.platform_config;
create policy "platform_config_read"
  on public.platform_config
  for select
  using (auth.role() = 'authenticated');

-- 5. Seed initial dynamic platform configs
insert into public.platform_config (key, value, category, description, updated_by)
values
  ('bachs_mode', '"sandbox"', 'payments', 'Active Bachs payment processing gateway mode: sandbox or live', 'kryptopacy@gmail.com'),
  ('platform_fee_percent', '1.5', 'commerce', 'Platform revenue take-rate percentage deducted from storefront sales', 'kryptopacy@gmail.com'),
  ('stripe_connect_enabled', 'true', 'payments', 'Whether alternative Stripe Connect provider toggle is visible in dispensary', 'kryptopacy@gmail.com'),
  ('gemini_model_tier', '"gemini-flash-latest"', 'ai', 'Primary Multimodal LLM engine backing the clinical ADK agent', 'kryptopacy@gmail.com'),
  ('ai_safety_strictness', '"clinical_strict"', 'ai', 'Safety threshold for clinical guideline search and medication dispensing queries', 'kryptopacy@gmail.com'),
  ('maintenance_mode', 'false', 'ops', 'Global maintenance flag for scheduled system upgrades', 'kryptopacy@gmail.com')
on conflict (key) do update set
  description = excluded.description,
  category = excluded.category;

-- 6. Grant execute permissions
grant execute on function internal.is_developer to authenticated, anon;
grant execute on function internal.is_clinic_manager to authenticated, anon;
grant execute on function internal.is_practitioner to authenticated, anon;
grant execute on function internal.is_staff to authenticated, anon;
grant execute on function internal.same_clinic to authenticated, anon;
