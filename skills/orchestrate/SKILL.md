---
name: orchestrate
description: Run one or more features through the multi-agent loop - TASK, implementer, reviewer iterating to PASS, then merge the default branch, re-gate, push, PR, CI, validation with evidence and merge - while keeping REPORT.md current. Use when the user asks to build, fix or ship something in a project set up with /workflow-init, or to run several branches in parallel.
argument-hint: "[<type>/<topic> <goal> ...]"
---

# Orchestrate

You are the orchestrator: you write TASKs, spawn and steer the agents, coordinate builds, and are the only one who pushes, opens PRs and (if allowed) merges.

## Load first
- `AGENTS.md`: the project's own rules, and the "How we work" parameters table. Every `<name>` below is a value from that table (`<default-branch>` = `default_branch`, and so on). No table: tell the user to run `/agent-workflow-kit:workflow-init` and stop.
- The profiles: `${CLAUDE_PLUGIN_ROOT}/profiles/<profile>.md`, for each entry in `profiles`.
- Validation modes: `${CLAUDE_PLUGIN_ROOT}/reference/validation-modes.md`.
- Lessons: `${CLAUDE_PLUGIN_ROOT}/LESSONS.md` (entries for `orchestrator` and `all`).
- Templates: `${CLAUDE_PLUGIN_ROOT}/templates/` (TASK.md, PR.md, REPORT.md).

These paths are substituted when the skill loads. The variable is not set in the Bash tool: copy the path as written here, never `$CLAUDE_PLUGIN_ROOT` in a shell command.

## Agents
- Use the names in the `agents` row. Without it, take the first that exists and contains `agent-workflow-kit:begin`:
  1. `.claude/agents/implementer.md`;
  2. `.claude/agents/kit-implementer.md`;
  3. else `agent-workflow-kit:implementer`.
  The same order applies to the reviewer. A project agent without the kit marker is not the kit's; never brief it as one.
- Keep each agent's ID. Fix rounds go to the SAME implementer and re-reviews to the SAME reviewer through SendMessage, so they keep context. Spawn a fresh one only if the agent is gone; then pass the full history of findings.

## Brief checklist (the brief is the agent's only context)
- Worktree path, branch, TASK path, and the lessons path (the substituted path above).
- The shell's directory resets between calls: every command uses `cd <worktree> &&` or `git -C <worktree>`.
- Rules it would otherwise break: `commit_format`, attribution, no push, build lock, no tool installs.
- Facts already established, with `file:line`, and which ones to verify.
- Out of scope, including other agents' worktrees.
- The reviewer gets none of the implementer's reasoning.

## 1. Set up each branch
1. `git fetch origin`, then cut from `origin/<default-branch>` at the `worktree_root` pattern:
   ```sh
   git worktree add -b <type>/<topic> <worktree-path> origin/<default-branch>
   ```
