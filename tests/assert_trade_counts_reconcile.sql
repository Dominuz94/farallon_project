-- This test fails if unique trades are dropped or duplicated during the pipeline processing.
with raw_unique_count as (
    select count(distinct trade_id) as total_raw_trades
    from {{ ref('stg_trades') }}
),

processed_count as (
    select 
        (select count(*) from {{ ref('fct_trades') }}) + 
        (select count(*) from {{ ref('int_quarantined_trades') }}) as total_processed_trades
)

select *
from raw_unique_count
join processed_count 
    on raw_unique_count.total_raw_trades != processed_count.total_processed_trades
