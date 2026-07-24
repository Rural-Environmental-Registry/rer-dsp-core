-- Unidades administrativas iniciais do DSP (levels 1–3).
-- Nomes alinhados ao contrato de instalação (level1 / level2 / level3).
-- Geometria: MultiPolygon SRID 4326 (WGS84).

CREATE SCHEMA IF NOT EXISTS dsp;

CREATE TABLE IF NOT EXISTS dsp.level1 (
    id         VARCHAR(64) PRIMARY KEY,
    label      VARCHAR(255) NOT NULL,
    geometry   geometry(MultiPolygon, 4326)
);

CREATE TABLE IF NOT EXISTS dsp.level2 (
    id         VARCHAR(64) PRIMARY KEY,
    label      VARCHAR(255) NOT NULL,
    level1_id  VARCHAR(64) NOT NULL REFERENCES dsp.level1 (id),
    geometry   geometry(MultiPolygon, 4326)
);

CREATE TABLE IF NOT EXISTS dsp.level3 (
    id         VARCHAR(64) PRIMARY KEY,
    label      VARCHAR(255) NOT NULL,
    level2_id  VARCHAR(64) NOT NULL REFERENCES dsp.level2 (id),
    geometry   geometry(MultiPolygon, 4326)
);

CREATE INDEX IF NOT EXISTS idx_dsp_level1_geometry
    ON dsp.level1 USING GIST (geometry);

CREATE INDEX IF NOT EXISTS idx_dsp_level2_geometry
    ON dsp.level2 USING GIST (geometry);

CREATE INDEX IF NOT EXISTS idx_dsp_level2_level1_id
    ON dsp.level2 (level1_id);

CREATE INDEX IF NOT EXISTS idx_dsp_level3_geometry
    ON dsp.level3 USING GIST (geometry);

CREATE INDEX IF NOT EXISTS idx_dsp_level3_level2_id
    ON dsp.level3 (level2_id);

COMMENT ON SCHEMA dsp IS 'Schema operacional do RER DSP';
COMMENT ON TABLE dsp.level1 IS 'Unidade administrativa — nível 1 (hierarquia configurável)';
COMMENT ON TABLE dsp.level2 IS 'Unidade administrativa — nível 2 (filha de level1)';
COMMENT ON TABLE dsp.level3 IS 'Unidade administrativa — nível 3 (filha de level2)';
