# Task 4 — Incident Post-Mortem & Debug Exercise

## 1. Diagnosis
The root cause of the incident is a flawed incremental loading strategy based on a strict business event date filter (`where trade_date > (select max(trade_date) from {{ this }})`). 

When the trade correction for `TRD100001` arrived on **2026-01-31**, it contained the updated quantity (4800) but retained its original historical transaction date of **2026-01-30**. Because the production model runs incrementally and filters strictly for new trade dates greater than what is already present in the warehouse, the incremental filter **silently ignored and dropped the correction row**. Because the query was logically valid, it completed with zero database engine errors, hiding the data loss from standard operational alerts.

---

## 2. Technical Fix
To prevent this class of bug, the incremental logic must be shifted from an unstable business event timestamp (`trade_date`) to a system-controlled processing lineage timestamp (`_ingested_at`) paired with an intentional **lookback safety window**. This ensures that any late-arriving modifications, amendments, or backfills are captured even if they modify historical records.

```sql
{{ config(
    materialized='incremental',
    unique_key='trade_id',
    incremental_strategy='delete+insert'
) }}

select
    trade_id,
    trade_date,
    security_id,
    quantity,
    price,
    version,
    last_updated_ts,
    _ingested_at
from {{ ref('int_trades_resolved') }}

{% if is_incremental() %}
  -- Captures late-arriving amendments or systemic backfills up to 3 days late
  where _ingested_at >= (select max(_ingested_at) - interval '3 days' from {{ this }})
{% endif %}
```

---

## 3. Prevention
This incident would have been caught instantly prior to deployment by this custom test that we already created:
tests\assert_trade_counts_reconcile.sql

By evaluating whether the unique entries in the raw staging view exactly equal the total record volume in the production table (`Valid Gold + Quarantined`), any skipped rows caused by restrictive macro filtering would trigger an immediate audit failure.

```sql
-- Placed in tests/assert_trade_counts_reconcile.sql
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
```

---

## 4. Operational Runbook & Remediation

### Phase 1: Impact Assessment & Isolation
Identify the exact scope of the drift by running a variance query comparing your raw historical staging data against the production fact table:
```sql
select trade_id, version, quantity from {{ ref('stg_trades') }}
except
select trade_id, version, quantity from {{ ref('fct_trades') }};
```
This isolates every trade record that was skipped, appended late, or currently shows an outdated version over the 3-week window. Export this delta to an impact worksheet.

### Phase 2: Technical Remediation
Execute a hard structural refresh to completely wipe out the stale state and re-materialize the table cleanly from historical source files:
```powershell
dbt run --full-refresh --select fct_trades
```
Confirm the data is accurate by re-running `dbt test` to ensure that your custom reconciliation tests pass perfectly.

### Phase 3: Stakeholder Communication
Proactively notify the portfolio and accounting leadership teams. Provide them with the isolated impact spreadsheet showing the exact trade variances alongside a calculated P&L delta impact statement so they can easily adjust or verify any mid-period reports. Inform them that the root sync latency has been resolved and a rigid code validation gate has been deployed to permanently block downstream drift moving forward.

---

# Task 5 — Architectural & Written Answers

## 1. Ingestion: Delimiter & Schema Governance
To prevent a future file format change from silently breaking our pipeline, I would configure **Fivetran Schema Drift Alerts** alongside rigid **Fivetran Block/Allow column rules** to halt replication if columns disappear or text data types shift (Easier to setup in Terraform when dealing with many connectors). Crucially, I would pair this with the custom `assert_trade_counts_reconcile` test built in Task 1. If an ingestion schema shift truncated rows or skewed fields, the source-to-target row reconciliation formula would immediately fail during the daily orchestration block. This catches structural ingestion corruption at the threshold of the warehouse before it pollutes the downstream Gold tables.

## 2. Scalability & Reuse: Scaling Multi-Venue Pipelines
To onboard 20+ trading venues without writing separate bronze models, I would replace one-off files with **dbt Sources combined with a dynamic Jinja generator macro**. This architectural pattern abstracts the source list into a centralized `src_venues.yml` schema file and dynamically loops through them in a single staging query, exactly mirroring the dynamic `graph.nodes` loop I implemented in `stg_trades.sql`. 

