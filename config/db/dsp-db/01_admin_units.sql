-- Unidades administrativas do DSP (contrato alinhado ao backend + CAR).
-- Tabelas: dsp.territory_level_1 / _2 / _3
-- Colunas: id, name, geometry; filhos usam parent_id.
-- Geometria: MultiPolygon SRID 4674 (SIRGAS 2000) — mesmo SRID do job CAR.

CREATE SCHEMA IF NOT EXISTS dsp;

CREATE TABLE IF NOT EXISTS dsp.territory_level_1 (
    id       VARCHAR(64) PRIMARY KEY,
    name     VARCHAR(255) NOT NULL,
    geometry geometry(MultiPolygon, 4674)
);

CREATE TABLE IF NOT EXISTS dsp.territory_level_2 (
    id        VARCHAR(64) PRIMARY KEY,
    name      VARCHAR(255) NOT NULL,
    parent_id VARCHAR(64) REFERENCES dsp.territory_level_1 (id),
    geometry  geometry(MultiPolygon, 4674)
);

CREATE TABLE IF NOT EXISTS dsp.territory_level_3 (
    id        VARCHAR(64) PRIMARY KEY,
    name      VARCHAR(255) NOT NULL,
    parent_id VARCHAR(64) REFERENCES dsp.territory_level_2 (id),
    geometry  geometry(MultiPolygon, 4674)
);

CREATE INDEX IF NOT EXISTS idx_territory_level_1_geometry
    ON dsp.territory_level_1 USING GIST (geometry);

CREATE INDEX IF NOT EXISTS idx_territory_level_2_geometry
    ON dsp.territory_level_2 USING GIST (geometry);

CREATE INDEX IF NOT EXISTS idx_territory_level_2_parent_id
    ON dsp.territory_level_2 (parent_id);

CREATE INDEX IF NOT EXISTS idx_territory_level_3_geometry
    ON dsp.territory_level_3 USING GIST (geometry);

CREATE INDEX IF NOT EXISTS idx_territory_level_3_parent_id
    ON dsp.territory_level_3 (parent_id);

COMMENT ON SCHEMA dsp IS 'Schema operacional do RER DSP';
COMMENT ON TABLE dsp.territory_level_1 IS 'Unidade administrativa — nível 1';
COMMENT ON TABLE dsp.territory_level_2 IS 'Unidade administrativa — nível 2 (parent = level 1)';
COMMENT ON TABLE dsp.territory_level_3 IS 'Unidade administrativa — nível 3 (parent = level 2)';
