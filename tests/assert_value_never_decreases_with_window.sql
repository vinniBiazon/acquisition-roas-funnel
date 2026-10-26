-- Cumulative value at a longer window can never be lower than at a shorter one
select a.*
from {{ ref('member_value_windows') }} a
join {{ ref('member_value_windows') }} b
    on  b.scenario = a.scenario
    and b.member_id = a.member_id
    and b.window_order = a.window_order + 1
where b.value_usd < a.value_usd
