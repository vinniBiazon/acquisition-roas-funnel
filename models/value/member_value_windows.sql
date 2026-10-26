-- Value per member at 14 days, 1, 3, 6, 12 and 24 months after registration, in each scenario.
-- A window only counts once it has fully passed: a member registered 2 months ago has no 3-month value yet.
with grid as (
    select
        c.member_id, c.channel, c.cohort_month, c.registered_at::date as registered_on,
        sc.scenario, sc.as_of, w.window_name, w.window_days, w.window_order
    from {{ ref('member_cohorts') }} c
    cross join {{ ref('value_scenarios') }} sc
    cross join {{ ref('value_windows') }} w
    where c.registered_at::date <= sc.as_of
)
select
    g.scenario,
    g.member_id,
    g.channel,
    g.cohort_month,
    g.window_name,
    g.window_order,
    g.registered_on + g.window_days <= g.as_of as eligible,
    coalesce(sum(p.amount_usd), 0)             as value_usd
from grid g
left join {{ ref('stg_payments') }} p
    on  p.member_id = g.member_id
    and p.paid_on <  g.registered_on + g.window_days
    and p.paid_on <= g.as_of
group by g.scenario, g.member_id, g.channel, g.cohort_month, g.window_name, g.window_order,
         g.registered_on, g.window_days, g.as_of
