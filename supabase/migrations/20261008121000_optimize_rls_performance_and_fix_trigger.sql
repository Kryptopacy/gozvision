-- Migration: 20261008120000_optimize_rls_performance_and_fix_trigger.sql
-- Fixes:
--  1. 0028/0029 (handle_new_user): Move trigger function to `internal` schema and drop from `public`
--  2. 0003 (auth_rls_initplan): Wrap auth.uid() and current_setting() in (select ...) across all policies
--  3. 0006 (multiple_permissive_policies): Replace `FOR ALL` write policies with dedicated INSERT/UPDATE/DELETE policies

-- ───────────────────────────── 1. Move Auth Trigger to internal ──────────────

create or replace function internal.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, internal
as $$
declare
  raw_role text;
  display_name text;
begin
  raw_role := coalesce(new.raw_user_meta_data->>'role', 'Patient');
  if raw_role not in ('Patient', 'Caregiver') then
    raw_role := 'Patient';
  end if;

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

-- Point auth trigger to internal function
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function internal.handle_new_user();

-- Drop exposed function from public schema so PostgREST doesn't publish /rpc/handle_new_user
drop function if exists public.handle_new_user();

-- ───────────────────────────── 2. Profiles RLS ────────────────────────────────

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select using (id = (select auth.uid()) or internal.is_staff());

drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles
  for insert with check (
    id = (select auth.uid())
    and role in ('Patient', 'Caregiver')
    and clinic_id is null
  );

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update using (id = (select auth.uid()))
  with check (
    id = (select auth.uid())
    and role = (select role from internal.my_profile())
    and clinic_id = (select clinic_id from internal.my_profile())
  );

-- ───────────────────────────── 3. Clinics RLS ─────────────────────────────────

drop policy if exists clinics_select on public.clinics;
create policy clinics_select on public.clinics
  for select using (internal.same_clinic(id));

drop policy if exists clinics_write on public.clinics;
drop policy if exists clinics_insert on public.clinics;
create policy clinics_insert on public.clinics
  for insert with check (internal.my_role() = 'Owner' and internal.same_clinic(id));

drop policy if exists clinics_update on public.clinics;
create policy clinics_update on public.clinics
  for update using (internal.my_role() = 'Owner' and internal.same_clinic(id))
  with check (internal.my_role() = 'Owner' and internal.same_clinic(id));

drop policy if exists clinics_delete on public.clinics;
create policy clinics_delete on public.clinics
  for delete using (internal.my_role() = 'Owner' and internal.same_clinic(id));

-- ───────────────────────────── 4. Patients RLS ────────────────────────────────

drop policy if exists patients_select on public.patients;
create policy patients_select on public.patients
  for select using (
    id = (select auth.uid())::text
    or internal.is_linked_to(id)
    or (internal.is_staff() and internal.same_clinic(clinic_id))
  );

drop policy if exists patients_insert on public.patients;
create policy patients_insert on public.patients
  for insert with check (
    (clinic_id is null and id = (select auth.uid())::text)
    or (internal.is_staff() and internal.same_clinic(clinic_id))
  );

drop policy if exists patients_update on public.patients;
create policy patients_update on public.patients
  for update using (
    (id = (select auth.uid())::text)
    or (internal.is_staff() and internal.same_clinic(clinic_id))
  );

drop policy if exists patients_delete on public.patients;
create policy patients_delete on public.patients
  for delete using (internal.is_practitioner() and internal.same_clinic(clinic_id));

-- ───────────────────────────── 5. Appointments RLS ────────────────────────────

drop policy if exists appointments_select on public.appointments;
create policy appointments_select on public.appointments
  for select using (internal.same_clinic(clinic_id) or patient_id = (select auth.uid())::text);

drop policy if exists appointments_write on public.appointments;
drop policy if exists appointments_insert on public.appointments;
create policy appointments_insert on public.appointments
  for insert with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists appointments_update on public.appointments;
