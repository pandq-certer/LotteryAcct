-- Approval workflow step 2: update views to exclude awaiting_approval

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
where status != 'awaiting_approval'
group by user_id;

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
from public.betting_records
where status != 'awaiting_approval';

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
