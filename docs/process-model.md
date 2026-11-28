# Process model: 90-161.Z (wing/installation)

Source: DAFMAN 90-161, 18 Oct 2023, Change 1, Corrective Action 1 May 2026. Status: draft. Paragraph references checked against ref/dafman90-161.txt on 12 Nov 26 (docs/reviews/2026-11-12-dafman-full-gap-check.md, docs/reviews/2026-11-12-independent-review.md).

## Target process (Administrator, 16 Nov 26)

The Administrator's 13 steps (docs/DECISIONS.md, 2026-11-16) are the target. The stage table below is what the lists and flows hold today; it changes when the flows and screens are rebuilt. "Stage" = the row of that table a step uses. Easy paths and what the documents say: docs/reviews/2026-11-16-easy-paths.md.

| Step | What happens | Who acts | Stage today | Ref |
|---|---|---|---|---|
| 1 | A publication is triggered for review; the trigger may force a full review | The system | 12 | 7.4.2, 7.4.4 |
| 2 | The OPR's closest organization mailbox gets the e-mail | The system | 0 | 2.7.2 |
| 3 | A person from that box names 1 or 2 AOs in the app; the app logs who | OPR | 0 | 2.7.2 |
| 4 | The AOs get one e-mail: the app, the last published version, a DAF Form 399 | The system | 1 | 7.4.4 |
| 5 | The AO answers "needs further review?" (no = certify current, 399; yes = full process, 673) and names the certifier, the approver and the CSS box of each; mandatory endorsers are prefilled | AO | 1 | 7.5.1, 5.6.3, 5.7 |
| 6 | The AO shares the draft with anyone; they read it and leave feedback in the app | AO, reviewers | 2, 4 | 3.2, 3.3 |
| 7 | The AO adds endorsers and fills in the master DAF Form 673 | AO | 2 | 5.1.3, 5.1.5 |
| 8 | The AO flags the Administrator; the Administrator reviews and formats, the privacy monitor review is recorded, and only the Administrator starts endorsement | Administrator, privacy monitor | 3, 5 | 2.8.1, Chapter 4 |
| 9 | Endorsers review the final draft in the app, comment on the joint CRM and answer; "//SIGNED//" counts; answers are transcribed to one form; the originals stay in the record set | Endorsers, AO | 6 | 5.1.4.3, 5.1.5, 5.3, 5.4 |
| 10 | Wave 1 optional endorsers, wave 2 mandatory endorsers, wave 3 legal. A wave opens when every answer of the wave before is on record | The system | 6, 7 | 5.1.8.2, 5.4.3 |
| 11 | Everything returns to the Administrator, who builds the final copy; then the certifier, then the approver. The CSS may act for an official; officials get no e-mail | Administrator, CSS, officials | 8, 9 | 5.6, 5.7, 5.7.4 |
| 12 | After the last signature: the AO is asked for related e-mail, the Administrator is alerted, the publication is available at once | The system, AO | 11 | 6.4.1, 5.1.5 |
| 13 | The Administrator can change who gets any step or skip anyone, with a logged reason; the app shows, extracts and summarizes publications and forms | Administrator | any | Administrator decision |

- Time (Administrator, 16 Nov 26): each wave has its own due time. The DAFMAN minimum is 15 business days (5.1.4.3, T-3). The AO may give a wave more; the app then shows a note that the ANG may move slower than the AO wants. The wording of that note needs the Administrator's approval.
- A silent endorser: after the due date the AO records "Concur—No Response" with the reason (5.4.3.2; never for legal), or the Administrator skips the row (step 13).
- Roles are data: one person may hold several (in this wing the Administrator is also the privacy monitor) and signs for each role held.
- Stage 10 (submission) has no AO step in the target: the app holds the files after steps 8 and 11. The OPR signature for an administrative change and for Certify Current is given at step 5 or 11.
- New publications and changes the OPR starts enter at step 3.

## Stages (one publication action)

