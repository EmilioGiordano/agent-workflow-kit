# Harnesses

How the kit maps onto each supported agent runtime. Everything outside this table (the loop, `AGENTS.md`, `LESSONS.md`, profiles, gates, build lock, templates) is identical across harnesses.

## Supported harnesses

| Parameter | `claude` (Claude Code) | `antigravity` (Google Antigravity) | `gemini-cli` (Gemini CLI) |
|---|---|---|---|
| Manifest in kit | `.claude-plugin/plugin.json` | `.antigravity-plugin/plugin.json` | `gemini-extension.json` |
| Project rules files to inspect | `CLAUDE.md`, `.claude/agents/*`, `.claude/skills/*`, `.claude/settings*.json` | `GEMINI.md`, `.agents/agents/*`, `.agents/skills/*`, `.agents/rules/*`, `.agents/*.json` | `GEMINI.md`, `.gemini/agents/*`, `.gemini/skills/*`, `.gemini/settings.json` |
| Loads `AGENTS.md` natively | No (offer `@AGENTS.md` in `CLAUDE.md`) | Yes | No by default (offer `@AGENTS.md` in `GEMINI.md`) |
| Project agents dir | `.claude/agents/<name>.md` | `.agents/agents/<name>.md` | `.gemini/agents/<name>.md` |
| Plugin fallback agent names | `agent-workflow-kit:implementer`, `agent-workflow-kit:reviewer` | `implementer`, `reviewer` | `implementer`, `reviewer` |
| Follow-up messaging | `SendMessage` (same agent ID) | `send_message` (same `conversationId`) | Re-invoke subagent with full prior findings history if sessions are not resumable |
| `agent_model` values | `inherit` (omit `model:`), or Claude alias/id (`sonnet`, `opus`, `haiku`) | `inherit` (omit `model:`), or tier (`pro`, `flash`, `flash_lite`) | `inherit` (omit `model:`), or Gemini model id (e.g. `gemini-2.5-pro`, `gemini-2.5-flash`) |
| Kit validation | `claude plugin validate .` | `agy plugin validate --strict .` | `gemini extensions list` after install |

## Tool allowlists for project agents

The plugin's bundled `agents/implementer.md` and `agents/reviewer.md` omit `tools:` so every harness parses them without tool-name validation errors. When `workflow-init` writes project copies into each selected harness's agents directory, it inserts that harness's `tools:` list as a YAML array so the reviewer's read-only boundary is enforced by the runtime.

### `claude` (`.claude/agents/`)
- `implementer`:
  ```yaml
  tools:
    - Read
    - Grep
    - Glob
    - Bash
    - Write
    - Edit
  ```
- `reviewer`:
  ```yaml
  tools:
    - Read
    - Grep
    - Glob
    - Bash
  ```

### `antigravity` (`.agents/agents/`)
Includes both CLI (`read_file`, `write_file`, `edit_file`) and IDE (`view_file`, `write_to_file`, `replace_file_content`, `multi_replace_file_content`) built-in names so the same project files work on both surfaces.
- `implementer`:
  ```yaml
  subagent: true
  tools:
    - read_file
    - view_file
    - grep_search
    - find_by_name
    - list_dir
    - run_command
    - manage_task
    - write_file
    - write_to_file
    - edit_file
    - replace_file_content
    - multi_replace_file_content
  ```
- `reviewer`:
  ```yaml
  subagent: true
  tools:
    - read_file
    - view_file
    - grep_search
    - find_by_name
    - list_dir
    - run_command
    - manage_task
  ```

> **Antigravity CLI (`agy`) subagent permissions:** Plugin-bundled agents (`agents/*.md`) spawned directly via `invoke_subagent` run in a read-only sandbox without `write_file`, `edit_file` or `run_command` — which blocks both the implementer (cannot edit/commit) and the reviewer (cannot run `scripts/gate.sh`). In Antigravity CLI, the orchestrator reads the project's `.agents/agents/implementer.md` and `.agents/agents/reviewer.md`, registers them for the session with `define_subagent(..., EnableWriteTools: true)` (using their markdown body as `SystemPrompt`), and spawns them with `invoke_subagent`. Because `EnableWriteTools: true` grants shell and file tools together, the orchestrator checks `git status --porcelain` before and after each review round to verify the reviewer left the worktree untouched.

### `gemini-cli` (`.gemini/agents/`)
Gemini CLI validates every entry in `tools:` against its built-in tool registry (`ALL_BUILTIN_TOOL_NAMES`). Use only exact Gemini CLI names:
- `implementer`:
  ```yaml
  kind: local
  tools:
    - read_file
    - grep_search
    - glob
    - list_directory
    - run_shell_command
    - write_file
    - replace
  ```
- `reviewer`:
  ```yaml
  kind: local
  tools:
    - read_file
    - grep_search
    - glob
    - list_directory
    - run_shell_command
  ```

## Resolving `<kit-root>` inside skills

Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}` in skill text when loading the skill (but does not export it in the shell). Antigravity and Gemini CLI do not substitute `${CLAUDE_PLUGIN_ROOT}`; instead, they give the agent the absolute path to `SKILL.md`, and the kit root is always `../..` relative to that `SKILL.md` file's directory (`skills/<name>/SKILL.md` -> `<kit-root>`).

In every skill:
1. If `${CLAUDE_PLUGIN_ROOT}` was substituted into a real path, use it as `<kit-root>`.
2. Otherwise resolve `<kit-root>` as `../..` from the loaded `SKILL.md` path.
3. Never pass literal `$CLAUDE_PLUGIN_ROOT` to a shell command; always pass the resolved path (and pass the resolved `LESSONS.md` path in each agent's brief).

## Multi-harness repositories

A team can list several harnesses in `harnesses` (e.g. `claude, antigravity`). `workflow-init` installs and maintains marked agent copies in each listed harness's agents directory. At runtime, `orchestrate` uses the active harness's directory first and falls back to the plugin's bundled agents.

When `agent_model` differs across harnesses (for example, `sonnet` on Claude and `pro` on Antigravity), record per-harness values in `agent_model` as `claude: sonnet; antigravity: pro` (otherwise a single value such as `inherit` applies to all).

## Windows shell notes (`antigravity` and `gemini-cli`)

Claude Code runs commands inside Git Bash on Windows, so `sh` and `&&` are always available. Antigravity and Gemini CLI on Windows default to PowerShell (often Windows PowerShell 5.1):
- `&&` is not valid in PowerShell 5.1: use `Set-Location <worktree>; ...` (or `git -C <worktree>`) instead of `cd <worktree> && ...`.
- `sh` may not be on `PATH` even when Git for Windows is installed: locate it from `git` (e.g. `"$(Split-Path (Split-Path (Get-Command git).Source))\bin\sh.exe" scripts/gate.sh`) or run under Git Bash.
- Windows PowerShell's default `Restricted` execution policy blocks `*.ps1` shims (such as `npm.ps1`): call `npm.cmd` directly or run commands via Git's `sh.exe`.

