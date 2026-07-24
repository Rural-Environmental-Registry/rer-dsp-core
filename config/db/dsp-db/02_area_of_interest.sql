-- Área de interesse (ex.: propriedade rural) — alinhado ao model JPA AreaOfInterest.
-- Depende de dsp.territory_level_3 (script 01_admin_units.sql).
-- Geometria: SRID 4674 (SIRGAS 2000), igual ao job CAR.

CREATE TABLE IF NOT EXISTS dsp.area_of_interest (
    id                   VARCHAR(255) PRIMARY KEY,
    registration_date    TIMESTAMP NOT NULL,
    alteration_date      TIMESTAMP,
    territory_level_3_id VARCHAR(64) REFERENCES dsp.territory_level_3 (id),
    area                 NUMERIC,
    geometry             geometry(MultiPolygon, 4674)
);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_territory_level_3_id
    ON dsp.area_of_interest (territory_level_3_id);

CREATE INDEX IF NOT EXISTS idx_area_of_interest_geometry
    ON dsp.area_of_interest USING GIST (geometry);

COMMENT ON TABLE dsp.area_of_interest IS 'Área de interesse vinculada ao territory_level_3';
