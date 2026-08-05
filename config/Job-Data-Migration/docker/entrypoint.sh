#!/bin/sh
# Migration job entrypoint — mode is controlled by DSP_MIGRATION_EXECUTION_MODE.
#   once       — run Spring Batch and exit (used by compose run --rm)
#   continuous — keep container idle for external scheduling / manual triggers
set -e

MODE="${DSP_MIGRATION_EXECUTION_MODE:-once}"

if [ "$MODE" = "continuous" ]; then
  exec sleep infinity
fi

exec java ${JAVA_OPTS:--XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0} -jar /app/app.jar
