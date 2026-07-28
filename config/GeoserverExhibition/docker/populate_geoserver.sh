#!/usr/bin/env bash
# Publishes DSP workspace/datastore/layers on GeoServer Exhibition via REST.
# Fixed FeatureTypes aligned with mapLayersConfig + job layer-name contract.
# Styles (colors) are read from the mounted mapLayersConfig.json.
# Does not CREATE database tables — only publishes existing PostGIS tables.

set -euo pipefail

GEOSERVER_URL="${GEOSERVER_URL:-http://localhost:8080/geoserver}"
GEOSERVER_USER="${GEOSERVER_ADMIN_USER:-admin}"
GEOSERVER_PASSWORD="${GEOSERVER_ADMIN_PASSWORD:-geoserver}"

WORKSPACE_NAME="${WORKSPACE_NAME:-dsp}"
DATASTORE_NAME="${DATASTORE_NAME:-dsp-db}"

DB_HOST="${DB_HOST:-dsp-geoserver-exhibition-db}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-dsp-geoserver-exhibition-db}"
DB_SCHEMA="${DB_SCHEMA:-dsp}"
DB_USER="${DB_USER:-dsp_geo}"
DB_PASSWORD="${DB_PASSWORD:-dsp_geo}"

MAP_LAYERS_CONFIG="${MAP_LAYERS_CONFIG:-/config/mapLayersConfig.json}"

require_layer_srs() {
  local env_name=$1
  local value=$2
  if [ -z "$value" ]; then
    echo "Environment variable '${env_name}' is required (EPSG code for layer SRS)."
    echo "Set it via start.sh (reads srid from application.yaml) or export manually."
    exit 1
  fi
}

require_layer_srs "LAYER_SRS_TERRITORY_LEVEL_1" "${LAYER_SRS_TERRITORY_LEVEL_1:-}"
require_layer_srs "LAYER_SRS_TERRITORY_LEVEL_2" "${LAYER_SRS_TERRITORY_LEVEL_2:-}"
require_layer_srs "LAYER_SRS_TERRITORY_LEVEL_3" "${LAYER_SRS_TERRITORY_LEVEL_3:-}"
require_layer_srs "LAYER_SRS_AREA_OF_INTEREST" "${LAYER_SRS_AREA_OF_INTEREST:-}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to read mapLayersConfig.json colors."
  exit 1
fi

if [ ! -f "$MAP_LAYERS_CONFIG" ]; then
  echo "mapLayersConfig.json not found: $MAP_LAYERS_CONFIG"
  echo "Mount config/map/mapLayersConfig.json into the container."
  exit 1
fi

