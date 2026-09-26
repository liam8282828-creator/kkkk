create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  phone text not null default '',
  expires_at timestamptz not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.licenses (
  id uuid primary key default gen_random_uuid(),
  license_key text not null unique,
  expires_at timestamptz not null,
  is_active boolean not null default true,
  user_id uuid references auth.users(id) on delete set null,
  device_id text,
  activated_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.licenses add column if not exists device_id text;
alter table public.licenses add column if not exists activated_at timestamptz;

create table if not exists public.license_login_attempts (
  id bigint generated always as identity primary key,
  client_ip_hash text not null,
  attempted_at timestamptz not null default now()
);

create index if not exists license_login_attempts_address_time_idx
  on public.license_login_attempts (client_ip_hash, attempted_at desc);

alter table public.profiles enable row level security;
alter table public.licenses enable row level security;
alter table public.license_login_attempts enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

insert into public.licenses (license_key, expires_at)
values ('MOON-TEST-2026', now() + interval '30 days')
on conflict (license_key) do update
  set expires_at = excluded.expires_at,
      is_active = true,
      device_id = null,
      activated_at = null;
