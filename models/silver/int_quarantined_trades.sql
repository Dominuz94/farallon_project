{{ config(materialized='table') }}

select
    trade_id,
    trade_date,
    security_id,
    side,
    quantity,
    price,
    trade_currency,
    version,
    last_updated_ts,
    source_file,
    source_row_number,
    _ingested_at,
    validation_status
from {{ ref('int_trades') }}
where validation_status is distinct from 'VALID'
