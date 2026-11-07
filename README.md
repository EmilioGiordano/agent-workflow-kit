# agent-workflow-kit

A Claude Code plugin that sets up a multi-agent development workflow in any project. The main session acts as orchestrator. An implementer and a reviewer iterate on each branch until the reviewer gives PASS. The orchestrator then merges the default branch, re-runs the gate, pushes, opens the PR, waits for CI, validates the feature through its interface and merges.

```
TASK -> implementer (own worktree) -> reviewer -> FAIL? -> same implementer fixes -> same reviewer re-reviews
                                              PASS -> merge default branch -> gate -> push -> PR -> CI -> UI validation -> merge
```

The kit provides only how the team works. Project-specific rules (domain, specs, ADRs) stay in your repo, and where your repo already has workflow rules (commit format, default branch, merge approval, required reviews), they win.

## What is inside

| Path | What it is |
|---|---|
| `agents/implementer.md` | Subagent: works in its own worktree; small commits that each pass lint and fmt; no push, no trailers; fixed-format report |
| `agents/reviewer.md` | Subagent, read-only: runs the gate, verifies the implementer's claims, gives PASS/FAIL with severity, `file:line`, failure scenario and fix |
| `skills/orchestrate/SKILL.md` | The full loop and the orchestrator's duties |
| `commands/workflow-init.md` | `/workflow-init`: reads the project's rules, detects stacks, branch, commit format and CI, resolves conflicts with you, writes the project files |
| `profiles/*.md` | Per-stack parameters: parallelism, build serialization, isolation, gate commands, failure criteria, UI validation mode |
| `scripts/gates/*.sh` | Gate skeleton plus stock steps per stack, POSIX sh. Each step prints `== step` and `-- exit N`; any non-zero exit fails the gate |
| `scripts/build-lock.sh` | Machine-wide build lock with a free-memory threshold and per-worktree build slots, for compiled stacks |
| `templates/` | TASK, PR, REPORT, merge policy and the "How we work" section |
| `reference/` | Detection rules for init, and the validation modes (browser, desktop-window, http, protocol, cli) |
| `LESSONS.md` | Lessons learned. The single source that the agents and the skill reference |

Profiles: `rust-compiled`, `php-laravel`, `node-ts`, `python`. A hybrid project (e.g. Tauri: Rust + TypeScript) uses several.

## Install

### From a local path

Clone or copy the repo, then inside Claude Code run:

```
/plugin marketplace add <path-to>/agent-workflow-kit
/plugin install agent-workflow-kit@agent-workflow-kit
```

Or from the shell:

```sh
claude plugin marketplace add <path-to>/agent-workflow-kit
claude plugin install agent-workflow-kit@agent-workflow-kit
```

A marketplace added from a local path loads the plugin in place. Edits take effect on the next session or after `/reload-plugins`.

### From GitHub (once published)

```
/plugin marketplace add <owner>/agent-workflow-kit
/plugin install agent-workflow-kit@agent-workflow-kit
```

Check the manifests after any change:

```sh
claude plugin validate <path-to>/agent-workflow-kit
```

## Usage

1. In the project root, run:
   ```
   /agent-workflow-kit:workflow-init
   ```
   It works in this order:
   - It reads your project's own rules (AGENTS.md, CLAUDE.md, CONTRIBUTING, agents, hooks, commitlint).
   - It detects the stacks, the default branch, the commit format, the CI capability and the gate (derived from CI and your scripts).
   - It shows each conflict with the kit's defaults and lets you choose, per row, project, kit or abort. The project wins by default.
   - It asks only what detection left open, then runs the static gate steps once on a clean checkout and reports any baseline failure.

   It then writes:
   - the "How we work" block in `AGENTS.md`, whose parameters table records every answer;
   - the agents in `.claude/agents/` (`implementer` / `reviewer`, or `kit-implementer` / `kit-reviewer` when the project already has unmarked agents with those names);
   - `scripts/gate.sh`, and `scripts/gate.local.sh` (created with a usage comment only, never overwritten);
   - for compiled stacks, `scripts/build-lock.sh`;
   - the `.gitignore` and `.gitattributes` entries.

   Re-running it reproduces the same files from the parameters table. It updates only:
   - the blocks between `<!-- agent-workflow-kit:begin -->` and `<!-- agent-workflow-kit:end -->`;
   - the text outside the steps markers of scripts marked `# agent-workflow-kit:managed`.

   The gate's steps section changes only after you approve the diff.
