-- Migration: 20261007000000_in_app_chat_and_notifications.sql
-- In-app messaging system between connected parties:
-- Practitioners, Staff, Patients, and Caregivers.
-- Backed by Realtime streams, push notification triggers, and email queues.

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid references public.clinics (id),
  title text,
  participant_ids text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id text not null,
  sender_role text not null check (sender_role in ('Practitioner', 'Staff', 'Patient', 'Caregiver', 'Agent')),
  content text not null,
  attachments jsonb default '[]'::jsonb,
  is_read boolean not null default false,
  email_dispatched boolean not null default false,
  push_dispatched boolean not null default false,
  created_at timestamptz not null default now()
);

-- Index for speedy thread loading
create index if not exists idx_messages_conversation_id on public.messages (conversation_id, created_at asc);
create index if not exists idx_conversations_participants on public.conversations using gin (participant_ids);

-- Enable RLS
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

-- Policies: Authenticated users can read conversations they belong to
create policy "Users can read conversations they participate in"
  on public.conversations for select
  using (
    auth.uid()::text = any(participant_ids) or
    current_setting('app.current_patient_id', true) = any(participant_ids)
  );

create policy "Users can send messages to conversations they participate in"
  on public.messages for insert
  with check (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id
      and (
        auth.uid()::text = any(c.participant_ids) or
        current_setting('app.current_patient_id', true) = any(c.participant_ids)
      )
    )
  );

create policy "Users can view messages in their conversations"
  on public.messages for select
  using (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id
      and (
        auth.uid()::text = any(c.participant_ids) or
        current_setting('app.current_patient_id', true) = any(c.participant_ids)
      )
    )
  );
