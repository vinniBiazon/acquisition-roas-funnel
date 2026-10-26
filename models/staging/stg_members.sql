select member_id, visitor_id, cast(registered_at as timestamp) as registered_at
from {{ source('raw', 'members') }}
