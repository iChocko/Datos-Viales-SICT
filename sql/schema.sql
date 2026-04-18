-- ============================================================================
-- Datos Viales 2025 — Esquema PostgreSQL (32 estados)
-- Fuente: https://datosviales2020.routedev.mx  (SICT / IMT)
-- Universos extraidos:
--   U1 : Volúmenes de Tránsito en la Red Nacional de Carreteras Pavimentadas
--   U2 : Volúmenes de Tránsito Registrados en las Estaciones Permanentes (Plazas de Cobro)
--   U3 : Mapas Temáticos (SÓLO Campeche: 3 PDFs + 3 resúmenes JSON)
-- Convenciones: snake_case, claves naturales de origen (Mongo _id) conservadas como
-- llaves primarias de texto; state_slug = slug de URL ('campeche', 'nuevo leon'...).
-- Todas las tablas tienen FKs con ON UPDATE CASCADE y ON DELETE RESTRICT salvo
-- las tablas hijas de detalle (TDPA, variación, mensual) que usan ON DELETE CASCADE.
-- Requiere PostgreSQL 14+ y extensión PostGIS (opcional pero recomendada).
-- ============================================================================

-- --------------------------------------------------------------
-- Preparación
-- --------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA IF NOT EXISTS datos_viales;
SET search_path TO datos_viales, public;

-- Idempotencia: dropear vistas dependientes si existen
DROP VIEW IF EXISTS v_u1_tdpa_wide CASCADE;
DROP VIEW IF EXISTS v_u2_tdpa_wide CASCADE;
DROP VIEW IF EXISTS v_u1_u2_combined CASCADE;

