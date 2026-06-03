-- LotteryAcct: Initial schema
-- Betting records with parlay support

-- Enable pgcrypto for gen_random_uuid()
create extension if not exists "pgcrypto";

-- ═══════════════════════════════════════════
-- PROFILES
-- ═══════════════════════════════════════════
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
create policy "Users can read own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on signup
create function public.handle_new_user() returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', ''));
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ═══════════════════════════════════════════
-- BETTING RECORDS
-- ═══════════════════════════════════════════
create type public.bet_status as enum ('pending', 'won', 'lost', 'partial', 'voided');
create type public.bet_type as enum ('single', 'parlay');
create type public.bet_category as enum ('football', 'basketball', 'tennis', 'other');

create table public.betting_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  bet_type public.bet_type not null default 'single',
  category public.bet_category not null default 'football',
  match_name text,  -- null for parlay parent
  play_type text not null default '',  -- 独赢/让球/大小分/波胆/半全场
  odds numeric(8,2) not null,
  stake numeric(12,2) not null check (stake > 0),
  potential_return numeric(12,2) generated always as (stake * odds) stored,
  result_amount numeric(12,2),  -- null until settled
  status public.bet_status not null default 'pending',
  note text default '',
  ticket_image_url text,
  settled_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.betting_records enable row level security;
create policy "Users can CRUD own bets" on public.betting_records
  for all using (auth.uid() = user_id);

-- ═══════════════════════════════════════════
-- BET LEGS (for parlays)
-- ═══════════════════════════════════════════
create table public.bet_legs (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references public.betting_records(id) on delete cascade,
  match_name text not null,
  play_type text not null default '',
  odds numeric(8,2) not null,
  result_amount numeric(12,2),
  status public.bet_status not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.bet_legs enable row level security;
create policy "Users can CRUD own legs" on public.bet_legs
  for all using (
    exists (
      select 1 from public.betting_records
      where betting_records.id = bet_legs.record_id
      and betting_records.user_id = auth.uid()
    )
  );

-- Parlay parents must have >= 2 legs
create function public.check_parlay_legs() returns trigger as $$
begin
  if new.match_name is null then
    if not exists (
      select 1 from public.bet_legs where record_id = new.id
    ) then
      -- Allow insert, trigger will check after legs added
      return new;
    end if;
    if (select count(*) from public.bet_legs where record_id = new.id) < 2 then
      raise exception 'Parlay bets must have at least 2 legs';
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_check_parlay_legs
  after insert or update on public.betting_records
  for each row execute procedure public.check_parlay_legs();

-- ═══════════════════════════════════════════
-- VIEWS
-- ═══════════════════════════════════════════

-- User P&L summary
create view public.user_pnl_summary as
select
  user_id,
  count(*) as total_bets,
  count(*) filter (where status = 'won') as wins,
  count(*) filter (where status in ('won', 'lost')) as settled_bets,
  coalesce(sum(result_amount), 0) as total_pnl,
  coalesce(sum(result_amount) filter (where created_at >= date_trunc('month', now())), 0) as monthly_pnl,
  coalesce(sum(stake), 0) as total_stake,
  round(
    count(*) filter (where status = 'won')::numeric /
    nullif(count(*) filter (where status in ('won', 'lost')), 0) * 100,
    1
  ) as win_rate
from public.betting_records
group by user_id;

-- Daily P&L trend (last 30 days)
create view public.daily_pnl_trend as
select
  user_id,
  date(created_at) as bet_date,
  sum(result_amount) as daily_pnl,
  sum(sum(result_amount)) over (
    partition by user_id order by date(created_at)
  ) as cumulative_pnl
from public.betting_records
where status in ('won', 'lost')
  and created_at >= now() - interval '30 days'
group by user_id, date(created_at);
