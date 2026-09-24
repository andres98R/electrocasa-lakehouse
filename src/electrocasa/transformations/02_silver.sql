-- ============================================================
-- ELECTROCASA
-- LAKEFLOW DECLARATIVE PIPELINES
-- CAPA SILVER
-- ============================================================


-- ============================================================
-- 1. PRODUCTOS SILVER
-- Limpieza de precio, categoria y deduplicacion.
--
-- Nota:
-- El origen no posee fecha de vigencia del precio.
-- Para duplicados validos se utiliza el precio mayor
-- como criterio deterministico de desempate.
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
silver.productos_silver_ldp
COMMENT 'Productos limpios, estandarizados y deduplicados'
AS

WITH productos_limpios AS (

    SELECT
        TRIM(producto_id) AS producto_id,
        TRIM(nombre_producto) AS nombre_producto,

        translate(
            lower(trim(categoria)),
            'áéíóúüñ ',
            'aeiouun_'
        ) AS categoria,

        CASE
            WHEN marca IS NULL OR trim(marca) = ''
            THEN NULL
            ELSE trim(marca)
        END AS marca,

        TRY_CAST(
            regexp_replace(
                precio_lista,
                '[^0-9.-]',
                ''
            )
            AS DECIMAL(18,2)
        ) AS precio_lista,

        _ingested_at,
        _source_file,
        _batch_id

    FROM bronze.productos_bronze_ldp
),

productos_validos AS (

    SELECT *
    FROM productos_limpios

    WHERE producto_id IS NOT NULL
      AND producto_id <> ''
      AND precio_lista IS NOT NULL
      AND precio_lista > 0
),

productos_rankeados AS (

    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY producto_id
            ORDER BY
                precio_lista DESC,
                _ingested_at DESC
        ) AS rn

    FROM productos_validos
)

SELECT
    producto_id,
    nombre_producto,
    categoria,
    marca,
    precio_lista,
    _ingested_at,
    _source_file,
    _batch_id

FROM productos_rankeados

WHERE rn = 1;


-- ============================================================
-- 2. VENTAS RECHAZADAS / CUARENTENA
-- Estos registros quedaran trazables antes de aplicar EXPECT.
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
audit.ventas_quarantine_ldp
COMMENT 'Ventas rechazadas por reglas criticas de calidad'
AS

WITH ventas_evaluadas AS (

    SELECT
        venta_id,
        sucursal_id,
        producto_id,
        cantidad,
        monto_total,
        metodo_pago,
        fecha_venta,
        canal,

        TRY_CAST(cantidad AS INT) AS cantidad_num,

        TRY_CAST(
            monto_total AS DECIMAL(18,2)
        ) AS monto_total_num,

        _source_file,
        _batch_id

    FROM bronze.ventas_bronze_ldp
)

SELECT
    venta_id,
    sucursal_id,
    producto_id,
    cantidad,
    monto_total,
    metodo_pago,
    fecha_venta,
    canal,

    concat_ws(
        ' | ',

        CASE
            WHEN monto_total_num IS NULL
              OR monto_total_num <= 0
            THEN 'MONTO_TOTAL_INVALIDO'
        END,

        CASE
            WHEN cantidad_num IS NULL
              OR cantidad_num <= 0
            THEN 'CANTIDAD_INVALIDA'
        END,

        CASE
            WHEN sucursal_id IS NULL
              OR trim(sucursal_id) = ''
            THEN 'SUCURSAL_ID_VACIA'
        END

    ) AS motivo_rechazo,

    _source_file AS source_file,
    _batch_id AS batch_id,

    current_timestamp() AS fecha_procesamiento

FROM ventas_evaluadas

WHERE
       monto_total_num IS NULL
    OR monto_total_num <= 0
    OR cantidad_num IS NULL
    OR cantidad_num <= 0
    OR sucursal_id IS NULL
    OR trim(sucursal_id) = '';