One stage table (Administrator 1A, 12 Nov 26, independent review): the walkthrough stages 0-12 (https://claude.ai/artifact/VLxDqQfhEfWSw4Ckrc52Ki). PFM Process Steps is seeded from this table.

| # | Stage | Ref | Exit condition | Target business days (Table A5.2) |
|---|---|---|---|---|
| 0 | AO appointment (Administrator 2026-11-12): the PFM office mailbox e-mails the target organization's CSS org box: publications X with OPR Y are due for {reason}; an authorized official in the OPR must appoint an AO. The CSS picks the appointee from the GAL in the app (11A). One AO per publication plus at most one alternate (Administrator 2A, 12 Nov). The app logs who named the AO (1.2A). AO change: the OPR asks in the app, the Administrator approves, a flow writes it and e-mails the old AO, the new AO and the Administrator (1.1C). | Glossary (AO is designated by the OPR), 2.7.2, 2.8 | AO named on the PFM Publications row | — |
| 1 | Request: action type, product (or new), OPR, who must follow it (scope level) and the officials that follow from it (N6, N11); preparation: directive or not, existing publications, prior record set, the PCM if the organization has one, notify the Administrator. A New action runs checks N1-N11 first | 3.1, 2.3.2, 5.6.3, 5.7.6.3 | Request saved; Administrator confirms; DAF Form 673 started | — |
| 2 | Drafting with SMEs | 3.2, 4.2.2.1 | Draft uploaded | 60 |
| 3 | Clean and format: the Administrator runs GenAI.mil and the renderer (draft mode) (Administrator Q2A) | Q2A, 3.1.7, Chapter 4 | Draft meets format rules (draft mode); Administrator marks it ready | — |
| 4 | Pre-coordination (optional) | 3.3 | — | — |
| 5 | Privacy review: the unit privacy monitor reviews the draft before formal coordination | 2.8.1, Table A3.1 note 2 | Privacy monitor review documented | — |
| 6 | Formal coordination: package = Word draft (flush left) + CRM + DAF Form 673 | 3.4, 5.1, 5.1.5 | All coordinators responded or marked N/A; all comments adjudicated (5.1.8.1, 2.8.13). An open nonconcur may go on to Legal and Certification (Administrator 1A, Figure A5.1 step 4) | 20 |
| 7 | Legal coordination (servicing legal office below HQ DAF), after all other coordination and adjudication | 5.1.8.2, 3.4 | Legal concur | 20 |
| 8 | Certification: certifying official endorses DAF Form 673 | 5.6 | Endorsed | 10 |
| 9 | Approval: approving official endorses DAF Form 673; delegation letter on file or attached when a delegate signs (5.7.4). Needs Open Nonconcurs = 0 or an impasse memo in the record set (5.5.1, 5.5.2; Administrator 1A) | 5.7 | Endorsed | 10 |
| 10 | Submission: OPR sends 673 (or DAF Form 399 for certify-current), draft, figure files to PFM. The OPR signature that Table A5.1 marks for an AC and for Certify Current is given here | 6.6.1, Table A5.1 | Administrator has package | — |
| 11 | Final build and posting: the Administrator renders the final (seal, page count), posts on the wing site and updates PFM Product Index; for a rescind, removes the product and its links; for Certify Current, marks "Certified Current on". Closeout: a flow files the action's records in Record Sets and deletes its Working Files (drafts) unless Legal Hold or a records freeze applies (Administrator 4.6A; AFI 33-322 3.4.2, 9.1.3) | 6.4.1-6.4.2, 1.1.3.2, 7.11.1, 7.5.2, Table A5.2 f | Posted on wing site; PI updated | 15 |
| 12 | Periodic review: Next Review Due = 4 years after the later of Effective Date and Last Certified Current Date; the review task opens 6 months before (PFM Reviews, DAF Form 399) | 7.4.2, 7.4.4 | OPR answer recorded | — |

Variants (stage numbers as above): Rewrite and interim change = stages 1-11 (7.6, 7.7.9). Administrative change = no coordination and no certifier; the OPR and the publication's approving official sign (7.8.10, Table A5.1; Administrator 4A, 12 Nov: DAFMAN 7.8.3 names a 3-Ltr/L3 official at or above the OPR, and no wing level). GM at wing level = local legal review only (5.1.7; Table A5.1 note 2): stages 1-3, 7-11. Periodic or special review (7.4.3, 7.4.4): OPR responds on a DAF Form 399 in at least 30 days. Certify Current = no changes: OPR and approving authority sign the 399, no coordination (7.5.1); the Administrator marks "Certified Current on" plus the date (7.5.2). Requires Revision, Requires Transfer, Is Obsolete: the AO starts and completes that action within 180 days (7.4.4.3.3). No response: the flow opens a PFM rescind action (7.4.4.4; route 7.11.5.5; Administrator 5A, 12 Nov). Prescribed forms are reviewed with their publication and are not re-dated; the 399 joins the record set (8.11.3.2).

## Timing

| Item | Value | Ref |
|---|---|---|
| Coordinator suspense | 15 business days (T-3) | 5.2 |
| ARC applicability review below MAJCOM/FLDCOM | at least 30 calendar days (written for guard and reserve applicability reviews; whether it covers wing-to-unit coordination is open, gap check) | 5.2.2 |
| Extension request | before suspense date, with rationale and estimated completion date | 5.2.1 |
| Re-coordination | not required if coordination is 365 days old or less and changes are not significant | 5.1 |

## Endorsement responses (PFM Endorsements, Endorsement Status choices)

Concur; Concur With Comment; Concur—No Response (good-faith effort recorded on 673); Nonconcur; No Comment. Ref 5.4.

## CRM columns (T-1)

Item number, Source, Type of comment (Administrative / Substantive / Critical; Critical = automatic nonconcur), Page, Paragraph, Line, Comment, Rationale, Decision. Ref 5.3.

## Mandatory coordinators

Decided (Administrator, 2026-11-12, Q6, Q13): the Administrator keeps the mandatory coordinators in PFM Offices: JAG (legal, last), CIO, PFM, FOIA (1.5.3) and Records (7.1.3), each its own row. The AO, with the PCM, adds offices with functional interest (5.1.3). The OPR identifies its own certifying official (5.6.3) and approving official (5.7).

Table A3.2 local offices and triggers: docs/coordination-table-a3-2.md (Administrator 3B, 12 Nov), seed for PFM Offices. Table A3.1 is not extracted (Q6 stands for A3.1). Open (assumption register): Table A3.1 item 3 also names the privacy official and the Federal Register and information-collection reviews for command or field publications; the Q13 rows do not include them. Records manager coordinates during formal coordination (7.1.3). Forms changed out of cycle: the Table A3.1 item 3 office is the only required coordinator (A3.2 paragraph), plus legal after all other coordination (8.11.1.2).

## System boundary

ANG wing (Administrator, 2026-11-10): publications post to the wing's own site (1.1.3.2, 6.4), not e-Publishing through AFIMPT. 90-161.Z tracks through posting and keeps the PI (6.4.2).

## Rules from the full DAFMAN check (12 Nov 26)

Source and line references: docs/reviews/2026-11-12-dafman-full-gap-check.md (table A). Open choices are marked Decide.

- Request: the Administrator assigns the control number (at least 3 digits, consecutive in the series) and approves every number; supplements = parent number + _<unit>SUP; IC-1, IC-2 ... per product (4.3.8, 4.3.9). Checks at request: what may be supplemented (1.1.3.5.1), OI scope = one function (Table A11.1 item 8), AFR unit applicability (1.9).
- Before Formal Coordination: 673 Section I and blocks 21a/22a filled (5.1.5). Before Legal: every coordinator shown on the 673 or marked N/A (2.8.13). Endorsements transcribed to a master 673 before certification (5.1.5).
- Concur-No Response: explanation required in the staff package (5.4.3.2). Critical comment = nonconcur (5.3.3).
- Certifier: one level above the OPR and one below the approver; the approver may sign both when they coincide (5.6.3.2).
- Effective date = release date or later with justification; never backdated (3.7.5).
- Action types added: Corrective Action (Administrator, no 673; glossary), Reissue GM (4.3.7.2), Transfer with the new approving authority's concurrence first (7.10.1). Administrative Change is started only by the OPR or a PCM (7.8.3).
- GMs: one active per publication (7.9.1); expire after 1 year or on IC/rewrite; a wing GM changes only wing publications (Table A11.1 item 7).
- Rescind: retained forms are first linked to another prescribing publication; ANG notifies subscribers; copy to the information reports management and control office (8.12, 8.12.1, 8.12.2).
- A higher-headquarters change opens a special review for each implementing row (2.6.19).
- Days are calendar days unless stated; coordination stays 15 business days (glossary, 5.2).
- Decided (Administrator 12 Nov, 13 14A 15A): FOIA and Records are separate mandatory coordinators in PFM Offices (one person may hold several roles); full scope is built now; the Administrator keeps record sets centrally in library 90-161.Z. A publication that prescribes paper records alerts SAF/CN (7.1.4).
- Decided (Administrator 12 Nov, independent review 1A 2A 3B 4A 5A): nonconcur gate as in stages 5 and 8; Form Type from Table 8.1, Prescribing Publication only for prescribed forms and forms that collect personal data (8.2.1, 8.7.4); Table A3.2 seeds PFM Offices. Waiver renewal: replaced by coverage-map 1A (12 Nov): one Wing Commander Memorandum for Record within 90 days of a change of command revalidates all wing waivers (ANGMAN 1.7.9); a per-waiver date stays only for waivers a delegated squadron commander approved (9.5.1).
- GMs: justification on the 673 or staff package (5.1.7, T-1); numbered per 4.3.8.2 (number unchanged on reissue); a wing GM changes only a wing instruction, manual or supplement (7.9.1, Table A11.1 item 7); an IC never changes a GM (7.7.6); follow-up action within 1 year (Table A5.1 note 1).
- An IC may also certify the publication current (7.5.3). A rescind after a "No Response" review is the Administrator rescission: 673 to the certifying and approving officials only (7.11.5.5).
- Wing ICs (camera-ready): Rule 2, changed elements marked with manual margin bars, no asterisks, no "(Added)" (7.7.5 note, 7.7.8.5).
- DAF Form 847: inbound for wing publications (7.4.5) and outbound for higher-headquarters publications (A6.3.1; the initiating level's PFM assigns the tracking number, Table A6.1).

## New publication request: no publication exists yet (DAFMAN 3.1)

Anyone may ask for a new publication. The app walks the request through these checks in order, before stage 1. Each check records its answer on the PFM Publications row (Action Type = New). The Administrator confirms or overrules each answer.

| # | Check | Result | DAFMAN |
|---|---|---|---|
| N1 | Owner: which office will own the publication (OPR)? The requester's office is not always the OPR. | OPR from PFM Offices. If the requester is not the AO the OPR designates, stage 0 (AO appointment) runs for that OPR | 2.7, 2.7.2, 3.1.5 |
| N2 | Directive or non-directive? | Directive: continue. Non-directive (pamphlet, handbook, visual aid): outside 90-161.Z (DECISIONS 2026-11-11, directive only); the app says so and refers the requester to the Administrator | 3.1.1, 1.1.2, Tables A11.1, A11.2 |
| N3 | Does a wing publication already cover the subject? Search PFM Product Index by title, series and subject words | Yes: revise it (Interim Change or Rewrite), not New. No: continue | 3.1.2 |
| N4 | Does a higher-headquarters publication cover the subject? | HHQ instruction or manual: a supplement extends its scope unless the HHQ publication allows otherwise; a wing instruction or manual may further implement it. Not allowed: supplementing a PD, PM, GM, MD, OI or a DoD issuance, or an HHQ publication that forbids supplements. A wing manual does not implement an HHQ manual: use a supplement | 1.1.3.5.1, 1.1.3.6.5, 4.7.3.4, Table A11.1 items 4-5 |
| N5 | No departmental instruction or manual exists | A wing instruction or manual may directly implement a PD or a DAF supplement to a DoD issuance. The row is flagged: when departmental guidance appears later, the wing revises or rescinds it (special review) | 1.1.3.6.4 |
| N6 | Who must follow it, then the publication type | Scope first (Administrator 4A): the level that owns it (wing, group, squadron, flight, section) and whether units under that level must follow it. Staff of one office only = an operating instruction of that level; that level and the units under it = an instruction or manual of that level (Table A11.1 item 8: "a group OI applies to the group staff ... If applicability to subordinate squadrons is needed, process a group instruction or manual"); squadron and flight rows are by analogy, not named in DAFMAN. Stored in Applies To Level. Then the type: Instruction (what to do); Manual (how to); Operating Instruction (one function at the lowest level; wider scope = instruction or manual); Instructional Checklist (supports a named instruction or manual; never collects data); Supplement (N4); Guidance Memorandum only when immediate release is needed for risk to life, safety, property or mission (justification required, expires in 1 year, a permanent publication must follow) | Table A11.1 items 4-8, 1.1.3.5.1, 7.9.1, 5.1.7, Table A5.1 note 1 |
| N7 | Higher authority implemented and need | The requester states what the publication implements, why it is needed and the risk of not issuing it | 3.1.4, 3.1.8, 4.4 |
| N8 | Series | From PFM Series (Table A2.1). Series 1 is reserved for the SecAF, CSAF and CSO | 4.3.1, Table A2.1 |
| N9 | Number | The Administrator assigns the control number, consecutive in the series, at least 3 digits; a supplement takes the parent number + _<unit>SUP; a GM that creates a publication is numbered per 4.3.8.2. The Administrator approves every number. The number is unique in PFM Product Index | 4.3.8, 4.3.8.1, 4.3.8.2, 2.6.3 |
| N10 | Forms | New forms: the Administrator assigns form numbers in sequence; adopt a higher-headquarters form first; no duplicate of an existing form; a new form posts with its publication | 8.1.3, 8.3, 8.6.1, 8.7 |
| N11 | Officials (from the N6 scope; Administrator 12 Nov) | Approving official: the commander or director over everyone who must follow it (a deputy or acting leader only when that leader cannot; 5.7.6.3). Certifying official: the lowest official with responsibility for the scope, normally one level above the OPR and one below the approver (5.6.3, 5.6.3.2.1). When the official one level above the OPR is the approver, the OPR's director or head certifies, or the approver signs both (5.6.3.2.2, 5.7.7). The app shows who and why; the OPR confirms the names. A delegate needs a delegation letter (5.7.4). Flight and section publications: the commander over them approves, normally the squadron commander (Administrator 1.6A). The app takes the leaders from PFM Offices (Level, Parent Office, Leader; Administrator 1.5A) | 5.6.3, 5.6.3.2, 5.7.4, 5.7.6.3, 5.7.7 |

Then the action follows stages 1-11 (stage table above) like any other New action. Prior record sets do not exist for a new publication (3.1.3 does not apply).

## Special review out of cycle: commander request or other trigger (DAFMAN 7.4.3, 7.4.4)

A commander (or director), the Administrator or an OPR can ask for a review at any time; changes to mission, implemented publications, laws, regulations, policies or a reorganization also trigger one (7.4.3). The Administrator opens the review task and tracks it (7.4.3, 2.6.11, T-1). It runs the same way for one product or for many.

| # | Step | Who | Result | DAFMAN |
|---|---|---|---|---|
| S1 | Request: who asks (requesting official), the reason, the scope (one product; all products of an OPR, group or series; or all wing products) and any date the requester needs (Review Needed By) | Requester to the Administrator (app screen REQ-01 or e-mail) | One review request | 7.4.3 |
| S2 | The Administrator selects the products in scope (filters on PFM Product Index: OPR, series, type, status Active) and confirms the list | Administrator | List of products, with their prescribed forms (8.11.3.2) | 7.4.3, 8.11.3.2 |
| S3 | A flow creates one PFM Reviews row per product: Review Type = Special, the request's reason and requesting official, OPR Response Due = opened + at least 30 days (later if the Administrator sets it) | Flow | Rows grouped by one Review Request ID | 7.4.4 |
| S4 | The PFM office mailbox e-mails each OPR (the organization's CSS org box and the product's AO, as in stage 0): the products, why, the due date, how to answer on a DAF Form 399 | Flow | Contact out of cycle; reminders in weekdays, measured tone | 7.4.4, 2.6.11 |
| S5 | The OPR answers per product: Certify Current, Requires Revision, Requires Transfer, Is Obsolete, Other; prescribed forms reviewed with it | OPR | 399 uploaded; Certify Current resets the 4-year clock (7.5.2); Requires Revision, Requires Transfer and Is Obsolete: the AO starts and completes the follow-up action within 180 days (7.4.4.3.3; Other has no 180-day rule) | 7.4.4.1-7.4.4.3, 7.5 |
| S6 | No answer by the due date: the flow opens a PFM rescind action (Administrator 5A, 12 Nov; 7.4.4.4 says "will", 7.11.5.5 "may"): the Administrator staffs a 673 to the certifying and approving officials only | Flow, then Administrator | Rescind action | 7.4.4.4, 7.11.5.5 |
| S7 | Status to the requester: on demand and at close, the Administrator sends a status report of the request (all products, answers, follow-up actions) | Flow | Report e-mail (DECISIONS 2026-11-11: status report to anyone at any time) | 2.6.8 |

A higher-headquarters change (2.6.19, 4.7.3.5) and new departmental guidance (1.1.3.6.4) use the same path with the reason set by the Administrator.
