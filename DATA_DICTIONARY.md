# Diccionario de Datos — Datos Viales 2025

Proyecto: Scraper del portal **Datos Viales 2025** (SICT/IMT) `https://datosviales2020.routedev.mx`.
Alcance:
- **U1** (Red Nacional de Carreteras Pavimentadas): 32 estados.
- **U2** (Estaciones Permanentes de Conteo / Plazas de Cobro): 32 estados.
- **U3** (Mapas Temáticos): **solo Campeche** (3 PDFs + 3 resúmenes JSON).

## Fuentes remotas (endpoints)

| Endpoint | Método | Devuelve |
|---|---|---|
| `/getByStateEstaciones?state={slug}` | GET | U1 + casetas: coordenadas de segmentos con metadata + pines de casetas |
| `/getAllByRoad?road={nombre}` | GET | U1: lista de estaciones (`_id`, ruta, clave, TDPA2024, composición) |
| `/getById?id={_id}` | GET | Detalle de estación/movimiento: `info`, `historical`, `bar`, `pie`, `variacion`, `tematico` |
| `/getMovimientos?_id={plaza_id}` | GET | U2: movimientos (sentidos) por plaza de cobro |
| `/getByStateTematicos?state={slug}` | GET | Geometría/metadata para mapas temáticos |
| `/resMapaNS?state={slug}` | GET | PDF Mapa Niveles de Servicio |
| `/resMapaVKABC?state={slug}` | GET | PDF Mapa Vehículos-Km |
| `/resMapaRVV?state={slug}` | GET | PDF Mapa Rangos de Volumen Vehicular |
| `/resEjecutivoNS?state={slug}` | GET | JSON resumen NS por red (FL/FC/EL/EC) |
| `/resEjecutivoVKABC?state={slug}` | GET | JSON resumen Vehículos-Km por red |
| `/resEjecutivoRVV?state={slug}` | GET | JSON resumen Rangos por red |

## Tablas

### `estados`
| Columna | Tipo | Descripción |
|---|---|---|
| state_slug | text (PK) | Slug de URL (`campeche`, `nuevo leon`…) |
| state_name | text | Nombre en mayúsculas |
| state_code | smallint (UNIQUE) | Código INEGI 1..32 |
| source_id | text | Id remoto del snapshot |
| retrieved_at | timestamptz | Fecha de extracción |

---
### Universo 1 — Red Nacional
#### `u1_carreteras`
| Columna | Tipo | Descripción |
|---|---|---|
| carretera_id | bigint (PK) | ID sintético (ordinal) |
| state_slug | text FK | → estados |
| carretera | text | Nombre p.ej. *Campeche - Mérida* |
| clave_carretera | text | Clave p.ej. *00066* |
| ruta | text | Clave p.ej. *MEX-180* |
| station_count | integer | Nº de estaciones listadas por el portal |

#### `u1_segmentos`
| Columna | Tipo | Descripción |
|---|---|---|
| segment_mongo_id | text (PK) | `_id` Mongo del portal |
| state_slug | text FK | → estados |
| carretera_id | bigint FK | → u1_carreteras |
| segment_seq | integer | Orden dentro del estado |
| segment_id_2025 | text | ID del Dato Vial 2025 |
| segment_id_2024 | text | ID del Dato Vial 2024 |
| clave_carretera | text | |
| carretera, ruta, estado, edo | | |
| red_ok | text | `Federal` / `Estatal` |
| operacion | text | `Libre` / `Cuota` |
| juris | smallint | 1 Federal Libre, 2 Federal Cuota, 4 Estatal |
| tipo_terr | text | L/M/P (Llano/Lomerío/Plano-Montañoso) |
| tipo_dv | text | ET (estación tipo), D (derivada), etc. |
| id_red, prog | int | Identificadores de red SICT |
| rango_vol | smallint | 1..16 categoría de volumen |
| ruta_de / ruta_a | text | Punto inicial / final |
| de_km / a_km / dist | numeric | Kilometraje |
| tdpa_2024 | int | TDPA del segmento 2024 |
| comp_* | numeric | Composición vehicular porcentual (A, B, C2, C3, T3S2, T3S3, T3S2R4, M, OTROS) |
| agg_aa/bb/cc | numeric | Agregados livianos/autobuses/camiones |
| vk_aa/bb/cc/total | numeric | Vehículos-Kilómetro anuales |
| fs_a..fs_e | text | Umbrales de capacidad (niveles de servicio A-E) |
| ns | text | Nivel de servicio calculado A..F |
| k_ok / d_ok | numeric | Factores K y D del segmento |
| wkt_linestring | text | Geometría en WKT (LINESTRING 4326), staging para PostGIS |
| geom | geometry(LINESTRING,4326) | Geometría poblada con ST_GeomFromText |

#### `u1_estaciones`
| Columna | Tipo | Descripción |
|---|---|---|
| station_id | text (PK) | `_id` Mongo |
| state_slug / carretera_id | FK | |
| carretera, clave_carretera, ruta | | |
| punto_generador | text | Localidad más cercana |
| tipo | smallint | Tipo de estación |
| sc | smallint | Sub-categoría |
| km | numeric | Kilometraje |
| lat / lon | double precision | Coordenadas WGS84 |
| tdpa_2024 | int | TDPA del año 2024 |
| pct_m/a/b/c2/c3/t3s2/t3s3/t3s2r4/otros | numeric | Composición % |
| pct_aa/bb/cc | numeric | Agregados (autos / autobuses / camiones) |
| d_val, k_prima | numeric | Factores D y K' |
| rubro | text | siempre `estaciones` |
| geom | geometry(POINT,4326) | Geometría |

