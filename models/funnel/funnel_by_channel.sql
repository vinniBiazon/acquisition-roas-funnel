-- Share of starts that finished signup within 1, 3 and 7 days, counting only eligible starts
select
    channel,
    count(*) as starts,
    {%- for n in [1, 3, 7] %}
    avg(case when old_enough_{{ n }}d then finished_{{ n }}d::int end) as finished_{{ n }}d_rate{{ "," if not loop.last }}
    {%- endfor %}
from {{ ref('funnel_starts') }}
group by 1
order by 1
