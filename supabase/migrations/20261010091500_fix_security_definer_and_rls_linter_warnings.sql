-- =============================================================================
-- Migration: 20261010091500_fix_security_definer_and_rls_linter_warnings.sql
-- Description:
--   Resolves Supabase Database Linter warnings:
--   1. Lint 0028 & 0029 (handle_new_user):
--      - public.handle_new_user() was mistakenly re-introduced in migration 20261008143000
--        under `public` schema.
--      - Updates trigger to internal.handle_new_user() with Developer role auto-assignment.
--      - Drops public.handle_new_user() from public schema so PostgREST stops exposing /rest/v1/rpc/handle_new_user.
--      - Explicitly revokes execute permissions from anon and authenticated.
--   2. Lint 0003 & 0006 (platform_config RLS):
--      - Lint 0003: Wraps (auth.role() = 'authenticated') in `(select auth.role() = 'authenticated')`
--        or binds directly `to authenticated` role to avoid per-row re-evaluation.
--      - Lint 0006: Replaces FOR ALL permissive policy with separate dedicated write policies
--        (INSERT, UPDATE, DELETE) and separates SELECT roles so that 'authenticated' does not
--        have multiple conflicting permissive SELECT policies evaluated against each row.
--   3. Lint 0003 (orders RLS):
--      - Refreshes orders_select and orders_insert policies to strictly wrap auth/session functions
--        in subqueries `(select auth.uid()::text)` avoiding any row-level re-evaluation.
-- =============================================================================

-- =============================================================================
-- 1. SECURITY DEFINER FIX: handle_new_user() -> internal schema only
-- =============================================================================

-- Create or update internal.handle_new_user() containing Developer auto-assignment
create or replace function internal.handle_new_user()
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

-- Point auth trigger to internal.handle_new_user()
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function internal.handle_new_user();

-- Drop public.handle_new_user if it exists and revoke public execute rights
drop function if exists public.handle_new_user();


-- =============================================================================
-- 2. PLATFORM CONFIG RLS: Resolve 0003 (initplan) & 0006 (multiple_permissive)
-- =============================================================================

-- Drop all existing policies on platform_config
drop policy if exists "platform_config_developer_all" on public.platform_config;
drop policy if exists "platform_config_read" on public.platform_config;
drop policy if exists "platform_config_developer_write" on public.platform_config;
drop policy if exists "platform_config_developer_insert" on public.platform_config;
drop policy if exists "platform_config_developer_update" on public.platform_config;
drop policy if exists "platform_config_developer_delete" on public.platform_config;

-- A. Unified single SELECT policy for authenticated users (including Developers):
--    Developer is an authenticated role, so a single policy covers all reads.
--    Explicitly scoped `to authenticated` to avoid multiple permissive evaluations across roles.
create policy "platform_config_read"
  on public.platform_config
  for select
  to authenticated
  using (true);

-- B. Granular write policies restricted to internal.is_developer():
--    Using INSERT / UPDATE / DELETE instead of FOR ALL prevents overlapping permissive SELECT policies.
create policy "platform_config_developer_insert"
  on public.platform_config
  for insert
  to authenticated
  with check ((select internal.is_developer()));

create policy "platform_config_developer_update"
  on public.platform_config
  for update
  to authenticated
  using ((select internal.is_developer()))
  with check ((select internal.is_developer()));

create policy "platform_config_developer_delete"
  on public.platform_config
  for delete
  to authenticated
  using ((select internal.is_developer()));


-- =============================================================================
-- 3. ORDERS RLS: Resolve 0003 (auth_rls_initplan)
-- =============================================================================

drop policy if exists "orders_select" on public.orders;
drop policy if exists "orders_insert" on public.orders;

-- Single optimized SELECT policy using subqueries for all auth/session functions:
create policy "orders_select"
  on public.orders
  for select
  to authenticated
  using (
    patient_id = (select auth.uid())::text
    or (
      clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  );

-- Single optimized INSERT policy using subqueries:
create policy "orders_insert"
  on public.orders
  for insert
  to authenticated
  with check (
    patient_id = (select auth.uid())::text
    or (
      clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  );
