#!/usr/bin/env bash
# Usage: ./setup.sh [--quickstart|--skip-migration|--status]   then ./start.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

DSP_ORCHESTRATION_SCRIPT="setup.sh"
TOTAL_STEPS=10

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/common.sh"

SKIP_MIGRATION=false
FORCE_QUICKSTART=false
SHOW_STATUS=false
for arg in "$@"; do
  case "$arg" in
    --skip-migration)
      SKIP_MIGRATION=true
      ;;
    --quickstart)
      FORCE_QUICKSTART=true
      ;;
    --status)
      SHOW_STATUS=true
      ;;
    -h|--help)
      echo "Usage: ./setup.sh [--quickstart | --skip-migration | --status]"
      echo ""
      echo "Prepares persistent data for the local DSP stack:"
      echo "  - starts databases"
      echo "  - real mode: runs the data-migration job (unless --skip-migration)"
      echo "  - demo mode: loads built-in Brazil seed (no JDBC source)"
      echo "  - starts GeoServer Exhibition and publishes layers"
      echo ""
      echo "With no flags, you are asked:"
      echo "  1) real adopter setup"
      echo "  2) demonstration"
      echo "  3) stack status / URLs (cleanup this project or exit)"
      echo ""
      echo "Flags:"
      echo "  --quickstart       demonstration seed (non-interactive)"
      echo "  --skip-migration   real setup without ETL (empty DBs + GeoServer)"
      echo "  --status           show container/health status + URLs; cleanup or exit (same as choice 3)"
      echo ""
      echo "Then run: ./start.sh"
      echo ""
      echo "Env:"
      echo "  DSP_SKIP_MIGRATION=true   same as --skip-migration"
      exit 0
      ;;
    *)
      error "Unknown argument: $arg (try --help)"
      exit 1
      ;;
  esac
done

mode_flags=0
[ "$FORCE_QUICKSTART" = "true" ] && mode_flags=$((mode_flags + 1))
[ "$SKIP_MIGRATION" = "true" ] && mode_flags=$((mode_flags + 1))
[ "$SHOW_STATUS" = "true" ] && mode_flags=$((mode_flags + 1))
if [ "$mode_flags" -gt 1 ]; then
  error "Use only one of: --quickstart, --skip-migration, --status."
  exit 1
fi

step_header 1 "Prerequisites (Docker)"
require_not_root
require_docker

step_header 2 "Environment (.env)"
ensure_dotenv

if [ "$SHOW_STATUS" = "true" ]; then
  step_header 3 "Stack status"
  show_stack_status_menu
fi

SKIP_MIGRATION="$(should_skip_migration "$SKIP_MIGRATION")"

# Resolve setup mode: demo vs real
SETUP_MODE="real"
if [ "$FORCE_QUICKSTART" = "true" ]; then
  SETUP_MODE="demo"
  step_header 3 "Setup mode"
  info "Mode: demonstration (--quickstart)"
elif [ "$SKIP_MIGRATION" = "true" ]; then
  SETUP_MODE="real"
  step_header 3 "Setup mode"
  info "Mode: real adopter setup without migration (--skip-migration / DSP_SKIP_MIGRATION)"
else
  step_header 3 "Setup mode"
  prompt_setup_mode
  if [ "$SETUP_MODE" = "demo" ]; then
    info "Mode: demonstration (built-in seed)"
  else
    info "Mode: real adopter setup (JDBC + ETL)"
  fi
fi

if [ "$SETUP_MODE" = "real" ]; then
  step_header 4 "Adopter configuration"
  ensure_adopter_config
fi

WILL_MIGRATE=false
if [ "$SETUP_MODE" = "real" ] && [ "$SKIP_MIGRATION" != "true" ]; then
  WILL_MIGRATE=true
fi

MIGRATION_CONFIG_EXAMPLE="$ROOT_DIR/config/Job-Data-Migration/application/application.yaml.example"
MIGRATION_CONFIG="$ROOT_DIR/config/Job-Data-Migration/application/application.yaml"

