-- BHG platform expansion: sponsors, memberships, users, chat, sales
-- Run once in Supabase SQL Editor. Existing properties/leads/admin_users are preserved.
create or replace function public.is_bhg_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.admin_users au
    where au.user_id = auth.uid() and au.role = 'admin'
  );
$$;

grant execute on function public.is_bhg_admin() to anon, authenticated;

create table if not exists public.platform_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  phone text,
  account_type text not null default 'customer' check (account_type in ('customer','seller','employee')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sponsors (
  id uuid primary key default gen_random_uuid(),
  company_name text not null,
  logo_url text,
  image_url text,
  ad_text text,
  target_url text,
  placement text not null default 'banner' check (placement in ('banner','sidebar','featured')),
  tier text not null default 'standard' check (tier in ('standard','featured','main')),
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price numeric(12,2) not null default 0 check (price >= 0),
  duration_days integer not null default 30 check (duration_days > 0),
  features jsonb not null default '[]'::jsonb,
  account_type text not null default 'customer' check (account_type in ('customer','seller','employee')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid references public.subscription_plans(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','active','expired','cancelled')),
  starts_at timestamptz,
  ends_at timestamptz,
  payment_reference text,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  thread_type text not null default 'customer' check (thread_type in ('customer','staff','sales')),
  title text,
  created_by uuid references auth.users(id) on delete set null,
  property_id uuid,
  customer_id uuid references auth.users(id) on delete set null,
  assigned_to uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_participants (
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_read_at timestamptz,
  joined_at timestamptz not null default now(),
  primary key (thread_id,user_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text,
  attachment_url text,
  created_at timestamptz not null default now(),
  constraint chat_message_content check (nullif(trim(coalesce(body,'')),'') is not null or attachment_url is not null)
);

create table if not exists public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid references auth.users(id) on delete set null,
  seller_id uuid references auth.users(id) on delete set null,
  property_id uuid,
  order_type text not null default 'inquiry' check (order_type in ('inquiry','reservation','sale')),
  status text not null default 'new' check (status in ('new','contacted','pending','confirmed','completed','cancelled')),
  amount numeric(12,2) check (amount is null or amount >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists sponsors_active_idx on public.sponsors(active,starts_at,ends_at);
create index if not exists subscriptions_user_idx on public.user_subscriptions(user_id,status);
create index if not exists chat_participants_user_idx on public.chat_participants(user_id);
create index if not exists chat_messages_thread_idx on public.chat_messages(thread_id,created_at);
create index if not exists sales_buyer_idx on public.sales_orders(buyer_id,created_at);
create index if not exists sales_seller_idx on public.sales_orders(seller_id,created_at);

alter table public.platform_profiles enable row level security;
alter table public.sponsors enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.user_subscriptions enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;
alter table public.sales_orders enable row level security;

-- Admin policies
drop policy if exists "BHG admins manage profiles" on public.platform_profiles;
create policy "BHG admins manage profiles" on public.platform_profiles for all to authenticated using (public.is_bhg_admin()) with check (public.is_bhg_admin());
drop policy if exists "BHG admins manage sponsors" on public.sponsors;
create policy "BHG admins manage sponsors" on public.sponsors for all to authenticated using (public.is_bhg_admin()) with check (public.is_bhg_admin());
drop policy if exists "BHG admins manage plans" on public.subscription_plans;
create policy "BHG admins manage plans" on public.subscription_plans for all to authenticated using (public.is_bhg_admin()) with check (public.is_bhg_admin());
drop policy if exists "BHG admins manage subscriptions" on public.user_subscriptions;
create policy "BHG admins manage subscriptions" on public.user_subscriptions for all to authenticated using (public.is_bhg_admin()) with check (public.is_bhg_admin());
drop policy if exists "BHG admins manage threads" on public.chat_threads;
create policy "BHG admins manage threads" on public.chat_threads for all to authenticated using (public.is_bhg_admin()) with check (public.is_bhg_admin());
drop policy if exists "BHG admins manage participants" on public.chat_participants;
create policy "BHG admins manage participants" on public.chat_participants for all to authenticated using (public.is_bhg_admin()) with check (public.is_bhg_admin());
drop policy if exists "BHG admins manage messages" on public.chat_messages;
create policy "BHG admins manage messages" on public.chat_messages for all to authenticated using (public.is_bhg_admin()) with check (public.is_bhg_admin());
drop policy if exists "BHG admins manage sales" on public.sales_orders;
create policy "BHG admins manage sales" on public.sales_orders for all to authenticated using (public.is_bhg_admin()) with check (public.is_bhg_admin());

-- Users can view and update only their own profile (role/account type is not user-editable).
drop policy if exists "Users read own profile" on public.platform_profiles;
create policy "Users read own profile" on public.platform_profiles for select to authenticated using (user_id=auth.uid() or public.is_bhg_admin());
drop policy if exists "Users insert own customer profile" on public.platform_profiles;
create policy "Users insert own customer profile" on public.platform_profiles for insert to authenticated with check (user_id=auth.uid() and account_type='customer' and active=true);
drop policy if exists "Users update own profile details" on public.platform_profiles;
create policy "Users update own profile details" on public.platform_profiles for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid() and account_type='customer');

-- Public sponsors/plans are read-only and limited to active items.
drop policy if exists "Public read active sponsors" on public.sponsors;
create policy "Public read active sponsors" on public.sponsors for select to anon,authenticated using (active=true and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now()));
drop policy if exists "Public read active plans" on public.subscription_plans;
create policy "Public read active plans" on public.subscription_plans for select to anon,authenticated using (active=true);

-- Members see their subscriptions; thread members can access chat.
drop policy if exists "Users request their own subscription" on public.user_subscriptions;
create policy "Users request their own subscription" on public.user_subscriptions for insert to authenticated with check (user_id=auth.uid() and status='pending' and starts_at is null and ends_at is null);
drop policy if exists "Users read own subscriptions" on public.user_subscriptions;
create policy "Users read own subscriptions" on public.user_subscriptions for select to authenticated using (user_id=auth.uid());
drop policy if exists "Participants read threads" on public.chat_threads;
create policy "Participants read threads" on public.chat_threads for select to authenticated using (exists(select 1 from public.chat_participants cp where cp.thread_id=id and cp.user_id=auth.uid()));
drop policy if exists "Participants read participant list" on public.chat_participants;
create policy "Participants read participant list" on public.chat_participants for select to authenticated using (user_id=auth.uid() or public.is_bhg_admin());
drop policy if exists "Users join threads they create" on public.chat_participants;
create policy "Users join threads they create" on public.chat_participants for insert to authenticated with check (user_id=auth.uid() and exists(select 1 from public.chat_threads t where t.id=thread_id and t.created_by=auth.uid()));
drop policy if exists "Participants read messages" on public.chat_messages;
create policy "Participants read messages" on public.chat_messages for select to authenticated using (exists(select 1 from public.chat_participants cp where cp.thread_id=thread_id and cp.user_id=auth.uid()));
drop policy if exists "Participants send messages" on public.chat_messages;
create policy "Participants send messages" on public.chat_messages for insert to authenticated with check (sender_id=auth.uid() and exists(select 1 from public.chat_participants cp where cp.thread_id=thread_id and cp.user_id=auth.uid()));
drop policy if exists "Participants create customer threads" on public.chat_threads;
create policy "Participants create customer threads" on public.chat_threads for insert to authenticated with check (created_by=auth.uid() and thread_type in ('customer','sales'));
drop policy if exists "Users read their orders" on public.sales_orders;
create policy "Users read their orders" on public.sales_orders for select to authenticated using (buyer_id=auth.uid() or seller_id=auth.uid());
drop policy if exists "Users create their own inquiries" on public.sales_orders;
create policy "Users create their own inquiries" on public.sales_orders for insert to authenticated with check (buyer_id=auth.uid() and order_type='inquiry' and status='new');

grant select on public.sponsors,public.subscription_plans to anon,authenticated;
grant select,insert,update on public.platform_profiles to authenticated;
grant select on public.user_subscriptions to authenticated;
grant select,insert on public.chat_threads to authenticated;
grant select,insert on public.chat_participants to authenticated;
grant select,insert on public.chat_messages to authenticated;
grant select,insert on public.sales_orders to authenticated;
grant all on public.sponsors,public.subscription_plans,public.user_subscriptions,public.chat_threads,public.chat_participants,public.chat_messages,public.sales_orders to authenticated;
