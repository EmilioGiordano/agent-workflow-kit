---
profile: node-ts
detect: [package.json, tsconfig.json]
parallel_implementers: free
build_serialization: none
build_lock: none
isolation: "one worktree per branch + one dev-server port per worker"
suite_cost: low
gate_script: scripts/gates/node-ts.sh
ui_validation: browser
failure: "any step exit != 0"
---

# Profile: node-ts

Parameters for Node + TypeScript projects (apps or libraries). `/workflow-init` and the `orchestrate` skill read the frontmatter; the sections below are the rules that go with it.

## Gate (full, in this order)

`<x>` is the package runner from the lockfile: `pnpm exec`, `yarn`, `bunx` or `npx --no-install`.

```sh
<x> prettier --check .                # only if prettier is installed
<x> eslint .
<x> tsc --noEmit
<x> vitest run
<pm> run build
```

If the project uses another test runner (jest, playwright test), init replaces the `test` step with it. The gate is cheap: every implementer runs the full gate itself before reporting.

## Isolation

- Each worktree runs its own install (`pnpm install --frozen-lockfile` or `npm ci`); never share `node_modules/`.
- Each worktree's dev server gets its own port, recorded in the TASK (`PORT=<base + n>`).
- Tests that bind ports use port 0 or a per-worker offset (`VITEST_POOL_ID`).

## UI validation: browser

- The orchestrator starts the worktree's dev server on its port and drives it with headless Playwright.
- Evidence: screenshots and the console/network log per validation step.
- A library with no UI: `ui_validation: none`; the PR states it and why.

## CI

One job per supported Node version (and OS if relevant). Merge only with all jobs green.
