-- GozVision initial schema — Postgres + RLS (supersedes firestore.rules, see ADR-0003).
--
-- Conventions:
--  * Patient-scoped ids are TEXT: either a Supabase auth uid or a demo slug
--    (e.g. 'demo_patient_001'). This keeps the zero-UI copilot flow and the
--    authenticated flow uniform (CONTEXT.md — "Patient identity").
--  * Tenancy: clinic-scoped tables carry clinic_id; RLS denies cross-tenant
--    access. Patients may be clinic-prescribed (clinic_id set) or self-serve
--    (clinic_id null).
--  * scribe drafts are jsonb, DRAFT-until-reviewed (never auto-final).

-- ───────────────────────────── clinics (tenant root) ─────────────────────────

create table public.clinics (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  branch text,
  created_at timestamptz not null default now()
);

-- ───────────────────────────── profiles (users) ──────────────────────────────

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  name text not null default '',
  role text not null
    check (role in ('Owner', 'Practitioner', 'Staff', 'Patient', 'Caregiver')),
  clinic_id uuid references public.clinics (id),
  assigned_patients text[] not null default '{}',
  caregiver_phone text,
  created_at timestamptz not null default now()
);

-- ───────────────────────────── patients ──────────────────────────────────────

create table public.patients (
  id text primary key,
  name text not null,
  age int,
  condition text,
  phone text,
  clinic_id uuid references public.clinics (id),
  practitioner_id uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- ───────────────────────── scheduling & clinical records ─────────────────────

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id),
  patient_id text not null references public.patients (id),
  practitioner_id uuid references public.profiles (id),
  type text not null default 'eye exam',
  status text not null default 'scheduled'
    check (status in ('scheduled', 'confirmed', 'completed', 'no_show', 'cancelled')),
  start_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table public.encounters (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id),
  patient_id text not null references public.patients (id),
  practitioner_id uuid references public.profiles (id),
  type text not null default 'exam',
  status text not null default 'completed',
  transcript_text text,
  scribe_draft jsonb not null default '{"status": "none"}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.low_vision_referrals (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id),
  patient_id text not null references public.patients (id),
  from_practitioner_id uuid references public.profiles (id),
  status text not null default 'made'
    check (status in ('made', 'attended', 'lost_to_followup', 'declined')),
  created_at timestamptz not null default now()
);

create table public.device_fits (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id),
  patient_id text not null references public.patients (id),
  encounter_id uuid references public.encounters (id),
  device jsonb not null default '{}'::jsonb,          -- {type, model}
  status text not null default 'trialing'
    check (status in ('trialing', 'prescribed', 'abandoned', 'sustained')),
  trial_ends_at timestamptz,
  recent_signal_count int not null default 0,          -- denormalized by backend jobs
  fit_at timestamptz not null default now()
);

-- Append-only copilot telemetry (structured, no media).
create table public.adherence_signals (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid references public.clinics (id),
  patient_id text not null,
  device_fit_id uuid references public.device_fits (id),
  kind text not null
    check (kind in ('daily_active_use', 'task_completion', 'struggle_detected', 'session_duration')),
  value numeric not null default 1,
  at timestamptz not null default now()
);

-- Recall / no-show outreach queue (gozvision_agent.recall.py enqueues).
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id),
  patient_id text not null,
  appointment_id uuid references public.appointments (id),
  kind text not null check (kind in ('reminder', 'recovery', 'recall')),
  channel text not null default 'sms',
  message text not null,
  status text not null default 'queued' check (status in ('queued', 'sent', 'failed')),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  provider text
);

-- ───────────────────────────── safety: SOS alerts ────────────────────────────

-- GozAI-compatible contract: one current alert per patient (upsert on
-- patient_id). Written by the patient app (client) and the backend agent
-- (service role).
create table public.sos_alerts (
  patient_id text primary key,
  clinic_id uuid references public.clinics (id),
  type text not null default 'sos',
  note text not null,
  severity text not null default 'High',
  location_included boolean not null default false,
  source text not null default 'gemini_live_agent',
  alert_status text not null default 'unacknowledged',
  user_id text not null,
  resolved boolean not null default false,
  updated_at timestamptz not null default now()
);

