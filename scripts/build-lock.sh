#!/bin/sh
# agent-workflow-kit:managed
# Runs one build command behind a machine-wide lock and a free-memory threshold,
# so parallel worktrees never compile at the same time.
#
# Usage: sh scripts/build-lock.sh [--full] <command> [args...]
#   --full  heavy step (full test, clippy, release build): higher memory threshold, more jobs
#
# Slot: if <worktree>/.build-slot exists (one line, an absolute dir, untracked),
# BUILD_SLOT_DIR is set to it, and CARGO_TARGET_DIR too unless the project sets its own
# target-dir in .cargo/config.toml (the project's per-worktree setting wins). One slot per branch.
#
# Waiting: the lock waits while any BUILD_LOCK_PROCS process runs, anywhere on the machine.
# - Under rustup, cargo runs through a proxy: one build shows as 2 cargo processes.
# - rust-analyzer (check on save), `tauri dev`, `cargo watch` and other sessions keep cargo
#   alive and block the lock until BUILD_LOCK_MAX_WAIT (exit 75). Stop them before locked builds.
# - Without PowerShell (Windows) or /proc/meminfo, free memory is unreadable: the lock then
#   checks processes only and says so.
#
# Settings (env, defaults in brackets):
#   BUILD_LOCK_DIR        lock directory          [${TMPDIR:-/tmp}/agent-workflow-build.lock]
#   BUILD_LOCK_MIN_MB     free MB, normal step    [2000]
#   BUILD_LOCK_FULL_MB    free MB, --full step    [4000]
#   BUILD_LOCK_JOBS       jobs, normal step       [2]
#   BUILD_LOCK_FULL_JOBS  jobs, --full step       [4]
#   BUILD_LOCK_PROCS      compiler process names that must not be running [cargo rustc]
#   BUILD_LOCK_MAX_WAIT   seconds before giving up [3600]
#   BUILD_LOCK_STALE      seconds after which a held lock is broken [14400]
#
# Exit codes: 2 setup error; 75 lock not acquired within BUILD_LOCK_MAX_WAIT
# (not a build failure: report it); otherwise the command's own exit code.
set -u

min_mb=${BUILD_LOCK_MIN_MB:-2000}
jobs=${BUILD_LOCK_JOBS:-2}
if [ "${1:-}" = "--full" ]; then
  min_mb=${BUILD_LOCK_FULL_MB:-4000}
  jobs=${BUILD_LOCK_FULL_JOBS:-4}
  shift
fi
if [ $# -eq 0 ]; then
  echo "build-lock.sh: no command given" >&2
  exit 2
fi

lock=${BUILD_LOCK_DIR:-${TMPDIR:-/tmp}/agent-workflow-build.lock}
procs=${BUILD_LOCK_PROCS:-cargo rustc}
max_wait=${BUILD_LOCK_MAX_WAIT:-3600}
stale_after=${BUILD_LOCK_STALE:-14400}

root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$(pwd)
if [ -f "$root/.build-slot" ]; then
  slot=$(tr -d '\r\n' < "$root/.build-slot")
  if [ -z "$slot" ]; then
    echo "build-lock.sh: $root/.build-slot is empty" >&2
    exit 2
  fi
  BUILD_SLOT_DIR=$slot
  export BUILD_SLOT_DIR
  if [ -f "$root/.cargo/config.toml" ] && grep -q '^[[:space:]]*target-dir[[:space:]]*=' "$root/.cargo/config.toml"; then
    echo "build-lock.sh: .cargo/config.toml sets target-dir; keeping it" >&2
  else
    CARGO_TARGET_DIR=$slot
    export CARGO_TARGET_DIR
  fi
fi

case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) os=windows ;;
  Darwin) os=mac ;;
  *) os=unix ;;
esac

to_int() {
  case "$1" in ''|*[!0-9]*) echo "-1" ;; *) echo "$1" ;; esac
}

