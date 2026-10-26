-- Every raw utm_source / utm_medium pair seen, what it was cleaned to and which channel it maps to.
-- The first place to look when a new partner or ad account starts sending traffic.
select
    coalesce(utm_source, '(none)')   as utm_source_raw,
    coalesce(utm_medium, '(none)')   as utm_medium_raw,
    coalesce(source_clean, '(none)') as source_clean,
    coalesce(medium_clean, '(none)') as medium_clean,
    channel,
    count(*)                         as starts
from {{ ref('int_starts_attributed') }}
group by all
order by channel, starts desc
