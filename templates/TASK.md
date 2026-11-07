<!-- TASK template. The orchestrator copies it to <worktree>/TASK-<topic>.md (untracked, never committed) and fills every <...>. Delete lines that do not apply. -->
# TASK: <type>/<topic>

Branch `<type>/<topic>`, worktree `<worktree-path>`, cut from `main` at `<commit>` (after <PR or branch> merged).
Profile: `<profile>`. Build slot: `<slot or n/a>`. Port / test DB: `<value or n/a>`.
<Build note, compiled profiles: "Builds only through scripts/build-lock.sh; keep full builds few.">

## Why
<The user-visible problem, with evidence: screenshot, log, measured number. One paragraph.>

## Read first
- `AGENTS.md` ("How we work") and `<lessons-path>`.
- Decisions of related branches: <branch names, from ROADMAP "Decisions taken on the way" or REPORT>.
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
- `sh scripts/gate.sh` passes (cheap profiles), or the branch checks from the profile pass (compiled profiles).
- Decisions taken are recorded: <ROADMAP "Decisions taken on the way" | the report>.
- Small commits, each passing lint and fmt; one-line `type/description` messages; no trailers; no push.
