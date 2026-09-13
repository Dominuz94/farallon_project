-- depends_on: {{ ref('trades_20260130') }}
-- depends_on: {{ ref('trades_20260131') }}

{{ config(materialized='view') }}

with unified_trades as (
    {% set trade_seeds = [] %}
    
    {% for node in graph.nodes.values() %}
        {% if node.resource_type == 'seed' and node.name.startswith('trades_') %}
            {% do trade_seeds.append(node.name) %}
        {% endif %}
    {% endfor %}

    {% for seed in trade_seeds %}
        select * from {{ ref(seed) }}
        {% if not loop.last %} union all {% endif %}
    {% endfor %}
)

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
    _ingested_at
from unified_trades
