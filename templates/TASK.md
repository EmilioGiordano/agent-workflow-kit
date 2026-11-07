<!-- TASK template. The orchestrator copies it to <worktree>/TASK-<topic>.md (untracked, never committed) and fills every <...>. Delete lines that do not apply. -->
# TASK: <type>/<topic>

Branch `<type>/<topic>`, worktree `<worktree-path>`, cut from `<default-branch>` at `<commit>` (after <PR or branch> merged).
Profiles: `<profiles>`. Build slot: `<slot | project target-dir | n/a>`. Port / test DB / data dir: `<values or n/a>`.
Commit format: <commit-format>.
<Build note, compiled profiles: "Builds only through scripts/build-lock.sh; keep full builds few.">

## Why
<The user-visible problem, with evidence: screenshot, log, measured number. One paragraph.>

## Read first
- `AGENTS.md` ("How we work") and `<lessons-path>`.
- Decisions of related branches: <branch names, from the decisions log>.
- Specs: <requirement ids, docs sections>.
- Code: <modules, files, key functions>.

## Scope
1. <Piece>: rules, edge cases, where it lives (respect the project's layers).
2. <...>
N. Tests: pure logic with injected time and no sleeps; fakes for OS, network and IO (LESSONS L6, L7).

## UI validation (the orchestrator runs it; make every step scriptable or keyboard-drivable)
- <step> -> <expected result>
- <step> -> <expected result>

## Out of scope
- <explicit list, including other agents' worktrees>

## Done when
- `sh scripts/gate.sh` passes (cheap profiles), or the branch checks from AGENTS.md pass (compiled profiles).
- Decisions taken are recorded in `<decisions_log>` (tracked), in a commit on the branch.
- Small commits, each passing lint and fmt; messages in the commit format above; no trailers unless allowed; no push.
