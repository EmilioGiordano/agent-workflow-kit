# Validation modes

The orchestrator validates each feature through its interface before merging. It runs the TASK's validation list and saves evidence to link in the PR and REPORT.md. `ui_validation` in AGENTS.md names the mode; `ui_validation_procedure` holds the project's exact commands.

## Isolation (every mode)
- One worktree, one instance. Ports, databases, and app data and config dirs are per worktree.
- Redirect app data and config through env overrides (e.g. `<APP>_HOME`, `XDG_CONFIG_HOME`, `APPDATA`, `--user-data-dir`) to a throwaway dir under the worktree or slot. Never use the user's real profile or session.
- Never kill a process you did not start.
- Authenticated calls, real accounts, payments and anything external go under "Needs a human". Never use the user's credentials.

## browser
- Serve the worktree on its own port (`PORT=<base + n>`); drive it with headless Playwright.
- Evidence: a screenshot per step, plus the console and network log.

## desktop-window
- Preferred: a test-control channel in the app (local pipe or socket, off by default) that dumps UI state and injects actions.
- Capture without taking focus (LESSONS L1). Watch responsiveness, CPU and memory; a freeze is a failure.
- With a build lock:
  - A running dev app (`tauri dev`, `cargo watch`) or an editor's check-on-save keeps cargo alive, so locked builds wait until exit 75. Stop the app before any locked build.
  - Or build and run the app through the lock with the slot target: `sh scripts/build-lock.sh <run command>`. The lock is then held for as long as the app runs.
  - A dev server started outside the lock (e.g. `bun dev`) also builds outside the slot. Record it in REPORT.md.
  - Fixed dev ports (e.g. 1420): one app at a time across all worktrees.

## http
For APIs and backends with no views:
- Serve the worktree on its own port with its own database: `php artisan serve --port <p>`, `uvicorn --port <p>`, `node dist/server.js` with `PORT=<p>`.
- Run the checks with `curl -sS -i` or `newman run <collection>` against that port.
- Evidence: each request with its full response (status, headers, body), saved under the report.
- Seed with factories or fixtures into the worktree's own database.

## protocol
For stdio servers (MCP, LSP, JSON-RPC CLIs):
- Start the built server from the worktree, with its data and config dirs redirected.
- Send a scripted session: `initialize`, then the TASK's calls (e.g. `tools/list`, `tools/call`). The MCP Inspector CLI or a short script writing JSON lines to stdin both work.
- Evidence: the full request/response transcript.

## cli
- Run the commands from the TASK's validation list. Evidence: each command with its output and exit code.

## none
- The PR states `n/a` and why. The gate output is the only evidence.
