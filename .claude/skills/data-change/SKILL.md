---
name: data-change
description: Use before any data write (INSERT, UPDATE, DELETE, MERGE, DROP, TRUNCATE, schema change, migration, backfill) and before any query that can scan a large table. Gives the dry run, approval, row-count and cost steps, and how to report numbers without personal data.
---

# Data change

AGENTS.md "Verification" points here.

## Which target is production

- Production = the targets listed in AGENTS.md "Commands" under "Production data". If that line is missing or says "not set yet", treat every target as production.
- Never infer the environment from a name such as `dev` or `test`. If the target is not listed, ask.

## Before a costly read

1. Do a dry run and report the bytes it will scan. BigQuery: `bq query --use_legacy_sql=false --dry_run '<SQL>'`. Other engines: `EXPLAIN`, and report the estimated rows.
2. If the scan is over 10 GB (or the limit in AGENTS.md "Project rules"), stop and ask, with the number.
3. On a partitioned table, filter on the partition column. Do not use `SELECT *` on a wide table: name the columns.

## Before a write

1. Show the full statement, with no placeholders.
2. Show its effect without changing data: a `SELECT COUNT(*)` with the same `WHERE`, or the engine's dry run. Show the counts, grouped where that helps (for example by date or status).
3. On production: wait for approval of this statement. An approval covers one statement as shown. A changed statement needs a new approval.
4. Have a way back before you run: a snapshot or a backup table (BigQuery: `CREATE TABLE ... CLONE`, or time travel), or a written reverse statement. Say which one.
5. Run it. Report the row counts before and after, and the rows the engine says it changed. If the numbers do not agree with step 2, stop and report.

## Personal data

- Never put raw rows that hold personal data in chat, artifacts, docs, logs, fixtures or commits.
- Report counts and aggregates. If you must show rows, mask them: hash IDs (for example `TO_HEX(SHA256(CAST(id AS STRING)))`), cut emails to the domain, and drop names.

## Report

For each number: the query or command that produced it, and the as-of time of the data, in the time zone in AGENTS.md.
