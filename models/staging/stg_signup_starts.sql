-- UTM parameters parsed from the landing URL and standardized: decoded, trimmed, lower case
with parsed as (
    select
        visitor_id,
        cast(started_at as timestamp)         as started_at,
        cast(finished_signup_at as timestamp) as finished_signup_at,
        last_step_reached,
        nullif(regexp_extract(landing_url, 'utm_source=([^&]*)', 1), '')   as utm_source,
        nullif(regexp_extract(landing_url, 'utm_medium=([^&]*)', 1), '')   as utm_medium,
        nullif(regexp_extract(landing_url, 'utm_campaign=([^&]*)', 1), '') as utm_campaign
    from {{ source('raw', 'signup_starts') }}
)
select
    *,
    lower(trim(url_decode(utm_source))) as source_clean,
    lower(trim(url_decode(utm_medium))) as medium_clean
from parsed
