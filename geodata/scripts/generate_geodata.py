"""
Genera capas geoespaciales (GeoJSON + GeoPackage) a partir de los CSVs
del dataset Datos Viales 2025 (SICT/IMT).

Salida:
  geodata/geojson/light/         -> 5 GeoJSON con campos clave + TDPA 2024
  geodata/geojson/historical/    -> 2 GeoJSON con histórico TDPA en columnas anchas
  geodata/geopackage/            -> 2 .gpkg (light y full)

Uso:
    python geodata/scripts/generate_geodata.py

CRS de salida: WGS84 / EPSG:4326
"""

from __future__ import annotations

import sys
from pathlib import Path

import geopandas as gpd
import pandas as pd
from shapely import wkt
from shapely.geometry import Point

ROOT = Path(__file__).resolve().parents[2]
CSV_DIR = ROOT / "csv"
OUT_GEOJSON_LIGHT = ROOT / "geodata" / "geojson" / "light"
OUT_GEOJSON_HIST = ROOT / "geodata" / "geojson" / "historical"
OUT_GPKG = ROOT / "geodata" / "geopackage"
CRS_WGS84 = "EPSG:4326"


def log(msg: str) -> None:
    print(f"[geodata] {msg}", flush=True)


def ensure_dirs() -> None:
    for d in (OUT_GEOJSON_LIGHT, OUT_GEOJSON_HIST, OUT_GPKG):
        d.mkdir(parents=True, exist_ok=True)


def build_points(df: pd.DataFrame, lon_col: str = "lon", lat_col: str = "lat") -> gpd.GeoDataFrame:
    before = len(df)
    df = df.dropna(subset=[lon_col, lat_col]).copy()
    dropped = before - len(df)
    if dropped:
        log(f"     (descartadas {dropped:,} filas sin coordenadas)")
    geom = [Point(xy) for xy in zip(df[lon_col], df[lat_col])]
    return gpd.GeoDataFrame(df, geometry=geom, crs=CRS_WGS84)


def build_lines_from_wkt(df: pd.DataFrame, wkt_col: str = "wkt_linestring") -> gpd.GeoDataFrame:
    df = df.dropna(subset=[wkt_col]).copy()
    df["geometry"] = df[wkt_col].apply(wkt.loads)
    df = df.drop(columns=[wkt_col])
    return gpd.GeoDataFrame(df, geometry="geometry", crs=CRS_WGS84)


def load_u1_segmentos_light() -> gpd.GeoDataFrame:
    log("Leyendo u1_segmentos.csv (4,791 features)...")
    df = pd.read_csv(CSV_DIR / "u1_segmentos.csv", low_memory=False)
    keep = [
        "segment_mongo_id", "state_slug", "carretera_id", "segment_id_2025",
        "clave_carretera", "carretera", "ruta", "estado", "red_ok", "operacion",
        "tipo_terr", "rango_vol", "ruta_de", "ruta_a", "de_km", "a_km", "dist",
        "tdpa_2024", "vk_total", "ns", "wkt_linestring",
    ]
    df = df[[c for c in keep if c in df.columns]]
    gdf = build_lines_from_wkt(df)
    log(f"  -> u1_segmentos: {len(gdf):,} líneas")
    return gdf


def load_u1_estaciones_light() -> gpd.GeoDataFrame:
    log("Leyendo u1_estaciones.csv (13,826 features)...")
    df = pd.read_csv(CSV_DIR / "u1_estaciones.csv", low_memory=False)
    keep = [
        "station_id", "state_slug", "carretera_id", "carretera", "clave_carretera",
        "ruta", "punto_generador", "tipo", "km", "lat", "lon",
        "tdpa_2024",
        "pct_M", "pct_A", "pct_B", "pct_C2", "pct_C3",
        "pct_T3S2", "pct_T3S3", "pct_T3S2R4", "pct_OTROS",
    ]
    df = df[[c for c in keep if c in df.columns]]
    gdf = build_points(df)
    log(f"  -> u1_estaciones: {len(gdf):,} puntos")
    return gdf


def load_u1_casetas_light() -> gpd.GeoDataFrame:
    log("Leyendo u1_casetas.csv...")
    df = pd.read_csv(CSV_DIR / "u1_casetas.csv", low_memory=False)
    gdf = build_points(df)
    log(f"  -> u1_casetas: {len(gdf):,} puntos")
    return gdf


def load_u2_plazas_light() -> gpd.GeoDataFrame:
    log("Leyendo u2_plazas.csv + u1_u2_map.csv (JOIN)...")
    plazas = pd.read_csv(CSV_DIR / "u2_plazas.csv", low_memory=False)
    mapdf = pd.read_csv(CSV_DIR / "u1_u2_map.csv", low_memory=False)
    carr = pd.read_csv(CSV_DIR / "u1_carreteras.csv", low_memory=False)

    plazas_dedup = plazas.drop_duplicates(subset=["plaza_id"], keep="first")

    match_rank = {"tematico_parent": 0, "name_match": 1, "fuzzy_substring": 2, "unmatched": 3}
    mapdf["_rank"] = mapdf["match_method"].map(match_rank).fillna(9)
    mapdf_dedup = (
        mapdf.sort_values("_rank")
        .drop_duplicates(subset=["plaza_id"], keep="first")
        .drop(columns=["_rank"])
    )

    carr_slim = carr[["carretera_id", "carretera", "clave_carretera"]].rename(
        columns={
            "carretera_id": "u1_carretera_id",
            "carretera": "u1_carretera_nombre",
            "clave_carretera": "u1_clave_carretera",
        }
    )
    mapdf_dedup = mapdf_dedup.merge(carr_slim, on="u1_carretera_id", how="left")
    map_slim = mapdf_dedup[[
        "plaza_id", "u1_carretera_id", "u1_carretera_nombre",
        "u1_clave_carretera", "match_method",
    ]]
    enriched = plazas_dedup.merge(map_slim, on="plaza_id", how="left")
    gdf = build_points(enriched)
    linked = enriched["u1_carretera_id"].notna().sum()
    log(f"  -> u2_plazas: {len(gdf):,} puntos únicos ({linked} con vínculo U1)")
    return gdf


