# Sweep decisions for the PFM (13 Nov 26)

Answered 14 Nov 26: S1 = the lists go on a new site, so T02 r10 builds all 12 from scratch (no upgrade flow; the PFM first chose A, then said the site is new); S4 confirm all 33, S5 item 1 A, R09 live. Answered 18 Nov 26 (docs/DECISIONS.md): S3 A, S5.3 A, S8 closed, S9 A, F1 A, F2 A and B, F3 C, S10 C. Still open: S2, S5 items 4-15, S6, S7, S11, F4, F5.

Written for PR rhope-ops/90-161.Z#10 (merged 13 Nov 26). The open items below still need the PFM. Each "Rec" is Claude's recommendation, not a decision. Answer by number (for example "S1 A, S2 approve, S5 all Rec").

## S1. T02 r10 on the live site (highest impact)

r10 creates 12 lists from scratch, which is right for a new wing. The live site already has the 9 r9 lists, and the provisioning flow fails on lists and fields that exist (docs/power-automate-provisioning.md section 3).

- A. **Rec:** Claude builds an upgrade flow (T02 r11): only the changes since r9 (new lists, new columns, new choice values, AO to multiple people, new views and filters, missing seed rows). Data in the lists stays. About 2-3 h of Claude time; tested on the live site like r9.
- B. Delete the 9 lists and run r10. Loses every row now in them (seeds and any test rows).
- C. Add the 113 columns by hand in List settings. Not practical.

## S2. Names the naming check forced (T02 r10)

tests/check_names.py allows only DAFMAN Attachment 1 abbreviations and title case, so the design's CIO, CSS and ID became "Chief Information Officer", "Command Support Staff" and "Review Request Identifier"; some names changed case (for example "Need and Authority", "Law or Regulation Change"); e-mail columns are "... E-Mail". **Rec:** approve as built.

## S3. Waiver tiers

The design lists T-1, T-2, T-3 and Non-Tiered; the waiver warning rule (4.4A) also names T-0. **Rec:** add T-0 (DAFMAN Attachment 10 defines it).

## S4. DAFMAN coverage gaps (docs/reviews/2026-11-13-coverage-gap-sweep.md)

- 33 rows are "does not apply to an ANG wing" candidates (waivers outside wing publications, AFDPO printing, HQ duties, joint base). **Rec:** confirm all 33 as N/A.
- G1-G8, each with options and a Rec in that file: forms software training, feedback, consolidation, forms and publications libraries, administrative change list, Risk Management Framework, form design waivers, mission directives.
- 1 row is covered now (Table A3.2 item 29); 15 are planned; 3 need new renderer rules; 9 need a flow, column or screen.

## S5. Flow package (flow/solution/README.md "Open design choices", 15 items)

The ones that change behavior most:
- 1. Endorsement routing: A (flow creates rows, Legal after the others), B (app creates all, flow unlocks Legal; new status), C (warn only). **Rec:** A.
- 3. No holiday calendar: 15 business days is built as 21 calendar days. **Rec:** add a PFM Holidays setting later; keep 21 days for the first import.
- 6. Reminder and escalation days are empty variables (no invented values). Need the PFM's numbers.
- 8. Extension Date ignored. **Rec:** use the later of Due Date and Extension Date.
Also note: F03 hard-codes 21/30 days while PFM Settings holds the same values; **Rec:** read PFM Settings (one place per value).

## S6. R09 and its new rules

- R09 goes on the bookmark page only after the PFM's review (PFM, 13 Nov). **Rec:** approve after reading the R09 task in go.md.
- AGENTS.md changed in two places: task scripts use the profile folder (no DODID question; PFM, 13 Nov, R09 scope "d") and the Commands line names the new builders. Confirm.
- T09: the window cannot open e-Publishing for the PFM because the e-Publishing website host is not on the `.pii-guard` allow list (only the PFM adds entries). Option: add it.
- T16 PnP retest: optional step; if a route connects, decision 1B is revisited (PnP could then set list permissions, the logo and r11 directly).

## S7. Validator

F-032 still warns for OPR (3 uses) and ANG (1 use) in the sample; DAFMAN 4.5.9.7.2.5 says such acronyms "should generally" be spelled out. **Rec:** keep these warnings.

## Second-look findings (14 Nov 26)

A review of what the 13-14 Nov work did not consider. The new site is a separate site collection (PFM, 14 Nov). Each "Rec" is Claude's recommendation, not a decision.

### Waiting for the PFM's go (F1-F5; the PFM gave no preference, 14 Nov)

- F1. F05 never creates Legal rows for a Guidance Memorandum: a wing GM runs stages 1-3, then 7-11 (docs/process-model.md variants; DAFMAN 5.1.7), and F05 creates Legal rows only on leaving step 6. **Rec:** create Legal rows when an action enters step 7 from any path.
- F2. Item-level permissions (T02 r11) may lock the Alternate and Acting PFM out of customer rows: the PFM Office group has Edit, and SharePoint lets only the Cancel Checkout permission (not in Edit) edit all items. docs/power-automate-provisioning.md section 4 says Manage Lists; unverified. **Rec:** test before Task 2, or give PFM Office a level with that permission.
- F3. Request limits (plan-audit G24, never decided): F01 and F05 each poll PFM Publications every minute (2,880 checks a day) on the PFM's one account. **Rec:** one trigger for both, polling every 5 minutes; check the account's limit (rights test P16).
- F4. The new site needs site-level setup no task lists: the 90-161.Z library and Seals folder (Task 7 still says "the real site"), P2A read-only config and log lists, groups, time zone, logo. **Rec:** one "new site ready" go.md task.
- F5. The new site is a separate site collection, so the site collection admin rights and the old-site rights results may not apply there. The R09 T16 step asks for "the site address" without saying which. **Rec:** Task 11 and any later rights checks on the new site; go.md R09 step names the new site (T16 itself stays on hold: PnP).

### S8. Old site retirement

The old site holds the 9 r9 lists (41 seed rows plus any test rows). Deleting them is a records action. A: keep read-only until the new site is live, then delete after the PFM (records manager) confirms no record content; B: delete now; C: keep. **Rec:** A.

### S9. Handover (one person runs every flow)

Every flow runs on the PFM's connections and every flow-made row is created by the PFM (service accounts not available, 12 Nov). At PCS or leave the flows stop. A: a handover runbook (co-owners on each flow, connection swap, re-own steps) plus a co-owner now; B: runbook only; C: accept. **Rec:** A; it also serves other wings (deployable package rule).

### S10. CUI in outbound e-mail (plan-audit G25)

F03 and F04 put publication titles and status into e-mail outside the CUI-approved site, unmarked. A: e-mails carry no content, only a link to the item; B: content with a CUI banner and the sensitivity label; C: accept. **Rec:** A.

### S11. Early import test of the flow solution

Five draft flows sit on a solution format written from memory; no import was tried. A: import the draft solution now with every flow turned off (about 10 minutes, a go.md task), fix the format, then build more; B: wait until the flows are final. **Rec:** A.