If volume scales 1000x, I would immediately abandon the project's **`ephemeral` materialization default for the Silver layer**. At enterprise scale, keeping complex data cleansing logic in memory as an inline subquery destroys query compiler performance; I would shift Silver to a clustered incremental or table materialization to write clean, physical states to disk before downstream query consumption.

## 3. Medallion Architecture & Stakeholder Trust

### Medallion Architecture Reflections
Yes, I have designed and operated Medallion architectures for nearly 7 years across data ecosystems at **Pulte, Pure, Yes Energy, and Forge Global**. Across these environments, the framework mapped cleanest in the **Silver layer**, which serves as the ideal, centralized clearinghouse for structural deduplication, schema stabilization, and multi-source enrichment (exactly as implemented in `int_trades`). 

However, the rigid three-layer paradigm often breaks down when managing complex financial state machines or multi-stage aggregation dependencies, where a single Silver model becomes bloated. My primary lesson learned from these implementations is that **preventative testing must be treated as a first-class citizen at the boundaries of each layer**. In future architectures, I would implement automated structural testing and alerting specifically targeting edge cases like late-arriving data backfills, upstream schema modifications, and row-level business validation rules before data transitions across layers.

### Stakeholder Communication Strategy
When communicating the P&L discrepancy to a Portfolio Manager, I would focus on transparency, platform reliability, and business impact while avoiding technical database jargon:

> *"Good morning. Yesterday afternoon, our automated data quality monitors successfully intercepted an upstream data discrepancy coming from the market feeds. To protect the integrity of your dashboards, the platform automatically quarantined those records, preventing the bad data from polluting your certified morning P&L reports. We deployed a permanent structural fix and fully refreshed the system hours ago. The numbers you see in your dashboard right now are 100% accurate, certified, and reconciled against the OMS. Moving forward, we are establishing an active notification protocol to alert your team immediately whenever an upstream data delay causes a temporary sync variance."*

---

# Task 6 — Time-Weighted Return Judgment

## Q1 — Production Fit
* **Choice:** **C) Method C**

### Defense
For running nightly on Snowflake over 50,000 deals and historical rows, **Method C is the superior production-grade architecture**. 

Method B (Recursive CTE) operates on row-by-row iteration loops. This completely neutralizes Snowflake's primary strength: its massively parallel processing (MPP) columnar execution engine. For this particular scenario recursion can be ommited.

While Method A leverages the windowing engine, its reliance on the default frame (`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` when an `ORDER BY` is present) which based on my experience does not handle ties (for duplicates) very well.

Method C explicitly declares a strict physical framing clause (`ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`). This makes duplicates handling a bit more precise. Based on my experience they get evaluated sequentially which is best when we need a strict, deterministic, row-by-row accumulation (like a running total) where every single physical row increments the calculation.

---

## Q2 — Correctness / Audit Judgment
* **Choice:** **B) No — it should raise an error or be flagged, since zero AverageCapital while generating income is likely a data problem.**

### Defense
From a certified fund reporting and financial audit perspective, silently treating a period with zero `AverageCapital` and active `Income` as a neutral 0% return is a material data integrity risk. 

If a deal generates revenue or experiences a valuation change without holding any active capital balance, it indicates a severe upstream transactional accounting failure—such as a missing ledger ingestion file, a broken currency conversion, or an unallocated capital call. 

Silently coercing this mismatch to a `1` or `0%` mathematically masks the anomaly, allowing corrupted calculations to compound permanently into downstream QTD and YTD investor metrics. 

The pipeline should explicitly trigger a hard failure or route the record to a quarantine audit table so data engineering can reconcile the underlying ledger entry before it impacts regulatory financial reporting.

---

## Q3 — Supportability
* **Choice:** **C) Method C**

### Defense
**Method C is by far the easiest and most sustainable pattern to extend to Inception-to-Date (ITD) returns**. 

To implement ITD using Method C, you only need to add one single, clean window function to the `SELECT` statement by simply removing the time-based window partition filters:

```sql
exp(sum(log(nullif(monthly_return,1)))
    over (partition by dealid order by perioddate
          rows between unbounded preceding and current row)) - 1 as itd_return
```

By removing the `year` and `quarter` parameters from the `PARTITION BY` clause, the explicit `ROWS BETWEEN` frame seamlessly accumulates every historical monthly log coefficient from the very first row of the deal's ledger history up to the current row. 

Conversely, extending Method B would require rewriting the recursive base anchors, re-mapping complex joint iteration criteria, and risking infinite recursion loops, which increases technical debt.
