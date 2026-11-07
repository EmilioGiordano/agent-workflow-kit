---
description: Set up the multi-agent workflow in this project - detect the stack, ask 5 questions, write the "How we work" section of AGENTS.md, tuned .claude/agents copies, scripts/gate.sh and (compiled stacks) scripts/build-lock.sh. Safe to re-run; it only updates its own marked blocks.
argument-hint: "[profile]"
disable-model-invocation: true
---

# /workflow-init

Bootstrap or update the agent workflow in the current repository. Idempotent: everything the kit owns sits between `<!-- agent-workflow-kit:begin -->` and `<!-- agent-workflow-kit:end -->` (Markdown) or carries the line `# agent-workflow-kit:managed` (scripts). Everything else in the project is left alone.

Kit files (read them; do not copy this command's text):
- Profiles: `${CLAUDE_PLUGIN_ROOT}/profiles/*.md`
- Gates: `${CLAUDE_PLUGIN_ROOT}/scripts/gates/<profile>.sh`, lock: `${CLAUDE_PLUGIN_ROOT}/scripts/build-lock.sh`
- Templates: `${CLAUDE_PLUGIN_ROOT}/templates/how-we-work.md`, `merge-policy.md`
- Agents: `${CLAUDE_PLUGIN_ROOT}/agents/implementer.md`, `reviewer.md`
- Lessons: `${CLAUDE_PLUGIN_ROOT}/LESSONS.md`

## 1. Check the repo
- Must be the root of a git repository (`git rev-parse --show-toplevel`). If not, stop.
- If `AGENTS.md` already has the kit block, read its parameters table: they are the defaults for the questions below.

## 2. Detect the profile
If `$ARGUMENTS` names a profile, use it. Otherwise match manifests at the repo root against each profile's `detect` list:

| Found | Profile |
|---|---|
| `Cargo.toml` | rust-compiled |
| `composer.json` + `artisan` | php-laravel |
| `package.json` + `tsconfig.json` | node-ts |
| `pyproject.toml`, `setup.py` or `requirements.txt` | python |

Several match (e.g. Laravel with a TS frontend): ask which is primary. None match: list the profiles and ask; offer to add a new one (README "Add a profile").

Inspect the project to tune the gate: lockfile and package manager, test runner (pest/phpunit, vitest/jest), `deny.toml`, existing CI workflows, existing lint configs.

## 3. Ask (one message, defaults shown)
1. Who merges PRs that meet the merge policy: the orchestrator, or only you? [orchestrator]
2. Is there an interface to validate, and how: desktop window, browser (Playwright), CLI output, or none? [the profile's `ui_validation`]
3. Machine limits: RAM, and how many implementers in parallel? Compiled profiles: where do build slots live (`<slot-dir>`, a disk with room)? [profile default]
4. Commit message language? [English]
5. Attribution rules for commits and PRs: none, or which trailer is allowed? [none]

Do not continue until the user answers. Unanswered items take the default and are listed in the summary.

## 4. Write the files
For each file: if it exists and has the kit marker, replace only the managed part. If it exists without the marker, do NOT overwrite it: show the user the diff you would make and ask.

1. `AGENTS.md` (create with a `# AGENTS.md` title if missing). Fill `how-we-work.md`:
   - parameters table from the answers and the profile;
   - `<profile gate and branch-check commands>`: the exact commands from the profile, tuned in step 2;
   - `<merge-policy>`: `merge-policy.md` with `<merger>`, `<commit-language>`, `<attribution-rule>` filled.
   - Strip the leading `<!-- ... -->` template comment of each template you insert.
   Replace the existing block between the markers, or append the block at the end. Never touch text outside the markers.
2. `.claude/agents/implementer.md` and `.claude/agents/reviewer.md`: copy the kit agents, then:
   - in the Inputs list, reduce the lessons line to `- Lessons file path: given in the brief.` (no absolute path: it goes stale on plugin updates and is machine-specific; the orchestrator passes it in every brief);
   - add the exact gate and branch-check commands inside the managed block;
   - commit language and attribution rule from the answers;
   - on re-run, keep the frontmatter edits the project made and everything after the end marker (project notes, the reviewer's "Known false positives").
3. `scripts/gate.sh`: copy `scripts/gates/<profile>.sh`, tuned to the project (package manager, test runner, optional steps). Keep the `== step` / `-- exit N` output and the final `GATE PASS|FAIL`. Project-only steps go in `scripts/gate.local.sh`, which init creates empty if missing and never overwrites.
4. Compiled profiles: `scripts/build-lock.sh` copied as is. Set lock path and thresholds through env defaults only if the user's limits differ (edit the defaults at the top).
5. `.gitignore`: ensure these lines exist (add only missing ones):
   ```
   TASK-*.md
   REPORT*.md
   .build-slot
   ```

## 5. Verify
```sh
sh -n scripts/gate.sh
sh -n scripts/build-lock.sh   # compiled profiles
git status --short
```
Run `sh scripts/gate.sh` once only if the gate is cheap (`suite_cost: low`); for compiled profiles offer to run it in the background.

## 6. Report
List created vs updated vs skipped files, the parameters chosen (marking defaults the user did not confirm), and the next step: "ask me to orchestrate a feature, e.g. `/agent-workflow-kit:orchestrate feat/<topic> <goal>`". Do not commit unless the user asks; if they do, one commit per file, `chore/...` messages, no trailers unless allowed.
