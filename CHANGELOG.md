# Changelog

## 0.3.0

Multi-harness support for Google Antigravity (`agy` / IDE / App) and Gemini CLI alongside Claude Code, keeping a single source of truth for skills, profiles, gates, templates and lessons.

### Multi-harness support
- Added `.antigravity-plugin/plugin.json` and `gemini-extension.json` alongside `.claude-plugin/plugin.json`; all three manifests move in lockstep.
- Moved `commands/workflow-init.md` to `skills/workflow-init/SKILL.md` so all three harnesses discover both skills cleanly without failing Antigravity strict validation.
- Added `reference/harnesses.md` mapping manifests, rules files, project agents dirs, per-harness `tools:` allowlists, follow-up messaging, `agent_model` values, `<kit-root>` resolution, and Windows PowerShell notes.
- Added the `harnesses` parameter to `AGENTS.md` and per-harness `agent_model` syntax (`claude: sonnet; antigravity: pro`).
- Skills resolve `<kit-root>` from `${CLAUDE_PLUGIN_ROOT}` when substituted, otherwise `../..` relative to `SKILL.md`, and pass `<kit-root>/LESSONS.md` in agent briefs.
- A name collision (`implementer.md` / `reviewer.md` without the kit marker) in any selected harness renames the kit agents to `kit-implementer` / `kit-reviewer` across all selected harnesses.
- `orchestrate` and `workflow-init` keep the reviewer's "Known false positives" section in sync across all reviewer copies in multi-harness repos.
- Gemini CLI support is checked statically against the Gemini CLI source and is marked experimental until tested end to end.

### Read-only boundary and PowerShell harnesses
- Bundled `agents/implementer.md` and `agents/reviewer.md` omit `tools:` so every harness parses them without tool-name errors. Bundled agents are read-only by instruction only; project copies carry runtime tool allowlists where the harness supports them.
- Whenever the reviewer runs without a runtime tool allowlist (`agy` with `EnableWriteTools: true`, or the bundled fallback in any harness), `orchestrate` records both `git rev-parse HEAD` and `git status --porcelain` before each review round and checks both after.
- Updated `orchestrate`, briefs and bundled agents to support PowerShell harnesses (`Set-Location <worktree>;` instead of `&&`, and passing the resolved `sh.exe` path in briefs).

### Upgrading from 0.2.0
- An existing `AGENTS.md` without a `harnesses` row defaults to the active harness plus any harnesses detected in the repo.
- Existing project agents that already have a `tools:` key keep it as is; `workflow-init` inserts the allowlist only when `tools:` is absent.
- For `claude`, `tools:` keeps the comma-separated form (`tools: Read, Grep, Glob, Bash`), so an unchanged re-run produces no diff on 0.2.0 projects. YAML arrays are used only where the harness requires them (`antigravity`, `gemini-cli`).
- `workflow-init` moved from `commands/workflow-init.md` to `skills/workflow-init/SKILL.md` (still invoked as `/agent-workflow-kit:workflow-init` in Claude Code).

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
- Gate scripts have `# agent-workflow-kit:steps:begin` / `:end` markers. Init owns the steps section and replaces it on re-run only after the user approves a diff. Re-derivation keeps the recorded tuning (`gate_tuning`, `# dropped:` lines). We chose markers over a separate data file: one file, the same `step` helpers, nothing more to keep in sync.
- Upgrading from 0.1.x: a managed `gate.sh` without steps markers counts as all steps. Init re-derives it, shows the diff, and replaces it only on OK.
- `scripts/gate.local.sh` is created with a usage comment only and is never overwritten.
- The agents have a `## Project settings` slot inside the managed block, and ship with the lessons line in its final form.

### Decisions log
- It defaults to a tracked `docs/decisions.md` when there is no ROADMAP. REPORT.md stays the orchestrator's untracked running report.

### Hybrid stacks, validation, safety
- `profiles` is a list. A hybrid gate has one steps section per stack, and branch checks are chosen by path.
- Each new worktree runs a lockfile install (`worktree_setup`) before its first commit.
- New validation modes `http` and `protocol`, with per-worktree isolation of data and config dirs, and rules for a desktop app versus the build lock (`reference/validation-modes.md`).
- Laravel: the gate refuses to test unless the testing database is `:memory:` or named `*test*`. It reads phpunit.xml first, then `.env.testing`, which it trusts only when phpunit.xml sets `APP_ENV=testing`. It also refuses when a cached config exists. Each worktree gets its own `.env.testing`, and `.env.testing` is gitignored.
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