-- ============================================================
-- 3. VENTAS VALIDAS CON EXPECTATIONS
--
-- Aquí cumplimos formalmente el requisito de calidad
-- de Lakeflow.
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
silver.ventas_validas_ldp
(
    CONSTRAINT monto_total_positivo
        EXPECT (monto_total > 0)
        ON VIOLATION DROP ROW,

    CONSTRAINT cantidad_positiva
        EXPECT (cantidad > 0)
        ON VIOLATION DROP ROW,

    CONSTRAINT sucursal_requerida
        EXPECT (
            sucursal_id IS NOT NULL
            AND sucursal_id <> ''
        )
        ON VIOLATION DROP ROW
)
COMMENT 'Ventas normalizadas con expectativas de calidad'
AS

SELECT
    trim(venta_id) AS venta_id,

    trim(sucursal_id) AS sucursal_id,

    trim(producto_id) AS producto_id,

    TRY_CAST(
        cantidad AS INT
    ) AS cantidad,

    TRY_CAST(
        monto_total AS DECIMAL(18,2)
    ) AS monto_total,

    CASE
        WHEN lower(trim(metodo_pago))
             IN (
                'tarjeta',
                'tc',
                'tarjeta de credito',
                'tarjeta_credito'
             )
        THEN 'tarjeta'

        WHEN lower(trim(metodo_pago))
             IN ('efectivo', 'efv')
        THEN 'efectivo'

        WHEN lower(trim(metodo_pago)) = 'yape'
        THEN 'yape'

        WHEN lower(trim(metodo_pago)) = 'plin'
        THEN 'plin'

        WHEN lower(trim(metodo_pago))
             IN (
                'transferencia',
                'transferencia bancaria'
             )
        THEN 'transferencia'

        ELSE lower(trim(metodo_pago))
    END AS metodo_pago,

    CAST(
        COALESCE(
            TRY_TO_TIMESTAMP(
                fecha_venta,
                'yyyy-MM-dd'
            ),
            TRY_TO_TIMESTAMP(
                fecha_venta,
                'dd/MM/yyyy'
            )
        )
        AS DATE
    ) AS fecha_venta,

    lower(trim(canal)) AS canal,

    _ingested_at,
    _source_file,
    _batch_id

FROM bronze.ventas_bronze_ldp;


-- ============================================================
-- 4. VENTAS SILVER FINAL
-- Deduplicacion por venta_id.
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
silver.ventas_silver_ldp
COMMENT 'Ventas Silver limpias y deduplicadas'
AS

WITH ventas_rankeadas AS (

    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY venta_id
            ORDER BY _ingested_at DESC
        ) AS rn

    FROM silver.ventas_validas_ldp
)

SELECT
    venta_id,
    sucursal_id,
    producto_id,
    cantidad,
    monto_total,
    metodo_pago,
    fecha_venta,
    canal,
    _ingested_at,
    _source_file,
    _batch_id

FROM ventas_rankeadas

WHERE rn = 1;


-- ============================================================
-- 5. DEVOLUCIONES SILVER
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
silver.devoluciones_silver_ldp
COMMENT 'Devoluciones limpias, validadas y deduplicadas'
AS

WITH productos_catalogo AS (

    SELECT DISTINCT producto_id
    FROM bronze.productos_bronze_ldp

    WHERE producto_id IS NOT NULL
),

devoluciones_limpias AS (

    SELECT
        trim(d.devolucion_id) AS devolucion_id,
        trim(d.pedido_id) AS pedido_id,
        trim(d.sucursal_id) AS sucursal_id,
        trim(d.producto_id) AS producto_id,

        CASE
            WHEN d.motivo IS NULL
              OR trim(d.motivo) = ''
            THEN 'sin_motivo'

            ELSE lower(trim(d.motivo))
        END AS motivo,

        TRY_CAST(
            d.monto_reembolso AS DECIMAL(18,2)
        ) AS monto_reembolso,

        TRY_CAST(
            d.fecha_devolucion AS DATE
        ) AS fecha_devolucion,

        d._ingested_at,
        d._source_file,
        d._batch_id

    FROM bronze.devoluciones_bronze_ldp d

    INNER JOIN productos_catalogo p
        ON trim(d.producto_id) = p.producto_id

    WHERE d.pedido_id IS NOT NULL
      AND trim(d.pedido_id) <> ''

      AND TRY_CAST(
            d.monto_reembolso AS DECIMAL(18,2)
          ) >= 0
),

