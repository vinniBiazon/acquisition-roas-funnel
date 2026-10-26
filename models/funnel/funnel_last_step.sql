-- Where people who never finished stopped, by channel. Only starts older than 30 days,
-- after which an unfinished signup is treated as abandoned
select
    channel,
    last_step_reached,
    count(*)                                             as abandoned_starts,
    count(*) / sum(count(*)) over (partition by channel) as share_of_abandoned
from {{ ref('funnel_starts') }}
where not finished
  and started_at + interval 30 day <= timestamp '{{ var("as_of") }}'
group by 1, 2
order by 1, 2