ps_int() {
  to_int "$(powershell -NoProfile -Command "$1" 2>/dev/null | tr -d '\r ')"
}

avail_mb() {
  case $os in
    windows) ps_int "(Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes" ;;
    mac)
      page=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
      pages=$(vm_stat 2>/dev/null | awk '/Pages (free|inactive|speculative)/ { gsub(/\./, "", $NF); s += $NF } END { print s + 0 }')
      to_int "$((pages * page / 1048576))" ;;
    *) to_int "$(awk '/^MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo 2>/dev/null)" ;;
  esac
}

compiler_count() {
  case $os in
    windows)
      names=$(echo "$procs" | sed 's/ /,/g')
      ps_int "(Get-Process $names -ErrorAction SilentlyContinue | Measure-Object).Count" ;;
    *)
      n=0
      for p in $procs; do
        c=$(ps -A -o comm= 2>/dev/null | awk -v p="$p" '{ sub(".*/", "", $0) } $0 == p { c++ } END { print c + 0 }')
        n=$((n + c))
      done
      echo "$n" ;;
  esac
}

my_pid() {
  if [ $os = windows ] && [ -r /proc/$$/winpid ]; then cat /proc/$$/winpid; else echo "$$"; fi
}

# Alive unless positively dead; an unreadable answer counts as alive.
pid_dead() {
  if [ $os = windows ]; then
    [ "$(ps_int "if (Get-Process -Id $1 -ErrorAction SilentlyContinue) { 1 } else { 0 }")" = "0" ]
  else
    ! kill -0 "$1" 2>/dev/null
  fi
}

break_stale_lock() {
  [ -d "$lock" ] || return 0
  pid=""
  since=""
  [ -f "$lock/owner" ] && read -r pid since < "$lock/owner"
  if [ -z "$pid" ] || [ -z "$since" ]; then
    # Ownerless lock: break it only once it is older than 10 minutes.
    if [ -n "$(find "$lock" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
      rm -rf "$lock"
      echo "build-lock.sh: removed ownerless lock" >&2
    fi
    return 0
  fi
  now=$(date +%s)
  if pid_dead "$pid" || [ $((now - since)) -gt "$stale_after" ]; then
    rm -rf "$lock"
    echo "build-lock.sh: removed stale lock of pid $pid" >&2
  fi
}

me=$(my_pid)
waited=0
warned_mem=0
while :; do
  break_stale_lock
  a=$(avail_mb)
  c=$(compiler_count)
  mem_ok=1
  if [ "$a" -lt 0 ]; then
    [ $warned_mem -eq 1 ] || echo "build-lock.sh: cannot read free memory; checking the lock only" >&2
    warned_mem=1
  elif [ "$a" -lt "$min_mb" ]; then
    mem_ok=0
  fi
  [ "$c" -lt 0 ] && c=0
  if [ $mem_ok -eq 1 ] && [ "$c" -eq 0 ] && mkdir "$lock" 2>/dev/null; then
    echo "$me $(date +%s)" > "$lock/owner"
    break
  fi
  if [ "$waited" -ge "$max_wait" ]; then
    echo "build-lock.sh: lock not acquired after ${waited}s (free ${a} MB, need ${min_mb}; compilers running ${c})" >&2
    exit 75
  fi
  if [ $((waited % 300)) -eq 0 ]; then
    echo "build-lock.sh: waiting (free ${a} MB, need ${min_mb}; compilers running ${c})" >&2
  fi
  sleep 20
  waited=$((waited + 20))
done

release_lock() {
  owner=""
  [ -f "$lock/owner" ] && read -r owner _ < "$lock/owner"
  # The lock may have been broken and retaken by another build.
  [ "$owner" = "$me" ] && rm -rf "$lock"
}
trap release_lock EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

CARGO_BUILD_JOBS=$jobs
BUILD_JOBS=$jobs
export CARGO_BUILD_JOBS BUILD_JOBS
"$@"
rc=$?
exit $rc