devoluciones_rankeadas AS (

    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY devolucion_id

            ORDER BY
                _ingested_at DESC,
                monto_reembolso DESC
        ) AS rn

    FROM devoluciones_limpias
)

SELECT
    devolucion_id,
    pedido_id,
    sucursal_id,
    producto_id,
    motivo,
    monto_reembolso,
    fecha_devolucion,
    _ingested_at,
    _source_file,
    _batch_id

FROM devoluciones_rankeadas

WHERE rn = 1;


-- ============================================================
-- 6. RESENAS SILVER
-- Parseo de estructuras JSON y deduplicacion.
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
silver.resenas_silver_ldp
COMMENT 'Reseñas limpias, normalizadas y deduplicadas'
AS

WITH productos_catalogo AS (

    SELECT DISTINCT producto_id

    FROM bronze.productos_bronze_ldp

    WHERE producto_id IS NOT NULL
),

resenas_parseadas AS (

    SELECT
        trim(r.resena_id) AS resena_id,
        trim(r.producto_id) AS producto_id,
        trim(r.cliente_id) AS cliente_id,

        TRY_CAST(
            r.calificacion AS INT
        ) AS calificacion,

        CASE
            WHEN r.comentario IS NULL
              OR trim(r.comentario) = ''
            THEN NULL

            ELSE trim(r.comentario)
        END AS comentario,

        from_json(
            r.tags,
            'ARRAY<STRING>'
        ) AS tags_parseados,

        from_json(
            r.respuestas,
            'ARRAY<STRUCT<autor:STRING,texto:STRING>>'
        ) AS respuestas_parseadas,

        TRY_CAST(
            r.fecha_resena AS DATE
        ) AS fecha_resena,

        r._ingested_at,
        r._source_file,
        r._batch_id

    FROM bronze.resenas_bronze_ldp r

    INNER JOIN productos_catalogo p
        ON trim(r.producto_id) = p.producto_id

    WHERE TRY_CAST(
            r.calificacion AS INT
          ) BETWEEN 1 AND 5
),

resenas_limpias AS (

    SELECT
        resena_id,
        producto_id,
        cliente_id,
        calificacion,
        comentario,

        COALESCE(
            tags_parseados,
            CAST(
                array()
                AS ARRAY<STRING>
            )
        ) AS tags,

        COALESCE(
            respuestas_parseadas,
            CAST(
                array()
                AS ARRAY<
                    STRUCT<
                        autor:STRING,
                        texto:STRING
                    >
                >
            )
        ) AS respuestas,

        fecha_resena,
        _ingested_at,
        _source_file,
        _batch_id,

        ROW_NUMBER() OVER (
            PARTITION BY resena_id

            ORDER BY
                fecha_resena DESC NULLS LAST,
                producto_id,
                cliente_id
        ) AS rn

    FROM resenas_parseadas
)

SELECT
    resena_id,
    producto_id,
    cliente_id,
    calificacion,
    comentario,
    tags,
    respuestas,
    fecha_resena,
    _ingested_at,
    _source_file,
    _batch_id

FROM resenas_limpias

WHERE rn = 1;


-- ============================================================
-- 7. EMPLEADOS SILVER
-- Historizacion tipo SCD2.
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
silver.empleados_silver_ldp
COMMENT 'Historial SCD Tipo 2 de empleados'
AS

WITH dni_conflictivos AS (

    SELECT
        trim(dni) AS dni

    FROM bronze.empleados_bronze_ldp

    WHERE dni IS NOT NULL
      AND trim(dni) <> ''

    GROUP BY trim(dni)

    HAVING COUNT(
        DISTINCT trim(id_empleado)
    ) > 1
),

