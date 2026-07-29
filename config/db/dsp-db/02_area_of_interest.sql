-- Area of interest (registration unit) — aligned with the JPA AreaOfInterest model.
-- Depends on dsp.territory_level_3 (script 01_admin_units.sql).
-- KPI measures: area + theme_1..theme_4 (numeric only; full geometry lives in exhibition DB).

CREATE TABLE IF NOT EXISTS dsp.area_of_interest (
    id                   VARCHAR(255) PRIMARY KEY,
    registration_date    TIMESTAMP NOT NULL,
    alteration_date      TIMESTAMP,
    territory_level_3_id VARCHAR(64) REFERENCES dsp.territory_level_3 (id),
    area                 NUMERIC,
    theme_1              NUMERIC,
    theme_2              NUMERIC,
    theme_3              NUMERIC,
    theme_4              NUMERIC,
    boundary_box         geometry(Polygon),
    centroid_coordinates geometry(Point)
);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_territory_level_3_id
    ON dsp.area_of_interest (territory_level_3_id);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_boundary_box
    ON dsp.area_of_interest USING GIST (boundary_box);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_centroid_coordinates
    ON dsp.area_of_interest USING GIST (centroid_coordinates);

COMMENT ON TABLE dsp.area_of_interest IS 'Registration unit / area of interest (KPI measures on dsp-db)';
COMMENT ON COLUMN dsp.area_of_interest.theme_1 IS 'Optional theme slot THEME_1 area (installation label in config)';
COMMENT ON COLUMN dsp.area_of_interest.theme_2 IS 'Optional theme slot THEME_2 area';
COMMENT ON COLUMN dsp.area_of_interest.theme_3 IS 'Optional theme slot THEME_3 area';
COMMENT ON COLUMN dsp.area_of_interest.theme_4 IS 'Optional theme slot THEME_4 area';