-- --------------------------------------------------------------
-- Catálogo: estados
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS estados (
    state_slug        text        PRIMARY KEY,                  -- 'campeche'
    state_name        text        NOT NULL,                     -- 'CAMPECHE'
    state_code        smallint    NOT NULL UNIQUE               -- código INEGI 1..32
                       CHECK (state_code BETWEEN 1 AND 32),
    source_id         text,                                     -- id remoto del snapshot
    retrieved_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE  estados IS 'Catálogo de entidades federativas';
COMMENT ON COLUMN estados.state_slug IS 'Slug URL usado por el portal';
COMMENT ON COLUMN estados.state_code IS 'Código INEGI 1..32';

-- =============================================================
-- UNIVERSO 1 — Red Nacional de Carreteras Pavimentadas
-- =============================================================

CREATE TABLE IF NOT EXISTS u1_carreteras (
    carretera_id      bigint      PRIMARY KEY,
    state_slug        text        NOT NULL,
    carretera         text        NOT NULL,
    clave_carretera   text,
    ruta              text,
    station_count     integer     DEFAULT 0,
    CONSTRAINT fk_u1c_state FOREIGN KEY (state_slug)
        REFERENCES estados(state_slug) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_u1c_state_carr UNIQUE (state_slug, carretera)
);
CREATE INDEX IF NOT EXISTS ix_u1c_state ON u1_carreteras (state_slug);
CREATE INDEX IF NOT EXISTS ix_u1c_ruta  ON u1_carreteras (ruta);
COMMENT ON TABLE  u1_carreteras IS 'U1: Carreteras únicas por estado';

CREATE TABLE IF NOT EXISTS u1_segmentos (
    segment_mongo_id  text        PRIMARY KEY,
    state_slug        text        NOT NULL,
    carretera_id      bigint,
    segment_seq       integer,
    segment_id_2025   text,
    segment_id_2024   text,
    clave_carretera   text,
    carretera         text        NOT NULL,
    ruta              text,
    estado            text,
    edo               smallint,
    red_ok            text        CHECK (red_ok IN ('Federal','Estatal')),
    operacion         text        CHECK (operacion IN ('Libre','Cuota')),
    juris             smallint,
    tipo_terr         text,
    tipo_dv           text,
    id_red            smallint,
    prog              integer,
    rango_vol         smallint,
    ruta_de           text,
    ruta_a            text,
    de_km             numeric(10,3),
    a_km              numeric(10,3),
    dist              numeric(10,3),
    tdpa_2024         integer,
    comp_a            numeric(8,4), comp_b    numeric(8,4),
    comp_c2           numeric(8,4), comp_c3   numeric(8,4),
    comp_t3s2         numeric(8,4), comp_t3s3 numeric(8,4), comp_t3s2r4 numeric(8,4),
    comp_m            numeric(8,4), comp_otros numeric(8,4),
    agg_aa            numeric(8,4), agg_bb    numeric(8,4), agg_cc   numeric(8,4),
    vk_aa             numeric(18,4), vk_bb numeric(18,4), vk_cc numeric(18,4), vk_total numeric(18,4),
    fs_a              text, fs_b text, fs_c text, fs_d text, fs_e text,
    ns                text        CHECK (ns IN ('A','B','C','D','E','F') OR ns IS NULL),
    k_ok              numeric(8,5),
    d_ok              numeric(8,5),
    wkt_linestring    text,
    geom              geometry(LINESTRING, 4326),
    CONSTRAINT fk_u1s_state FOREIGN KEY (state_slug)
        REFERENCES estados(state_slug) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_u1s_carr  FOREIGN KEY (carretera_id)
        REFERENCES u1_carreteras(carretera_id) ON UPDATE CASCADE ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS ix_u1s_state     ON u1_segmentos (state_slug);
CREATE INDEX IF NOT EXISTS ix_u1s_carr      ON u1_segmentos (carretera_id);
CREATE INDEX IF NOT EXISTS ix_u1s_red_op    ON u1_segmentos (red_ok, operacion);
CREATE INDEX IF NOT EXISTS ix_u1s_ns        ON u1_segmentos (ns);
CREATE INDEX IF NOT EXISTS ix_u1s_geom      ON u1_segmentos USING GIST (geom);

CREATE TABLE IF NOT EXISTS u1_estaciones (
    station_id        text        PRIMARY KEY,
    state_slug        text        NOT NULL,
    carretera_id      bigint,
    carretera         text        NOT NULL,
    clave_carretera   text,
    ruta              text,
    punto_generador   text,
    tipo              smallint,
    sc                smallint,
    km                numeric(10,3),
    lat               double precision,
    lon               double precision,
    tdpa_2024         integer,
    pct_m numeric(6,3), pct_a numeric(6,3), pct_b numeric(6,3),
    pct_c2 numeric(6,3), pct_c3 numeric(6,3),
    pct_t3s2 numeric(6,3), pct_t3s3 numeric(6,3), pct_t3s2r4 numeric(6,3),
    pct_otros numeric(6,3),
    pct_aa numeric(6,3), pct_bb numeric(6,3), pct_cc numeric(6,3),
    d_val numeric(8,5),
    k_prima numeric(8,5),
    rubro text,
    geom geometry(POINT, 4326),
    CONSTRAINT fk_u1e_state FOREIGN KEY (state_slug)
        REFERENCES estados(state_slug) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_u1e_carr  FOREIGN KEY (carretera_id)
        REFERENCES u1_carreteras(carretera_id) ON UPDATE CASCADE ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS ix_u1e_state ON u1_estaciones (state_slug);
CREATE INDEX IF NOT EXISTS ix_u1e_carr  ON u1_estaciones (carretera_id);
CREATE INDEX IF NOT EXISTS ix_u1e_tdpa  ON u1_estaciones (tdpa_2024 DESC);
CREATE INDEX IF NOT EXISTS ix_u1e_geom  ON u1_estaciones USING GIST (geom);

CREATE TABLE IF NOT EXISTS u1_estaciones_tdpa (
    station_id  text      NOT NULL,
    year        smallint  NOT NULL CHECK (year BETWEEN 2000 AND 2100),
    tdpa        integer,
    PRIMARY KEY (station_id, year),
    CONSTRAINT fk_u1et_station FOREIGN KEY (station_id)
        REFERENCES u1_estaciones(station_id) ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ix_u1et_year ON u1_estaciones_tdpa (year);

CREATE TABLE IF NOT EXISTS u1_estaciones_variacion (
    station_id  text      NOT NULL,
    dia_num     smallint  NOT NULL CHECK (dia_num BETWEEN 1 AND 7),
    dia_nombre  text,
    valor       numeric(8,3),
    porc        numeric(8,4),
    PRIMARY KEY (station_id, dia_num),
    CONSTRAINT fk_u1ev_station FOREIGN KEY (station_id)
        REFERENCES u1_estaciones(station_id) ON UPDATE CASCADE ON DELETE CASCADE
);

-- Casetas como pines referenciales dentro del universo U1
CREATE TABLE IF NOT EXISTS u1_casetas (
    caseta_mongo_id   text        PRIMARY KEY,
    state_slug        text        NOT NULL,
    caseta_name       text,
    cve               text,
    carretera         text,
    ruta              text,
    movimiento        text,
    tdpa_2024         integer,
    lat               double precision,
    lon               double precision,
    rubro             text,
    geom              geometry(POINT, 4326),
    CONSTRAINT fk_u1k_state FOREIGN KEY (state_slug)
        REFERENCES estados(state_slug) ON UPDATE CASCADE ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS ix_u1k_state ON u1_casetas (state_slug);
CREATE INDEX IF NOT EXISTS ix_u1k_geom  ON u1_casetas USING GIST (geom);

-- =============================================================
-- UNIVERSO 2 — Estaciones Permanentes de Conteo (Plazas de Cobro)
-- =============================================================

CREATE TABLE IF NOT EXISTS u2_plazas (
    plaza_id          text        PRIMARY KEY,
    state_slug        text        NOT NULL,
    caseta            text        NOT NULL,
    cve               text,
    carretera         text,
    ruta              text,
    movimiento_principal text,
    tdpa_2024_plaza   integer,
    lat               double precision,
    lon               double precision,
    rubro             text,
    geom              geometry(POINT, 4326),
    CONSTRAINT fk_u2p_state FOREIGN KEY (state_slug)
        REFERENCES estados(state_slug) ON UPDATE CASCADE ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS ix_u2p_state ON u2_plazas (state_slug);
CREATE INDEX IF NOT EXISTS ix_u2p_ruta  ON u2_plazas (ruta);
CREATE INDEX IF NOT EXISTS ix_u2p_geom  ON u2_plazas USING GIST (geom);

CREATE TABLE IF NOT EXISTS u2_movimientos (
    movement_id       text        PRIMARY KEY,
    plaza_id          text        NOT NULL,
    caseta            text,
    cve               text,
    carretera         text,
    ruta              text,
    movimiento        text,
    km                numeric(10,3),
    sen               smallint,
    lat               double precision,
    lon               double precision,
    x_pg              double precision,
    y_pg              double precision,
    zona_geo          text,
    estado            text,
    vta_2024          bigint,
    pct_a numeric(6,3), pct_ar numeric(6,3), pct_b numeric(6,3),
    pct_c2 numeric(6,3), pct_c3 numeric(6,3), pct_c4 numeric(6,3),
    pct_c5 numeric(6,3), pct_c6 numeric(6,3), pct_c7 numeric(6,3),
    pct_c8 numeric(6,3), pct_c9 numeric(6,3),
    pct_vnc numeric(6,3), pct_m numeric(6,3),
    rubro text,
    geom geometry(POINT, 4326),
    CONSTRAINT fk_u2m_plaza FOREIGN KEY (plaza_id)
        REFERENCES u2_plazas(plaza_id) ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ix_u2m_plaza ON u2_movimientos (plaza_id);
CREATE INDEX IF NOT EXISTS ix_u2m_geom  ON u2_movimientos USING GIST (geom);

CREATE TABLE IF NOT EXISTS u2_movimientos_tdpa (
    movement_id text      NOT NULL,
    year        smallint  NOT NULL CHECK (year BETWEEN 2000 AND 2100),
    tdpa        integer,
    PRIMARY KEY (movement_id, year),
    CONSTRAINT fk_u2mt_mov FOREIGN KEY (movement_id)
        REFERENCES u2_movimientos(movement_id) ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ix_u2mt_year ON u2_movimientos_tdpa (year);

CREATE TABLE IF NOT EXISTS u2_movimientos_mensual (
    movement_id text      NOT NULL,
    mes_num     smallint  NOT NULL CHECK (mes_num BETWEEN 1 AND 12),
    mes_nombre  text,
    porcentaje  numeric(6,3),
    PRIMARY KEY (movement_id, mes_num),
    CONSTRAINT fk_u2mm_mov FOREIGN KEY (movement_id)
        REFERENCES u2_movimientos(movement_id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS u2_movimientos_variacion_semanal (
    movement_id text    NOT NULL,
    periodo     text    NOT NULL,
    valor       numeric(8,3),
    porc        numeric(8,4),
    PRIMARY KEY (movement_id, periodo),
    CONSTRAINT fk_u2mv_mov FOREIGN KEY (movement_id)
        REFERENCES u2_movimientos(movement_id) ON UPDATE CASCADE ON DELETE CASCADE
);

-- =============================================================
-- Puente U1 ↔ U2  (relaciona plazas de cobro con carretera del U1)
-- =============================================================
CREATE TABLE IF NOT EXISTS u1_u2_map (
    plaza_id          text        PRIMARY KEY,
    state_slug        text        NOT NULL,
    u1_carretera_id   bigint,
    u2_caseta_name    text,
    u2_carretera_raw  text,
    ruta              text,
    match_method      text        CHECK (match_method IN
                        ('tematico_parent','name_match','fuzzy_substring','unmatched')),
    CONSTRAINT fk_map_plaza FOREIGN KEY (plaza_id)
        REFERENCES u2_plazas(plaza_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_map_state FOREIGN KEY (state_slug)
        REFERENCES estados(state_slug) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_map_u1c   FOREIGN KEY (u1_carretera_id)
        REFERENCES u1_carreteras(carretera_id) ON UPDATE CASCADE ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS ix_map_state ON u1_u2_map (state_slug);
CREATE INDEX IF NOT EXISTS ix_map_u1c   ON u1_u2_map (u1_carretera_id);

-- =============================================================
-- UNIVERSO 3 — Mapas Temáticos (Campeche)
-- =============================================================
CREATE TABLE IF NOT EXISTS u3_resumen (
    state_slug  text      NOT NULL,
    tipo        text      NOT NULL CHECK (tipo IN ('NS','RVV','VKABC')),
    red         text      NOT NULL CHECK (red IN ('redFL','redFC','redEL','redEC')),
    categoria   text      NOT NULL,
    valor       numeric(18,4),
    PRIMARY KEY (state_slug, tipo, red, categoria),
    CONSTRAINT fk_u3r_state FOREIGN KEY (state_slug)
        REFERENCES estados(state_slug) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS u3_pdf_mapa (
    state_slug  text      NOT NULL,
    tipo        text      NOT NULL CHECK (tipo IN ('NS','RVV','VKABC')),
    pdf_url     text      NOT NULL,
    pdf_path    text,                 -- ruta relativa al zip, por ejemplo 'u3/pdfs/xxx.pdf'
    fetched_at  timestamptz DEFAULT now(),
    PRIMARY KEY (state_slug, tipo),
    CONSTRAINT fk_u3p_state FOREIGN KEY (state_slug)
        REFERENCES estados(state_slug) ON UPDATE CASCADE ON DELETE CASCADE
);

-- =============================================================
-- Vistas útiles
-- =============================================================
CREATE VIEW v_u1_tdpa_wide AS
SELECT e.station_id, e.state_slug, e.carretera, e.punto_generador, e.km, e.lat, e.lon,
       MAX(CASE WHEN t.year=2010 THEN t.tdpa END) AS tdpa_2010,
       MAX(CASE WHEN t.year=2011 THEN t.tdpa END) AS tdpa_2011,
       MAX(CASE WHEN t.year=2012 THEN t.tdpa END) AS tdpa_2012,
       MAX(CASE WHEN t.year=2013 THEN t.tdpa END) AS tdpa_2013,
       MAX(CASE WHEN t.year=2014 THEN t.tdpa END) AS tdpa_2014,
       MAX(CASE WHEN t.year=2015 THEN t.tdpa END) AS tdpa_2015,
       MAX(CASE WHEN t.year=2016 THEN t.tdpa END) AS tdpa_2016,
       MAX(CASE WHEN t.year=2017 THEN t.tdpa END) AS tdpa_2017,
       MAX(CASE WHEN t.year=2018 THEN t.tdpa END) AS tdpa_2018,
       MAX(CASE WHEN t.year=2019 THEN t.tdpa END) AS tdpa_2019,
       MAX(CASE WHEN t.year=2020 THEN t.tdpa END) AS tdpa_2020,
       MAX(CASE WHEN t.year=2021 THEN t.tdpa END) AS tdpa_2021,
       MAX(CASE WHEN t.year=2022 THEN t.tdpa END) AS tdpa_2022,
       MAX(CASE WHEN t.year=2023 THEN t.tdpa END) AS tdpa_2023,
       MAX(CASE WHEN t.year=2024 THEN t.tdpa END) AS tdpa_2024
FROM u1_estaciones e
LEFT JOIN u1_estaciones_tdpa t USING (station_id)
GROUP BY e.station_id, e.state_slug, e.carretera, e.punto_generador, e.km, e.lat, e.lon;

CREATE VIEW v_u2_tdpa_wide AS
SELECT m.movement_id, p.state_slug, m.caseta, m.movimiento, m.carretera, m.ruta, m.km, m.lat, m.lon,
       MAX(CASE WHEN t.year=2009 THEN t.tdpa END) AS tdpa_2009,
       MAX(CASE WHEN t.year=2010 THEN t.tdpa END) AS tdpa_2010,
       MAX(CASE WHEN t.year=2011 THEN t.tdpa END) AS tdpa_2011,
       MAX(CASE WHEN t.year=2012 THEN t.tdpa END) AS tdpa_2012,
       MAX(CASE WHEN t.year=2013 THEN t.tdpa END) AS tdpa_2013,
       MAX(CASE WHEN t.year=2014 THEN t.tdpa END) AS tdpa_2014,
       MAX(CASE WHEN t.year=2015 THEN t.tdpa END) AS tdpa_2015,
       MAX(CASE WHEN t.year=2016 THEN t.tdpa END) AS tdpa_2016,
       MAX(CASE WHEN t.year=2017 THEN t.tdpa END) AS tdpa_2017,
       MAX(CASE WHEN t.year=2018 THEN t.tdpa END) AS tdpa_2018,
       MAX(CASE WHEN t.year=2019 THEN t.tdpa END) AS tdpa_2019,
       MAX(CASE WHEN t.year=2020 THEN t.tdpa END) AS tdpa_2020,
       MAX(CASE WHEN t.year=2021 THEN t.tdpa END) AS tdpa_2021,
       MAX(CASE WHEN t.year=2022 THEN t.tdpa END) AS tdpa_2022,
       MAX(CASE WHEN t.year=2023 THEN t.tdpa END) AS tdpa_2023,
       MAX(CASE WHEN t.year=2024 THEN t.tdpa END) AS tdpa_2024
FROM u2_movimientos m
JOIN u2_plazas p USING (plaza_id)
LEFT JOIN u2_movimientos_tdpa t USING (movement_id)
GROUP BY m.movement_id, p.state_slug, m.caseta, m.movimiento, m.carretera, m.ruta, m.km, m.lat, m.lon;

-- Vista combinada: une carretera U1 con sus plazas U2 asociadas
CREATE VIEW v_u1_u2_combined AS
SELECT c.state_slug, c.carretera_id, c.carretera AS u1_carretera, c.ruta,
       p.plaza_id, p.caseta, p.tdpa_2024_plaza
FROM u1_carreteras c
LEFT JOIN u1_u2_map map ON map.u1_carretera_id = c.carretera_id
LEFT JOIN u2_plazas p ON p.plaza_id = map.plaza_id;

-- =============================================================
-- Carga desde CSV (ejemplos, ejecutar desde psql):
--   \COPY estados FROM 'csv/estados.csv' CSV HEADER;
--   \COPY u1_carreteras FROM 'csv/u1_carreteras.csv' CSV HEADER;
--   ... etc.
-- Tras cargar u1_segmentos y u1_estaciones, construir geometrías:
--   UPDATE u1_segmentos SET geom = ST_GeomFromText(wkt_linestring, 4326);
--   UPDATE u1_estaciones  SET geom = ST_SetSRID(ST_MakePoint(lon, lat), 4326) WHERE lon IS NOT NULL;
--   UPDATE u1_casetas     SET geom = ST_SetSRID(ST_MakePoint(lon, lat), 4326) WHERE lon IS NOT NULL;
--   UPDATE u2_plazas      SET geom = ST_SetSRID(ST_MakePoint(lon, lat), 4326) WHERE lon IS NOT NULL;
--   UPDATE u2_movimientos SET geom = ST_SetSRID(ST_MakePoint(lon, lat), 4326) WHERE lon IS NOT NULL;
-- =============================================================
