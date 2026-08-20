#!/bin/sh
# Migration job entrypoint — mode is controlled by DSP_MIGRATION_EXECUTION_MODE.
#   once       — run Spring Batch and exit (used by compose run --rm)
#   continuous — re-run Spring Batch on DSP_MIGRATION_SYNC_INTERVAL (default 1h)
set -e

MODE="${DSP_MIGRATION_EXECUTION_MODE:-once}"

if [ "$MODE" != "continuous" ]; then
  exec java ${JAVA_OPTS:--XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0} -jar /app/app.jar
fi

# --- continuous: periodic re-sync -------------------------------------------

LOCK_FILE="/tmp/dsp-migration-sync.lock"

interval_to_seconds() {
  raw="$1"
  if ! printf '%s' "$raw" | grep -Eq '^[0-9]+[mh]$'; then
    return 1
  fi
  num=$(printf '%s' "$raw" | sed 's/[mh]$//')
  unit=$(printf '%s' "$raw" | sed 's/^[0-9]*//')
  if [ -z "$num" ] || [ "$num" -eq 0 ]; then
    return 1
  fi
  case "$unit" in
    m) seconds=$((num * 60)) ;;
    h) seconds=$((num * 3600)) ;;
    *) return 1 ;;
  esac
  if [ "$seconds" -lt 300 ]; then
    return 1
  fi
  printf '%s\n' "$seconds"
}

acquire_sync_lock() {
  if [ -f "$LOCK_FILE" ]; then
    old_pid=$(cat "$LOCK_FILE" 2>/dev/null || true)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      return 1
    fi
    rm -f "$LOCK_FILE"
  fi
  printf '%s\n' "$$" >"$LOCK_FILE"
  return 0
}

release_sync_lock() {
  rm -f "$LOCK_FILE"
}

INTERVAL_RAW="${DSP_MIGRATION_SYNC_INTERVAL:-1h}"
INTERVAL_SECONDS=$(interval_to_seconds "$INTERVAL_RAW") || {
  echo "[entrypoint] Invalid or too-small DSP_MIGRATION_SYNC_INTERVAL='${INTERVAL_RAW}' — using 1h" >&2
  INTERVAL_RAW="1h"
  INTERVAL_SECONDS=3600
}

echo "[entrypoint] Continuous mode: re-sync every ${INTERVAL_RAW} (${INTERVAL_SECONDS}s)"
echo "[entrypoint] Initial load already ran in setup; waiting one interval before first cycle."

while true; do
  echo "[entrypoint] Sleeping ${INTERVAL_SECONDS}s until next sync cycle..."
  sleep "$INTERVAL_SECONDS"

  if ! acquire_sync_lock; then
    echo "[entrypoint] Sync cycle skipped — another sync is still running (lock ${LOCK_FILE})" >&2
    continue
  fi

  echo "[entrypoint] Starting sync cycle..."
  set +e
  java ${JAVA_OPTS:--XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0} -jar /app/app.jar
  status=$?
  set -e
  release_sync_lock

  if [ "$status" -eq 0 ]; then
    echo "[entrypoint] Sync cycle finished successfully"
  else
    echo "[entrypoint] Sync cycle failed (exit ${status}) — will retry after next interval" >&2
  fi
done
