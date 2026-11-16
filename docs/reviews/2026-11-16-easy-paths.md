# Easy paths for the 13-step process (16 Nov 26)

Rule (PFM, 16 Nov 26): no platform limit is assumed unless confidence is high; every easy path is tried at least once before a fallback. This file lists the easy paths, what Microsoft Learn says (pages read 16 Nov 26; they describe the product in general, the tenant can differ), and the fallback that applies only after a failed test. Steps = docs/process-model.md "Target process".

| Test | Easy path | Step | Documents say | Page | Fallback after a failed test |
|---|---|---|---|---|---|
| T1 | An organization mailbox opens the app | 3 | No: a shared mailbox is used through a person's own account; its own account has an unknown password. No try is possible | https://learn.microsoft.com/en-us/exchange/collaboration-exo/shared-mailboxes | A person from the box opens the link as themselves; the app logs who |
| T2 | The Word draft is shown and commented on inside the app | 6, 9 | Partly: the PDF viewer shows only PDF files that are open without sign-in. No Word viewer found | https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/controls/control-pdf-viewer | The draft opens beside the app; feedback is typed on cards |
| T3 | A flow writes the DAF Form 673, 399 and 847 fields and transcribes all answers to one master form | 5, 7, 9 | Word Online (Business) is Premium. PDF form fill: not stated | https://learn.microsoft.com/en-us/connectors/wordonlinebusiness/ | The AO fills or consolidates the form once by hand |
| T4 | A person with Read on the site writes feedback and answers through the app | 6, 9 | The app uses each person's own rights to the data | https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/share-app | A flow writes with the PFM's connection |
| T5 | A flow builds the final copy and posts it with no PFM computer | 11, 12 | Partly: OneDrive "Convert file" is Standard; it does not convert a digitally signed file | https://learn.microsoft.com/en-us/connectors/onedriveforbusiness/ | The PFM builds it at step 11; a flow posts it |
| T6 | The app summarizes a publication and extracts details by itself | 13 | AI Builder models: not available in DoD. Prompts: not read | https://learn.microsoft.com/en-us/ai-builder/availability-region | The GenAI.mil pass at step 8 supplies them |
| T7 | The app searches the address list and returns office and mail | 3, 5, 7 | Yes: Office 365 Users is Standard and returns department, office location and mail | https://learn.microsoft.com/en-us/connectors/office365users/ | The AO picks from PFM Offices |
| T8 | A flow reads who belongs to an organization box | 2, 3, 11 | Not stated for a shared mailbox; group members can be listed | https://learn.microsoft.com/en-us/connectors/office365groups/ | Named people on the office row |
| T9 | A flow sends from the PFM office box, never to an official | 4, 11 | Yes: "Send an email from a shared mailbox (V2)", Standard | https://learn.microsoft.com/en-us/connectors/office365/ | Send from the PFM's own mailbox |
| T10 | The CSS attaches the signed PDF in the app, and the app reads that it is signed | 11 | Attach to a list row: yes (inside a form). Reading the signature: not stated | https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/controls/control-attachments | The CSS confirms with one tick |

Also read: e-mail answer buttons "are only supported with single user mailboxes" (Office 365 Outlook page), so answers stay in the app; an e-mail link can open the app on an exact card (https://learn.microsoft.com/en-us/power-platform/power-fx/reference/function-param). The two US Government pages list no limits themselves; they point to a download that was not read.

Results (2026-11-16-r26-results.md): after R26 r1 (15 Nov 26) and r2 (16 Nov 26), T2, T3, T5, T6, T7, T9 and T10 passed; T4 failed on way a (way b not tried) and T8 failed (fallback: named people on the office row).
