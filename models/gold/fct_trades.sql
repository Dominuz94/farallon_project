{{ config(materialized='table') }}

select
    trade_id,
    trade_date,
    security_id,
    ticker,
    side,
    quantity,
    price,
    trade_currency,
    case 
        when trade_currency = '{{ var("default_reporting_currency") }}' then true 
        else false 
    end as is_reporting_currency,
    version,
    last_updated_ts,
    source_file,
    source_row_number,
    _ingested_at
from {{ ref('int_trades') }}
where validation_status = 'VALID'
