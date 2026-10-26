-- Every signup start gets a channel. No UTM at all means organic search; a UTM that the map
-- does not know is flagged as unmapped (and a data test fails if there are too many)
select
    s.*,
    case
        when s.utm_source is null then 'organic_search'
        else coalesce(m.channel, 'unmapped')
    end as channel
from {{ ref('stg_signup_starts') }} s
left join {{ ref('utm_channel_map') }} m
    on m.source_clean = s.source_clean and m.medium_clean = s.medium_clean