-- Copilot telemetry for clinicians (O&M / functional-vision events).
create table public.clinical_events (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null,
  kind text not null,                                  -- glare_aversion | ocr_assist | reading_session | ...
  payload jsonb not null default '{}'::jsonb,
  at timestamptz not null default now()
);
create index clinical_events_patient_idx on public.clinical_events (patient_id, at desc);

-- ───────────────────────────── copilot data ──────────────────────────────────

create table public.memory_facts (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  category text not null default 'general',
  fact text not null,
  created_at timestamptz not null default now()
);
create index memory_facts_user_idx on public.memory_facts (user_id, created_at desc);

create table public.transcripts (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null,
  session_id text not null,
  content jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- ───────────────────────────── RLS helpers ───────────────────────────────────

create function public.my_profile()
returns public.profiles
language sql stable security definer set search_path = public
as $$ select * from public.profiles where id = auth.uid() $$;

create function public.my_clinic_id()
returns uuid
language sql stable security definer set search_path = public
as $$ select clinic_id from public.my_profile() $$;

create function public.my_role()
returns text
language sql stable security definer set search_path = public
as $$ select role from public.my_profile() $$;

create function public.is_staff()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(role in ('Practitioner', 'Staff', 'Owner'), false) from public.my_profile() $$;

create function public.is_practitioner()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(role in ('Practitioner', 'Owner'), false) from public.my_profile() $$;

create function public.same_clinic(target uuid)
returns boolean
language sql stable
as $$ select target is not null and target = public.my_clinic_id() $$;

create function public.is_linked_to(patient_id text)
returns boolean
language sql stable security definer set search_path = public
as $$ select patient_id in (select unnest(assigned_patients) from public.my_profile()) $$;

-- ───────────────────────────── RLS policies ──────────────────────────────────

alter table public.clinics enable row level security;
alter table public.profiles enable row level security;
alter table public.patients enable row level security;
alter table public.appointments enable row level security;
alter table public.encounters enable row level security;
alter table public.low_vision_referrals enable row level security;
alter table public.device_fits enable row level security;
alter table public.adherence_signals enable row level security;
alter table public.notifications enable row level security;
alter table public.sos_alerts enable row level security;
alter table public.memory_facts enable row level security;
alter table public.transcripts enable row level security;
alter table public.clinical_events enable row level security;

-- profiles: read own or staff; users manage own non-privileged fields.
create policy profiles_select on public.profiles
  for select using (id = auth.uid() or public.is_staff());
create policy profiles_insert on public.profiles
  for insert with check (id = auth.uid());
create policy profiles_update_self on public.profiles
  for update using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from public.my_profile())
              and clinic_id = (select clinic_id from public.my_profile()));
-- role/clinic_id/assigned_patients changes go through the backend (service role).

-- clinics: members read; owners write.
create policy clinics_select on public.clinics
  for select using (public.same_clinic(id));
create policy clinics_write on public.clinics
  for all using (public.my_role() = 'Owner' and public.same_clinic(id));

-- patients: own record, linked caregiver/practitioner, or same-clinic staff.
create policy patients_select on public.patients
  for select using (
    id = auth.uid()::text
    or public.is_linked_to(id)
    or (public.is_staff() and public.same_clinic(clinic_id))
  );
create policy patients_insert on public.patients
  for insert with check (
    (clinic_id is null and id = auth.uid()::text)
    or (public.is_staff() and public.same_clinic(clinic_id))
  );
create policy patients_update on public.patients
  for update using (
    (id = auth.uid()::text)
    or (public.is_staff() and public.same_clinic(clinic_id))
  );
create policy patients_delete on public.patients
  for delete using (public.is_practitioner() and public.same_clinic(clinic_id));

-- appointments / encounters / referrals / fits: clinic staff manage,
-- patients read their own.
create policy appointments_select on public.appointments
  for select using (public.same_clinic(clinic_id) or patient_id = auth.uid()::text);
create policy appointments_write on public.appointments
  for all using (public.is_staff() and public.same_clinic(clinic_id))
  with check (public.is_staff() and public.same_clinic(clinic_id));

