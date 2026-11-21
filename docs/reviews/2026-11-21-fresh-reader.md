# Fresh-reader test: go.md round steps (21 Nov 26)

File: go.md, "How a paste task (round) works" (the steps to start a round, send a line to Claude, the window RADE, red text in ISE, round steps as text, send the results by hand). TASKS.md is the copy that build_readme.py makes from go.md.
Reader: the `reviewer` subagent (inherits the author's tier, Opus). Each test used a new agent that read only the steps.

| Test | Steps | Marked | Main marks | Result |
|---|---|---|---|---|
| 1 | 15 | 7 | no round named; copy failure order; Claude chat not on the work computer; address not shown again; e-mail by hand without keys | rewritten |
| 2 | 19 | 11 | one list cannot hold the cases: the NOT found gate after Run, "task is complete" before the no-draft steps | split into one list per case |
| 3 | 6 lists | 12 | NOT found gate after Run in the RADE list; clipboard not named; no step after Claude answers | gates moved before the steps they guard; shared lists |
| 4 | 6 lists | 0 blockers | minor: no step for a wait past its estimate; To line with another address; a short red line | released; the minor points go to the R42 redraft |

Also from the fresh review of PR 216: the page texts now match the live RADE page ("Copied. Now paste it in PowerShell ISE.", "The browser blocked the copy.", "View as .txt").
