-- Approval workflow step 1: add enum value and create table

-- ═══════════════════════════════════════════
-- ENUMS
-- ═══════════════════════════════════════════
create type public.approval_status as enum ('pending', 'approved', 'rejected');
create type public.approval_op as enum ('create', 'settle', 'delete');

alter type public.bet_status add value 'awaiting_approval' before 'pending';

-- ═══════════════════════════════════════════
-- APPROVAL REQUESTS TABLE
-- ═══════════════════════════════════════════
create table public.approval_requests (
  id uuid primary key default gen_random_uuid(),
  operation public.approval_op not null,
  record_id uuid references public.betting_records(id) on delete cascade,
  payload jsonb not null default '{}',
  requested_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  status public.approval_status not null default 'pending',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

alter table public.approval_requests enable row level security;

create policy "Authenticated users can view approvals" on public.approval_requests
  for select using (auth.role() = 'authenticated');

create policy "Authenticated users can create approvals" on public.approval_requests
  for insert with check (auth.role() = 'authenticated');

create policy "Non-requester can resolve approvals" on public.approval_requests
  for update using (auth.uid() != requested_by and status = 'pending');

create policy "Requester can cancel own approvals" on public.approval_requests
  for delete using (auth.uid() = requested_by and status = 'pending');

-- ═══════════════════════════════════════════
-- REALTIME
-- ═══════════════════════════════════════════
alter publication supabase_realtime add table public.approval_requests;