create policy encounters_select on public.encounters
  for select using (public.same_clinic(clinic_id) or patient_id = auth.uid()::text);
create policy encounters_insert on public.encounters
  for insert with check (public.is_staff() and public.same_clinic(clinic_id));
create policy encounters_update on public.encounters
  for update using (public.is_practitioner() and public.same_clinic(clinic_id));
create policy encounters_delete on public.encounters
  for delete using (public.is_practitioner() and public.same_clinic(clinic_id));

create policy referrals_select on public.low_vision_referrals
  for select using (public.same_clinic(clinic_id) or patient_id = auth.uid()::text);
create policy referrals_write on public.low_vision_referrals
  for all using (public.is_staff() and public.same_clinic(clinic_id))
  with check (public.is_staff() and public.same_clinic(clinic_id));

create policy fits_select on public.device_fits
  for select using (public.same_clinic(clinic_id) or patient_id = auth.uid()::text);
create policy fits_write on public.device_fits
  for all using (public.is_staff() and public.same_clinic(clinic_id))
  with check (public.is_staff() and public.same_clinic(clinic_id));

-- adherence signals: patients create for themselves; everything else reads.
create policy signals_select on public.adherence_signals
  for select using (
    public.same_clinic(clinic_id)
    or patient_id = auth.uid()::text
    or public.is_linked_to(patient_id)
  );
create policy signals_insert on public.adherence_signals
  for insert with check (patient_id = auth.uid()::text);

-- notifications: staff of the clinic.
create policy notifications_select on public.notifications
  for select using (public.is_staff() and public.same_clinic(clinic_id));
create policy notifications_insert on public.notifications
  for insert with check (public.is_staff() and public.same_clinic(clinic_id));
create policy notifications_update on public.notifications
  for update using (public.is_staff() and public.same_clinic(clinic_id))
  with check (public.is_staff() and public.same_clinic(clinic_id));
create policy notifications_delete on public.notifications
  for delete using (public.is_practitioner() and public.same_clinic(clinic_id));

-- SOS: patient writes own; linked caregivers + clinic staff read.
create policy sos_select on public.sos_alerts
  for select using (
    patient_id = auth.uid()::text
    or public.is_linked_to(patient_id)
    or (public.is_staff() and public.same_clinic(clinic_id))
  );
create policy sos_write on public.sos_alerts
  for all using (patient_id = auth.uid()::text)
  with check (patient_id = auth.uid()::text);

-- memory + transcripts: the patient (or linked caregiver reads).
create policy memory_select on public.memory_facts
  for select using (user_id = auth.uid()::text or public.is_linked_to(user_id));
create policy memory_write on public.memory_facts
  for all using (user_id = auth.uid()::text)
  with check (user_id = auth.uid()::text);

create policy transcripts_all on public.transcripts
  for all using (patient_id = auth.uid()::text)
  with check (patient_id = auth.uid()::text);

-- clinical events: the patient writes own telemetry; clinic staff read.
create policy clinical_events_select on public.clinical_events
  for select using (patient_id = auth.uid()::text or public.is_linked_to(patient_id));
create policy clinical_events_insert on public.clinical_events
  for insert with check (patient_id = auth.uid()::text);

-- ───────────────────────────── realtime ──────────────────────────────────────

-- Streams used by the apps (supabase_flutter .stream() / Realtime).
alter publication supabase_realtime add table public.sos_alerts;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.appointments;
alter publication supabase_realtime add table public.encounters;
alter publication supabase_realtime add table public.low_vision_referrals;
alter publication supabase_realtime add table public.device_fits;
alter publication supabase_realtime add table public.adherence_signals;
alter publication supabase_realtime add table public.memory_facts;

-- ───────────────────────────── indexes ───────────────────────────────────────

create index appointments_clinic_start_idx on public.appointments (clinic_id, start_at);
create index encounters_clinic_idx on public.encounters (clinic_id, created_at desc);
create index referrals_clinic_idx on public.low_vision_referrals (clinic_id);
create index fits_clinic_idx on public.device_fits (clinic_id);
create index signals_patient_idx on public.adherence_signals (patient_id, at desc);
create index notifications_clinic_idx on public.notifications (clinic_id, created_at desc);
