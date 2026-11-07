#!/bin/sh
# agent-workflow-kit:managed profiles=rust-compiled
# Full gate. Usage, from the worktree root: sh scripts/gate.sh
# /workflow-init owns this file. Outside the steps markers it is the kit's text, refreshed on re-run.
# Inside the markers are the steps derived for this project (CI, package scripts, profile); a re-run
# replaces them only after the user approves the diff. Dropped steps are recorded there as "# dropped:".
# Hand-written project steps go in scripts/gate.local.sh (created with a usage comment only, never overwritten).
# Exit: 0 only if every step exits 0. A step exiting 75 means the build lock timed out (report it).
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2

failed=""
# step <name> <command...>: run, print the exit code, record a failure.
step() {
  name=$1
  shift
  echo "== $name"
  "$@"
  rc=$?
  echo "-- exit $rc"
  [ "$rc" -eq 75 ] && echo "-- build lock timed out: report it, not a code failure"
  [ "$rc" -eq 0 ] || failed="$failed $name"
}
# step_if <file> <name> <command...>: run only when <file> exists (the project opted in by config).
step_if() {
  file=$1
  shift
  if [ -e "$file" ]; then step "$@"; else echo "== $1"; echo "-- n/a ($file not found)"; fi
}
# step_need <tool> <name> <command...>: <tool> is a path (vendor/bin/pint, node_modules/eslint/package.json)
# or a command name (cargo). A missing tool fails the step: the gate never installs anything.
step_need() {
  tool=$1
  shift
  case $tool in
    */*) [ -e "$tool" ] && found=1 || found=0 ;;
    *) command -v "$tool" >/dev/null 2>&1 && found=1 || found=0 ;;
  esac
  if [ "$found" -eq 1 ]; then
    step "$@"
  else
    echo "== $1"
    echo "-- missing $tool: install the project's dependencies first; the gate never installs tools"
    echo "-- exit 127"
    failed="$failed $1"
  fi
}

# agent-workflow-kit:steps:begin
# -- stack: rust-compiled
# init: add --manifest-path <dir>/Cargo.toml when Cargo.toml is not at the root.
# init: append "-- -D warnings" to clippy, and enable build-release, only when CI enforces them or the user opts in.
L="sh scripts/build-lock.sh"
step_need cargo fmt cargo fmt --all -- --check
step_need cargo clippy $L --full cargo clippy --workspace --all-targets --locked
step_need cargo test $L --full cargo test --workspace --locked --no-fail-fast
step_if deny.toml deny cargo deny check
# step build-release $L --full cargo build --release --locked
# agent-workflow-kit:steps:end

[ -f scripts/gate.local.sh ] && . scripts/gate.local.sh

if [ -n "$failed" ]; then
  echo "GATE FAIL:$failed"
  exit 1
fi
echo "GATE PASS"
