-- fct_trades.sql -- this exact model has been running in production, once a
-- day, since 2026-01-30. It has never errored or failed a run.

{{ config(
    materialized='incremental',
    unique_key='trade_id'
) }}

select
    trade_id,
    trade_date,
    security_id,
    quantity,
    price,
    version,
    last_updated_ts
from {{ ref('int_trades_resolved') }}

{% if is_incremental() %}
where trade_date > (select max(trade_date) from {{ this }})
{% endif %}
