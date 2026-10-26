select
    m.member_id,
    s.channel,
    m.registered_at,
    date_trunc('month', m.registered_at)::date as cohort_month
from {{ ref('stg_members') }} m
join {{ ref('int_starts_attributed') }} s using (visitor_id)