2. Run `worktree_setup` in the new worktree before anything commits there: the lockfile install (hooks call the toolchain) and the env files the profile needs (e.g. `.env.testing` with the worktree's own test DB).
3. Isolation:
   - With a build lock and a `slot_dir` that is not `project`: write `<worktree>/.build-slot` with a slot no live branch uses (reuse finished slots). With `slot_dir: project`, write nothing; the project's target-dir applies.
   - Otherwise assign the port, test DB, venv and data dirs that the profile and `validation-modes.md` describe.
4. Write `<worktree>/TASK-<topic>.md` from the TASK template. Fill every field from reading the code, not from guesses.
5. Do not run two branches that touch the same files in parallel. Respect `max_parallel_implementers`.

## 2. Implement and review until PASS
1. Spawn the implementer with the brief. Wait for its report; never predict it.
2. Spawn the reviewer on the same worktree with the TASK path.
3. Sanity-check findings before relaying them:
   - a finding that contradicts the spec or a settled decision: override it, record it as deliberate in REPORT.md and in the next brief;
   - a finding that is wrong: add it to the reviewer's "Known false positives" (outside the managed block).
4. On FAIL: send the findings to the same implementer; send its fix commits, with each finding's resolution, to the same reviewer. Repeat until PASS, or until `review_round_limit` failed rounds; then stop that branch and ask the user. When the reviewer says `design`, redesign before patching again.
5. Medium and Low findings are fixed or recorded as deliberate before the PR. Any commit after a PASS needs a new PASS.
6. Run each `extra_reviews` entry the project requires, and treat its blocking findings like the reviewer's.
7. Stop and ask the user only for a decision the merge policy reserves for them.

## 3. Build coordination
- `build_serialization: lock`: only one heavy build at a time across all worktrees. Implementers run branch checks only; the reviewer runs the full gate through the lock; you run it again only after merging the default branch. Full gates and release builds run in the background; wait for completion.
- `build_serialization: none`: implementers run the full gate themselves; parallelize freely up to the limit.
- Gate exit 75 (lock timeout) is not a code failure. Report it with the numbers it printed, and check for a dev app, an editor or another session keeping cargo alive (`validation-modes.md`, desktop-window).

## 4. Ship each branch with PASS
1. Merge the current default branch into the branch and re-gate (LESSONS L8):
   ```sh
   git -C <worktree> fetch origin
   git -C <worktree> merge --no-ff origin/<default-branch>
   cd <worktree> && sh scripts/gate.sh
   ```
   If the merge needed a conflict resolution, get a new PASS on it.
2. Push to `remote` and open the PR as a draft, with the body from the PR template (or the project's PR template). The title follows `commit_format`.
   ```sh
   git -C <worktree> push -u <remote> <type>/<topic>
   gh pr create --draft --base <default-branch> --title "<title>" --body-file <filled-PR.md>
   ```
   With `remote: local-only` or no push rights, record a pending decision and continue with other branches.
3. CI:
   - `ci: required`: wait for every job, in the background (`gh pr checks <n> --watch`). A red job goes back to the implementer as a finding.
   - Any other value: CI cannot run. After the merge in step 6, re-run the full gate on the merged result and record its output in the PR and REPORT.md.
4. Validation per `ui_validation` and `ui_validation_procedure` (`validation-modes.md`), following the TASK's validation list. Save the evidence (screenshots, request/response logs, transcripts) and link it in the PR and REPORT.md. Never steal focus while the user may be present (LESSONS L1).
5. Merge, if `merger` is `orchestrator`, `merge_approval` is met, and every merge-policy criterion holds:
   ```sh
   gh pr ready <n>
   gh pr merge <n> --merge
   ```
   NEVER `--delete-branch`. If `merger` is `user`, or `merge_approval` needs them (e.g. a staging batch), mark ready and report that it awaits them.
6. Update the local default branch: `git pull --ff-only`. Rebase nothing that is pushed.

## Duties at all times
- REPORT.md (untracked, never committed): create it from the template at the start, and update it after every event (spawn, verdict, push, CI, validation, merge, incident). Never only at the end (LESSONS L9). Branch decisions go to `decisions_log`, committed on the branch.
- Pending user decisions (licence, third-party downloads, publishing, paid services, anything irreversible): record them under "Pending decisions", stop that line of work, continue the others. Never take them or work around them (LESSONS L10).
- Never delete a branch or worktree. Before rewriting any existing commit (e.g. to drop a trailer): `git branch backup/<branch>-before-rework`, then rewrite non-interactively (LESSONS L5).
- Never push to `<default-branch>`, never force-push a pushed branch.
- Parallel agents or trial runs each get their own scratch directory (LESSONS L13).
- New lessons from this session: propose them to the user for `LESSONS.md` in the kit repo.

## Final message to the user
What was merged (PR links), what awaits them (merges, pending decisions), incidents, and what needs a human check. Point to REPORT.md for the rest.
