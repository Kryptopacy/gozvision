-- Repair the public demo SOS contract used by the judge-facing patient PWA.
--
-- The client has always sent `target`, but the base table did not define it,
-- so PostgREST rejected every write before RLS evaluation (PGRST204). The app
-- is intentionally usable without login for judging, so grant only the one
-- fixed demo patient row to `anon`; all real patient rows still require a JWT.

alter table public.sos_alerts
  add column if not exists target text not null default 'caregiver'
    check (target in ('caregiver', 'clinic', 'caregiver_and_clinic'));

-- The table is exposed through PostgREST. Keep grants explicit; RLS remains on.
grant insert, update, select on table public.sos_alerts to anon;

-- Required because the client uses UPSERT on the primary key. SELECT and UPDATE
-- policies are deliberately scoped to the same fixed demo row.
drop policy if exists sos_demo_select on public.sos_alerts;
create policy sos_demo_select on public.sos_alerts
  for select to anon
  using (
    patient_id = 'demo_patient_001'
    and user_id = 'demo_patient_001'
    and source = 'gemini_live_agent'
  );

drop policy if exists sos_demo_insert on public.sos_alerts;
create policy sos_demo_insert on public.sos_alerts
  for insert to anon
  with check (
    patient_id = 'demo_patient_001'
    and user_id = 'demo_patient_001'
    and type = 'sos'
    and source = 'gemini_live_agent'
    and target in ('caregiver', 'clinic', 'caregiver_and_clinic')
    and severity in ('mild', 'critical', 'info', 'High')
  );

drop policy if exists sos_demo_update on public.sos_alerts;
create policy sos_demo_update on public.sos_alerts
  for update to anon
  using (
    patient_id = 'demo_patient_001'
    and user_id = 'demo_patient_001'
    and source = 'gemini_live_agent'
  )
  with check (
    patient_id = 'demo_patient_001'
    and user_id = 'demo_patient_001'
    and type = 'sos'
    and source = 'gemini_live_agent'
    and target in ('caregiver', 'clinic', 'caregiver_and_clinic')
    and severity in ('mild', 'critical', 'info', 'High')
  );
