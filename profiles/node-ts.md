---
profile: node-ts
detect: [package.json, tsconfig.json]
parallel_implementers: free
build_serialization: none
build_lock: none
isolation: "one worktree per branch + one dev-server port and data dir per worker"
suite_cost: low
gate_script: scripts/gates/node-ts.sh
ui_validation: browser
failure: "any step exit != 0"
---

# Profile: node-ts

Parameters for Node + TypeScript projects (apps, libraries, servers). `/workflow-init` and the `orchestrate` skill read the frontmatter; the sections below are the rules that go with it.

## Gate (stock steps; init derives the real ones from CI first)

`<pm>` and the runner come from the lockfile: `pnpm exec`, `yarn`, `bun run`, or `npx --no-install`.

```sh
<x> prettier --check .        # or biome check / oxfmt, whichever the project declares
<x> eslint .                  # or biome lint / oxlint
<x> tsc --noEmit              # -p <test tsconfig> when one exists
<x> vitest run                # or jest, node --test, playwright test
<pm> run build                # only if package.json has scripts.build
npm audit --audit-level=high  # only if CI runs it
```

- Prefer the project's scripts (`<pm> run lint`, `typecheck`, `test`, `check`) over direct tool calls. They are what CI and the developers run.
- Keep only declared tools. Never eslint when the project uses Biome or oxlint, and never prettier when it is not a dependency.
- Plain `tsc` uses `tsconfig.json`, which often excludes tests. Use the tsconfig CI uses for types.
- Missing tools fail; nothing installs them. Check `node_modules/<pkg>/package.json`, not `.bin/<tool>` (Windows shims differ). Never `bunx` or bare `npx`.
- `npm audit` needs the network. Offline, report it as `n/a (offline)`, not as a failure.
- The gate is cheap: every implementer runs the full gate itself before reporting.

## Isolation

- Each worktree runs its own install from the lockfile (`npm ci`, `pnpm install --frozen-lockfile`, `bun install --frozen-lockfile`) before its first commit; hooks often need it. Never share `node_modules/`.
- Each worktree's dev server gets its own port, recorded in the TASK (`PORT=<base + n>`).
- An app that keeps data or a session in a user dir gets a per-worktree override through its env variable (e.g. `<APP>_HOME`).
- Tests that bind ports use port 0 or a per-worker offset (`VITEST_POOL_ID`).

## UI validation

- Web frontend: `browser` (headless Playwright, a screenshot per step, the console/network log).
- HTTP API: `http`.
- MCP or other stdio server (an `@modelcontextprotocol/*` dependency or a `bin` entry): `protocol`. The evidence is the JSON-RPC transcript; authenticated calls go under "Needs a human".
- Library: `none`.
- Details: `reference/validation-modes.md`.

## CI

One job per supported Node version (and OS if relevant). Merge only with all jobs green.
