---
description: Set up the multi-agent workflow in this project - read the project's own rules, detect stacks, branch, commit format and CI, resolve conflicts with the user, then write the "How we work" block of AGENTS.md, the agents, scripts/gate.sh and (compiled stacks) scripts/build-lock.sh. Safe to re-run; it only updates its own marked blocks.
argument-hint: "[profile[,profile]]"
disable-model-invocation: true
---

# /workflow-init

Bootstrap or update the agent workflow in the current repository. Respect the existing project: its rules win unless the user says otherwise. Write nothing before step 6.

Kit files (read them; do not copy this command's text):
- Detection rules: `${CLAUDE_PLUGIN_ROOT}/reference/detection.md`
- Validation modes: `${CLAUDE_PLUGIN_ROOT}/reference/validation-modes.md`
- Profiles: `${CLAUDE_PLUGIN_ROOT}/profiles/*.md`
- Gates: `${CLAUDE_PLUGIN_ROOT}/scripts/gates/<profile>.sh`; lock: `${CLAUDE_PLUGIN_ROOT}/scripts/build-lock.sh`
- Templates: `${CLAUDE_PLUGIN_ROOT}/templates/how-we-work.md`, `merge-policy.md`
- Agents: `${CLAUDE_PLUGIN_ROOT}/agents/implementer.md`, `reviewer.md`
- Lessons: `${CLAUDE_PLUGIN_ROOT}/LESSONS.md`

These paths are substituted when this command loads. The variable is not set in the Bash tool: use the paths as written here, never `$CLAUDE_PLUGIN_ROOT` in a shell command.

## Ownership rules
- Markdown the kit owns sits between `<!-- agent-workflow-kit:begin -->` and `<!-- agent-workflow-kit:end -->`. Re-runs replace only that block, generated from the parameters table.
- A Markdown file without the markers (e.g. an existing AGENTS.md): append a new marked block at the end, only after showing the block and getting an OK. Never edit text outside the markers.
- Any other file without the kit marker is never overwritten. An unmarked `.claude/agents/implementer.md` or `reviewer.md` means the kit agents are installed as `kit-implementer.md` / `kit-reviewer.md`, with the frontmatter `name:` changed to match.
- `scripts/gate.sh` carries `# agent-workflow-kit:managed`. Init refreshes the text outside `# agent-workflow-kit:steps:begin` / `:end`. The steps section is derived; on re-run, re-derive it, show the diff against the current section, and replace it only on OK.
- `scripts/gate.local.sh` is the project's: created with a usage comment only, never overwritten.
- `.gitignore` and `.gitattributes`: append missing lines only, and list them in the summary.
- Match each file's line endings: a CRLF file gets a CRLF block.

## 1. Check the repo
- Must be the root of a git repository (`git rev-parse --show-toplevel`). If not, stop.
- If AGENTS.md has the kit block, its parameters table holds the defaults for every question below. A re-run with unchanged answers must produce no diff.

## 2. Read the project's rules (required)
Read every source listed under "Project rules" in `detection.md`. Note each rule with `file:line`.

## 3. Detect
Follow `detection.md` for each item:
- profiles (a list, from `$ARGUMENTS` or the detect table below);
- default branch and commit format;
- CI capability and remote;
- the gate (CI steps first, then package scripts, then declared profile tools), opt-ins and dropped tools;
- worktree root and setup, slot dir, parallelism, validation mode;
- the Laravel test database (php-laravel).

| Found | Profile |
|---|---|
| `Cargo.toml` (root or a subdir such as `src-tauri/`) | rust-compiled |
| `composer.json` + `artisan` | php-laravel |
| `package.json` + `tsconfig.json` | node-ts |
| `pyproject.toml`, `setup.py` or `requirements.txt` | python |

Several match: they all go in `profiles` (a hybrid). None match: list the profiles and ask; offer to add one (README "Add a profile").

## 4. Conflicts, then questions (one message)
1. Show the conflict table from `detection.md`: rule | project says (`file:line`) | kit default | proposed (project). The user answers per row: `project`, `kit` or `abort`. On `abort`, stop without writing.
2. Show the detected values (the parameters table, with defaults marked) and ask only what detection left open:
   - who merges, and any approval or batching rule [project rule, else orchestrator];
   - extra required reviews and the review-round limit [project rule, else none];
   - validation mode and its exact procedure [detected mode];
   - machine: cores and RAM (for the parallelism formula), slot dir and memory thresholds for compiled stacks;
   - commit format and language [detected];
   - attribution [none];
   - agent model [the project's existing agents, else inherit];
   - decisions log [ROADMAP.md if it has "Decisions taken on the way", else `docs/decisions.md`].
3. If CLAUDE.md exists and does not import AGENTS.md, offer to add an `@AGENTS.md` line to it (Claude Code loads CLAUDE.md, not AGENTS.md).

Do not continue until the user answers. Unanswered items take the default and are listed in the report.

## 5. Baseline
Run the static steps of the derived gate (format, lint, types; no compile, no tests) on a clean checkout of the default branch. On failure, follow "Baseline" in `detection.md`: report the result and offer the formatting branch or dropping the step. The user decides.

## 6. Write
1. `AGENTS.md` (create it with a `# AGENTS.md` title if missing). Fill `how-we-work.md`:
   - every row of the parameters table;
   - `<gate and branch-check commands>`: the derived commands, per stack for hybrids;
   - `<merge-policy>`: `merge-policy.md` filled from the table; drop the alternatives that do not apply;
   - drop the leading `<!-- ... -->` template comment of each inserted template.
2. Agents (`.claude/agents/<name>.md`, names per the ownership rules): copy the kit agents, then:
   - fill `## Project settings` inside the managed block from the table;
   - set `model:` in the frontmatter when `agent_model` is not `inherit`;
   - on re-run, keep the project's frontmatter edits and everything after the end marker (project notes, the reviewer's "Known false positives").
3. `scripts/gate.sh`: the head and foot of `scripts/gates/<first profile>.sh`, with the header set to `profiles=<list>`. The steps section holds:
   - one `# -- stack: <profile>` part per profile, from the derived steps;
   - each step only once; no `# init:` comment lines;
   - a `# dropped: <step> (<reason>)` line for each dropped or deferred step.
4. `scripts/gate.local.sh`, only if missing: a comment explaining that project steps go here, each as `step <name> <command>`. Show proposals (e.g. path-filtered CI jobs); write them only if the user asks.
5. Build lock (`build_serialization: lock`): copy `scripts/build-lock.sh` as is; set the recorded thresholds as the env defaults at its top.
6. php-laravel with database tests: `worktree_setup` includes writing `<worktree>/.env.testing` (from `.env.example`, `DB_DATABASE=<app>_test_<topic>`). Never touch `.env`.
7. `.gitignore`: add the missing lines among `TASK-*.md`, `REPORT*.md`, `.build-slot` (build lock only) and `.env.testing` (php-laravel, unless tracked).
8. `.gitattributes`: add `*.sh text eol=lf` if missing. Do not renormalize existing files.
9. The decisions log: create `docs/decisions.md` with a title and the entry format if it is the chosen log and missing.

## 7. Verify
```sh
sh -n scripts/gate.sh
sh -n scripts/build-lock.sh   # build lock only
git status --short
```
Re-run check: the AGENTS.md block, the agents and the gate must regenerate byte-identical from the table. Run the full gate only if `suite_cost: low`; for compiled stacks offer to run it in the background.

## 8. Report
- Files: created, updated, skipped (with reasons).
- Conflicts: each row and who won.
- Parameters: mark the defaults the user did not confirm.
- Gate: derived steps, dropped tools, opt-ins left off, and the baseline result.
- Next step: `/agent-workflow-kit:orchestrate <type>/<topic> <goal>`.

Do not commit unless the user asks. If they do, follow the project's commit format; no trailers unless allowed.
