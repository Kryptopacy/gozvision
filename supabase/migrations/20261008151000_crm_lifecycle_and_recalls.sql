-- =============================================================================
-- Migration: 20261008151000_crm_lifecycle_and_recalls.sql
-- Description:
--   Expands the clinic CRM engine with automated patient lifecycle pipelines:
--   1. Expands notifications.kind to support optical order pickup, drop refills,
--      post-visit 5-star review requests, and caregiver updates.
--   2. Adds recipient_target ('patient', 'caregiver', 'both') for low-vision care.
--   3. Adds crm_pipelines table for automated practice recall schedules.
-- =============================================================================

-- 1. Expand notifications table
alter table public.notifications
  drop constraint if exists notifications_kind_check;

alter table public.notifications
  add constraint notifications_kind_check
  check (kind in ('reminder', 'recovery', 'recall', 'pickup_ready', 'drop_refill', 'review_request', 'caregiver_update'));

alter table public.notifications
  add column if not exists recipient_target text not null default 'patient'
    check (recipient_target in ('patient', 'caregiver', 'both')),
  add column if not exists patient_name text,
  add column if not exists metadata jsonb default '{}'::jsonb;

-- 2. CRM Pipelines table for automated lifecycle stages
create table if not exists public.crm_recalls (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  patient_id text not null references public.patients (id) on delete cascade,
  patient_name text not null,
  patient_phone text,
  caregiver_phone text,
  pipeline_type text not null
    check (pipeline_type in ('annual_exam', 'glaucoma_check', 'diabetic_screen', 'drop_refill', 'optical_pickup', 'review_request')),
  due_date timestamptz not null,
  last_contacted_at timestamptz,
  status text not null default 'pending'
    check (status in ('pending', 'contacted', 'scheduled', 'completed', 'overdue')),
  recipient_target text not null default 'patient'
    check (recipient_target in ('patient', 'caregiver', 'both')),
  notes text,
  created_at timestamptz not null default now()
);

-- Index for fast clinic queries
create index if not exists idx_crm_recalls_clinic_status
  on public.crm_recalls (clinic_id, status, due_date);

-- Enable RLS on crm_recalls
alter table public.crm_recalls enable row level security;

-- Policies for crm_recalls
drop policy if exists "crm_recalls_clinic_all" on public.crm_recalls;
create policy "crm_recalls_clinic_all"
  on public.crm_recalls
  for all
  using (internal.same_clinic(clinic_id))
  with check (internal.same_clinic(clinic_id));

-- 3. Seed demo CRM recalls for instant testing in clinics
insert into public.crm_recalls (clinic_id, patient_id, patient_name, pipeline_type, due_date, status, recipient_target, notes)
select
  p.clinic_id,
  p.id,
  p.name,
  'annual_exam',
  now() + interval '5 days',
  'pending',
  'both',
  '11-month recall due. Severe low vision. Alert caregiver.'
from public.patients p
where p.clinic_id is not null
limit 1
on conflict do nothing;

insert into public.crm_recalls (clinic_id, patient_id, patient_name, pipeline_type, due_date, status, recipient_target, notes)
select
  p.clinic_id,
  p.id,
  p.name,
  'drop_refill',
  now() + interval '2 days',
  'pending',
  'both',
  'Latanoprost 0.005% bottle approaching 30-day depletion. Auto-reorder prompt.'
from public.patients p
where p.clinic_id is not null
limit 1
on conflict do nothing;