#### `u1_estaciones_tdpa` *(TDPA Histórico, formato largo)*
| Columna | Tipo | Descripción |
|---|---|---|
| station_id | text FK | → u1_estaciones (ON DELETE CASCADE) |
| year | smallint PK | 2010..2024 (subset según disponibilidad) |
| tdpa | int | Tránsito Diario Promedio Anual |

#### `u1_estaciones_variacion` *(distribución semanal)*
| station_id | text FK | |
| dia_num | smallint | 1=Lun … 7=Dom |
| dia_nombre | text | Lun/Mar/Mie/Jue/Vie/Sab/Dom |
| valor | numeric | |
| porc | numeric | % |

#### `u1_casetas`
Pines de casetas como aparecen en el mapa del universo 1 (referencial).

---
### Universo 2 — Plazas de Cobro
#### `u2_plazas`
| Columna | Tipo | Descripción |
|---|---|---|
| plaza_id | text (PK) | |
| state_slug FK | | |
| caseta | text | Nombre de la plaza |
| cve | text | Clave |
| carretera, ruta | | |
| movimiento_principal | text | |
| tdpa_2024_plaza | int | TDPA agregado de la plaza |
| lat / lon | | |
| geom | geometry(POINT,4326) | |

#### `u2_movimientos`
Cada plaza tiene 1..N movimientos (sentidos).
| Columna | Tipo | Descripción |
|---|---|---|
| movement_id | text (PK) | |
| plaza_id FK | | → u2_plazas (ON DELETE CASCADE) |
| caseta, cve, carretera, ruta, movimiento | | |
| km, sen | | |
| lat, lon, x_pg, y_pg, zona_geo | | coords geográficas + UTM |
| estado | text | |
| vta_2024 | bigint | Vehículos Totales Anuales 2024 |
| pct_a/ar/b/c2..c9/vnc/m | numeric | Composición vehicular fina (13 clases) |
| rubro | text | `casetas` |
| geom | geometry(POINT,4326) | |

#### `u2_movimientos_tdpa` *(TDPA Histórico 2009–2024)*
| movement_id, year, tdpa |

#### `u2_movimientos_mensual` *(distribución mensual)*
| movement_id, mes_num (1-12), mes_nombre, porcentaje |

#### `u2_movimientos_variacion_semanal`
Idéntica a la U1 pero algunos endpoints retornan Ene..Dic.

---
### Puente U1 ↔ U2
#### `u1_u2_map`
| Columna | Tipo | Descripción |
|---|---|---|
| plaza_id (PK) | text FK | → u2_plazas |
| state_slug FK | | |
| u1_carretera_id FK | bigint | → u1_carreteras (NULL si no se pudo matchear) |
| u2_caseta_name, u2_carretera_raw, ruta | | |
| match_method | text | `tematico_parent` (preferido), `name_match`, `fuzzy_substring`, `unmatched` |

Heurística: se usa en primer lugar el campo `tematico.Carretera` que el endpoint
`/getById` devuelve para cada movimiento (apunta al segmento U1 padre). Si no,
se normaliza el nombre y se busca coincidencia exacta o por substring.

---
### Universo 3 — Mapas Temáticos (Campeche)
#### `u3_resumen`
Valores agregados km/vkm por red (FL/FC/EL/EC) y categoría (A..F | 1..16 | 1..3).
#### `u3_pdf_mapa`
Metadata de los 3 PDFs generados por el portal.

## Código de clases vehiculares

| Clase | Descripción |
|---|---|
| M | Motocicletas |
| A | Autos |
| AR | Autos con remolque |
| B | Autobuses |
| C2 | Camión 2 ejes |
| C3 | Camión 3 ejes |
| C4..C9 | Tracto-camiones 4..9 ejes (U2 usa clasificación extendida) |
| T3S2, T3S3, T3S2R4 | Combinaciones articuladas (U1) |
| VNC | Vehículos No Clasificados |
| OTROS | Otros |

## Niveles de Servicio (HCM)

| Nivel | Condición |
|---|---|
| A | Flujo libre |
| B | Flujo estable con ligera restricción |
| C | Flujo estable, libertad restringida |
| D | Flujo cerca de condiciones inestables |
| E | Capacidad |
| F | Forzado / congestión |

## Recomendaciones de buenas prácticas (Postgres)

1. Cargar siempre en este orden: `estados` → `u1_carreteras` → `u1_segmentos` →
   `u1_estaciones` → `u1_estaciones_tdpa` → `u1_estaciones_variacion` →
   `u1_casetas` → `u2_plazas` → `u2_movimientos` → `u2_movimientos_tdpa` →
   `u2_movimientos_mensual` → `u2_movimientos_variacion_semanal` → `u1_u2_map` →
   `u3_resumen` → `u3_pdf_mapa`.
2. Geometrías: poblar con `ST_SetSRID(ST_MakePoint(lon,lat),4326)` para puntos
   y `ST_GeomFromText(wkt_linestring,4326)` para las polilíneas.
3. Indexar GIST sobre `geom` para consultas espaciales (nearest, contains).
4. Para análisis longitudinal usar las vistas `v_u1_tdpa_wide` y
   `v_u2_tdpa_wide`.
5. Mantener `retrieved_at` en `estados` para versionado del snapshot; cada
   re-extracción inserta un row nuevo con `state_slug` idéntico (usar UPSERT
   `ON CONFLICT DO UPDATE SET retrieved_at=EXCLUDED.retrieved_at`).
