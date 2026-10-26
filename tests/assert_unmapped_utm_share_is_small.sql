-- Fails if too many starts carry a UTM the channel map does not recognize (a new source nobody mapped)
select count(*) filter (where channel = 'unmapped') / count(*) as unmapped_share
from {{ ref('int_starts_attributed') }}
where utm_source is not null
having count(*) filter (where channel = 'unmapped') / count(*) > {{ var("max_unmapped_share") }}
