-- Migration: 20261008101500_secure_rls_functions.sql
-- Fix Supabase Database Linter warnings:
--  1. 0011_function_search_path_mutable (public.same_clinic)
--  2. 0028_anon_security_definer_function_executable (public.* RLS helpers)
--  3. 0029_authenticated_security_definer_function_executable (public.* RLS helpers)
--
-- Solution:
-- Internal RLS helpers are moved to an unexposed `internal` schema with pinned search_path.
-- PostgREST only exposes `public`, preventing RPC endpoint generation (/rest/v1/rpc/*),
-- while database roles (authenticated, anon) retain execution rights inside RLS policies.

-- ───────────────────────────── 1. Internal Schema ─────────────────────────────

create schema if not exists internal;

-- Grant usage on internal schema so RLS policies can evaluate functions
grant usage on schema internal to authenticated, anon;

-- ───────────────────────── 2. Secure RLS Helper Functions ─────────────────────

create or replace function internal.my_profile()
returns public.profiles
language sql stable security definer
set search_path = public
as $$
  select * from public.profiles where id = auth.uid()
$$;

create or replace function internal.my_clinic_id()
returns uuid
language sql stable security definer
set search_path = public, internal
as $$
  select clinic_id from internal.my_profile()
$$;

create or replace function internal.my_role()
returns text
language sql stable security definer
set search_path = public, internal
as $$
  select role from internal.my_profile()
$$;

create or replace function internal.is_staff()
returns boolean
language sql stable security definer
set search_path = public, internal
as $$
  select coalesce(role in ('Practitioner', 'Staff', 'Owner'), false) from internal.my_profile()
$$;

create or replace function internal.is_practitioner()
returns boolean
language sql stable security definer
set search_path = public, internal
as $$
  select coalesce(role in ('Practitioner', 'Owner'), false) from internal.my_profile()
$$;

create or replace function internal.same_clinic(target uuid)
returns boolean
language sql stable
set search_path = public, internal
as $$
  select target is not null and target = internal.my_clinic_id()
$$;

create or replace function internal.is_linked_to(patient_id text)
returns boolean
language sql stable security definer
set search_path = public, internal
as $$
  select patient_id in (select unnest(assigned_patients) from internal.my_profile())
$$;

-- Grant execution to DB roles for RLS policy evaluation
grant execute on all functions in schema internal to authenticated, anon;
alter default privileges in schema internal grant execute on functions to authenticated, anon;

-- ───────────────────────── 3. Update Existing RLS Policies ────────────────────

-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select using (id = auth.uid() or internal.is_staff());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from internal.my_profile())
              and clinic_id = (select clinic_id from internal.my_profile()));

-- clinics
drop policy if exists clinics_select on public.clinics;
create policy clinics_select on public.clinics
  for select using (internal.same_clinic(id));

drop policy if exists clinics_write on public.clinics;
create policy clinics_write on public.clinics
  for all using (internal.my_role() = 'Owner' and internal.same_clinic(id));

-- patients
drop policy if exists patients_select on public.patients;
create policy patients_select on public.patients
  for select using (
    id = auth.uid()::text
    or internal.is_linked_to(id)
    or (internal.is_staff() and internal.same_clinic(clinic_id))
  );

drop policy if exists patients_insert on public.patients;
create policy patients_insert on public.patients
  for insert with check (
    (clinic_id is null and id = auth.uid()::text)
    or (internal.is_staff() and internal.same_clinic(clinic_id))
  );

drop policy if exists patients_update on public.patients;
create policy patients_update on public.patients
  for update using (
    (id = auth.uid()::text)
    or (internal.is_staff() and internal.same_clinic(clinic_id))
  );

drop policy if exists patients_delete on public.patients;
create policy patients_delete on public.patients
  for delete using (internal.is_practitioner() and internal.same_clinic(clinic_id));

-- appointments
drop policy if exists appointments_select on public.appointments;
create policy appointments_select on public.appointments
  for select using (internal.same_clinic(clinic_id) or patient_id = auth.uid()::text);

drop policy if exists appointments_write on public.appointments;
create policy appointments_write on public.appointments
  for all using (internal.is_staff() and internal.same_clinic(clinic_id))
  with check (internal.is_staff() and internal.same_clinic(clinic_id));

-- encounters
drop policy if exists encounters_select on public.encounters;
create policy encounters_select on public.encounters
  for select using (internal.same_clinic(clinic_id) or patient_id = auth.uid()::text);

drop policy if exists encounters_insert on public.encounters;
create policy encounters_insert on public.encounters
  for insert with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists encounters_update on public.encounters;
create policy encounters_update on public.encounters
  for update using (internal.is_practitioner() and internal.same_clinic(clinic_id));

drop policy if exists encounters_delete on public.encounters;
create policy encounters_delete on public.encounters
  for delete using (internal.is_practitioner() and internal.same_clinic(clinic_id));

-- low_vision_referrals
drop policy if exists referrals_select on public.low_vision_referrals;
create policy referrals_select on public.low_vision_referrals
  for select using (internal.same_clinic(clinic_id) or patient_id = auth.uid()::text);

drop policy if exists referrals_write on public.low_vision_referrals;
create policy referrals_write on public.low_vision_referrals
  for all using (internal.is_staff() and internal.same_clinic(clinic_id))
  with check (internal.is_staff() and internal.same_clinic(clinic_id));

-- device_fits
drop policy if exists fits_select on public.device_fits;
create policy fits_select on public.device_fits
  for select using (internal.same_clinic(clinic_id) or patient_id = auth.uid()::text);

drop policy if exists fits_write on public.device_fits;
create policy fits_write on public.device_fits
  for all using (internal.is_staff() and internal.same_clinic(clinic_id))
  with check (internal.is_staff() and internal.same_clinic(clinic_id));

-- adherence_signals
drop policy if exists signals_select on public.adherence_signals;
create policy signals_select on public.adherence_signals
  for select using (
    internal.same_clinic(clinic_id)
    or patient_id = auth.uid()::text
    or internal.is_linked_to(patient_id)
  );

-- notifications
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
  for select using (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists notifications_insert on public.notifications;
create policy notifications_insert on public.notifications
  for insert with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications
  for update using (internal.is_staff() and internal.same_clinic(clinic_id))
  with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists notifications_delete on public.notifications;
create policy notifications_delete on public.notifications
  for delete using (internal.is_practitioner() and internal.same_clinic(clinic_id));

-- sos_alerts
drop policy if exists sos_select on public.sos_alerts;
create policy sos_select on public.sos_alerts
  for select using (
    patient_id = auth.uid()::text
    or internal.is_linked_to(patient_id)
    or (internal.is_staff() and internal.same_clinic(clinic_id))
  );

-- memory_facts
drop policy if exists memory_select on public.memory_facts;
create policy memory_select on public.memory_facts
  for select using (user_id = auth.uid()::text or internal.is_linked_to(user_id));

-- clinical_events
drop policy if exists clinical_events_select on public.clinical_events;
create policy clinical_events_select on public.clinical_events
  for select using (patient_id = auth.uid()::text or internal.is_linked_to(patient_id));

-- ───────────────────────── 4. Drop Old Public Functions ───────────────────────

drop function if exists public.is_linked_to(text);
drop function if exists public.is_practitioner();
drop function if exists public.is_staff();
drop function if exists public.same_clinic(uuid);
drop function if exists public.my_role();
drop function if exists public.my_clinic_id();
drop function if exists public.my_profile();
