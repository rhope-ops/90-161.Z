---
name: data-change
description: Use before a write to data that people or a live page use (a list, database, spreadsheet or data file; a schema change too) and before a query that can read a large table or list.
---

# Data change

AGENTS.md "Verification" points here. A data write can be irreversible, and a wrong one is often silent: the page still loads, with wrong rows. So each write shows its exact change and its counts before it runs, and has a way back.

## Which target is production

- Production = the targets listed in AGENTS.md "Commands" under "Production data". If that line is missing or says "not set yet", treat every target as production.
- Never infer the environment from a name such as `dev` or `test`. If the target is not listed, ask.
- A data file in the repo that a published page reads is production data from the moment it is published: the write is the merge plus the publish.

## Before a costly read

1. Find the size first: the row or item count, or the engine's dry run (BigQuery: `bq query --use_legacy_sql=false --dry_run '<SQL>'`; other SQL engines: `EXPLAIN`; a list or an API: its count call).
2. Over 10 GB, or over the limit in AGENTS.md "Project rules": stop and ask, with the number. A SharePoint list over 5,000 items: read it in pages with a filter on an indexed column; do not read it whole.
3. Name the columns or fields you need. Do not read all of them from a wide table or list.

## Before a write

1. Show the full change, with no placeholders: the statement, the request body, the script with its arguments, or the diff of the data file.
2. Show its effect without changing data: a count with the same filter (`SELECT COUNT(*)` with the same `WHERE`, the list filter, a script's `--dry-run`), grouped where that helps (by date or status). For a data file: the count of rows added, changed and removed, and proof that stable IDs did not change.
3. Get the fresh review that AGENTS.md "Fresh review" requires for a data write (lane C): give the reviewer the change and the counts of step 2. On production: wait for the Maintainer's approval of this change. An approval covers one change as shown. A changed statement, filter or file needs a new approval.
4. Have a way back before you run, and say which one: a snapshot or backup table (BigQuery: `CREATE TABLE ... CLONE`, or time travel), an export of the rows or list items the change touches, the version history of the list or file, the earlier commit of a data file, or a written reverse change.
5. Run it. Report the counts before and after, and the count the engine or the script says it changed. If the numbers do not agree with step 2, stop and report.
6. A page that reads the data: load it after the write and confirm one changed row and one row that must stay the same.

## Personal data

- Never put raw rows that hold personal data in chat, artifacts, docs, logs, fixtures or commits.
- Report counts and aggregates. If you must show rows, mask them: hash IDs (for example `TO_HEX(SHA256(CAST(id AS STRING)))`), cut emails to the domain, and drop names.
- Test with invented rows only.

## Report

For each number: the query or command that produced it, and the as-of time of the data, in the time zone in AGENTS.md.
