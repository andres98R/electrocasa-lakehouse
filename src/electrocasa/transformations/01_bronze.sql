-- ============================================================
-- ELECTROCASA - LAKEFLOW DECLARATIVE PIPELINES
-- CAPA BRONZE
-- ============================================================


-- ============================================================
-- 1. PRODUCTOS
-- Fuente: JSON - snapshot de baja frecuencia
-- Patrón: Materialized View
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
bronze.productos_bronze_ldp
COMMENT 'Bronze de catálogo de productos desde JSON'
AS
SELECT
    *,
    current_timestamp() AS _ingested_at,
    _metadata.file_path AS _source_file,

    concat(
        'productos_',
        date_format(
            _metadata.file_modification_time,
            'yyyyMMddHHmmss'
        )
    ) AS _batch_id

FROM read_files(
    '/Volumes/${electrocasa_catalog}/bronze/landing/productos/',
    format => 'json',
    multiLine => true,
    inferColumnTypes => false
);


-- ============================================================
-- 2. VENTAS
-- Fuente: CSV incremental
-- Patrón: Streaming Table + Auto Loader
-- ============================================================

CREATE OR REFRESH STREAMING TABLE
bronze.ventas_bronze_ldp
COMMENT 'Bronze incremental de ventas por sucursal'
AS
SELECT
    *,
    current_timestamp() AS _ingested_at,
    _metadata.file_path AS _source_file,

    concat(
        'ventas_',
        date_format(
            _metadata.file_modification_time,
            'yyyyMMddHHmmss'
        )
    ) AS _batch_id

FROM STREAM read_files(
    '/Volumes/${electrocasa_catalog}/bronze/landing/ventas/',
    format => 'csv',
    header => true,
    inferColumnTypes => false
);


-- ============================================================
-- 3. DEVOLUCIONES
-- Fuente: CSV incremental
-- Patrón: Streaming Table + Auto Loader
-- ============================================================

CREATE OR REFRESH STREAMING TABLE
bronze.devoluciones_bronze_ldp
COMMENT 'Bronze incremental de devoluciones'
AS
SELECT
    *,
    current_timestamp() AS _ingested_at,
    _metadata.file_path AS _source_file,

    concat(
        'devoluciones_',
        date_format(
            _metadata.file_modification_time,
            'yyyyMMddHHmmss'
        )
    ) AS _batch_id

FROM STREAM read_files(
    '/Volumes/${electrocasa_catalog}/bronze/landing/devoluciones/',
    format => 'csv',
    header => true,
    inferColumnTypes => false
);


-- ============================================================
-- 4. RESEÑAS
-- Fuente: JSON semiestructurado incremental
-- Patrón: Streaming Table + Auto Loader
-- ============================================================

CREATE OR REFRESH STREAMING TABLE
bronze.resenas_bronze_ldp
COMMENT 'Bronze incremental de reseñas de clientes'
AS
SELECT
    *,
    current_timestamp() AS _ingested_at,
    _metadata.file_path AS _source_file,

    concat(
        'resenas_',
        date_format(
            _metadata.file_modification_time,
            'yyyyMMddHHmmss'
        )
    ) AS _batch_id

FROM STREAM read_files(
    '/Volumes/${electrocasa_catalog}/bronze/landing/resenas/',
    format => 'json',
    multiLine => true,
    inferColumnTypes => false
);


-- ============================================================
-- 5. EMPLEADOS
-- Fuente: CSV - eventos por lote
-- Patrón: Streaming Table + Auto Loader
-- ============================================================

CREATE OR REFRESH STREAMING TABLE
bronze.empleados_bronze_ldp
COMMENT 'Bronze de eventos de empleados de RRHH'
AS
SELECT
    *,
    current_timestamp() AS _ingested_at,
    _metadata.file_path AS _source_file,

    concat(
        'empleados_',
        date_format(
            _metadata.file_modification_time,
            'yyyyMMddHHmmss'
        )
    ) AS _batch_id

FROM STREAM read_files(
    '/Volumes/${electrocasa_catalog}/bronze/landing/empleados/',
    format => 'csv',
    header => true,
    inferColumnTypes => false
);


-- ============================================================
-- 6. TRACKING
-- Fuente: Azure SQL Database
-- Método: Lakehouse Federation
-- Patrón: Materialized View
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
bronze.tracking_bronze_ldp
COMMENT 'Bronze de tracking desde Azure SQL mediante Lakehouse Federation'
AS
SELECT
    tracking_id,
    pedido_id,
    courier,
    estado_entrega,
    sucursal_origen,
    fecha_actualizacion,

    current_timestamp() AS _ingested_at,

    'azure_sql:electrocasadb.dbo.TrackingEnvios'
        AS _source_system,

    concat(
        'tracking_',
        date_format(
            current_timestamp(),
            'yyyyMMddHHmmss'
        )
    ) AS _batch_id

FROM electrocasa_azure_sql_catalog.dbo.TrackingEnvios;