2. Ask for a feature:
   ```
   /agent-workflow-kit:orchestrate feat/<topic> <goal in plain words>
   ```
   You can also just say "orchestrate feat/x and fix/y in parallel". The orchestrator then:
   - writes the TASKs;
   - runs the implementer and reviewer until PASS;
   - ships each branch;
   - keeps `REPORT.md` current.

   It stops and asks whenever a decision belongs to you.

Agent names once installed: `agent-workflow-kit:implementer` and `agent-workflow-kit:reviewer`. The skill prefers the project copies written by init (the names in the `agents` row of AGENTS.md), and only those carrying the kit marker.

`${CLAUDE_PLUGIN_ROOT}` is substituted in the plugin's skill, command and agent text, but it is not set in the Bash tool, and it stays literal in files copied into a project. So the agents take the lessons path from the brief.

## Add a profile

1. Create `profiles/<name>.md` with the same frontmatter keys as the existing profiles:
   - `profile`, `detect`, `parallel_implementers`;
   - `build_serialization`, `build_lock`, `isolation`;
   - `suite_cost`, `gate_script`, `ui_validation`, `failure`.
2. Add these sections to the profile: Gate (the exact commands, in order), Isolation, UI validation and CI.
3. Add `scripts/gates/<name>.sh`, copied from an existing gate. Keep everything outside `# agent-workflow-kit:steps:begin` / `:end` byte-identical, since a hybrid gate joins the steps sections of several profiles under one head and foot. That shared part holds:
   - the `step`, `step_if` and `step_need` helpers;
   - the `== step` / `-- exit N` output;
   - the `scripts/gate.local.sh` hook;
   - `GATE PASS|FAIL` with exit 1 on any failed step.

   Between the markers, start with `# -- stack: <name>`, and mark each init decision with a `# init:` comment. A missing tool must fail (`step_need`), never be installed.
4. Add the detection row to `commands/workflow-init.md`.
5. Check it:
   ```sh
   sh -n scripts/gates/<name>.sh
   claude plugin validate .
   ```
   To exercise a gate, use fake tools only, on a PATH where `command -v` resolves every tool to the fake (LESSONS L14). Then try it on a real project of that stack.

## Feed lessons back

When a project teaches something new, such as a bug class the reviewer missed or an unsafe default:

1. Append an entry to `LESSONS.md` using the format at the end of that file. Give the role it applies to and its scope.
2. If it changes a check, add one line to the agent or profile that should enforce it, citing the lesson (`LESSONS L<n>`). Do not copy the text.
3. Commit, then update the plugin in your projects:
   - local marketplace: `/reload-plugins`;
   - GitHub: `/plugin marketplace update agent-workflow-kit`.

Every project inherits the lesson on its next session.

## Rules the kit enforces

- The orchestrator is the only one that pushes and opens PRs. It merges only if init set it as merger, and only when every merge-policy criterion holds.
- Branches and worktrees are never deleted. A `backup/<branch>-before-rework` branch is created before any history rewrite.
- Commit messages follow the project's format (default: one line, `type/description`). No attribution trailers unless the project allows them.
- The gate never installs tools; a missing tool fails. Laravel tests refuse to run against a database whose name lacks `test`.
- Pending user decisions (licence, third-party downloads, publishing, anything irreversible) are recorded and never bypassed.
