-- Cargar CSVs (ejecutar desde psql: "psql -d datos_viales -f sql/load.sql")
SET search_path TO datos_viales, public;

\copy estados                             FROM 'csv/estados.csv' CSV HEADER;
\copy u1_carreteras                       FROM 'csv/u1_carreteras.csv' CSV HEADER;
\copy u1_segmentos                        FROM 'csv/u1_segmentos.csv' CSV HEADER;
\copy u1_estaciones                       FROM 'csv/u1_estaciones.csv' CSV HEADER;
\copy u1_estaciones_tdpa                  FROM 'csv/u1_estaciones_tdpa.csv' CSV HEADER;
\copy u1_estaciones_variacion             FROM 'csv/u1_estaciones_variacion.csv' CSV HEADER;
\copy u1_casetas                          FROM 'csv/u1_casetas.csv' CSV HEADER;
\copy u2_plazas                           FROM 'csv/u2_plazas.csv' CSV HEADER;
\copy u2_movimientos                      FROM 'csv/u2_movimientos.csv' CSV HEADER;
\copy u2_movimientos_tdpa                 FROM 'csv/u2_movimientos_tdpa.csv' CSV HEADER;
\copy u2_movimientos_mensual              FROM 'csv/u2_movimientos_mensual.csv' CSV HEADER;
\copy u2_movimientos_variacion_semanal    FROM 'csv/u2_movimientos_variacion_semanal.csv' CSV HEADER;
\copy u1_u2_map                           FROM 'csv/u1_u2_map.csv' CSV HEADER;
\copy u3_resumen                          FROM 'csv/u3_resumen.csv' CSV HEADER;
\copy u3_pdf_mapa                         FROM 'csv/u3_pdf_mapa.csv' CSV HEADER;
