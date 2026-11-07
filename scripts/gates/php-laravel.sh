#!/bin/sh
# agent-workflow-kit:managed profile=php-laravel
# Full gate for a Laravel app: style, static analysis, tests in parallel.
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

step pint vendor/bin/pint --test
step phpstan vendor/bin/phpstan analyse --no-progress --memory-limit=1G
if [ -x vendor/bin/pest ]; then
  step test vendor/bin/pest --parallel
else
  step test php artisan test --parallel
fi
if [ -f package.json ] && grep -q '"build"' package.json; then
  step assets npm run build
fi

[ -f scripts/gate.local.sh ] && . scripts/gate.local.sh

if [ -n "$failed" ]; then
  echo "GATE FAIL:$failed"
  exit 1
fi
echo "GATE PASS"
