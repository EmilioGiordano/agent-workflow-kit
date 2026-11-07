---
profile: rust-compiled
detect: [Cargo.toml]
parallel_implementers: "several; only one compile at a time"
build_serialization: lock
build_lock: scripts/build-lock.sh
isolation: "one worktree per branch + one build slot (target dir) per worktree"
slot_file: .build-slot
suite_cost: high
gate_script: scripts/gates/rust-compiled.sh
ui_validation: desktop-window
failure: "any step exit != 0; exit 75 = build lock timeout, reported, not a code failure"
---

# Profile: rust-compiled

Parameters for Rust workspaces where compiling is the expensive part. `/workflow-init` and the `orchestrate` skill read the frontmatter; the sections below are the rules that go with it.

## Gate (full, in this order)

```sh
cargo fmt --all -- --check
sh scripts/build-lock.sh --full cargo clippy --workspace --all-targets --locked -- -D warnings
sh scripts/build-lock.sh --full cargo test --workspace --locked --no-fail-fast
cargo deny check                       # only if deny.toml exists
sh scripts/build-lock.sh --full cargo build --release --locked
```

Project extras (e.g. `cargo xtask check-deps`) go in `scripts/gate.local.sh`, each wrapped in `step <name> ...`.

## Branch checks (implementer, cheap, crates touched only)

```sh
cargo fmt --all -- --check
sh scripts/build-lock.sh cargo check -p <crates> --all-targets
sh scripts/build-lock.sh cargo test -p <crates>
```

The full gate runs at review and before the PR.

## Builds

- Every cargo invocation except `fmt` goes through `scripts/build-lock.sh`. Never call `cargo build/test/clippy` directly. Never lower the thresholds to get through.
- The lock waits for no running compiler and enough free memory, then runs at reduced `-j`. Exit 75 means it waited `BUILD_LOCK_MAX_WAIT` without acquiring: report it with the memory and process counts printed.
- Run the full gate and release builds in the background; they outlast tool-call timeouts (LESSONS L12).
- `cargo fmt --all` in write mode reformats everyone's files. Run `--check`, then `rustfmt --edition <edition> <file>` on your own files only.

## Slots

- The orchestrator writes `<worktree>/.build-slot` (untracked, gitignored) with `<slot-dir>/slot-<n>` when it creates the worktree.
- One slot per running branch; reuse a finished branch's slot so rebuilds stay warm. Never share a slot between two live branches (LESSONS L11).
- Put slots on a disk with room; clean old slots only when that disk runs low.

## UI validation: desktop-window

- Preferred: a test-control channel in the app (a local pipe or socket, off by default) that dumps UI state and injects actions, so validation is a script.
- Run the app with a throwaway data/config dir under the slot, never the user's real profile.
- Capture evidence without taking focus (LESSONS L1). Real keyboard and focus driving only when the user says they are away.
- Watch the process (responding, CPU, memory) while it runs; a freeze is a failure.
- Never kill a process you did not start. A locked binary (link error) is reported.
- Implementer and reviewer never run the app.

## CI

Matrix on the target OSes (e.g. Windows, Linux, macOS). The local gate covers one OS only; a PR merges only with every CI job green.
