-- Per channel and registration month: spend, members, 14-day ROAS, the naive "value so far" ROAS
-- a dashboard would show, and the projected 24-month ROAS
with spend as (
    select date_trunc('month', s.spend_date)::date as cohort_month, m.channel, sum(s.spend_usd) as spend_usd
    from {{ ref('stg_ad_spend') }} s
    join {{ ref('ad_platform_map') }} m using (ad_platform)
    group by 1, 2
),
value_so_far as (
    -- what a dashboard sums without thinking about maturity: every payment up to the as-of date
    select sc.scenario, c.channel, c.cohort_month, coalesce(sum(p.amount_usd), 0) as value_so_far
    from {{ ref('member_cohorts') }} c
    cross join {{ ref('value_scenarios') }} sc
    left join {{ ref('stg_payments') }} p
        on p.member_id = c.member_id and p.paid_on <= sc.as_of
    where c.registered_at::date <= sc.as_of
    group by 1, 2, 3
),
members as (
    select
        p.scenario, p.channel, p.cohort_month,
        count(*)                                   as members,
        sum(p.projected_value_24m)                 as projected_value_24m,
        sum(w.value_usd)                           as value_14d,
        bool_and(w.eligible)                       as all_14d_eligible
    from {{ ref('member_projected_value') }} p
    join {{ ref('member_value_windows') }} w
        on w.scenario = p.scenario and w.member_id = p.member_id and w.window_name = '14d'
    group by 1, 2, 3
)
select
    m.scenario,
    m.channel,
    m.cohort_month,
    m.members,
    s.spend_usd,
    s.spend_usd / m.members                                         as spend_per_member,
    case when m.all_14d_eligible then m.value_14d / s.spend_usd end as roas_14d,
    v.value_so_far / s.spend_usd                                    as roas_so_far_naive,
    m.projected_value_24m / s.spend_usd                             as projected_roas_24m,
    m.projected_value_24m / m.members                               as projected_value_24m_per_member
from members m
join value_so_far v using (scenario, channel, cohort_month)
left join spend s using (channel, cohort_month)
order by 1, 2, 3
