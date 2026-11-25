---
name: instructions
description: Use before you write or change text a person acts on: steps, pages, READMEs, go.md, window cards, hand steps or messages.
---

# Write instructions that people follow

AGENTS.md "Instructions people follow" holds the rule; this file holds the steps. The hook `scripts/check_instructions.py --hook` blocks a Write or Edit of a file that `.check` names (`audit-instructions:` lines) until this skill is loaded in the session (with the Skill tool, or a Read of this whole file). After a compaction, load it again.

## Steps

1. Do the context check (below) for the surface and the person.
2. Write each step in the step form (below), in STE (below).
3. Run `python3 scripts/check_instructions.py <file>` on each file you changed, and fix each finding in the text. The check reads numbered steps in Markdown and HTML.
4. Before a release, run the fresh-reader test (below).
5. Text that the check cannot read (a chat message, a card that code makes at run time): do steps 1, 2 and 4 by hand, and say so in the report.

## STE (ASD-STE100)

- Write each instruction as one sentence; it can hold up to three short actions on one screen ("Click **File** > **New**, then press `Ctrl+V`.").
- Write at most 20 words in a sentence of a procedure, and at most 25 words in a description.
- Start each instruction with the verb, in the imperative: "Click", "Type", "Open", "Press".
- Use the active voice and the simple tenses (present, past, future). Do not use an -ing form as a verb.
- Put a condition first: "If the card **Error** shows, click **Retry**."
- Put a warning or a caution before the step it is for.
- Use "the" and "a". Do not use contractions.
- Use one name for one thing, every time: the name that is on the screen.
- Use approved words with their approved meaning (the STE dictionary). Write a technical name (a button, a window, a file) as it is on the screen, in **bold**; write text to type in `code`. If you are not sure that a word is approved, use the shortest common word that has one meaning.
- Do not point to other text: no "see step 3", "as above", "in the section", and no link to another file. Put the words that the person needs in the step.
- Do not use vague words ("appropriate", "as needed", "some", "should", "a few", "soon"). Write the exact thing, number or condition.

## The step form

AGENTS.md "Instructions people follow" sets what a step holds. The parts, in this order:

1. Where: the screen or window, by its name on the screen ("In the window **Backup**,"), when it is not plain from the step before. A step in chat names the screen where the action happens ("On GitHub, on the page **Settings**,").
2. The action: one verb and the exact thing ("click **Restore**"), or up to three short actions on one screen ("Click **File** > **New**, press `Ctrl+V`, then press `F5`."). Text to type in `code`, exactly as it must be typed.
3. What the person sees, only when the screen changes in a way they must check (a new window, a code, an error): "The card **Restore code** opens."
4. A cue, only when one is needed:
   - "Wait until <what the person sees>." for a run or a download. Add "Do not <action> until then." when that helps.
   - "Write down <the value>." Then show the value again in the step that uses it: the page or card shows it there, or the step names the value and where it is on the screen at that time.
   - The next step is the cue in every other case ("Go on." fails the check).

A lead-in step ("On the screen **Sign in**, do these actions:") with up to three numbered actions below it is one step; more actions go in more steps.

Example:

```text
1. In the window **Backup**, click **Restore**, then write down the code on the card **Restore code**.
2. In the window **Restore**, type the code from the card **Restore code**, then press **Enter**.
3. Wait until the card **Restore done** shows. Do not close the window before then.
4. Close the window **Backup**.
```

## Context check

Before you write, and again before a release, answer for each step:

- Which screen or window is the person on? When two windows are open, the step names the window.
- What does the person see right before this step? The step starts from that state.
- When does the step show? Show it on the screen where the action happens, at the time it is needed: on the card, page or dialog of that moment, not in a list that the person reads before.
- What breaks if the person acts too early? Add a wait cue. What goes wrong in the other window? Add a "Do not ..." sentence.
- Which values go from one screen to the next? Show each one again on the screen where the person uses it.

## Fresh-reader test

1. Start a fresh agent that has not seen the build: the `reviewer` subagent where the host has subagents, else a new session. Give it only the steps, as the person sees them, with the screen names, and this brief: "For each step, say back the screen or window, the actions, the exact text to type, and any value you must note (and where you use it). Mark each step where you cannot say one of these, where you would act before you should, or where a sentence tells you nothing you need."
2. Rewrite each marked step. Give the rewritten steps to a new fresh agent with the same brief.
3. Record the result in `docs/reviews/YYYY-MM-DD-fresh-reader.md`: the date, the files, the reader and its model tier, the marked steps, and the result. Fix each marked step before the release.

## A project's own layer

- The instruction files: `audit-instructions: <glob>` lines in `.check` (a guard file: add a line on the Maintainer's request).
- More verbs, vague words, pointers, lower limits, a parser for another file type, or more checks: `scripts/check_instructions_local.py` (its entry points: the header of `scripts/check_instructions.py`).
- Project text for this skill: `PROJECT.md` in this folder.

## What the check does not see

The check measures length, actions, pointers, vague words, waits and filler cues. It does not know if a word is STE-approved, if the named thing is on the screen, or if the step shows at the right time: the context check and the fresh-reader test cover those. The hook does not see a file that a shell command writes: write instruction files with Write or Edit.
