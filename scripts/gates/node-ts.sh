#!/bin/sh
# agent-workflow-kit:managed profile=node-ts
# Full gate for a Node + TypeScript project: format, lint, types, tests, build.
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

# Package manager from the lockfile.
if [ -f pnpm-lock.yaml ]; then pm=pnpm; x="pnpm exec"
elif [ -f yarn.lock ]; then pm=yarn; x="yarn"
elif [ -f bun.lockb ] || [ -f bun.lock ]; then pm=bun; x="bunx"
else pm=npm; x="npx --no-install"
fi

if [ -x node_modules/.bin/prettier ]; then
  step format $x prettier --check .
else
  echo "== format"; echo "-- n/a (prettier not installed)"
fi
step lint $x eslint .
step types $x tsc --noEmit
step test $x vitest run
step build $pm run build

[ -f scripts/gate.local.sh ] && . scripts/gate.local.sh

if [ -n "$failed" ]; then
  echo "GATE FAIL:$failed"
  exit 1
fi
echo "GATE PASS"
