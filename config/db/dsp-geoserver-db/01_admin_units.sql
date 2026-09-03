-- Administrative units for GeoServers (Exhibition + Download).
-- Tables: dsp.territory_level_1 / _2 / _3 — full MultiPolygon geometry.
-- SRID defined at runtime by the migration job (no fixed typmod).

CREATE SCHEMA IF NOT EXISTS dsp;

CREATE TABLE IF NOT EXISTS dsp.territory_level_1 (
    id       VARCHAR(64) PRIMARY KEY,
    name     VARCHAR(255) NOT NULL,
    geom geometry(MultiPolygon),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS dsp.territory_level_2 (
    id        VARCHAR(64) PRIMARY KEY,
    name      VARCHAR(255) NOT NULL,
    parent_id VARCHAR(64) REFERENCES dsp.territory_level_1 (id),
    geom  geometry(MultiPolygon),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS dsp.territory_level_3 (
    id        VARCHAR(64) PRIMARY KEY,
    name      VARCHAR(255) NOT NULL,
    parent_id VARCHAR(64) REFERENCES dsp.territory_level_2 (id),
    geom  geometry(MultiPolygon),   
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_territory_level_1_geom
    ON dsp.territory_level_1 USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_territory_level_1_updated_at
    ON dsp.territory_level_1 (created_at);

CREATE INDEX IF NOT EXISTS idx_territory_level_2_geom
    ON dsp.territory_level_2 USING GIST (geom);
    
CREATE INDEX IF NOT EXISTS idx_territory_level_2_parent_id
    ON dsp.territory_level_2 (parent_id);

CREATE INDEX IF NOT EXISTS idx_territory_level_2_updated_at
    ON dsp.territory_level_2 (created_at);

    
CREATE INDEX IF NOT EXISTS idx_territory_level_3_geom
    ON dsp.territory_level_3 USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_territory_level_3_parent_id
    ON dsp.territory_level_3 (parent_id);

CREATE INDEX IF NOT EXISTS idx_territory_level_3_updated_at
    ON dsp.territory_level_3 (created_at);

COMMENT ON SCHEMA dsp IS 'RER DSP WMS display schema';