# Returns style.color and style.fillColor for a WMS layer id (workspace:layer).
layer_style_values() {
  local wms_id=$1
  jq -r --arg id "$wms_id" '
    .groups[]?.layers[]?
    | select(.layers == $id)
    | [.style.color // "", .style.fillColor // ""]
    | @tsv
  ' "$MAP_LAYERS_CONFIG" | head -n 1
}

build_polygon_sld() {
  local style_name=$1
  local stroke_color=$2
  local fill_color=$3
  local stroke_width=$4
  local fill_opacity
  local fill_xml

  if [ "$fill_color" = "transparent" ]; then
    fill_opacity="0.0"
    fill_xml="<CssParameter name=\"fill-opacity\">${fill_opacity}</CssParameter>"
  else
    fill_opacity="0.25"
    fill_xml="<CssParameter name=\"fill\">${fill_color}</CssParameter>
              <CssParameter name=\"fill-opacity\">${fill_opacity}</CssParameter>"
  fi

  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0"
 xmlns="http://www.opengis.net/sld"
 xmlns:ogc="http://www.opengis.net/ogc"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xsi:schemaLocation="http://www.opengis.net/sld StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>${style_name}</Name>
    <UserStyle>
      <Title>${style_name}</Title>
      <FeatureTypeStyle>
        <Rule>
          <PolygonSymbolizer>
            <Fill>
              ${fill_xml}
            </Fill>
            <Stroke>
              <CssParameter name="stroke">${stroke_color}</CssParameter>
              <CssParameter name="stroke-width">${stroke_width}</CssParameter>
            </Stroke>
          </PolygonSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
EOF
}

rest_request() {
  local method=$1
  local url=$2
  local data=${3:-}

  if [ "$method" = "GET" ]; then
    curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
      -X GET -H "Accept: application/json" \
      "${GEOSERVER_URL}${url}"
  else
    curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
      -X "$method" -H "Content-Type: application/json" \
      -d "$data" \
      "${GEOSERVER_URL}${url}"
  fi
}

rest_status() {
  local method=$1
  local url=$2
  local data=${3:-}

  if [ "$method" = "GET" ]; then
    curl -s -o /dev/null -w "%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
      -X GET -H "Accept: application/json" \
      "${GEOSERVER_URL}${url}"
  else
    curl -s -o /dev/null -w "%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
      -X "$method" -H "Content-Type: application/json" \
      -d "$data" \
      "${GEOSERVER_URL}${url}"
  fi
}

ensure_workspace() {
  local status
  status=$(rest_status "GET" "/rest/workspaces/${WORKSPACE_NAME}")
  if [ "$status" = "200" ]; then
    echo "Workspace '${WORKSPACE_NAME}' already exists"
    return 0
  fi

  echo "Creating workspace '${WORKSPACE_NAME}'"
  local response status_code
  response=$(rest_request "POST" "/rest/workspaces" "{\"workspace\":{\"name\":\"${WORKSPACE_NAME}\"}}")
  status_code=$(echo "$response" | tail -n 1)
  if [ "$status_code" != "201" ]; then
    echo "Failed to create workspace (HTTP ${status_code})"
    echo "$response" | head -n -1
    exit 1
  fi
  echo "Workspace created"
}

ensure_datastore() {
  local status
  status=$(rest_status "GET" "/rest/workspaces/${WORKSPACE_NAME}/datastores/${DATASTORE_NAME}")
  if [ "$status" = "200" ]; then
    echo "Datastore '${DATASTORE_NAME}' already exists"
    return 0
  fi

  echo "Creating PostGIS datastore '${DATASTORE_NAME}' -> ${DB_HOST}:${DB_PORT}/${DB_NAME} schema=${DB_SCHEMA}"
  local data
  data=$(cat <<EOF
{
  "dataStore": {
    "name": "${DATASTORE_NAME}",
    "type": "PostGIS",
    "enabled": true,
    "connectionParameters": {
      "entry": [
        {"@key": "host", "\$": "${DB_HOST}"},
        {"@key": "port", "\$": "${DB_PORT}"},
        {"@key": "database", "\$": "${DB_NAME}"},
        {"@key": "schema", "\$": "${DB_SCHEMA}"},
        {"@key": "user", "\$": "${DB_USER}"},
        {"@key": "passwd", "\$": "${DB_PASSWORD}"},
        {"@key": "dbtype", "\$": "postgis"},
        {"@key": "Expose primary keys", "\$": "true"}
      ]
    }
  }
}
EOF
)

  local response status_code
  response=$(rest_request "POST" "/rest/workspaces/${WORKSPACE_NAME}/datastores" "$data")
  status_code=$(echo "$response" | tail -n 1)
  if [ "$status_code" != "201" ]; then
    echo "Failed to create datastore (HTTP ${status_code})"
    echo "$response" | head -n -1
    exit 1
  fi
  echo "Datastore created"
}

upload_sld() {
  local style_name=$1
  local sld_content=$2
  local put_response put_status

  put_response=$(curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
    -X PUT -H "Content-Type: application/vnd.ogc.sld+xml" \
    -d "$sld_content" \
    "${GEOSERVER_URL}/rest/workspaces/${WORKSPACE_NAME}/styles/${style_name}")
  put_status=$(echo "$put_response" | tail -n 1)
  if [ "$put_status" != "200" ]; then
    echo "Failed to upload SLD for '${style_name}' (HTTP ${put_status})"
    echo "$put_response" | head -n -1
    exit 1
  fi
}

# Creates the style if missing, then always overwrites SLD from mapLayersConfig colors.
ensure_style() {
  local style_name=$1
  local sld_content=$2

  local status
  status=$(rest_status "GET" "/rest/workspaces/${WORKSPACE_NAME}/styles/${style_name}")
  if [ "$status" != "200" ]; then
    echo "Creating style '${style_name}'"
    local response status_code
    response=$(rest_request "POST" "/rest/workspaces/${WORKSPACE_NAME}/styles" \
      "{\"style\":{\"name\":\"${style_name}\",\"filename\":\"${style_name}.sld\"}}")
    status_code=$(echo "$response" | tail -n 1)
    if [ "$status_code" != "201" ]; then
      echo "Failed to create style '${style_name}' (HTTP ${status_code})"
      echo "$response" | head -n -1
      exit 1
    fi
  else
    echo "Updating style '${style_name}' from mapLayersConfig"
  fi

  upload_sld "$style_name" "$sld_content"
  echo "Style '${style_name}' ready"
}

apply_default_style() {
  local layer_name=$1
  local style_name=$2
  local style_payload

  style_payload=$(cat <<EOF
{
  "layer": {
    "defaultStyle": {
      "name": "${style_name}",
      "workspace": "${WORKSPACE_NAME}"
    }
  }
}
EOF
)
  rest_request "PUT" "/rest/layers/${WORKSPACE_NAME}:${layer_name}" "$style_payload" >/dev/null
}

publish_layer() {
  local layer_name=$1
  local table_name=$2
  local style_name=$3
  local srs=$4

  if [ -z "$srs" ]; then
    echo "SRS is required to publish layer '${layer_name}'"
    exit 1
  fi

  local status
  status=$(rest_status "GET" "/rest/layers/${WORKSPACE_NAME}:${layer_name}")
  if [ "$status" = "200" ]; then
    echo "Layer '${layer_name}' already exists — syncing default style"
    apply_default_style "$layer_name" "$style_name"
    return 0
  fi

  echo "Publishing layer '${layer_name}' (table ${table_name})"
  local data
  data=$(cat <<EOF
{
  "featureType": {
    "name": "${layer_name}",
    "nativeName": "${table_name}",
    "title": "${layer_name}",
    "enabled": true,
    "srs": "${srs}",
    "projectionPolicy": "FORCE_DECLARED",
    "nativeBoundingBox": {
      "minx": -74.0,
      "maxx": -34.0,
      "miny": -34.0,
      "maxy": 6.0,
      "crs": "${srs}"
    },
    "latLonBoundingBox": {
      "minx": -74.0,
      "maxx": -34.0,
      "miny": -34.0,
      "maxy": 6.0,
      "crs": "EPSG:4326"
    }
  }
}
EOF
)

  local response status_code
  response=$(rest_request "POST" \
    "/rest/workspaces/${WORKSPACE_NAME}/datastores/${DATASTORE_NAME}/featuretypes" "$data")
  status_code=$(echo "$response" | tail -n 1)
  if [ "$status_code" != "201" ]; then
    echo "Failed to publish layer '${layer_name}' (HTTP ${status_code})"
    echo "$response" | head -n -1
    echo "Check: table ${DB_SCHEMA}.${table_name} exists and has geometry (exhibition-db init SQL + migration)."
    return 1
  fi

  apply_default_style "$layer_name" "$style_name"
  echo "Layer '${layer_name}' published"
}

# Reads colors from mapLayersConfig, builds SLD, ensures style, publishes/syncs layer.
sync_layer_from_config() {
  local wms_id=$1
  local layer_name=$2
  local table_name=$3
  local style_name=$4
  local stroke_width=$5
  local srs=$6

  local style_tsv stroke_color fill_color sld
  style_tsv=$(layer_style_values "$wms_id")
  if [ -z "$style_tsv" ]; then
    echo "Layer '${wms_id}' not found in ${MAP_LAYERS_CONFIG}"
    exit 1
  fi

  stroke_color=$(echo "$style_tsv" | cut -f1)
  fill_color=$(echo "$style_tsv" | cut -f2)
  if [ -z "$stroke_color" ] || [ -z "$fill_color" ]; then
    echo "Layer '${wms_id}' is missing style.color or style.fillColor in mapLayersConfig.json"
    exit 1
  fi

  echo "  ${wms_id}: color=${stroke_color} fillColor=${fill_color}"
  sld=$(build_polygon_sld "$style_name" "$stroke_color" "$fill_color" "$stroke_width")
  ensure_style "$style_name" "$sld"
  publish_layer "$layer_name" "$table_name" "$style_name" "$srs"
}

echo "=== DSP GeoServer Exhibition populate ==="
echo "URL: ${GEOSERVER_URL}"
echo "DB:  ${DB_HOST}:${DB_PORT}/${DB_NAME} schema=${DB_SCHEMA}"
echo "Map layers config: ${MAP_LAYERS_CONFIG}"
echo ""

ensure_workspace
ensure_datastore

echo ""
echo "=== Syncing styles and layers from mapLayersConfig.json ==="
sync_layer_from_config "dsp:territory-level-1" "territory-level-1" "territory_level_1" "dsp_territory_level_1" "1.5" "${LAYER_SRS_TERRITORY_LEVEL_1}"
sync_layer_from_config "dsp:territory-level-2" "territory-level-2" "territory_level_2" "dsp_territory_level_2" "1.5" "${LAYER_SRS_TERRITORY_LEVEL_2}"
sync_layer_from_config "dsp:territory-level-3" "territory-level-3" "territory_level_3" "dsp_territory_level_3" "1.5" "${LAYER_SRS_TERRITORY_LEVEL_3}"
sync_layer_from_config "dsp:area-of-interest" "area-of-interest" "area_of_interest" "dsp_area_of_interest" "1" "${LAYER_SRS_AREA_OF_INTEREST}"

echo ""
echo "Done. WMS: ${GEOSERVER_URL}/${WORKSPACE_NAME}/wms"
echo "Example layers: ${WORKSPACE_NAME}:territory-level-2 , ${WORKSPACE_NAME}:area-of-interest"
