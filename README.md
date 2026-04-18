# Datos Viales México 2025 — Dataset Geoestadístico

Dataset completo y reproducible extraído del portal **Datos Viales 2025** de la
Secretaría de Infraestructura, Comunicaciones y Transportes (SICT) y el
Instituto Mexicano del Transporte (IMT). Empaquetado en múltiples formatos
(CSV, JSON, SQL/PostGIS, GeoJSON, GeoPackage) para consumo inmediato en
QGIS, ArcGIS, Kepler.gl, Tableau, PowerBI, Google Earth, o cualquier
herramienta de análisis y georreferenciación.

> **No oficial.** Esta compilación es un esfuerzo de apertura de datos
> públicos. La titularidad de los datos originales corresponde
> a SICT/IMT.

---

## Fuente de información

| Campo | Valor |
|---|---|
| **Portal de origen** | https://datosviales2020.routedev.mx/ |
| **Institución responsable de los datos** | Secretaría de Infraestructura, Comunicaciones y Transportes (SICT) — Instituto Mexicano del Transporte (IMT) |
| **Año de publicación del portal** | 2025 |
| **Cobertura temporal de tránsito (TDPA)** | U1: 2010–2024 · U2: 2009–2024 |
| **Cobertura geográfica** | U1 y U2: 32 entidades federativas · U3: Campeche |
| **Fecha de extracción** | Abril 2026 |
| **Sistema de referencia espacial** | WGS84 (EPSG:4326) |

---

## Universos de información

| Universo | Alcance | Contenido |
|---|---|---|
| **U1** | 32 estados | Red Nacional de Carreteras Pavimentadas: segmentos con polilínea, estaciones de conteo con TDPA anual, casetas, niveles de servicio, composición vehicular, vehículos-kilómetro. |
| **U2** | 32 estados | Plazas de Cobro (Estaciones Permanentes de Conteo): plazas, movimientos, TDPA anual 2009–2024, distribución mensual, variación semanal, composición por clase vehicular. |
| **U3** | Solo Campeche | Mapas Temáticos (PDFs + resúmenes JSON): Niveles de Servicio, Rangos de Volumen Vehicular y Vehículos-Kilómetro por Tipo (VKABC). |

---

## Totales del dataset

| Indicador | Registros |
|---|---:|
| Estados | 32 |
| Carreteras U1 únicas | 1,559 |
| Segmentos U1 (con polilínea WKT) | 4,791 |
| Estaciones de conteo U1 | 13,826 |
| Registros TDPA U1 (formato largo 2010–2024) | 94,672 |
| Registros variación semanal U1 | 27,132 |
| Plazas de cobro U2 | 401 filas (333 plazas únicas) |
| Movimientos U2 | 1,081 |
| Registros TDPA U2 (formato largo 2009–2024) | 15,579 |
| Registros distribución mensual U2 | 12,841 |
| Plazas vinculadas a carretera U1 (`u1_u2_map`) | 332 / 333 |
| Mapas temáticos Campeche (PDF + JSON) | 3 + 3 |

---

## Estructura del repositorio

```
datos_viales_mexico/
├── README.md                        Este archivo
├── DATA_DICTIONARY.md               Diccionario de datos completo
├── LICENSE                          Licencia CC BY 4.0
│
├── csv/                             Un archivo CSV por tabla (formato plano)
│   ├── estados.csv
│   ├── u1_carreteras.csv
│   ├── u1_segmentos.csv             incluye wkt_linestring
│   ├── u1_estaciones.csv
│   ├── u1_estaciones_tdpa.csv       TDPA formato largo
│   ├── u1_estaciones_variacion.csv
│   ├── u1_casetas.csv
│   ├── u2_plazas.csv
│   ├── u2_movimientos.csv
│   ├── u2_movimientos_tdpa.csv
│   ├── u2_movimientos_mensual.csv
│   ├── u2_movimientos_variacion_semanal.csv
│   ├── u1_u2_map.csv                Puente U1 ↔ U2
│   ├── u3_resumen.csv
│   └── u3_pdf_mapa.csv
│
├── json/
│   ├── raw/<estado>.json            Respuesta original del portal por estado
│   └── u3/                          Resúmenes temáticos Campeche
│
├── sql/
│   ├── schema.sql                   DDL PostgreSQL+PostGIS idempotente
│   └── load.sql                     Plantilla \COPY para todos los CSVs
│
├── u3/pdfs/                         Mapas temáticos de Campeche
│
└── geodata/                         Capas geoespaciales listas para consumir
    ├── geojson/
    │   ├── light/                   Campos clave + TDPA 2024
    │   │   ├── u1_segmentos.geojson
    │   │   ├── u1_estaciones.geojson
    │   │   ├── u1_casetas.geojson
    │   │   ├── u2_plazas.geojson    enriquecido con carretera U1
    │   │   └── u2_movimientos.geojson
    │   └── historical/              TDPA 2009–2024 en columnas anchas
    │       ├── u1_estaciones_tdpa_wide.geojson
    │       └── u2_movimientos_tdpa_wide.geojson
    ├── geopackage/
    │   ├── datos_viales_2025_light.gpkg    5 capas base
    │   └── datos_viales_2025_full.gpkg     5 capas base + 2 históricas
    └── scripts/
        ├── generate_geodata.py      Script reproducible
        └── requirements.txt
```

