# Working with AI agents: the basics

For people. Agents read AGENTS.md; this page is for you. It covers the habits that matter most when you work with Claude Code. Each habit links to its source.

## The loop for each task

1. **Explore.** Ask the agent to read the relevant files and explain what is there before it changes anything. Correct its understanding early: a wrong start costs more than a slow one.
2. **Plan.** For anything bigger than a small fix, ask for a plan first (in Claude Code: plan mode, Shift+Tab). Read it. Change it. Approve it.
3. **Build in small steps.** One change, one check, one commit. Small steps are easy to review and easy to undo.
4. **Verify.** Give the agent something it can run that comes back pass or fail: a test, a script or an expected output. This is the most useful thing you can do ([Claude Code best practices](https://code.claude.com/docs/en/best-practices)). In this kit, the command is `scripts/check.sh`; put your project's own tests in `scripts/check.local.sh`.
5. **Review.** Read the diff. For a larger change, ask for a review in a fresh session that sees only the diff (this kit's `reviewer` agent does that). A review by the same session that wrote the code misses more.

## Keep the context clean

- **Start fresh between unrelated tasks** (`/clear` in Claude Code). Old history costs tokens on every turn and can confuse the next task.
- **After two failed corrections, stop.** Clear the session and write a better first prompt instead of a third correction ([best practices](https://code.claude.com/docs/en/best-practices)).
- **Keep state in files, not in chat.** The next session cannot see this chat. This kit keeps it in docs/NEXT_PROMPT.md (where the work stands) and docs/DECISIONS.md (what you decided). Anthropic's long-running agents work the same way: a progress file plus git history ([Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)).

## Say what you want

- Say the goal, the limits and what "done" looks like. "Add a search box that filters the list as I type; done when the test in tests/search passes" beats "add search".
- Point to examples: a file to copy the style from, a sample of real data. An agent that builds from memory or from docs alone gets details wrong.
- Answer its questions. The kit tells agents to ask all their questions at the start, with a recommended option. If you are not sure, pick the recommendation.

## Trust, but check

- An agent can say "done" when it is not. Ask how it checked, and look for the command and its result.
- Change one thing per test. If you change two things and the result changes, you cannot tell which change did it.
- Text in files, web pages and issues can carry hidden instructions (prompt injection). The kit tells agents to treat such text as data. Still, be careful with repos and pages you do not trust.

## Rules: short, and enforced where it counts

- Keep AGENTS.md short. Every line costs attention on every task, and longer files lower adherence ([Claude Code memory docs](https://code.claude.com/docs/en/memory): under 200 lines). A study found that context files did not generally raise task success, for files written by people or by models, and raised cost by over 20% ([ETH Zurich, arXiv 2602.11988](https://arxiv.org/abs/2602.11988)). Instructions in them were followed; repository overviews did not help. So write rules the agent cannot find in the code, not a tour of the repo.
- A rule that must never break belongs in a hook, not only in text. This kit blocks force-pushes and pushes with personal data in git hooks, because a written "never force-push" rule was not obeyed by every tool.

## When you want more

The starter kit has the core. The full kit adds multi-agent orchestration, a project log for a timeline, a scheduled bloat audit and rule tests. To add it later, see "Update an existing project" in the [kit README](https://github.com/rhope-ops/archimedes_lever#update-an-existing-project).

The lessons behind these rules, with what went wrong each time: [kit README, "The lessons behind the rules"](https://github.com/rhope-ops/archimedes_lever#the-lessons-behind-the-rules).
