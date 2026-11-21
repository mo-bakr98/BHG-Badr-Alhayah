-- BHG read-only security audit queries.
-- Run in Supabase SQL Editor. These queries do not modify data or policies.

-- 1) RLS enabled/disabled for public tables.
select schemaname, tablename, rowsecurity, forcerowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;

-- 2) Policies on public tables.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 3) Storage policies (especially property-images bucket).
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'storage'
order by tablename, policyname;

-- 4) Table grants to anon/authenticated (review broad grants alongside RLS).
select table_schema, table_name, grantee, privilege_type
from information_schema.table_privileges
where table_schema in ('public','storage')
  and grantee in ('anon','authenticated')
order by table_schema, table_name, grantee, privilege_type;

-- 5) Bucket visibility and configuration.
select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
order by id;
