-- Shared data: remove per-user isolation, all authenticated users share everything

-- ═══════════════════════════════════════════
-- RLS: allow all authenticated users to CRUD all records
-- ═══════════════════════════════════════════
drop policy if exists "Users can CRUD own bets" on public.betting_records;
create policy "Authenticated users can CRUD all bets" on public.betting_records
  for all using (auth.role() = 'authenticated');

drop policy if exists "Users can CRUD own legs" on public.bet_legs;
create policy "Authenticated users can CRUD all legs" on public.bet_legs
  for all using (auth.role() = 'authenticated');

-- ═══════════════════════════════════════════
-- Views: combined totals across all users
-- ═══════════════════════════════════════════
create or replace view public.user_pnl_summary as
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

-- Combined summary view (no user_id grouping)
create or replace view public.combined_pnl_summary as
select
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
from public.betting_records;

-- Combined daily trend
create or replace view public.daily_pnl_trend as
select
  user_id,
  bet_date,
  daily_pnl,
  sum(daily_pnl) over (
    partition by user_id order by bet_date
  ) as cumulative_pnl
from (
  select
    user_id,
    date(created_at) as bet_date,
    coalesce(sum(result_amount), 0) as daily_pnl
  from public.betting_records
  where status in ('won', 'lost')
    and created_at >= now() - interval '30 days'
  group by user_id, date(created_at)
) sub;
