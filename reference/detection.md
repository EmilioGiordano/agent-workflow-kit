# Detection rules for /workflow-init

How init fills each workflow parameter from the project. Detect first. Ask only when detection is empty or ambiguous. Every value lands in the AGENTS.md parameters table, so a re-run reproduces it.

## Project rules (read before anything else)

Read these when they exist:
- `AGENTS.md`, `CLAUDE.md` (and any files they `@`-import), `CONTRIBUTING*`, `.github/PULL_REQUEST_TEMPLATE*`;
- `.claude/agents/*`, `.claude/skills/*`, `.claude/settings*.json`;
- `scripts/`, `Makefile`, `justfile`, the `package.json` / `composer.json` scripts;
- git hooks (`git rev-parse --git-path hooks`; also `.husky/`, `lefthook.yml`, `.pre-commit-config.yaml`);
- `commitlint.config.*`, `.commitlintrc*`;
- `.cargo/config.toml`, `rustfmt.toml`, `.gitattributes`, `.editorconfig`.

For each rule below, compare the project's value with the kit default. Each difference is a conflict row.

| Rule | Kit default | Where projects state it |
|---|---|---|
| Commit format | `type/short description`, one line | commitlint, commit-msg hook, CONTRIBUTING, `git log` |
| Commit granularity | one commit per file or aspect | CONTRIBUTING ("squash into logical units") |
| Default branch | detected | AGENTS.md ("work on master"), remote HEAD |
| Who merges | orchestrator | AGENTS.md (user approval, manual test, `staging/<date>` batches) |
| Extra required reviews | none | AGENTS.md, CLAUDE.md, `.claude/skills` (e.g. a security review command) |
| Review-round limit | none | AGENTS.md ("after 2 failed rounds, stop and ask") |
| Branch checks | profile | AGENTS.md ("no workspace clippy on feature branches") |
| Build output dir | `.build-slot` per worktree | `.cargo/config.toml` `target-dir`, "never override CARGO_TARGET_DIR" |
| PR tooling | `gh pr create` | `scripts/pr/*`, Makefile targets |
| Agent model | inherit | existing agents' `model:`, AGENTS.md |
| Agent names | `implementer`, `reviewer` | unmarked `.claude/agents/implementer.md` / `reviewer.md` |
| Editing AGENTS.md / CLAUDE.md | append a marked block | "never change AGENTS.md unless asked" |
| Worktree location | detected | AGENTS.md, `git worktree list` |

Default answer for every row: **project wins**. Show the table, then ask once. Per row, the user answers `project`, `kit` or `abort`. The project's value goes into the parameters table, and from there into the agents and the merge policy.

## Default branch
1. `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`).
2. Else `git remote show origin` ("HEAD branch").
3. Else the one of `main` / `master` that exists locally.
4. An AGENTS.md rule ("work on master") wins over all of these.

## Commit format
Look in this order, and stop at the first hit:
1. commitlint config: the type rules, header case and maximum length, and whether a body is allowed.
2. commit-msg hook: read what it rejects.
3. CONTRIBUTING / AGENTS.md text.
4. `git log --format=%s -30`: show the subjects and name the pattern (e.g. sentence case, imperative, no prefix).

The format to record is one line, for example `Sentence-case imperative subject, max 72 chars, optional body`. If none of these hits, the default is `type/short description`.

## CI capability (`ci` row)
- No `.github/workflows/*` (or other CI config): `none`.
- A job guarded by `if: github.repository == '<owner>/<repo>'` while `origin` is a fork: `skipped-on-forks`.
- No push rights (`gh repo view --json viewerPermission` is READ or TRIAGE): `no-push`. Ask where branches go (a fork remote), or switch to local-only merges.
- Otherwise: `required`.

When `ci` is not `required`: after merging, the orchestrator re-runs the full gate on the merged branch in place of waiting for CI.

## Gate derivation (the gate is a superset of CI)
1. List every CI step that checks code (format, lint, types, tests, audit, build), with its flags and env vars.
2. Add the project's own check scripts (`package.json` / `composer.json` scripts named lint, typecheck, test, check, format:check).
3. Add the profile's steps only for tools the project declares (manifest dependencies or a config file). Each undeclared tool is dropped and reported as `# dropped: <tool> (not declared)` inside the steps section.
4. Prefer `<pm> run <script>` over direct tool calls.
5. Opt-in when CI does not enforce them: clippy `-D warnings`, the release build, `--parallel` (needs paratest), `pytest -n auto` (needs pytest-xdist), `npm audit` (needs network; offline = `n/a (offline)`).
6. A path-filtered CI job (benchmarks, docs) becomes a proposal for `scripts/gate.local.sh`. Show it; do not write it.
7. Never call an installer: no `bunx`, no bare `npx`, no `uv run` without `--no-sync`. A declared tool that is missing fails its step.

## Baseline (clean checkout of the default branch)
Run the static steps (format, lint, types; no compile, no tests) once. For each step that fails, report the step and the file count, then offer two options:
- a separate `chore/<format-baseline>` branch first (recommended);
- drop the step with `# dropped: <step> (fails on <default-branch>; until <branch>)`.

The user decides. Never let every review FAIL on day one.

## Hybrid stacks
Several profiles match (e.g. `Cargo.toml` under `src-tauri/` plus `package.json`): `profiles` lists all of them. The gate gets one steps section per stack, in list order. `branch_checks` maps paths to commands, e.g. `src-tauri/** -> cargo checks; src/** -> typecheck + lint`.

## Worktrees
- `worktree_root`: the pattern of the existing worktrees in `git worktree list` (e.g. `../<repo>-wt-<topic>`). Default: `../<repo>-worktrees/<topic>`.
- `worktree_setup`: the install each new worktree needs before it can commit (hooks call the toolchain), always from the lockfile: `npm ci`, `pnpm install --frozen-lockfile`, `bun install --frozen-lockfile`, `composer install`, `uv sync --frozen`. Plus copying `.env.example` (and `.env.testing`) when the profile says so.
- `slot_dir`: compiled profiles only. `project` when `.cargo/config.toml` sets `target-dir`; then no `.build-slot` is written. Otherwise a directory on a disk with room.

## Machine
- `max_parallel_implementers` = max(1, min(floor(cores / 4), floor(RAM GB / 4))). Show the numbers.
- Build-lock memory thresholds (`BUILD_LOCK_MIN_MB`, `BUILD_LOCK_FULL_MB`): record them even when they are the defaults.

## Laravel test database (php-laravel)
- Read `phpunit.xml(.dist)` `<env name="DB_*">`; lines inside `<!-- -->` do not count.
- Search tests for `RefreshDatabase` / `LazilyRefreshDatabase` / `DatabaseMigrations`.
- If the tests touch a database and phpunit.xml does not pin a test DB, each worktree needs `.env.testing` with `DB_DATABASE=<app>_test_<topic>`. Add `.env.testing` to `.gitignore` unless it is tracked; a tracked one is a conflict row.

## Validation mode
See `validation-modes.md`. Pick the default as follows:
- `@modelcontextprotocol/*` dependency, a `bin` entry or a stdio server: `protocol`;
- routes but no views or frontend: `http`;
- a Tauri / Electron / native window: `desktop-window`;
- a web frontend: `browser`;
- otherwise: `cli` or `none`.

## Line endings
- Add `*.sh text eol=lf` to `.gitattributes` (create it if missing; append only).
- When writing into an existing file, match its line endings: a CRLF file gets a CRLF block. Never renormalize other files.