create policy appointments_update on public.appointments
  for update using (internal.is_staff() and internal.same_clinic(clinic_id))
  with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists appointments_delete on public.appointments;
create policy appointments_delete on public.appointments
  for delete using (internal.is_staff() and internal.same_clinic(clinic_id));

-- ───────────────────────────── 6. Encounters RLS ──────────────────────────────

drop policy if exists encounters_select on public.encounters;
create policy encounters_select on public.encounters
  for select using (internal.same_clinic(clinic_id) or patient_id = (select auth.uid())::text);

drop policy if exists encounters_insert on public.encounters;
create policy encounters_insert on public.encounters
  for insert with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists encounters_update on public.encounters;
create policy encounters_update on public.encounters
  for update using (internal.is_practitioner() and internal.same_clinic(clinic_id));

drop policy if exists encounters_delete on public.encounters;
create policy encounters_delete on public.encounters
  for delete using (internal.is_practitioner() and internal.same_clinic(clinic_id));

-- ───────────────────────────── 7. Low Vision Referrals RLS ────────────────────

drop policy if exists referrals_select on public.low_vision_referrals;
create policy referrals_select on public.low_vision_referrals
  for select using (internal.same_clinic(clinic_id) or patient_id = (select auth.uid())::text);

drop policy if exists referrals_write on public.low_vision_referrals;
drop policy if exists referrals_insert on public.low_vision_referrals;
create policy referrals_insert on public.low_vision_referrals
  for insert with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists referrals_update on public.low_vision_referrals;
create policy referrals_update on public.low_vision_referrals
  for update using (internal.is_staff() and internal.same_clinic(clinic_id))
  with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists referrals_delete on public.low_vision_referrals;
create policy referrals_delete on public.low_vision_referrals
  for delete using (internal.is_staff() and internal.same_clinic(clinic_id));

-- ───────────────────────────── 8. Device Fits RLS ─────────────────────────────

drop policy if exists fits_select on public.device_fits;
create policy fits_select on public.device_fits
  for select using (internal.same_clinic(clinic_id) or patient_id = (select auth.uid())::text);

drop policy if exists fits_write on public.device_fits;
drop policy if exists fits_insert on public.device_fits;
create policy fits_insert on public.device_fits
  for insert with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists fits_update on public.device_fits;
create policy fits_update on public.device_fits
  for update using (internal.is_staff() and internal.same_clinic(clinic_id))
  with check (internal.is_staff() and internal.same_clinic(clinic_id));

drop policy if exists fits_delete on public.device_fits;
create policy fits_delete on public.device_fits
  for delete using (internal.is_staff() and internal.same_clinic(clinic_id));

-- ───────────────────────────── 9. Adherence Signals RLS ───────────────────────

drop policy if exists signals_select on public.adherence_signals;
create policy signals_select on public.adherence_signals
  for select using (
    internal.same_clinic(clinic_id)
    or patient_id = (select auth.uid())::text
    or internal.is_linked_to(patient_id)
  );

drop policy if exists signals_insert on public.adherence_signals;
create policy signals_insert on public.adherence_signals
  for insert with check (patient_id = (select auth.uid())::text);

-- ───────────────────────────── 10. SOS Alerts RLS ─────────────────────────────

drop policy if exists sos_select on public.sos_alerts;
create policy sos_select on public.sos_alerts
  for select using (
    patient_id = (select auth.uid())::text
    or internal.is_linked_to(patient_id)
    or (internal.is_staff() and internal.same_clinic(clinic_id))
  );

drop policy if exists sos_write on public.sos_alerts;
drop policy if exists sos_insert on public.sos_alerts;
create policy sos_insert on public.sos_alerts
  for insert with check (patient_id = (select auth.uid())::text);

drop policy if exists sos_update on public.sos_alerts;
create policy sos_update on public.sos_alerts
  for update using (patient_id = (select auth.uid())::text)
  with check (patient_id = (select auth.uid())::text);

drop policy if exists sos_delete on public.sos_alerts;
create policy sos_delete on public.sos_alerts
  for delete using (patient_id = (select auth.uid())::text);

