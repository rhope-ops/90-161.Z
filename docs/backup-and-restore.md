# Backup and restore ("chapters"): design r1 (13 Nov 26)

Status: design after Administrator 20A (12 Nov) and 22A 23A (13 Nov): weekly automatic backup, browsable in the app, with a way to roll back. Administrator 13 Nov: keep backups very small and have the app encourage deleting old ones (section 5). Items marked **REC:** are open until the Administrator approves; **Test** = not proven on the tenant.

## 1. Three layers, smallest first

| Layer | Covers | How the app shows it | Restore keeps lookups intact |
|---|---|---|---|
| 1. Row history (SharePoint version history, on by default) | A wrong edit on one row | "History" panel on a row: each version, who, when, what changed | Yes: a flow copies the old values onto the same row (same ID) |
| 2. Recycle bin (93 days) | A deleted row or file | "Deleted" screen, PFM Office only | Yes: SharePoint restores the original ID |
| 3. Chapters (weekly snapshot) | A bad bulk change, a deleted list, anything older than 93 days | "Chapters" screen: one entry per week, row counts per list, the Activity Log events of that week as the chapter summary | Partly: see section 3 |

## 2. Chapters

- Flow "90-161.Z - Weekly Backup": every Sunday 0300 (time zone from PFM Settings). For each PFM list it writes one JSON file (all columns, IDs and lookup IDs: the restore source) to Record Sets/Backups/<yyyy-mm-dd>/. No CSV copy: the Chapters screen shows the rows, and an "Export to CSV" button makes one on request. PFM Activity Log is saved only as the rows added since the last chapter (it is append-only). It writes one PFM Activity Log row with the counts.
- Retention (Administrator 23A): the last 8 weekly chapters plus the first chapter of each month for 12 months (20 folders at most).
- Chapters screen (PFM Office only): pick a chapter, see per list "rows then / rows now / changed / deleted since", open a row as it was.

## 3. Rollback from a chapter

- **Selective (REC default):** the Administrator picks rows or fields in a chapter; a flow writes those values back onto the same rows. Deleted rows come back from the recycle bin first (same ID); only past 93 days is a row created new.
- **Whole list (PFM Office, confirm twice):** before it starts, the flow takes a fresh chapter, so the rollback itself can be undone. Then it sets every row to its chapter values and lists rows created since the chapter for the Administrator to keep or delete.
- Limit (high confidence): SharePoint gives a re-created row a new ID; it cannot reuse the old one. Rows in other lists that pointed to it (Endorsements to Publications, forms to their prescribing publication) are re-pointed by the flow through the IDs stored in the JSON. **Test:** re-pointing on the test site before the pilot.
- Every restore is logged (who, which chapter, which rows).

## 4. Answered (13 Nov): 22A, 23A

| Q | Question | Options | REC |
|---|---|---|---|
| Q22 | Rollback scope | A: all three layers; whole-list rollback by PFM Office only, with an automatic chapter first. B: row history and recycle bin only; chapters are read-only | A |
| Q23 | Chapter retention | A: 8 weekly + 12 monthly. B: 8 weekly only | A (a yearly review often looks back more than 2 months) |

## 5. Small, and old ones deleted (Administrator 13 Nov)

Size estimate (not measured; about 1.5 KB of JSON per row; files are not in chapters, they keep their own version history):

| Wing age | Rows in a chapter (lists except the log) | One chapter | 20 chapters |
|---|---|---|---|
| Year 1 | about 1,000 | about 1.5 MB | about 30 MB |
| Year 3 | about 3,000 | about 4.5 MB | about 90 MB |

The Activity Log adds about 3 MB a year in total (2,000 rows a year, saved once each). Without the two cuts above (no CSV, log saved once) year 3 would be about 400 MB for 20 chapters.

The app encourages deletion; it never deletes a chapter silently:
- Chapters past retention are marked "Ready to Delete". The Chapters screen shows the space each chapter uses, the total, and one button: "Delete 6 Old Chapters (27 MB)".
- PFM Office sees a banner on the home screen while any chapter is Ready to Delete. The weekly Wednesday e-mail to PFM Office carries the same line.
- A chapter a whole-list rollback depends on, or one under Legal Hold or a Records Freeze (PFM Settings), is never marked Ready to Delete.
- Each delete is one Activity Log row.
