# Farallon Data Engineering Assessment Solution

## Data Ambiguities & Assumptions
During pipeline construction, two material data ambiguities were identified and resolved with the following explicit engineering assumptions:

*   **Ambiguity 1: Today's `is_active` status applied to historical trades.** 
    *   *Assumption/Treatment:* The `reference_securities.is_active` flag reflects status as of today’s extract, not the historical execution date. To protect historical ledger accounting from retroactive corruption (e.g., a trade executed legally in January shouldn't be deleted because the stock delisted in February), our pipeline preserves the record but routes it to `int_quarantined_trades`. This keeps our certified Gold tables free from downstream reporting volatility while allowing the business to audit compliance.
*   **Ambiguity 2: Missing `trade_currency` values.**
    *   *Assumption/Treatment:* Where `trade_currency` was missing, the pipeline defaults to the security’s home currency (`security_currency`). While dual-listed instruments can settle in alternative currencies in practice, defaulting to the asset's primary issuing currency is a standard data-cleansing heuristic that maintains continuity in our compounding logic. Any record falling outside our standard reporting threshold is safely flagged via our `is_reporting_currency` boolean block.

---

## 🤖 AI Usage Disclosure
*   **AI Tool Used**: Gemini Basic
*   **Scope of Assistance**: AI was utilized to verify the syntax of the dbt core models within the medallion architecture (specifically optimizing the Jinja loop syntax for dynamic file discovery and handling dependency graph compile hints) and to polish the readability and conciseness of the written engineering answers in Tasks 4 through 6.

---

## ⚠️ Things to improve/did not complete:
I think this logic is better for the models\gold\dim_security.sql model
```sql
{{ config(materialized='table') }}

select
    security_id,
    ticker,
    security_name,
    asset_class,
    currency
from {{ ref('stg_securities') }}
where is_active = true  -- Manually enforcing validity rules here instead
```

## 📖 Setup & Reference Documentation
*   For the original project briefing, repository scaffolding details, and environment package configurations, please refer directly to the [README_SETUP.md](./README_SETUP.md) file.
*   For my complete technical post-mortem analysis, production incident runbook, scalability breakdowns, and Task 6 time-weighted return compounding judgments, please refer directly to my [DESIGN_NOTES.md](./DESIGN_NOTES.md) file.
