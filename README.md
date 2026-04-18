# Datos Viales 2025 — Dataset & Pipeline

Scrape completo del portal **Datos Viales 2025** (SICT / IMT) para los tres universos
de información que ofrece:

| Universo | Alcance | Contenido |
|---|---|---|
| U1 | 32 estados | Red Nacional de Carreteras Pavimentadas (segmentos, estaciones, TDPA 2010-2024) |
| U2 | 32 estados | Estaciones Permanentes de Conteo = Plazas de Cobro (movimientos, TDPA 2009-2024, distribución mensual) |
| U3 | Solo Campeche | Mapas Temáticos (PDFs de NS/RVV/VKABC + resúmenes JSON) |

## Contenido del ZIP

```
datos_viales_mexico/
├── README.md                        Este archivo
├── DATA_DICTIONARY.md               Diccionario completo
├── sql/
│   ├── schema.sql                   DDL Postgres idempotente (PostGIS)
│   └── load.sql                     Plantilla de \COPY para todos los CSVs
├── csv/                             Un archivo CSV por tabla
│   ├── estados.csv
│   ├── u1_carreteras.csv
│   ├── u1_segmentos.csv             (incluye columna wkt_linestring)
│   ├── u1_estaciones.csv
│   ├── u1_estaciones_tdpa.csv       TDPA Histórico formato largo
│   ├── u1_estaciones_variacion.csv
│   ├── u1_casetas.csv
│   ├── u2_plazas.csv
│   ├── u2_movimientos.csv
│   ├── u2_movimientos_tdpa.csv      TDPA Histórico formato largo
│   ├── u2_movimientos_mensual.csv
│   ├── u2_movimientos_variacion_semanal.csv
│   ├── u1_u2_map.csv                Puente U1 ↔ U2
│   ├── u3_resumen.csv               (sólo Campeche)
│   └── u3_pdf_mapa.csv              (sólo Campeche)
├── json/
│   ├── raw/<estado>.json            Respuesta cruda por estado (debug / reproducibilidad)
│   └── u3/
│       ├── resumen_niveles_servicio.json
│       ├── resumen_vehiculos_km.json
│       └── resumen_rangos_volumen.json
└── u3/pdfs/                         Sólo Campeche
    ├── campeche_mapa_niveles_servicio.pdf
    ├── campeche_mapa_vehiculos_km.pdf
    └── campeche_mapa_rangos_volumen.pdf
```

## Totales extraídos

- 32 estados.
- 1,559 carreteras únicas.
- 4,791 segmentos de DV con polilínea WKT.
- 13,826 estaciones U1.
- 94,672 registros TDPA Histórico U1 (formato largo).
- 27,132 filas de variación semanal U1.
- 401 plazas de cobro U2.
- 1,081 movimientos U2.
- 15,579 registros TDPA Histórico U2 (2009-2024).
- 12,841 filas de distribución mensual U2.
- 397/401 plazas vinculadas a una carretera U1 via `u1_u2_map`.
- 3 PDFs + 3 resúmenes JSON para Campeche (U3).

## Carga rápida en Postgres

```bash
# 1. Crear base + extensión PostGIS
createdb datos_viales
psql -d datos_viales -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# 2. Crear esquema
psql -d datos_viales -f sql/schema.sql

# 3. Cargar CSVs
psql -d datos_viales -f sql/load.sql

# 4. Poblar geometrías (PostGIS)
psql -d datos_viales <<SQL
SET search_path TO datos_viales, public;
UPDATE u1_segmentos    SET geom = ST_GeomFromText(wkt_linestring, 4326) WHERE wkt_linestring IS NOT NULL;
UPDATE u1_estaciones   SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326) WHERE lon IS NOT NULL AND lat IS NOT NULL;
UPDATE u1_casetas      SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326) WHERE lon IS NOT NULL AND lat IS NOT NULL;
UPDATE u2_plazas       SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326) WHERE lon IS NOT NULL AND lat IS NOT NULL;
UPDATE u2_movimientos  SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326) WHERE lon IS NOT NULL AND lat IS NOT NULL;
VACUUM ANALYZE;
SQL
```

## Diseño MCP recomendado

Un servidor MCP sobre esta base debería exponer al menos las siguientes tools:

| Tool | Parámetros | Uso |
|---|---|---|
| `list_states` | — | Lista estados con totales |
| `list_roads` | state_slug | Carreteras del estado |
| `list_stations_by_road` | carretera_id | Estaciones con TDPA 2024 |
| `get_station_tdpa_history` | station_id | Serie anual TDPA 2010-2024 |
| `get_station_detail` | station_id | Composición + variación semanal |
| `list_plazas` | state_slug | Plazas de cobro + movimientos |
| `get_movement_tdpa_history` | movement_id | Serie 2009-2024 |
| `get_movement_monthly` | movement_id | Distribución mensual |
| `top_stations_by_tdpa` | state_slug, year, limit | Ranking |
| `road_growth_yoy` | carretera_id, year_from, year_to | CAGR y crecimiento |
| `nearest_points` | lat, lon, radius_km | Búsqueda espacial (PostGIS) |
| `thematic_summary` | state_slug, tipo | (Solo Campeche) resumen NS/VK/RVV |

## Relación U1 ↔ U2

La relación se materializa en `u1_u2_map`. Para cada plaza de cobro (`plaza_id`)
se identifica la carretera U1 correspondiente usando el campo `tematico.Carretera`
que devuelve el endpoint `/getById` del movimiento (coincide con un
`u1_carreteras.carretera` en ese estado). Cuando no hay match exacto se cae a
heurísticas de normalización y substring.

**Cobertura actual:** 397 de 401 plazas mapeadas. Los 4 casos sin match son plazas
cuyo tramo padre está en otro estado o tienen nombres muy específicos (ej. *Arco
Norte Cd. México* en Hidalgo).

## Reproducibilidad

El scraper está embebido como función JavaScript en `notes/scraper_snippet.js`
(opcional). Ejecutar desde la consola del sitio autenticado, o replicar con
cualquier cliente HTTP que conserve la cookie de sesión.

## Licencia / crédito de datos

Los datos son propiedad de **SCT / SICT / IMT** (México). Esta compilación se
distribuye sólo con fines de análisis y cita de la fuente original.