---

## Inicio rápido por herramienta

### QGIS · ArcGIS Pro

Abrir directamente el GeoPackage; todas las capas se cargan con un clic y
mantienen tipos nativos:

```
geodata/geopackage/datos_viales_2025_full.gpkg
```

En QGIS: *Capa → Agregar capa → Agregar capa vectorial → Origen: archivo →
seleccionar el .gpkg*. Aparecerán las 7 capas listas para simbología.

### Kepler.gl

Arrastrar cualquier archivo `.geojson` de `geodata/geojson/light/` o
`geodata/geojson/historical/` a https://kepler.gl/demo. Para animaciones
temporales usar las capas `historical/` y configurar un *filter by time* sobre
los campos `tdpa_2010`..`tdpa_2024`.

### Tableau

Conectar a *Spatial file* y seleccionar los GeoJSON. Alternativamente,
conectar al CSV correspondiente (`csv/u1_estaciones.csv`, `csv/u2_plazas.csv`,
etc.) y generar puntos con `lat` y `lon` — Tableau detecta automáticamente
los roles geográficos.

### PowerBI

- **Visual ArcGIS Maps for PowerBI**: usar los GeoJSON de `geodata/geojson/light/`.
- **Visual Map estándar / Shape map**: usar los CSVs de `csv/` con columnas `lat` y `lon`.

### Google Earth Pro

Abrir los GeoJSON directamente (*Archivo → Abrir → filtro a GeoJSON*) o
convertirlos a KML con QGIS / `ogr2ogr`.

### PostgreSQL + PostGIS

Para análisis espacial completo (buffers, nearest, intersecciones,
agregaciones por polígono):

```bash
createdb datos_viales
psql -d datos_viales -c "CREATE EXTENSION IF NOT EXISTS postgis;"
psql -d datos_viales -f sql/schema.sql
psql -d datos_viales -f sql/load.sql

psql -d datos_viales <<'SQL'
SET search_path TO datos_viales, public;
UPDATE u1_segmentos   SET geom = ST_GeomFromText(wkt_linestring, 4326) WHERE wkt_linestring IS NOT NULL;
UPDATE u1_estaciones  SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326) WHERE lon IS NOT NULL AND lat IS NOT NULL;
UPDATE u1_casetas     SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326) WHERE lon IS NOT NULL AND lat IS NOT NULL;
UPDATE u2_plazas      SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326) WHERE lon IS NOT NULL AND lat IS NOT NULL;
UPDATE u2_movimientos SET geom = ST_SetSRID(ST_MakePoint(lon,lat),4326) WHERE lon IS NOT NULL AND lat IS NOT NULL;
VACUUM ANALYZE;
SQL
```

### Python (geopandas)

```python
import geopandas as gpd

segmentos = gpd.read_file("geodata/geopackage/datos_viales_2025_full.gpkg", layer="u1_segmentos")
plazas    = gpd.read_file("geodata/geopackage/datos_viales_2025_full.gpkg", layer="u2_plazas")
print(segmentos.crs, len(segmentos), plazas[["caseta", "u1_carretera_nombre"]].head())
```

### R (sf)

