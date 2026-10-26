select cast(date as date) as spend_date, ad_platform, cast(spend_usd as double) as spend_usd
from {{ source('raw', 'ad_spend') }}
