{{ config(materialized='table') }}

select
    security_id,
    ticker,
    security_name,
    asset_class,
    security_currency
from {{ ref('int_trades') }}  -- Pulling from our single source of truth
where validation_status = 'VALID'
group by 1, 2, 3, 4, 5       -- Ensures distinct, unique security records
