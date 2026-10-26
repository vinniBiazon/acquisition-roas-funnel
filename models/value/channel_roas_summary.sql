-- One line per paid channel for the Jan to Aug 2026 cohorts (all past their 14-day window):
-- the number each method would put in front of the budget meeting
select
    channel,
    sum(members)                                         as members,
    sum(spend_usd)                                       as spend_usd,
    sum(spend_usd) / sum(members)                        as spend_per_member,
    sum(roas_14d * spend_usd) / sum(spend_usd)           as roas_14d,
    sum(roas_so_far_naive * spend_usd) / sum(spend_usd)  as roas_so_far_naive,
    sum(projected_roas_24m * spend_usd) / sum(spend_usd) as projected_roas_24m
from {{ ref('cohort_roas') }}
where scenario = 'current'
  and spend_usd is not null
  and cohort_month between date '2026-01-01' and date '2026-08-01'
group by 1
order by projected_roas_24m desc
