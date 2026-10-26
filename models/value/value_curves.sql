-- Average cumulative value per member at each window, by channel, counting only members old
-- enough for that window. This is the curve the projection extends.
select
    channel,
    window_name,
    window_order,
    count(*)       as eligible_members,
    avg(value_usd) as avg_value_usd
from {{ ref('member_value_windows') }}
where scenario = 'current'
  and eligible
group by 1, 2, 3
order by 1, 3
