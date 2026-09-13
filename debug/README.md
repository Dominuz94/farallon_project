# Task 4 -- Incident / debug exercise

This folder is intentionally outside `models/` and is not part of the dbt
DAG -- it doesn't need to compile or run. Reason about it against the seed
data in `../seeds/` and answer in your written notes.

## The incident

`buggy_fct_trades_incremental.sql` is the real model backing `fct_trades` in
production. It has been running daily, incrementally, since 2026-01-30, and
has never thrown an error.

Three weeks later, an auditor reconciling January P&L flags that `fct_trades`
still shows TRD100001 at its original quantity (5000), not the corrected
quantity (4800) that you already know arrived via trades_20260131.csv on
2026-01-31 (you handled this same correction in Task 1). No error was ever
logged, no test ever failed, and nobody noticed until the auditor's
reconciliation caught it.

Answer these in DESIGN_NOTES.md:

1. Diagnose: why did TRD100001's correction never make it into `fct_trades`,
   even though the model ran successfully every single day?
2. Fix: rewrite the incremental logic so this class of bug can't happen.
   (In production this would run on Snowflake with `incremental_strategy =
   'merge'`; locally on DuckDB the equivalent is `'delete+insert'` with
   `unique_key` set -- either is fine to reference.)
3. Prevention: what single dbt test, if it had existed before this model was
   first deployed, would have caught this before it ever reached production?
4. Runbook (3-5 sentences): it's been silently wrong for three weeks --
   how do you find every affected row, safely rebuild the table, and what
   do you tell the stakeholders (e.g. the portfolio/accounting team) who
   consumed the wrong numbers in the meantime?

Budget about 30 minutes total. We're not grading whether you can spot a bug
in the abstract -- we're grading whether you can reason precisely about why
production code that "never errors" can still be silently wrong, and how
you'd respond once you found out.
