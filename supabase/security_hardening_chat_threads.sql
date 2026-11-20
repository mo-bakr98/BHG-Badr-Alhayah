-- BHG security hardening: restrict non-admin chat-thread creation.
-- Apply this migration in Supabase SQL Editor.
drop policy if exists "Participants create customer threads" on public.chat_threads;
create policy "Participants create customer threads"
on public.chat_threads for insert to authenticated
with check (
  created_by = auth.uid()
  and thread_type in ('customer','sales')
  and (customer_id is null or customer_id = auth.uid())
  and assigned_to is null
);