def load_u2_movimientos_light() -> gpd.GeoDataFrame:
    log("Leyendo u2_movimientos.csv...")
    df = pd.read_csv(CSV_DIR / "u2_movimientos.csv", low_memory=False)
    gdf = build_points(df)
    log(f"  -> u2_movimientos: {len(gdf):,} puntos")
    return gdf


def pivot_tdpa(long_df: pd.DataFrame, id_col: str, prefix: str = "tdpa_") -> pd.DataFrame:
    wide = long_df.pivot_table(
        index=id_col, columns="year", values="tdpa", aggfunc="first"
    ).reset_index()
    wide.columns = [id_col] + [f"{prefix}{int(c)}" for c in wide.columns if c != id_col]
    return wide


def load_u1_estaciones_historical() -> gpd.GeoDataFrame:
    log("Construyendo u1_estaciones histórica (TDPA 2010-2024 wide)...")
    est = pd.read_csv(CSV_DIR / "u1_estaciones.csv", low_memory=False)
    tdpa = pd.read_csv(CSV_DIR / "u1_estaciones_tdpa.csv", low_memory=False)
    wide = pivot_tdpa(tdpa, "station_id")
    keep_est = [
        "station_id", "state_slug", "carretera_id", "carretera",
        "clave_carretera", "ruta", "punto_generador", "tipo",
        "km", "lat", "lon",
    ]
    merged = est[[c for c in keep_est if c in est.columns]].merge(
        wide, on="station_id", how="left"
    )
    gdf = build_points(merged)
    log(f"  -> u1_estaciones_tdpa_wide: {len(gdf):,} puntos, {wide.shape[1] - 1} años")
    return gdf


def load_u2_movimientos_historical() -> gpd.GeoDataFrame:
    log("Construyendo u2_movimientos histórica (TDPA 2009-2024 wide)...")
    mov = pd.read_csv(CSV_DIR / "u2_movimientos.csv", low_memory=False)
    tdpa = pd.read_csv(CSV_DIR / "u2_movimientos_tdpa.csv", low_memory=False)
    wide = pivot_tdpa(tdpa, "movement_id")
    keep_mov = [
        "movement_id", "plaza_id", "caseta", "cve", "carretera", "ruta",
        "movimiento", "km", "sen", "lat", "lon", "estado",
    ]
    merged = mov[[c for c in keep_mov if c in mov.columns]].merge(
        wide, on="movement_id", how="left"
    )
    gdf = build_points(merged)
    log(f"  -> u2_movimientos_tdpa_wide: {len(gdf):,} puntos, {wide.shape[1] - 1} años")
    return gdf


def write_geojson(gdf: gpd.GeoDataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    gdf.to_file(path, driver="GeoJSON")
    size_mb = path.stat().st_size / (1024 * 1024)
    log(f"  Escrito {path.relative_to(ROOT)} ({size_mb:.1f} MB)")


def write_gpkg(layers: dict[str, gpd.GeoDataFrame], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        path.unlink()
    for name, gdf in layers.items():
        log(f"  Escribiendo capa '{name}' ({len(gdf):,} features)...")
        gdf.to_file(path, layer=name, driver="GPKG")
    size_mb = path.stat().st_size / (1024 * 1024)
    log(f"  Escrito {path.relative_to(ROOT)} ({size_mb:.1f} MB)")


def main() -> int:
    ensure_dirs()

    log("=== CARGANDO CAPAS LIGHT ===")
    light = {
        "u1_segmentos": load_u1_segmentos_light(),
        "u1_estaciones": load_u1_estaciones_light(),
        "u1_casetas": load_u1_casetas_light(),
        "u2_plazas": load_u2_plazas_light(),
        "u2_movimientos": load_u2_movimientos_light(),
    }

    log("=== CARGANDO CAPAS HISTÓRICAS ===")
    historical = {
        "u1_estaciones_tdpa_wide": load_u1_estaciones_historical(),
        "u2_movimientos_tdpa_wide": load_u2_movimientos_historical(),
    }

    log("=== ESCRIBIENDO GEOJSON (light) ===")
    for name, gdf in light.items():
        write_geojson(gdf, OUT_GEOJSON_LIGHT / f"{name}.geojson")

    log("=== ESCRIBIENDO GEOJSON (historical) ===")
    for name, gdf in historical.items():
        write_geojson(gdf, OUT_GEOJSON_HIST / f"{name}.geojson")

    log("=== ESCRIBIENDO GEOPACKAGE (light) ===")
    write_gpkg(light, OUT_GPKG / "datos_viales_2025_light.gpkg")

    log("=== ESCRIBIENDO GEOPACKAGE (full) ===")
    full = {**light, **historical}
    write_gpkg(full, OUT_GPKG / "datos_viales_2025_full.gpkg")

    log("=== DONE ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
