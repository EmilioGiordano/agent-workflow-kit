#!/bin/sh
# agent-workflow-kit:managed profiles=php-laravel
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
# -- stack: php-laravel
# init: keep only tools composer.json declares (pint, phpstan/larastan, pest); record the others as "# dropped:".
# init: assets only if package.json has scripts.build.
# Refuses to test unless the testing database is clearly a test one: phpunit.xml <env DB_DATABASE> first,
# then .env.testing, which Laravel loads only when phpunit.xml sets APP_ENV=testing. Otherwise
# RefreshDatabase would run against the .env database. A cached config bypasses .env files: refused too.
test_db_guard() {
  if [ -f bootstrap/cache/config.php ]; then
    echo "refusing: bootstrap/cache/config.php exists (cached config ignores .env.testing); run php artisan config:clear"
    return 1
  fi
  db=""
  app_env=""
  for f in phpunit.xml phpunit.xml.dist; do
    [ -f "$f" ] || continue
    xml=$(grep -v '<!--' "$f")
    db=$(echo "$xml" | sed -n 's/.*name="DB_DATABASE"[^>]*value="\([^"]*\)".*/\1/p' | head -n 1)
    app_env=$(echo "$xml" | sed -n 's/.*name="APP_ENV"[^>]*value="\([^"]*\)".*/\1/p' | head -n 1)
    break
  done
  if [ -z "$db" ] && [ -f .env.testing ]; then
    if [ "$app_env" != testing ]; then
      echo "refusing: .env.testing is loaded only when phpunit.xml sets APP_ENV=testing"
      return 1
    fi
    db=$(sed -n 's/^DB_DATABASE=//p' .env.testing | tail -n 1 | tr -d "\"'\r")
  fi
  case $db in
    '') echo "refusing: no DB_DATABASE in phpunit.xml or .env.testing (tests would use .env)"; return 1 ;;
    :memory:|*test*) echo "testing database: $db" ;;
    *) echo "refusing: testing database '$db' does not contain 'test'"; return 1 ;;
  esac
}
step test-db-guard test_db_guard
step_need vendor/bin/pint pint vendor/bin/pint --test
step_need vendor/bin/phpstan phpstan vendor/bin/phpstan analyse --no-progress --memory-limit=1G
par=""
[ -d vendor/brianium/paratest ] && par="--parallel"
case $failed in
  *test-db-guard*) echo "== test"; echo "-- skipped: test-db-guard failed"; failed="$failed test" ;;
  *) if [ -x vendor/bin/pest ]; then step test vendor/bin/pest $par; else step test php artisan test $par; fi ;;
esac
# step assets npm run build
# agent-workflow-kit:steps:end

[ -f scripts/gate.local.sh ] && . scripts/gate.local.sh

if [ -n "$failed" ]; then
  echo "GATE FAIL:$failed"
  exit 1
fi
echo "GATE PASS"
