-- Area of interest for GeoServers (Exhibition + Download).
-- Depends on dsp.territory_level_3 (script 01_admin_units.sql).
-- SRID defined at runtime by the migration job (no fixed typmod).

CREATE TABLE IF NOT EXISTS dsp.area_of_interest (
    id                   VARCHAR(255) PRIMARY KEY,
    registration_date    TIMESTAMP NOT NULL,
    alteration_date      TIMESTAMP,
    territory_level_3_id VARCHAR(64) REFERENCES dsp.territory_level_3 (id),
    area                 NUMERIC,
    geometry             geometry(MultiPolygon)
);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_territory_level_3_id
    ON dsp.area_of_interest (territory_level_3_id);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_geometry
    ON dsp.area_of_interest USING GIST (geometry);

COMMENT ON TABLE dsp.area_of_interest IS 'Area of interest for WMS (GeoServer)';
