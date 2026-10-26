-- Projected 24-month value: the member's value at the latest window that has fully passed,
-- multiplied by the growth factors of the windows still to come
with latest as (
    select scenario, member_id, channel, cohort_month, max(window_order) as last_window
    from {{ ref('member_value_windows') }}
    where eligible
    group by 1, 2, 3, 4
),
remaining_growth as (
    select l.scenario, l.member_id, exp(sum(ln(f.factor_to_next))) as growth
    from latest l
    join {{ ref('development_factors') }} f
        on f.scenario = l.scenario and f.channel = l.channel and f.window_order >= l.last_window
    group by 1, 2
)
select
    l.scenario,
    l.member_id,
    l.channel,
    l.cohort_month,
    l.last_window,
    v.value_usd                         as value_at_last_window,
    v.value_usd * coalesce(g.growth, 1) as projected_value_24m
from latest l
join {{ ref('member_value_windows') }} v
    on v.scenario = l.scenario and v.member_id = l.member_id and v.window_order = l.last_window
left join remaining_growth g
    on g.scenario = l.scenario and g.member_id = l.member_id
