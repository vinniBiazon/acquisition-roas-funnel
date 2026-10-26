select member_id, cast(paid_on as date) as paid_on, cast(amount_usd as double) as amount_usd
from {{ source('raw', 'payments') }}
