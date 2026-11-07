---
profile: rust-compiled
detect: [Cargo.toml]
parallel_implementers: "several; only one compile at a time"
build_serialization: lock
build_lock: scripts/build-lock.sh
isolation: "one worktree per branch + one build slot (target dir) per worktree, or the project's own per-worktree target-dir"
slot_file: .build-slot
suite_cost: high
gate_script: scripts/gates/rust-compiled.sh
ui_validation: desktop-window
failure: "any step exit != 0; exit 75 = build lock timeout, reported, not a code failure"
---

# Profile: rust-compiled

Parameters for Rust workspaces where compiling is the expensive part. `/workflow-init` and the `orchestrate` skill read the frontmatter; the sections below are the rules that go with it.

## Gate (stock steps; init derives the real ones from CI first)

```sh
cargo fmt --all -- --check
sh scripts/build-lock.sh --full cargo clippy --workspace --all-targets --locked [-- -D warnings]
sh scripts/build-lock.sh --full cargo test --workspace --locked --no-fail-fast
cargo deny check                       # only if deny.toml exists
sh scripts/build-lock.sh --full cargo build --release --locked   # opt-in
```

- `-D warnings` and the release build are opt-in: on when CI enforces them or the user asks. A release build may need assets or toolchains (a frontend `dist/`, a linker) that a plain checkout lacks.
- Mirror CI's flags and env vars (`--all-features`, `RUSTFLAGS`, `--exclude`).
- `Cargo.toml` not at the root (e.g. `src-tauri/`): add `--manifest-path <dir>/Cargo.toml` to every step.
- Project extras (e.g. `cargo xtask check-deps`) go in `scripts/gate.local.sh`, each as `step <name> ...`.

## Branch checks (implementer, cheap, crates touched only)

```sh
cargo fmt --all -- --check
sh scripts/build-lock.sh cargo check -p <crates> --all-targets
sh scripts/build-lock.sh cargo test -p <crates>
```

The project's own branch rules win (e.g. "no workspace clippy on feature branches"). The full gate runs at review and before the PR.

## Builds

- Every cargo invocation except `fmt` goes through `scripts/build-lock.sh`. Never call `cargo build/test/clippy` directly. Never lower the thresholds to get through.
- The lock waits for no running compiler and enough free memory, then runs at reduced `-j`. Exit 75 means it waited `BUILD_LOCK_MAX_WAIT` without acquiring: report it with the memory and process counts printed.
- The lock counts every `cargo`/`rustc` process on the machine. Under rustup one build is 2 cargo processes (proxy and toolchain). rust-analyzer's check on save, a running `tauri dev` or `cargo watch`, and other sessions all block it.
- Run the full gate and release builds in the background; they outlast tool-call timeouts (LESSONS L12).
- `cargo fmt --all` in write mode reformats everyone's files. Run `--check`, then format only your own files with `rustfmt` and the project's `rustfmt.toml` (a nightly-only config needs the toolchain it names).

## Slots

- The project sets `target-dir` in `.cargo/config.toml` (often per worktree): `slot_dir: project`. Write no `.build-slot`; build-lock keeps the project's setting and never exports `CARGO_TARGET_DIR`.
- Otherwise the orchestrator writes `<worktree>/.build-slot` (untracked, gitignored) with `<slot_dir>/slot-<n>` when it creates the worktree.
- One slot per running branch; reuse a finished branch's slot so rebuilds stay warm. Never share a slot between two live branches (LESSONS L11).
- Put slots on a disk with room; clean old slots only when that disk runs low.

## UI validation: desktop-window

Follow `reference/validation-modes.md` (desktop-window), including its build-lock rules. In short:
- Stop the dev app before any locked build, or run it through the lock with the slot target.
- With a fixed dev port, run one app at a time.
- Use a throwaway data/config dir; never the user's real profile.
- Implementer and reviewer never run the app.

A library or CLI crate: `cli` or `none`.

## CI

Matrix on the target OSes (e.g. Windows, Linux, macOS). The local gate covers one OS only; a PR merges only with every CI job green. When CI cannot run (`ci` is not `required`), the orchestrator re-runs the gate on the merged result.
