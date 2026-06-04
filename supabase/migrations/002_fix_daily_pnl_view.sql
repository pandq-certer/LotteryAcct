-- Fix daily_pnl_trend: coalesce null result_amount
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
