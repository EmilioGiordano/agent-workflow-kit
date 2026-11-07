#!/bin/sh
# agent-workflow-kit:managed profile=python
# Full gate for a Python project: format, lint, types, tests in parallel.
# Usage, from the worktree root: sh scripts/gate.sh
# Project-specific extra steps go in scripts/gate.local.sh (sourced at the end, never overwritten).
# Exit: 0 only if every step exits 0.
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
  [ "$rc" -eq 0 ] || failed="$failed $name"
}

# Runner from the lockfile; otherwise the active venv (the worktree's own .venv).
if [ -f uv.lock ]; then r="uv run"
elif [ -f poetry.lock ]; then r="poetry run"
else r=""
fi

step format $r ruff format --check .
step lint $r ruff check .
step types $r mypy .
step test $r pytest -n auto

[ -f scripts/gate.local.sh ] && . scripts/gate.local.sh

if [ -n "$failed" ]; then
  echo "GATE FAIL:$failed"
  exit 1
fi
echo "GATE PASS"
