{{ config(materialized='view') }}

select
    security_id,
    ticker,
    security_name,
    asset_class,
    currency,
    is_active
from {{ ref('reference_securities') }}