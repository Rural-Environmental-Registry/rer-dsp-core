-- Area of interest (e.g., rural property) — aligned with the JPA AreaOfInterest model.
-- Depends on dsp.territory_level_3 (script 01_admin_units.sql).

CREATE TABLE IF NOT EXISTS dsp.area_of_interest (
    id                   VARCHAR(255) PRIMARY KEY,
    registration_date    TIMESTAMP NOT NULL,
    alteration_date      TIMESTAMP,
    territory_level_3_id VARCHAR(64) REFERENCES dsp.territory_level_3 (id),
    area                 NUMERIC,
    boundary_box         geometry(Polygon),
    centroid_coordinates geometry(Point)
);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_territory_level_3_id
    ON dsp.area_of_interest (territory_level_3_id);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_boundary_box
    ON dsp.area_of_interest USING GIST (boundary_box);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_centroid_coordinates
    ON dsp.area_of_interest USING GIST (centroid_coordinates);

COMMENT ON TABLE dsp.area_of_interest IS 'Area of interest linked to territory_level_3';