-- ───────────────────────────── 11. Memory Facts RLS ───────────────────────────

drop policy if exists memory_select on public.memory_facts;
create policy memory_select on public.memory_facts
  for select using (user_id = (select auth.uid())::text or internal.is_linked_to(user_id));

drop policy if exists memory_write on public.memory_facts;
drop policy if exists memory_insert on public.memory_facts;
create policy memory_insert on public.memory_facts
  for insert with check (user_id = (select auth.uid())::text);

drop policy if exists memory_update on public.memory_facts;
create policy memory_update on public.memory_facts
  for update using (user_id = (select auth.uid())::text)
  with check (user_id = (select auth.uid())::text);

drop policy if exists memory_delete on public.memory_facts;
create policy memory_delete on public.memory_facts
  for delete using (user_id = (select auth.uid())::text);

-- ───────────────────────────── 12. Transcripts RLS ────────────────────────────

drop policy if exists transcripts_all on public.transcripts;
drop policy if exists transcripts_select on public.transcripts;
create policy transcripts_select on public.transcripts
  for select using (patient_id = (select auth.uid())::text);

drop policy if exists transcripts_insert on public.transcripts;
create policy transcripts_insert on public.transcripts
  for insert with check (patient_id = (select auth.uid())::text);

drop policy if exists transcripts_update on public.transcripts;
create policy transcripts_update on public.transcripts
  for update using (patient_id = (select auth.uid())::text)
  with check (patient_id = (select auth.uid())::text);

drop policy if exists transcripts_delete on public.transcripts;
create policy transcripts_delete on public.transcripts
  for delete using (patient_id = (select auth.uid())::text);

-- ───────────────────────────── 13. Clinical Events RLS ────────────────────────

drop policy if exists clinical_events_select on public.clinical_events;
create policy clinical_events_select on public.clinical_events
  for select using (patient_id = (select auth.uid())::text or internal.is_linked_to(patient_id));

drop policy if exists clinical_events_insert on public.clinical_events;
create policy clinical_events_insert on public.clinical_events
  for insert with check (patient_id = (select auth.uid())::text);

-- ───────────────────────────── 14. Conversations RLS ──────────────────────────

drop policy if exists "Users can read conversations they participate in" on public.conversations;
create policy "Users can read conversations they participate in"
  on public.conversations for select
  using (
    (select auth.uid())::text = any(participant_ids) or
    (select current_setting('app.current_patient_id', true)) = any(participant_ids)
  );

drop policy if exists "Users can start conversations they belong to" on public.conversations;
create policy "Users can start conversations they belong to"
  on public.conversations for insert
  with check (
    (select auth.uid())::text = any(participant_ids) or
    (select current_setting('app.current_patient_id', true)) = any(participant_ids)
  );

drop policy if exists "Users can update conversations they belong to" on public.conversations;
create policy "Users can update conversations they belong to"
  on public.conversations for update
  using (
    (select auth.uid())::text = any(participant_ids) or
    (select current_setting('app.current_patient_id', true)) = any(participant_ids)
  )
  with check (
    (select auth.uid())::text = any(participant_ids) or
    (select current_setting('app.current_patient_id', true)) = any(participant_ids)
  );

-- ───────────────────────────── 15. Messages RLS ───────────────────────────────

drop policy if exists "Users can view messages in their conversations" on public.messages;
create policy "Users can view messages in their conversations"
  on public.messages for select
  using (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id
      and (
        (select auth.uid())::text = any(c.participant_ids) or
        (select current_setting('app.current_patient_id', true)) = any(c.participant_ids)
      )
    )
  );

drop policy if exists "Users can send messages to conversations they participate in" on public.messages;
create policy "Users can send messages to conversations they participate in"
  on public.messages for insert
  with check (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id
      and (
        (select auth.uid())::text = any(c.participant_ids) or
        (select current_setting('app.current_patient_id', true)) = any(c.participant_ids)
      )
    )
  );
