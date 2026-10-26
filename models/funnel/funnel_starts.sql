-- One row per signup start, with "finished within N days" and whether the start is old enough
-- to be counted for each window. A start from 3 days ago cannot have finished "within 7 days" yet.
{% set as_of = "timestamp '" ~ var("as_of") ~ " 23:59:59'" %}
select
    visitor_id,
    channel,
    started_at,
    date_trunc('week', started_at)::date as start_week,
    last_step_reached,
    finished_signup_at is not null       as finished,
    {%- for n in [1, 3, 7] %}
    coalesce(finished_signup_at <= started_at + interval {{ n }} day, false) as finished_{{ n }}d,
    started_at + interval {{ n }} day <= {{ as_of }}                        as old_enough_{{ n }}d{{ "," if not loop.last }}
    {%- endfor %}
from {{ ref('int_starts_attributed') }}
