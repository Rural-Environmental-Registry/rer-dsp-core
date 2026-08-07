-- Administrative units for WMS display (GeoServer Exhibition).
-- Tables: dsp.territory_level_1 / _2 / _3 — full MultiPolygon geometry.
-- SRID defined at runtime by the migration job (no fixed typmod).

CREATE SCHEMA IF NOT EXISTS dsp;

CREATE TABLE IF NOT EXISTS dsp.territory_level_1 (
    id       VARCHAR(64) PRIMARY KEY,
    name     VARCHAR(255) NOT NULL,
    geom geometry(MultiPolygon)
);

CREATE TABLE IF NOT EXISTS dsp.territory_level_2 (
    id        VARCHAR(64) PRIMARY KEY,
    name      VARCHAR(255) NOT NULL,
    parent_id VARCHAR(64) REFERENCES dsp.territory_level_1 (id),
    geom  geometry(MultiPolygon)
);

CREATE TABLE IF NOT EXISTS dsp.territory_level_3 (
    id        VARCHAR(64) PRIMARY KEY,
    name      VARCHAR(255) NOT NULL,
    parent_id VARCHAR(64) REFERENCES dsp.territory_level_2 (id),
    geom  geometry(MultiPolygon)
);

CREATE INDEX IF NOT EXISTS idx_territory_level_1_geom
    ON dsp.territory_level_1 USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_territory_level_2_geom
    ON dsp.territory_level_2 USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_territory_level_2_parent_id
    ON dsp.territory_level_2 (parent_id);

CREATE INDEX IF NOT EXISTS idx_territory_level_3_geom
    ON dsp.territory_level_3 USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_territory_level_3_parent_id
    ON dsp.territory_level_3 (parent_id);

COMMENT ON SCHEMA dsp IS 'RER DSP WMS display schema';
