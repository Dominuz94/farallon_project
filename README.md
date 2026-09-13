# Farallon Data Engineering Assessment Solution

## 🛠️ Solution Overview

*   **Bronze Layer (`models/bronze/`)**: Implements clean staging views utilizing dynamic Jinja templating to automatically union and discover raw trade daily snapshot files.
*   **Silver Layer (`models/silver/`)**: Provides our single source of truth (`int_trades`) which handles multi-day version deduplication, asset master enrichment, and maps out a clean row-level validation status.
*   **Quarantine Component (`models/silver/`)**: Isolates broken data streams into a separate `int_quarantined_trades` destination for strict data quality tracking without dropping records.
*   **Gold Layer (`models/gold/`)**: Materializes fully certified presentation tables (`fct_trades`, `dim_security`) and an explicitly documented schema configuration detailing the fact table's unique grain.
*   **Testing Suite (`tests/`)**: Deploys a custom source-to-target row reconciliation script (`assert_trade_counts_reconcile.sql`) confirming zero historical data leakage across our operational boundaries.

---

## 🤖 AI Usage Disclosure
*   **AI Tool Used**: Gemini Basic
*   **Scope of Assistance**: AI was utilized to verify the syntax of the dbt core models within the medallion architecture (specifically optimizing the Jinja loop syntax for dynamic file discovery and handling dependency graph compile hints) and to polish the readability and conciseness of the written engineering answers in Tasks 4 through 6.

---

## 📖 Setup & Reference Documentation
*   For the original project briefing, repository scaffolding details, and environment package configurations, please refer directly to the [README_SETUP.md](./README_SETUP.md) file.
*   For my complete technical post-mortem analysis, production incident runbook, scalability breakdowns, and Task 6 time-weighted return compounding judgments, please refer directly to my [DESIGN_NOTES.md](./DESIGN_NOTES.md) file.
