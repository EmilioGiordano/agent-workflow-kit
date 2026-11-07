#!/bin/sh
# agent-workflow-kit:managed profiles=node-ts
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
# -- stack: node-ts
# init: prefer the project's package.json scripts and CI steps ($pm run <script>); call a tool directly only
# when no script covers it. Keep only tools the project declares (eslint | biome | oxlint, prettier, vitest | jest).
# init: types use "tsc -p <test tsconfig>" when one exists; plain tsc skips test files.
# init: build only if package.json has scripts.build; audit only if CI runs it (needs network; offline = n/a).
# Runner from the lockfile; none of these install a missing package (never bunx or bare npx).
if [ -f pnpm-lock.yaml ]; then pm=pnpm; x="pnpm exec"
elif [ -f yarn.lock ]; then pm=yarn; x="yarn"
elif [ -f bun.lockb ] || [ -f bun.lock ]; then pm=bun; x="bun run"
else pm=npm; x="npx --no-install"
fi
step_need node_modules/prettier/package.json format $x prettier --check .
step_need node_modules/eslint/package.json lint $x eslint .
step_need node_modules/typescript/package.json types $x tsc --noEmit
step_need node_modules/vitest/package.json test $x vitest run
step build $pm run build
# step audit npm audit --audit-level=high
# agent-workflow-kit:steps:end

[ -f scripts/gate.local.sh ] && . scripts/gate.local.sh

if [ -n "$failed" ]; then
  echo "GATE FAIL:$failed"
  exit 1
fi
echo "GATE PASS"
