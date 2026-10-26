select p.*
from {{ ref('stg_payments') }} p
join {{ ref('stg_members') }} m using (member_id)
where p.paid_on < cast(m.registered_at as date)
