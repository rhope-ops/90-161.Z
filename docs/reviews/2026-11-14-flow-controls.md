# Flow controls: hold, cancel, delete, re-coordination, test mode (14 Nov 26)

Status: design approved by the PFM (14 Nov 26, "yes to all"); the flow parts are built for R21 (D1 skip, D2 hold and resume in F06, D3 cancel log, D4 round number, D6 test mode, kill switch, failure e-mails), not yet run on the gov device; the app parts (P02 buttons, hard delete, Restart coordination, P13 Health) are not built. Build: F03 r3, F05 r2, F06 r1, list schema change (T02 r12, T19 r1), R21 (built 14 Nov 26; the plan said R20 r2: renamed, PFM 14 Nov 26). Sources: flow/solution/README.md, flow/solution/defs/*.json, schemas/lists/*.json, docs/app/screen-map.md.

## Finding

No flow reads Action Status, so On Hold changes nothing. There is no Cancelled or closed state; the only exit is deleting the row. Each flow run is short and does not wait (no approvals), so per-action control is data on the row, not control of a flow run. The Power Automate Management connector would work on whole flows and needs owner rights other wings do not have (Deployable package rule), so it is not used.

## Edge cases (before the fix)

| # | Case | Now | Fixed by |
|---|---|---|---|
| E1 | Action On Hold | F03 still reminds and escalates; F05 still routes | D1, D2 |
| E2 | Action cancelled or withdrawn | No status for it ("Rescind" removes a publication) | D1 |
| E3 | Publications row deleted | Lookup has no delete rule: endorsement rows lose their Publication; F03 still e-mails; escalation cannot find the AO | D3, doctor check |
| E4 | Re-coordination (5.1) | Step back to 6: old answered rows count; no new rows | D4 |
| E5 | PFM moves straight to step 7 | No Legal rows (F05 makes them only on its own 6 to 7 move) | D4 "Re-run routing" |
| E6 | Office added, or a run stops part way | No row for it (README open point f) | D4 "Re-run routing" |
| E7 | Endorser leaves or is reassigned | Endorser copied at creation; reminders go to the old person | App "Not me, reassign"; doctor check |
| E8 | Extension approved (5.2.1) | F03 ignores ExtensionDate (open choice 8) | F03 r3: later of DueDate and ExtensionDate |
| E9 | Answer after All Comments Adjudicated = Yes | Gate does not run again (open point a) | Open |
| E10 | A flow off for days, or F03 fails one day | Unknown: item trigger catch-up; F03 may send 2-3 tiers at once (confidence low) | Test in a round |
| E11 | Endorsers answer in the app | Flow-made rows are not "own rows" (open point d) | Endorser-answer app flow (not built) |
| E12 | E-mail already sent | Cannot be recalled | D2 notice e-mail |

## Design (approved 14 Nov 26)

- D1 Action Status values: On Track, On Hold, Stalled, Cancelled, Complete; new columns Status Reason (required on change) and Held Since. Every flow skips On Hold, Cancelled and Complete actions.
- D2 Hold: reminders stop; on Resume each open due date moves out by the weekdays held, logged as an extension (5.2.1 is the only DAFMAN tool; the hold itself is a PFM design, not a DAFMAN rule). Pause, Resume and Cancel log to the Activity Log and e-mail the open endorsers once.
- D3 Cancel keeps the row and its records. Hard delete: PFM Office only, only an empty draft (no endorsement rows), to the Recycle Bin (93 days; P15 restores).
- D4 Coordination round: a Round number on PFM Endorsements. "Restart coordination" closes the old round (kept as record) and makes fresh rows. "Re-run routing" adds only the missing offices' rows.
- D5 Who: PFM Office pauses, resumes and cancels on P02; the AO requests a hold or cancel in the app, the PFM approves.
- D6 Test mode: environment variable pfm_TestMode (Yes/No); Yes sends every flow e-mail to the PFM only, with the intended recipients named in the body. Added to the slice 1 build (R21).
- QOL (approved with the set): global kill switch variable (all flows stop), P13 Health shows failed runs and orphan rows, e-mails link to the item (open choice 13), held actions grey with the reason in My Work, endorser "Request extension" and "Not me, reassign", daily digest (later).

## Open (agent REC, not approved)

- Troubleshooting (PFM 14 Nov 26, lean first): each flow e-mails the PFM on a failed step (flow, step, item ID, error); Resubmit from run history resumes; F05 adds only missing rows. R21 tests: forced failure e-mail, Resubmit with no duplicates, one deleted row comes back, Repair round restores a removed column.
- RADE maintenance modes (PFM goal 14 Nov 26: set and forget; agent REC, not approved): Diagnose, Repair, Restore, Reinstall, Fresh Install, Delete everything. Open: meaning of Reset, backup format (JSON + CSV), path without PnP, Record Sets excluded from delete.
- Flow owner continuity: decided 11 Nov 26 (every flow and the Power App get a co-owner). Diagnose should check that a co-owner exists.
- Date-only columns (open choice 7), E9. Holidays: closed (PFM 14 Nov 26: 20 working days, no holiday list).
