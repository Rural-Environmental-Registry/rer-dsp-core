#!/usr/bin/env bash
# =============================================================================
# RER DSP — start local stack (databases + optional migration + apps)
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$(id -u)" -eq 0 ]; then
  error "Do not run as root/sudo. Use: ./start.sh"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  error "Docker is required."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  error "Docker Compose v2 is required (docker compose)."
  exit 1
fi

if [ ! -f .env ]; then
  info "Creating .env from .env.example"
  cp .env.example .env
  ok ".env created — review values if needed"
else
  info "Using existing .env"
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

BACKEND_PATH="${DSP_BACKEND_PATH:-../rer-dsp-backend}"
FRONTEND_PATH="${DSP_FRONTEND_PATH:-../rer-dsp-frontend}"
JOB_PATH="${DSP_JOB_MIGRATION_PATH:-../rer-dsp-job-data-migration}"

resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$ROOT_DIR/$path"
  fi
}

BACKEND_ABS="$(resolve_path "$BACKEND_PATH")"
FRONTEND_ABS="$(resolve_path "$FRONTEND_PATH")"
JOB_ABS="$(resolve_path "$JOB_PATH")"

if [ ! -f "$BACKEND_ABS/Dockerfile" ]; then
  error "Backend not found at: $BACKEND_ABS"
  error "Clone rer-dsp-backend as a sibling or set DSP_BACKEND_PATH in .env"
  exit 1
fi

if [ ! -f "$FRONTEND_ABS/Dockerfile" ]; then
  error "Frontend not found at: $FRONTEND_ABS"
  error "Clone rer-dsp-frontend as a sibling or set DSP_FRONTEND_PATH in .env"
  exit 1
fi

ok "Backend:  $BACKEND_ABS"
ok "Frontend: $FRONTEND_ABS"

wait_for_db() {
  local service="$1"
  local user="$2"
  local db="$3"
  local i
  for i in $(seq 1 60); do
    if docker compose --env-file .env exec -T "$service" \
        pg_isready -U "$user" -d "$db" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

info "Starting databases (dsp-db, dsp-job-migration-db)..."
docker compose --env-file .env up -d dsp-db dsp-job-migration-db

info "Waiting for databases to become healthy..."
if ! wait_for_db dsp-db "${DSP_DB_USER:-dsp}" "${DSP_DB_NAME:-dsp-db}"; then
  error "dsp-db did not become ready in time."
  exit 1
fi
if ! wait_for_db dsp-job-migration-db "${DSP_JOB_MIGRATION_DB_USER:-dsp_job}" "${DSP_JOB_MIGRATION_DB_NAME:-dsp-job-migration-db}"; then
  error "dsp-job-migration-db did not become ready in time."
  exit 1
fi
ok "Databases are ready"

if [ "${DSP_RUN_MIGRATION:-false}" = "true" ]; then
  if [ ! -f "$JOB_ABS/Dockerfile" ]; then
    error "Migration job not found at: $JOB_ABS"
    error "Clone rer-dsp-job-data-migration or set DSP_JOB_MIGRATION_PATH in .env"
    exit 1
  fi
  if [ -z "${DSP_SOURCE_JDBC_URL:-}" ]; then
    error "DSP_RUN_MIGRATION=true requires DSP_SOURCE_JDBC_URL in .env"
    exit 1
  fi
  ok "Job:      $JOB_ABS"
  info "Running data migration (profile=migration)..."
  docker compose --env-file .env --profile migration run --rm --build dsp-job-migration
  ok "Migration finished"
else
  info "Skipping migration (DSP_RUN_MIGRATION=${DSP_RUN_MIGRATION:-false})"
fi

info "Building and starting application containers..."
docker compose --env-file .env up -d --build dsp-backend dsp-frontend

ok "Stack is up"
echo ""
echo "Frontend:              http://${DSP_HTTP_HOST:-localhost}:${DSP_FRONTEND_HOST_PORT:-8081}${VITE_BASE_URL:-/dsp/}"
echo "Backend:               http://${DSP_HTTP_HOST:-localhost}:${DSP_BACKEND_HOST_PORT:-8080}${DSP_BACKEND_CONTEXT_PATH:-/dsp-backend}"
echo "Config:                http://${DSP_HTTP_HOST:-localhost}:${DSP_BACKEND_HOST_PORT:-8080}${DSP_BACKEND_CONTEXT_PATH:-/dsp-backend}/config/installation"
echo "DSP DB:                localhost:${DSP_DB_HOST_PORT:-5433}  db=${DSP_DB_NAME:-dsp-db}  user=${DSP_DB_USER:-dsp}"
echo "Job migration DB:      localhost:${DSP_JOB_MIGRATION_DB_HOST_PORT:-5434}  db=${DSP_JOB_MIGRATION_DB_NAME:-dsp-job-migration-db}  user=${DSP_JOB_MIGRATION_DB_USER:-dsp_job}"
echo ""
echo "Verify tables:"
echo "  docker compose exec dsp-db psql -U ${DSP_DB_USER:-dsp} -d ${DSP_DB_NAME:-dsp-db} -c '\\dt dsp.*'"
echo "  docker compose exec dsp-job-migration-db psql -U ${DSP_JOB_MIGRATION_DB_USER:-dsp_job} -d ${DSP_JOB_MIGRATION_DB_NAME:-dsp-job-migration-db} -c '\\dt BATCH*'"
echo ""
echo "Run migration later:"
echo "  DSP_RUN_MIGRATION=true ./start.sh"
echo "  # or: docker compose --profile migration run --rm --build dsp-job-migration"
echo ""
echo "Logs:       docker compose logs -f"
echo "Stop:       docker compose down"
echo "Reset DBs:  docker compose down -v   # removes volumes (re-runs init SQL)"
