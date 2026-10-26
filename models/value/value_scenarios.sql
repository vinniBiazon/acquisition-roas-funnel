-- "current": what we know today. "backtest": the same models as if today were an earlier date,
-- so the projection can be compared with what really happened afterwards
select 'current' as scenario, date '{{ var("as_of") }}' as as_of
union all
select 'backtest', date '{{ var("backtest_as_of") }}'
