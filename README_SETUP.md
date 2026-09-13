# Local dbt environment setup

This project uses dbt-core with the DuckDB adapter so you can run everything
locally without provisioning a Snowflake account. Treat the underlying
warehouse conceptually as Snowflake for the written questions in Task 5 --
the DuckDB adapter is only a local stand-in to keep the exercise fast to
set up.

This project follows a bronze / silver / gold (medallion) structure:
bronze = thin, standardized raw pass-through; silver = resolved, enriched,
quarantined -- your single source of truth; gold = business-ready,
dimensionally modeled marts.

## Setup

    python3 -m venv .venv
    source .venv/bin/activate
    pip install "dbt-core>=1.8,<1.9" "dbt-duckdb>=1.8,<1.9"
    dbt deps
    dbt seed
    dbt build

Versions are pinned to the 1.8.x line for both packages -- newer combinations
may also work, but this range is the one we've verified.

`dbt docs generate` is optional if you'd like a browsable catalog, but it is
not required and isn't scored -- don't spend time on it if you're tight on
the time box.

## profiles.yml (place in ~/.dbt/profiles.yml)

    farallon_de_takehome:
      target: dev
      outputs:
        dev:
          type: duckdb
          path: dev.duckdb
          threads: 4

## What's already scaffolded for you
- `seeds/` -- four raw source files as dbt seeds, including realistic
  ingestion lineage columns (`source_file`, `source_row_number`,
  `_ingested_at`) that a real Fivetran sync would attach. The
  `positions_20260131` seed is semicolon-delimited -- its delimiter is
  already configured in `dbt_project.yml`, so `dbt seed` will parse it
  correctly out of the box.
- `models/bronze/`, `models/silver/`, `models/gold/` -- empty folders for
  you to populate
- `debug/` -- a standalone exercise for Task 4 (not part of the dbt DAG;
  it will not compile as-is and doesn't need to)
- `dbt_project.yml` -- materialization defaults per layer (bronze=view,
  silver=ephemeral, gold=table) -- feel free to change these if you'd
  choose differently, and say why in your README

Everything else (sources.yml, schema.yml, the bronze/silver/gold models,
tests) is your task to build.