```r
library(sf)
segmentos <- st_read("geodata/geopackage/datos_viales_2025_full.gpkg", layer = "u1_segmentos")
```

---

## Vinculación U1 ↔ U2

La tabla `csv/u1_u2_map.csv` materializa la relación entre plazas de cobro
(U2) y su carretera padre en la Red Nacional (U1). La capa
`geodata/geojson/light/u2_plazas.geojson` ya incluye los campos
`u1_carretera_id`, `u1_carretera_nombre`, `u1_clave_carretera` y `match_method`
para consumo directo sin joins.

**Métodos de match** (en orden de preferencia):

1. `tematico_parent` — el campo `tematico.Carretera` del endpoint `/getById`
   del movimiento coincide exactamente con un `u1_carreteras.carretera` en el
   mismo estado.
2. `name_match` — coincidencia por nombre normalizado (acentos, mayúsculas).
3. `fuzzy_substring` — coincidencia parcial por substring.
4. `unmatched` — sin correspondencia automática (casos muy específicos, p.ej.
   *Arco Norte Cd. México* en Hidalgo).

Ejemplo SQL:

```sql
SELECT p.caseta, p.tdpa_2024_plaza, c.carretera, c.clave_carretera
FROM u2_plazas p
LEFT JOIN u1_u2_map m ON m.plaza_id = p.plaza_id
LEFT JOIN u1_carreteras c ON c.carretera_id = m.u1_carretera_id
WHERE p.state_slug = 'campeche';
```

---

## Notas sobre los conteos geoespaciales

- **u1_estaciones** publicado con 12,248 puntos (de 13,826 registros totales):
  se descartan 1,578 estaciones sin coordenadas válidas. El histórico TDPA
  completo se conserva en `csv/u1_estaciones_tdpa.csv`.
- **u2_plazas** consolidado a 333 plazas únicas (de 401 filas originales): la
  tabla base contenía múltiples registros por plaza (uno por movimiento);
  `geodata/geojson/light/u2_plazas.geojson` presenta una fila por plaza.
- Todas las capas usan **EPSG:4326 (WGS84)** en grados decimales.

---

## Diccionario de datos

Consulta `DATA_DICTIONARY.md` para:

- Descripción de los 11 endpoints remotos del portal SICT.
- Detalle de las 14 tablas (columnas, tipos, cardinalidades).
- 13 clases vehiculares (M, A, AR, B, C2–C9, T3S2/S3/S2R4, VNC, OTROS).
- Niveles de Servicio HCM (A–F) y su interpretación.
- Buenas prácticas de indexación espacial (GIST) y vistas recomendadas.

---

## Reproducibilidad

### Regenerar las capas geoespaciales

Desde la raíz del repositorio:

```bash
python3 -m venv .venv
source .venv/bin/activate          # Linux/macOS
# .venv\Scripts\activate           # Windows
pip install -r geodata/scripts/requirements.txt
python geodata/scripts/generate_geodata.py
```

El script lee los CSVs de `csv/`, construye las geometrías con `shapely` y
exporta los 7 GeoJSON y los 2 GeoPackage en menos de 60 segundos.

### Regenerar los CSVs desde el portal

La extracción original utiliza los 11 endpoints documentados en
`DATA_DICTIONARY.md`. Cualquier cliente HTTP con manejo de cookie de sesión
puede replicar la descarga.

---

## Licencia y atribución

- **Esta compilación** se distribuye bajo **Creative Commons Attribution 4.0
  International (CC BY 4.0)** — ver `LICENSE`.
- **Los datos originales** son propiedad de la **Secretaría de
  Infraestructura, Comunicaciones y Transportes (SICT)** y el **Instituto
  Mexicano del Transporte (IMT)** del Gobierno de México.

### Cita sugerida

> *Datos Viales México 2025 — Dataset Geoestadístico* (2026). Compilación a
> partir del portal Datos Viales 2025 de SICT/IMT.
> https://github.com/iChocko/Datos-Viales-SICT

---

## Créditos

**Datos originales:**
Secretaría de Infraestructura, Comunicaciones y Transportes (SICT) · Instituto
Mexicano del Transporte (IMT) — https://datosviales2020.routedev.mx/

**Contacto:** issues y pull requests son bienvenidos en
https://github.com/iChocko/Datos-Viales-SICT
