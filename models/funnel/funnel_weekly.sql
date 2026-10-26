-- Weekly trend of "finished within 7 days". The naive line counts recent starts that have not
-- had 7 days yet, so it always shows a drop at the end.
select
    start_week,
    count(*)                                             as starts,
    avg(finished_7d::int)                                as finished_7d_rate_naive,
    avg(case when old_enough_7d then finished_7d::int end) as finished_7d_rate,
    bool_and(old_enough_7d)                                as week_fully_eligible
from {{ ref('funnel_starts') }}
where start_week >= date '2026-06-01'
group by 1
order by 1
