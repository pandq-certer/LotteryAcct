-- Fix: allow UPDATE to change status from 'pending' by adding explicit WITH CHECK clause.
-- Without WITH CHECK, PostgreSQL defaults to the USING clause, which requires status = 'pending'
-- on the NEW row — that fails when setting status to 'approved' or 'rejected'.

drop policy if exists "Non-requester can resolve approvals" on public.approval_requests;

create policy "Non-requester can resolve approvals" on public.approval_requests
  for update using (auth.uid() != requested_by and status = 'pending')
  with check (auth.uid() != requested_by);
