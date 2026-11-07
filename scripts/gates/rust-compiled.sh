#!/bin/sh
# agent-workflow-kit:managed profile=rust-compiled
# Full gate for a Rust workspace. Builds go through scripts/build-lock.sh (one compile at a time).
# Usage, from the worktree root: sh scripts/gate.sh
# Project-specific extra steps go in scripts/gate.local.sh (sourced at the end, never overwritten).
# Exit: 0 only if every step exits 0. A step that exits 75 means the build lock timed out.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2

failed=""
step() {
  name=$1
  shift
  echo "== $name"
  "$@"
  rc=$?
  echo "-- exit $rc"
  [ "$rc" -eq 75 ] && echo "-- build lock timed out: report it, not a test failure"
  [ "$rc" -eq 0 ] || failed="$failed $name"
}
# Runs a step only when its config file exists; otherwise prints n/a.
step_if() {
  file=$1
  shift
  if [ -e "$file" ]; then step "$@"; else echo "== $1"; echo "-- n/a ($file not found)"; fi
}

L="sh scripts/build-lock.sh"

step fmt cargo fmt --all -- --check
step clippy $L --full cargo clippy --workspace --all-targets --locked -- -D warnings
step test $L --full cargo test --workspace --locked --no-fail-fast
step_if deny.toml deny cargo deny check
step build-release $L --full cargo build --release --locked

[ -f scripts/gate.local.sh ] && . scripts/gate.local.sh

if [ -n "$failed" ]; then
  echo "GATE FAIL:$failed"
  exit 1
fi
echo "GATE PASS"
