# 90-161.Z PFM window: usability targets (17 Nov 26)

Deeper pass, step 2 (plan: docs/reviews/2026-11-17-window-plan.md). Inputs: the PFM's answers of 17 Nov 26 (counts and patterns only). Each target has a field source (schemas/lists), a DAFMAN 90-161 paragraph where one applies, and a proof that is not the author's judgment. Targets are agent RECs until the PFM approves them.

## PFM answers (17 Nov 26)

| Question | Answer |
|---|---|
| Open actions in a busy month | Under 15 |
| Monitors | The PFM: one 49" ultrawide. Others: two 34" ultrawides, or 24", 27" or 32" regular monitors. The window works at any regular aspect ratio, and as half of a 34" or a third of a 49" |
| First look each morning | What needs me today |
| Slowest or most error-prone today | Chasing offices; who has it now |

## Window sizes to support (logical px)

| Case | Logical size (approx.) | Note |
|---|---|---|
| Smallest: 24" 1920 x 1080 at 150 % | 1280 x 720 | Main column scrolls; nothing is cut |
| 1920 x 1080 at 125 % | 1536 x 864 | |
| Third of a 49" (5120 x 1440, 100 %) | 1707 x 1440 | Tall: more rows, not wider cards |
| Half of a 34" (3440 x 1440, 100 %) | 1720 x 1440 | Same layout as the third of a 49" |
| 1920 x 1080 at 100 % | 1920 x 1080 | |
| 27" or 32" 2560 x 1440 at 100 % | 2560 x 1440 | Content width capped; no line longer than about 100 characters |

The window keeps the size and place the PFM gives it (Windows Snap included) and opens there next time; it never forces full screen. This replaces "maximized on one monitor" (plan revision 2).

## Targets

| # | Target | Fields | DAFMAN | Proof |
|---|---|---|---|---|
| U1 | See what needs me today in under 5 s: Your Work opens on it, soonest due first, the first item visible without scrolling at 1280 x 720 | Publications ProcessStep, ActionStatus; Endorsements DueDate | PFM steps 8, 11 (2.8.1; 5.6, 5.7) | PFM timed task on the prototype; layout check at 1280 x 720 |
| U2 | Who has it now: every open action shows who must act next and since when, all on one screen (15 actions or fewer), no click needed | Publications ProcessStep, AO, CertifyingOfficial, ApprovingOfficial; Endorsements Endorser, ResponseDate; "since": Activity Log (gap G1) | 5.1.8.2 (legal last) | PFM timed task; 15-row board fits at 1280 x 720 with in-table scroll only |
| U3 | Chase offices: every late or due-soon office in one list; one reminder in 2 actions or fewer; "remind all late" with one confirm; each contact logged with its date | Endorsements DueDate, ExtensionDate, ResponseDate, NoResponseExplanation; reminder log (gap G2) | 5.2 (15 business days, T-3); 5.2.1 (extension); 5.4.3, 5.4.3.1 (good-faith contacts; never Concur-No Response for legal) | PFM timed task; the log row exists after a reminder (flow test in an app round) |
| U4 | Start endorsement in 3 actions or fewer, with a confirm that names the offices and the due date | Endorsements CoordinationRound, EndorserOrder, DueDate | 2.8.1 (privacy monitor before formal coordination); 5.2 | PFM timed task |
| U5 | Change or skip anyone (step 13) in 3 actions or fewer; a reason is required and logged | Activity Log EventType, EventBy, EventDetails | PFM decision 16 Nov 26 | PFM timed task; empty reason blocks Save |
| U6 | Every task works with the keyboard only; focus always visible | - | Section 508 | Keyboard-only walk of U1 to U5 on the WinForms spike |
| U7 | Every control has a screen-reader name; Windows high contrast stays readable | - | Section 508 | Script lists controls with no AccessibleName (0); spike picture in high contrast |
| U8 | No horizontal scroll, no cut text at every size above; text 4.5:1, parts 3:1, targets 24 px | - | WCAG 2.1 AA | ui-verify measure at each size; tests/check_palette.py |

## Data gaps (agent RECs, not decisions)

- G1 "With since": no field holds the date an action entered its step. REC: derive from PFM Activity Log (EventType = step change); a new Publications field only if the read is too slow in an app round.
- G2 Reminder log: nothing records a reminder to an office. REC: an Activity Log row per contact (EventType = Reminder, the office in EventDetails); it is also the 5.4.3.1 good-faith record. Show "last reminded" and the contact count on each late office.
- Citation fix: the 15-business-day suspense is DAFMAN 90-161 5.2, not 5.1.4.3 (the preview canvas and the Thirteen Steps artifact cite 5.1.4.3).