empleados_limpios AS (

    SELECT
        trim(e.id_empleado) AS id_empleado,
        trim(e.nombre) AS nombre,
        trim(e.dni) AS dni,

        lower(
            trim(e.email)
        ) AS email,

        TRY_CAST(
            e.salario AS DECIMAL(18,2)
        ) AS salario,

        trim(e.sucursal_id) AS sucursal_id,
        trim(e.cargo) AS cargo,

        regexp_replace(
            lower(trim(e.tipo_evento)),
            '[ _]+',
            '_'
        ) AS tipo_evento,

        TRY_CAST(
            e.fecha_evento AS DATE
        ) AS fecha_evento,

        e._ingested_at,
        e._source_file,
        e._batch_id

    FROM bronze.empleados_bronze_ldp e

    LEFT JOIN dni_conflictivos d
        ON trim(e.dni) = d.dni

    WHERE
        e.id_empleado IS NOT NULL
        AND trim(e.id_empleado) <> ''

        AND e.dni IS NOT NULL
        AND trim(e.dni) <> ''

        AND TRY_CAST(
            e.fecha_evento AS DATE
        ) IS NOT NULL

        AND d.dni IS NULL

        AND regexp_replace(
                lower(trim(e.tipo_evento)),
                '[ _]+',
                '_'
            ) IN (
                'alta',
                'transferencia',
                'cambio_salario',
                'baja'
            )
),

historial AS (

    SELECT
        *,

        LEAD(fecha_evento) OVER (
            PARTITION BY dni

            ORDER BY
                fecha_evento,
                tipo_evento,
                id_empleado
        ) AS siguiente_fecha_evento,

        ROW_NUMBER() OVER (
            PARTITION BY dni

            ORDER BY
                fecha_evento DESC,
                tipo_evento DESC,
                id_empleado DESC
        ) AS rn_actual

    FROM empleados_limpios
)

SELECT
    id_empleado,
    nombre,
    dni,
    email,
    salario,
    sucursal_id,
    cargo,
    tipo_evento,
    fecha_evento,

    fecha_evento
        AS vigencia_desde,

    siguiente_fecha_evento
        AS vigencia_hasta_exclusiva,

    CASE
        WHEN rn_actual = 1
        THEN TRUE
        ELSE FALSE
    END AS es_actual,

    CASE
        WHEN rn_actual = 1
         AND tipo_evento = 'baja'
        THEN 'inactivo'

        WHEN rn_actual = 1
        THEN 'activo'

        ELSE 'historico'
    END AS estado_empleado,

    _ingested_at,
    _source_file,
    _batch_id

FROM historial;


-- ============================================================
-- 8. TRACKING SILVER
-- Normalizacion de estado y courier + deduplicacion.
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
silver.tracking_silver_ldp
COMMENT 'Tracking normalizado y deduplicado'
AS

WITH tracking_limpio AS (

    SELECT
        trim(tracking_id) AS tracking_id,
        trim(pedido_id) AS pedido_id,

        regexp_replace(
            lower(trim(courier)),
            '[ ]+',
            '_'
        ) AS courier,

        CASE

            WHEN regexp_replace(
                    lower(trim(estado_entrega)),
                    '[ ]+',
                    '_'
                 )
                 IN (
                    'en_camino',
                    'en_transito'
                 )
            THEN 'en_transito'

            WHEN regexp_replace(
                    lower(trim(estado_entrega)),
                    '[ ]+',
                    '_'
                 ) = 'entregado'
            THEN 'entregado'

            WHEN regexp_replace(
                    lower(trim(estado_entrega)),
                    '[ ]+',
                    '_'
                 ) = 'pendiente'
            THEN 'pendiente'

            WHEN regexp_replace(
                    lower(trim(estado_entrega)),
                    '[ ]+',
                    '_'
                 ) = 'devuelto'
            THEN 'devuelto'

            ELSE NULL

        END AS estado_entrega,

        trim(sucursal_origen)
            AS sucursal_origen,

        fecha_actualizacion,

        _ingested_at,
        _source_system,
        _batch_id

    FROM bronze.tracking_bronze_ldp
),

tracking_validos AS (

    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY tracking_id

            ORDER BY
                fecha_actualizacion DESC NULLS LAST,
                estado_entrega,
                courier
        ) AS rn

    FROM tracking_limpio

    WHERE estado_entrega IN (
        'entregado',
        'en_transito',
        'pendiente',
        'devuelto'
    )
)

SELECT
    tracking_id,
    pedido_id,
    courier,
    estado_entrega,
    sucursal_origen,
    fecha_actualizacion,
    _ingested_at,
    _source_system,
    _batch_id

FROM tracking_validos

WHERE rn = 1;