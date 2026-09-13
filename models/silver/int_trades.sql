{{ config(materialized='ephemeral') }}

with deduplicated_trades as (
    select
        *,
        -- Window function to pick the latest version across same-day/late cross-day changes
        row_number() over (
            partition by trade_id 
            order by 
                version desc, 
                last_updated_ts desc, 
                _ingested_at desc, 
                source_row_number desc  -- Deterministic tie-breaker for the exact duplicate
        ) as rn
    from {{ ref('stg_trades') }}
),

latest_trades as (
    select * 
    from deduplicated_trades 
    where rn = 1
),

enriched_trades as (
    select
        t.trade_id,
        t.trade_date,
        t.security_id,
        t.side,
        t.quantity,
        t.price,
        t.trade_currency,
        t.version,
        t.last_updated_ts,
        t.source_file,
        t.source_row_number,
        t._ingested_at,
        
        -- Enriched fields from security master
        s.ticker,
        s.security_name,
        s.asset_class,
        s.currency as security_currency,
        
        -- Tracking indicators to identify quarantine candidates dynamically downstream
        case 
            when s.security_id is null then 'UNKNOWN_SECURITY'
            when s.is_active = false then 'INACTIVE_SECURITY'
            else 'VALID'
        end as validation_status

    from latest_trades t
    left join {{ ref('stg_securities') }} s 
        on t.security_id = s.security_id
)

select * from enriched_trades
