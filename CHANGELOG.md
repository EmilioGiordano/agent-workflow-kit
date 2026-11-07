# Changelog

## 0.2.0

Fixes from trial runs of `/workflow-init` on four real projects: a Laravel API with no CI, a Rust workspace with a mature workflow of its own, a Node MCP stdio server using Biome, and a Tauri hybrid using commitlint on `master`.

### Respect the existing project
- Init reads AGENTS.md, CLAUDE.md, CONTRIBUTING, `.claude/agents|skills`, scripts, hooks and commitlint before writing anything. It lists each conflict with the kit's defaults, and the user picks project, kit or abort per row. The project wins by default.
- Existing files: init may append a new marked block to an unmarked Markdown file after showing it. Other unmarked files are never overwritten.
- When unmarked `implementer` / `reviewer` agents exist, the kit agents install as `kit-implementer` / `kit-reviewer`. The skill uses only agents that carry the kit marker.
- `build-lock.sh` keeps a project `target-dir` from `.cargo/config.toml` instead of overriding it with `CARGO_TARGET_DIR`.

### Detect, don't hardcode
- `<default-branch>` and `<commit-format>` placeholders replace `main` and `type/description` in the templates, agents, skill, reviewer severity table and LESSONS L8.
- The gate is derived from CI and the project scripts first, as a superset of CI. Undeclared profile tools are dropped and reported. Clippy `-D warnings`, the release build, `--parallel`, `-n auto` and `npm audit` are opt-in.
- Gates never install tools: no `bunx` or bare `npx`, and `uv run --no-sync`. A missing declared tool fails its step (`step_need`).
- CI capability is detected (`ci: required | none | skipped-on-forks | no-push`). When CI cannot run, the orchestrator re-runs the gate on the merged result.

### Persistence
- The parameters table records every answer: profiles, default branch, commit format, merge approval, extra reviews, review-round limit, CI, remote, validation procedure, memory limits, slot dir, worktree root and setup, gate tuning, agent names and model, decisions log.
- Gate scripts have `# agent-workflow-kit:steps:begin` / `:end` markers. Init owns the steps section and replaces it on re-run only after the user approves a diff; dropped steps are recorded as `# dropped:`. We chose markers over a separate data file: one file, the same `step` helpers, nothing more to keep in sync.
- `scripts/gate.local.sh` is created with a usage comment only and is never overwritten.
- The agents have a `## Project settings` slot inside the managed block, and ship with the lessons line in its final form.

### Decisions log
- It defaults to a tracked `docs/decisions.md` when there is no ROADMAP. REPORT.md stays the orchestrator's untracked running report.

### Hybrid stacks, validation, safety
- `profiles` is a list. A hybrid gate has one steps section per stack, and branch checks are chosen by path.
- Each new worktree runs a lockfile install (`worktree_setup`) before its first commit.
- New validation modes `http` and `protocol`, with per-worktree isolation of data and config dirs, and rules for a desktop app versus the build lock (`reference/validation-modes.md`).
- Laravel: the gate refuses to test unless the testing database (phpunit.xml, then `.env.testing`) is `:memory:` or named `*test*`. Each worktree gets its own `.env.testing`, and `.env.testing` is gitignored.
- Init runs the static gate steps once on a clean checkout. On failure it offers a separate formatting branch instead of letting every review FAIL.

### Smaller items
- `.build-slot` is gitignored only with a build lock.
- Init adds `*.sh text eol=lf` to `.gitattributes` and keeps each file's existing line endings.
- Parallelism defaults to min(cores/4, RAM GB/4).
- build-lock: documented the rustup proxy (one build counts as 2 cargo processes), and that rust-analyzer, dev apps and missing PowerShell can block it or weaken its memory check.
- `npm audit` offline is `n/a (offline)`.
- Init offers to add `@AGENTS.md` to CLAUDE.md.
- `${CLAUDE_PLUGIN_ROOT}` is substituted in skill, command and agent text, but not in the Bash environment. Files now say to use the substituted path.
- New lessons L13 to L16: scratch dirs per parallel run, fake-tool harnesses, derived gates, project rules win.

## 0.1.0

First release.
