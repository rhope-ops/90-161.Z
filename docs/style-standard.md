# Style standard: 90-161.Z

Decided (Administrator, 2026-11-11): everything 90-161.Z creates is standardized IAW DAFMAN 90-161 and The Tongue and Quill. The rules below were approved by the Administrator on 2026-11-11 (1A). `tests/check_names.py` enforces the rules marked **(test)**.

Sources:
- DAFMAN 90-161, 18 Oct 2023, Change 1 and Corrective Action: `ref/dafman90-161.txt`. It governs terms and publication format.
- AFH 33-337, The Tongue and Quill, 27 May 2015, incorporating Change 1, 19 Nov 2015 (cited in DAFMAN 90-161 1.2.4, 1.5.9 and Attachment 1). It governs general writing style. Copy: https://www.govinfo.gov/content/pkg/GOVPUB-D301-PURL-gpo67301/pdf/GOVPUB-D301-PURL-gpo67301.pdf (SHA-256 4aac9128a7282f494153ba2ab072d478b2acd61ecd28dfdd2969915cf08ccc4d). It is not stored in the repo because it is 7.8 MB.
- On a conflict, DAFMAN 90-161 wins (it is the rule source).

## Scope

| Applies to | Rules |
|---|---|
| Text people see in SharePoint, Power Automate and Power Apps: list titles and descriptions, column names and descriptions, choice values, view names, flow names, flow messages, e-mails the flows send | All |
| Files for the gov device: go.md, the list mockup, script console text | All |
| Rendered publications and the CRM | DAFMAN format rules (docs/format-rules.md) first, then this file |
| Repo records for agents (docs/DECISIONS.md, docs/NEXT_PROMPT.md, the project log, AGENTS.md) | Terms (1) only; dates stay YYYY-MM-DD for sorting (AGENTS.md) |

## Rules

1. **Terms.** Use the DAFMAN term, spelled as DAFMAN spells it **(test, for the terms listed in the test)**.
   - Action types (1.1.4.1-1.1.4.8): New, Rewrite, Interim Change, Administrative Change, Guidance Memorandum, Certify Current, Rescind, Transfer.
   - Coordination responses (5.4.1-5.4.5): Concur, Concur With Comment, Concur—No Response, Nonconcur, No Comment. The 5.4.3 heading uses an em dash; DAFMAN body text also shows a hyphen or en dash. We use the heading form.
   - Review statuses (7.4.4.1, 7.4.4.3): Certify Current, Requires Revision, Requires Transfer, Is Obsolete, Other. PFM Reviews also has No Response, which is not a DAFMAN status: it records the 7.4.4.4 case (no response, the Administrator starts a Rescind). Kept by the Administrator, 2026-11-11 (2A).
   - e-mail (DAFMAN about 30 times, "Email" 2 times; T&Q chapter 25, Hyphen rule 4: "E-mail"). In a title: E-Mail, as in the T&Q heading "Electronic Mail (E-Mail)" (chapter 12) and the DAFMAN table of contents. T&Q chapter 27 title rule 4 would lowercase a second element after a prefix; "e-" is a letter, not a prefix, and both sources capitalize it.
   - nonconcur, record set, Product Index, action officer, office of primary responsibility.
2. **Title capitalization** for list titles, column names, view names, flow names, choice values and headings (T&Q chapter 27, "Titles of Literary and Artistic Works and Headings") **(test)**:
   - Capitalize every word, except articles (a, an, the), short conjunctions (and, as, but, if, or, nor) and short prepositions (at, by, for, in, of, off, on, out, to, up).
   - Always capitalize the first word, the last word and the first word after a dash, a colon or a " - " separator (rule 5).
   - Capitalize both parts of a hyphenated word; "up" in "Follow-Up" is an adverb and is capitalized (rule 5c).
   - "with" has 4 letters and is capitalized: Concur With Comment.
3. **Abbreviations** (T&Q chapter 26; DAFMAN 4.5.9.7.2):
   - A name may use only abbreviations listed in DAFMAN Attachment 1, Abbreviations and Acronyms **(test)**. Others are spelled out (for example, personal identifiable information, 8.9.1.2).
   - A column whose name has an abbreviation has a SharePoint column description that spells it out **(test)**.
   - A list description spells out each abbreviation at its first use, for example "Publications and Forms Manager (PFM)".
   - No informal short forms in product text: "government computer", not "gov device"; "repository", not "repo"; no contractions.
   - Approved exception (Administrator, 2026-11-11): list titles keep the prefix "PFM" (T&Q advises against abbreviations in main headings; the Administrator chose the prefix, and the description spells it out).
4. **Dates and times** (T&Q chapter 28, Dates; Clock Time):
   - Short form: 11 Nov 26 (when the month is abbreviated, the year is too). Full form: 11 November 2026. Never 2026-11-11 or 11/11/2026 in product text.
   - Grids and lists use the short form; e-mails and generated documents use the full form.
   - Times are 24-hour without a colon and without "hours": 1708 CT.
5. **Numbers** (T&Q chapter 28): in sentences, write one through nine as words and 10 and above as figures. Use figures in tables, counts in tool output, time periods (30 days, 15 business days), money, measurements, references (5.2, Table A5.2) and compound modifiers (4-year review).
6. **Punctuation** (T&Q chapter 25): em dash (—) without spaces for a break; hyphen in compound modifiers before a noun (follow-up action, 4-year cycle); "e-mail". Exception (Administrator naming rule 5, 2026-11-11): view names use "<audience> - <what>" with a spaced hyphen, because an em dash cannot be typed on the gov device and breaks the view address.
7. **Flow inputs** (Administrator, 2026-11-12): every input label and its gray help text tells a low-skill user what to do and where to find it, in plain words (DAFMAN 1.2.4 plain language). Example help text: "Open the SharePoint site, copy the whole address from the bar at the top of the browser, and paste it here."
8. **Publications.** Two spaces between sentences, format and layout come from DAFMAN 90-161 and docs/format-rules.md; plain language per DAFMAN 4.5.9.7 and T&Q.

## Change a rule

A rule changes only by an Administrator decision in docs/DECISIONS.md. Update this file and the test in the same commit.
