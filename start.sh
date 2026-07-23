#!/usr/bin/env bash
# =============================================================================
# RER DSP — start local stack (backend + frontend)
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

# Load env for path checks (without exporting everything to compose twice)
set -a
# shellcheck disable=SC1091
source .env
set +a

BACKEND_PATH="${DSP_BACKEND_PATH:-../rer-dsp-backend}"
FRONTEND_PATH="${DSP_FRONTEND_PATH:-../rer-dsp-frontend}"

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

info "Building and starting containers..."
docker compose --env-file .env up -d --build

ok "Stack is up"
echo ""
echo "Frontend:  http://${DSP_HTTP_HOST:-localhost}:${DSP_FRONTEND_HOST_PORT:-8081}${VITE_BASE_URL:-/dsp/}"
echo "Backend:   http://${DSP_HTTP_HOST:-localhost}:${DSP_BACKEND_HOST_PORT:-8080}${DSP_BACKEND_CONTEXT_PATH:-/dsp-backend}"
echo "Config:    http://${DSP_HTTP_HOST:-localhost}:${DSP_BACKEND_HOST_PORT:-8080}${DSP_BACKEND_CONTEXT_PATH:-/dsp-backend}/config/installation"
echo ""
echo "Logs:      docker compose logs -f"
echo "Stop:      docker compose down"
