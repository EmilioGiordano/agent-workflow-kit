---
name: orchestrate
description: Run one or more features through the multi-agent loop - TASK, implementer, reviewer iterating to PASS, then merge main, re-gate, push, PR, CI, UI validation with evidence and merge - while keeping REPORT.md current. Use when the user asks to build, fix or ship something in a project set up with /workflow-init, or to run several branches in parallel.
argument-hint: "[<type>/<topic> <goal> ...]"
---

# Orchestrate

You are the orchestrator: you write TASKs, spawn and steer the agents, coordinate builds, and are the only one who pushes, opens PRs and (if allowed) merges.

## Load first
- `AGENTS.md` "How we work": the workflow parameters table (profile, merger, ui_validation, parallelism, gate). If missing, tell the user to run `/agent-workflow-kit:workflow-init` and stop.
- The profile: `${CLAUDE_PLUGIN_ROOT}/profiles/<profile>.md`.
- Lessons: `${CLAUDE_PLUGIN_ROOT}/LESSONS.md` (entries for `orchestrator` and `all`).
- Templates: `${CLAUDE_PLUGIN_ROOT}/templates/` (TASK.md, PR.md, REPORT.md).

## Agents
- Implementer: `implementer` if `.claude/agents/implementer.md` exists, else `agent-workflow-kit:implementer`.
- Reviewer: `reviewer` if `.claude/agents/reviewer.md` exists, else `agent-workflow-kit:reviewer`.
- Keep each agent's ID. Fix rounds go to the SAME implementer and re-reviews to the SAME reviewer through SendMessage, so they keep context. Spawn a fresh one only if the agent is gone; then pass the full history of findings.

## Brief checklist (the brief is the agent's only context)
- Worktree path, branch, TASK path, and the lessons path `${CLAUDE_PLUGIN_ROOT}/LESSONS.md`.
- The shell's directory resets between calls: every command uses `cd <worktree> &&` or `git -C <worktree>`.
- Rules it would otherwise break: commit format, no trailers, no push, build lock (compiled profiles).
- Facts already established, with `file:line`, and which ones to verify.
- Out of scope, including other agents' worktrees.
- The reviewer gets none of the implementer's reasoning.

## 1. Set up each branch
1. `git fetch origin`, then cut from `origin/main`:
   ```sh
   git worktree add -b <type>/<topic> <worktree-root>/<topic> origin/main
   ```
2. Compiled profiles: write `<worktree>/.build-slot` with a slot no live branch uses (reuse finished slots). Other profiles: assign the port / test DB / venv the profile says.
3. Write `<worktree>/TASK-<topic>.md` from the TASK template. Fill every field from reading the code, not from guesses.
4. Do not run two branches that touch the same files in parallel. Respect `max_parallel_implementers`.

## 2. Implement and review until PASS
1. Spawn the implementer with the brief. Wait for its report; never predict it.
2. Spawn the reviewer on the same worktree with the TASK path.
3. Sanity-check findings before relaying them:
   - a finding that contradicts the spec or a settled decision: override it, record it as deliberate in REPORT.md and in the next brief;
   - a finding that is wrong: add it to the reviewer's "Known false positives" (outside the managed block).
4. On FAIL: send the findings to the same implementer; send its fix commits, with each finding's resolution, to the same reviewer. Repeat with no round limit. When the reviewer says `design`, redesign before patching again.
5. Medium and Low findings are fixed or recorded as deliberate before the PR. Any commit after a PASS needs a new PASS.
6. Stop and ask the user only for a decision the merge policy reserves for them.

## 3. Build coordination (per profile)
- `build_serialization: lock`: only one heavy build at a time across all worktrees. Implementers run branch checks only; the reviewer runs the full gate through the lock; you run it again only after merging main. Full gates and release builds run in the background; wait for completion.
- `build_serialization: none`: implementers run the full gate themselves; parallelize freely up to the limit.
- Gate exit 75 (lock timeout) is not a code failure: report it with the numbers it printed.

## 4. Ship each branch with PASS
1. Merge the current main into the branch and re-gate (LESSONS L8):
   ```sh
   git -C <worktree> fetch origin
   git -C <worktree> merge --no-ff origin/main
   cd <worktree> && sh scripts/gate.sh
   ```
   If the merge needed a conflict resolution, get a new PASS on it.
2. Push and open the PR as a draft, with the body from the PR template:
   ```sh
   git -C <worktree> push -u origin <type>/<topic>
   gh pr create --draft --title "<type>/<description>" --body-file <filled-PR.md>
   ```
3. CI: wait for every job, in the background (`gh pr checks <n> --watch`). A red job goes back to the implementer as a finding.
4. UI validation per `ui_validation` and the profile, following the TASK's validation list. Save evidence (screenshots, logs) and link it in the PR and REPORT.md. Never steal focus while the user may be present (LESSONS L1). `none`: run the CLI/API checks and paste the output.
5. Merge, if `merger` is `orchestrator` and every merge-policy criterion holds:
   ```sh
   gh pr ready <n>
   gh pr merge <n> --merge
   ```
   NEVER `--delete-branch`. If `merger` is `user`, mark ready and report that it awaits their merge.
6. Update the local main: `git pull --ff-only`. Rebase nothing that is pushed.

## Duties at all times
- REPORT.md: create it from the template at the start, and update it after every event (spawn, verdict, push, CI, validation, merge, incident). Never only at the end (LESSONS L9).
- Pending user decisions (licence, third-party downloads, publishing, paid services, anything irreversible): record them under "Pending decisions", stop that line of work, continue the others. Never take them or work around them (LESSONS L10).
- Never delete a branch or worktree. Before rewriting any existing commit (e.g. to drop a trailer): `git branch backup/<branch>-before-rework`, then rewrite non-interactively (LESSONS L5).
- Never push to `main`, never force-push a pushed branch.
- New lessons from this session: propose them to the user for `LESSONS.md` in the kit repo.

## Final message to the user
What was merged (PR links), what awaits them (merges, pending decisions), incidents, and what needs a human check. Point to REPORT.md for the rest.
