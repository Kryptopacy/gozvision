-- Migration: 20261008110000_auth_trigger_indexes_chat_policies.sql
-- 1. Index critical foreign keys for tenant, patient, and conversation lookups
-- 2. Realtime publication for in-app chat
-- 3. In-app conversations INSERT policy
-- 4. Automated user profile creation trigger on auth.users (works for email + Google OAuth)
-- 5. Harden profiles_insert policy against privilege escalation

-- ───────────────────────────── 1. Foreign Key & Query Indexes ─────────────────

create index if not exists idx_patients_clinic on public.patients (clinic_id);
create index if not exists idx_patients_practitioner on public.patients (practitioner_id);
create index if not exists idx_profiles_clinic on public.profiles (clinic_id);
create index if not exists idx_appointments_patient on public.appointments (patient_id);
create index if not exists idx_encounters_patient on public.encounters (patient_id);
create index if not exists idx_referrals_patient on public.low_vision_referrals (patient_id);
create index if not exists idx_fits_patient on public.device_fits (patient_id);
create index if not exists idx_signals_clinic on public.adherence_signals (clinic_id);
create index if not exists idx_notifications_patient on public.notifications (patient_id);
create index if not exists idx_sos_clinic on public.sos_alerts (clinic_id);
create index if not exists idx_conversations_clinic on public.conversations (clinic_id);

-- ───────────────────────────── 2. Realtime for In-App Chat ─────────────────────

alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.messages;

-- ───────────────────────────── 3. Conversations Policies ──────────────────────

-- Allow participants to initiate new conversations
create policy "Users can start conversations they belong to"
  on public.conversations for insert
  with check (
    auth.uid()::text = any(participant_ids) or
    current_setting('app.current_patient_id', true) = any(participant_ids)
  );

-- Allow participants to update conversations (e.g. title, timestamps)
create policy "Users can update conversations they belong to"
  on public.conversations for update
  using (
    auth.uid()::text = any(participant_ids) or
    current_setting('app.current_patient_id', true) = any(participant_ids)
  )
  with check (
    auth.uid()::text = any(participant_ids) or
    current_setting('app.current_patient_id', true) = any(participant_ids)
  );

-- ───────────────────────────── 4. Auth Trigger on auth.users ──────────────────

-- Automatically creates public.profiles row when a new user signs up
-- Works for both Email/Password and OAuth providers (Google, Apple, etc.)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  raw_role text;
  display_name text;
begin
  -- Resolve role, defaulting to Patient for self-registered users
  raw_role := coalesce(new.raw_user_meta_data->>'role', 'Patient');
  if raw_role not in ('Patient', 'Caregiver') then
    raw_role := 'Patient';
  end if;

  -- Extract display name (Google OAuth passes full_name or name)
  display_name := coalesce(
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'full_name',
    split_part(new.email, '@', 1)
  );

  insert into public.profiles (id, email, name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    display_name,
    raw_role
  )
  on conflict (id) do update set
    email = excluded.email,
    name = case when public.profiles.name = '' then excluded.name else public.profiles.name end;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────────────────────── 5. Harden profiles_insert Policy ───────────────

-- Prevent public callers from escalating their own role or claiming clinic ownership
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles
  for insert with check (
    id = auth.uid()
    and role in ('Patient', 'Caregiver')
    and clinic_id is null
  );
