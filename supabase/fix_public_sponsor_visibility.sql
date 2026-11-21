-- BHG public sponsor visibility fix.
-- Safe to run in Supabase SQL Editor. Makes only active, in-date sponsors publicly readable.
alter table public.sponsors enable row level security;
grant select on public.sponsors to anon, authenticated;
drop policy if exists "Public read active sponsors" on public.sponsors;
create policy "Public read active sponsors"
on public.sponsors
for select
to anon, authenticated
using (
  active = true
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at >= now())
);

-- Sponsor/property images are intentionally public listing assets served by public URLs.
update storage.buckets
set public = true
where id = 'property-images';
