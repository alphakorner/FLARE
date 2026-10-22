-- FLARE starter schema — REVIEW BEFORE DEPLOYING.
-- Important: do not expose public SELECT on profiles, PIN hashes, or precise locations.
create extension if not exists pgcrypto;
create extension if not exists postgis;

create table if not exists public.flare_profiles (
  id uuid primary key default gen_random_uuid(),
  pseudo varchar(50) not null,
  avatar_index int not null default 0 check (avatar_index between 0 and 11),
  -- Store only a server-verified strong password hash. Never store a raw PIN.
  pin_hash text not null,
  role varchar(20) not null default 'user' check (role in ('user','medic','admin')),
  trust_score int not null default 1,
  created_at timestamptz not null default now()
);

create table if not exists public.signals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.flare_profiles(id) on delete cascade,
  type varchar(30) not null check (type in ('police','danger','barrage','secours','incident','libre')),
  geom geography(point,4326) not null,
  description varchar(100),
  status varchar(20) not null default 'pending' check (status in ('pending','validated','expired')),
  validation_count int not null default 1,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '20 minutes'
);
create index if not exists signals_geom_gix on public.signals using gist(geom);
create index if not exists signals_expiry_idx on public.signals(expires_at);

create table if not exists public.signal_votes (
  id uuid primary key default gen_random_uuid(),
  signal_id uuid not null references public.signals(id) on delete cascade,
  user_id uuid not null references public.flare_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(signal_id,user_id)
);

-- Store only a current, coarse cell when genuinely required; avoid a public GPS history.
create table if not exists public.presences (
  user_id uuid primary key references public.flare_profiles(id) on delete cascade,
  geom geography(point,4326) not null,
  updated_at timestamptz not null default now()
);
create index if not exists presences_geom_gix on public.presences using gist(geom);
create index if not exists presences_updated_idx on public.presences(updated_at);

create table if not exists public.medic_locations (
  user_id uuid primary key references public.flare_profiles(id) on delete cascade,
  geom geography(point,4326) not null,
  available boolean not null default false,
  updated_at timestamptz not null default now()
);
create index if not exists medic_locations_geom_gix on public.medic_locations using gist(geom);

alter table public.flare_profiles enable row level security;
alter table public.signals enable row level security;
alter table public.signal_votes enable row level security;
alter table public.presences enable row level security;
alter table public.medic_locations enable row level security;

-- Deliberately NO permissive public policies are added here.
-- Implement access through a trusted backend / Edge Functions that authenticate
-- anonymous sessions, rate-limit writes, validate types and coordinates, enforce
-- consent, and expose only the minimum aggregated data. Do not put service_role
-- or Claude API keys in browser code.

create or replace function public.purge_stale_data()
returns void language sql security definer set search_path=public as $$
  delete from public.presences where updated_at < now()-interval '5 minutes';
  delete from public.medic_locations where updated_at < now()-interval '2 minutes';
  update public.signals set status='expired'
    where expires_at < now() and status <> 'expired';
$$;

-- For a production consensus, use a trusted transaction/RPC:
-- 1. validate authenticated user and rate limit;
-- 2. deduplicate by (user_id,type,geography cell/time window);
-- 3. count DISTINCT users with same type within ST_DWithin(..., 200);
-- 4. validate only when >=3 distinct users inside a 2-minute window;
-- 5. expire signals and avoid returning exact reporter locations.
-- Schedule purge_stale_data() with Supabase Cron. Do not call it from an untrusted client.
