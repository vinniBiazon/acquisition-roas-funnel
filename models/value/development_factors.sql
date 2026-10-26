-- How much value grows from one window to the next, per channel, measured only on members old
-- enough for both windows (the chain-ladder idea from insurance reserving)
select
    a.scenario,
    a.channel,
    a.window_order,
    sum(b.value_usd) / nullif(sum(a.value_usd), 0) as factor_to_next,
    count(*)                                       as members
from {{ ref('member_value_windows') }} a
join {{ ref('member_value_windows') }} b
    on  b.scenario = a.scenario
    and b.member_id = a.member_id
    and b.window_order = a.window_order + 1
where b.eligible
group by 1, 2, 3
