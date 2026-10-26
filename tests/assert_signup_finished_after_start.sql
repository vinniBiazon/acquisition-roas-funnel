select *
from {{ ref('stg_signup_starts') }}
where finished_signup_at < started_at
