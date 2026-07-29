-- Operational administrative units (API / KPIs / search).
-- Tables: dsp.territory_level_1 / _2 / _3
-- Geo on dsp-db: boundary_box + centroid_coordinates (no full polygon).
-- Full polygon lives in dsp-geoserver-exhibition-db.

CREATE SCHEMA IF NOT EXISTS dsp;

CREATE TABLE IF NOT EXISTS dsp.territory_level_1 (
    id                   VARCHAR(64) PRIMARY KEY,
    name                 VARCHAR(255) NOT NULL,
    boundary_box         geometry(Polygon),
    centroid_coordinates geometry(Point)
);

CREATE TABLE IF NOT EXISTS dsp.territory_level_2 (
    id                   VARCHAR(64) PRIMARY KEY,
    name                 VARCHAR(255) NOT NULL,
    parent_id            VARCHAR(64) REFERENCES dsp.territory_level_1 (id),
    boundary_box         geometry(Polygon),
    centroid_coordinates geometry(Point)
);

CREATE TABLE IF NOT EXISTS dsp.territory_level_3 (
    id                   VARCHAR(64) PRIMARY KEY,
    name                 VARCHAR(255) NOT NULL,
    parent_id            VARCHAR(64) REFERENCES dsp.territory_level_2 (id),
    boundary_box         geometry(Polygon),
    centroid_coordinates geometry(Point)
);

CREATE INDEX IF NOT EXISTS idx_territory_level_1_boundary_box
    ON dsp.territory_level_1 USING GIST (boundary_box);
CREATE INDEX IF NOT EXISTS idx_territory_level_1_centroid_coordinates
    ON dsp.territory_level_1 USING GIST (centroid_coordinates);

CREATE INDEX IF NOT EXISTS idx_territory_level_2_boundary_box
    ON dsp.territory_level_2 USING GIST (boundary_box);
CREATE INDEX IF NOT EXISTS idx_territory_level_2_centroid_coordinates
    ON dsp.territory_level_2 USING GIST (centroid_coordinates);
CREATE INDEX IF NOT EXISTS idx_territory_level_2_parent_id
    ON dsp.territory_level_2 (parent_id);

CREATE INDEX IF NOT EXISTS idx_territory_level_3_boundary_box
    ON dsp.territory_level_3 USING GIST (boundary_box);
CREATE INDEX IF NOT EXISTS idx_territory_level_3_centroid_coordinates
    ON dsp.territory_level_3 USING GIST (centroid_coordinates);
CREATE INDEX IF NOT EXISTS idx_territory_level_3_parent_id
    ON dsp.territory_level_3 (parent_id);

COMMENT ON SCHEMA dsp IS 'DSP RER operational schema';
COMMENT ON TABLE dsp.territory_level_1 IS 'Level 1 (e.g. region)';
COMMENT ON TABLE dsp.territory_level_2 IS 'Level 2 (parent = level 1)';
COMMENT ON TABLE dsp.territory_level_3 IS 'Level 3 (parent = level 2)';