if [ "$SETUP_MODE" = "demo" ]; then
  step_header 4 "Adopter configs (quickstart UI / map layers)"
  ensure_quickstart_adopter_configs

  step_header 5 "Confirmation"
  warn "Demonstration data only — no JDBC source and no migration job."
  if ! prompt_yes_no "Do you want to continue with this setup?"; then
    info "Setup cancelled."
    exit 0
  fi

  step_header 6 "Databases"
  start_databases_and_wait "false"

  step_header 7 "Quickstart seed"
  apply_quickstart_seed

  step_header 8 "GeoServer Exhibition (publish layers)"
  use_quickstart_layer_srids
  start_geoserver_exhibition "populate" ""

  ok "Setup finished — demonstration data is ready on Docker volumes."
  echo ""
  echo "Next: start the application stacks with:"
  echo "  ./start.sh"
  echo ""
  echo "Day-to-day: prefer ./start.sh (does not re-run seed)."
  echo "Real adopter data later: run ./config.sh and then ./setup.sh (choose 1)."
  echo "Reset DBs (lose data): docker compose down -v && ./setup.sh"
  echo ""
  exit 0
fi

# --- Real adopter path ---

step_header 4 "Migration job repository path"

JOB_PATH="${DSP_JOB_MIGRATION_PATH:-../rer-dsp-job-data-migration}"
JOB_ABS="$(resolve_path "$JOB_PATH")"

if [ "$WILL_MIGRATE" = "true" ]; then
  if [ ! -f "$JOB_ABS/Dockerfile" ]; then
    error "Migration job not found at: $JOB_ABS"
    error "Clone rer-dsp-job-data-migration or set DSP_JOB_MIGRATION_PATH in .env"
    exit 1
  fi
  ok "Migration job found: $JOB_ABS"
else
  info "Migration skipped — job repository check not required."
fi

step_header 5 "Map layers config (WMS / GeoServer)"

ensure_map_layers_config

step_header 6 "Migration config (JDBC + ETL)"

if [ ! -f "$MIGRATION_CONFIG_EXAMPLE" ]; then
  error "Migration config template not found at: $MIGRATION_CONFIG_EXAMPLE"
  exit 1
fi

if [ ! -f "$MIGRATION_CONFIG" ]; then
  error "Migration configuration file not found:"
  echo "        $MIGRATION_CONFIG"
  error "Run ./config.sh to generate the active configuration from the adopter wizard."
  error "If adopter-config.yaml already exists, use ./config.sh --apply."
  error "Or choose demonstration with ./setup.sh --quickstart."
  exit 1
fi

MIGRATION_CONFIG_READY=true
if cmp -s "$MIGRATION_CONFIG" "$MIGRATION_CONFIG_EXAMPLE"; then
  warn "Migration config is still identical to the generic template:"
  echo "       $MIGRATION_CONFIG"
  warn "Replace <placeholders> with your adopter source mapping before migrating."
  MIGRATION_CONFIG_READY=false
else
  ok "Migration config found: $MIGRATION_CONFIG"
fi

print_migration_preview "$MIGRATION_CONFIG" "$WILL_MIGRATE"

step_header 7 "Confirmation"

if [ "$WILL_MIGRATE" = "true" ] && [ "$MIGRATION_CONFIG_READY" = "false" ]; then
  error "Migration will run, but application.yaml is still a copy of the template."
  error "Edit $MIGRATION_CONFIG and run './setup.sh' again."
  error "Or use: ./setup.sh --skip-migration"
  error "Or demonstration: ./setup.sh --quickstart"
  exit 1
fi

if ! prompt_yes_no "Do you want to continue with this setup?"; then
  info "Setup cancelled."
  exit 0
fi

step_header 8 "Databases (+ migration)"

start_databases_and_wait "true"

if [ "$WILL_MIGRATE" = "true" ]; then
  info "Running data migration (profile=migration)..."
  docker compose --env-file .env --profile migration run --rm --build dsp-job-migration
  ok "Migration finished"
else
  info "Data migration skipped (--skip-migration / DSP_SKIP_MIGRATION=true)."
fi

step_header 9 "GeoServer Exhibition (publish layers)"

start_geoserver_exhibition "populate" "$MIGRATION_CONFIG"

ok "Setup finished — data is ready on Docker volumes."
echo ""
echo "Next: start the application stacks with:"
echo "  ./start.sh"
echo ""
echo "Day-to-day: prefer ./start.sh (does not re-run migration)."
echo "Rebuild only frontend: docker compose up -d --build dsp-frontend"
echo "Reset DBs (lose data): docker compose down -v && ./setup.sh"
echo ""
