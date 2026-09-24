-- ============================================================
-- ELECTROCASA
-- LAKEFLOW DECLARATIVE PIPELINES
-- CAPA GOLD
-- ============================================================


-- ============================================================
-- 1. VENTAS Y TICKET PROMEDIO POR SUCURSAL Y MES
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
electrocasa_dev.gold.ventas_mensuales_sucursal_ldp
COMMENT 'Ventas, unidades y ticket promedio por sucursal y mes'
AS

SELECT
    sucursal_id,

    CAST(
        DATE_TRUNC('MONTH', fecha_venta)
        AS DATE
    ) AS mes,

    COUNT(
        DISTINCT venta_id
    ) AS cantidad_ventas,

    SUM(cantidad)
        AS unidades_vendidas,

    ROUND(
        SUM(monto_total),
        2
    ) AS monto_total_ventas,

    ROUND(
        SUM(monto_total)
        / COUNT(DISTINCT venta_id),
        2
    ) AS ticket_promedio

FROM electrocasa_dev.silver.ventas_silver_ldp

WHERE fecha_venta IS NOT NULL

GROUP BY
    sucursal_id,
    CAST(
        DATE_TRUNC('MONTH', fecha_venta)
        AS DATE
    );


-- ============================================================
-- 2. PRODUCTOS MAS VENDIDOS
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
electrocasa_dev.gold.productos_mas_vendidos_ldp
COMMENT 'Ranking de productos por unidades vendidas'
AS

WITH base AS (

    SELECT
        v.producto_id,

        COALESCE(
            p.nombre_producto,
            'Producto sin dimension valida'
        ) AS nombre_producto,

        COALESCE(
            p.categoria,
            'sin_categoria'
        ) AS categoria,

        COALESCE(
            p.marca,
            'sin_marca'
        ) AS marca,

        SUM(v.cantidad)
            AS unidades_vendidas,

        COUNT(
            DISTINCT v.venta_id
        ) AS cantidad_ventas,

        ROUND(
            SUM(v.monto_total),
            2
        ) AS monto_vendido

    FROM electrocasa_dev.silver.ventas_silver_ldp v

    LEFT JOIN electrocasa_dev.silver.productos_silver_ldp p
        ON v.producto_id = p.producto_id

    GROUP BY
        v.producto_id,

        COALESCE(
            p.nombre_producto,
            'Producto sin dimension valida'
        ),

        COALESCE(
            p.categoria,
            'sin_categoria'
        ),

        COALESCE(
            p.marca,
            'sin_marca'
        )
)

SELECT
    producto_id,
    nombre_producto,
    categoria,
    marca,
    unidades_vendidas,
    cantidad_ventas,
    monto_vendido,

    DENSE_RANK() OVER (
        ORDER BY unidades_vendidas DESC
    ) AS ranking_unidades_vendidas

FROM base;


-- ============================================================
-- 3. PRODUCTOS MAS DEVUELTOS
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
electrocasa_dev.gold.productos_mas_devueltos_ldp
COMMENT 'Ranking de productos con mayor cantidad de devoluciones'
AS

WITH base AS (

    SELECT
        d.producto_id,

        COALESCE(
            p.nombre_producto,
            'Producto sin dimension valida'
        ) AS nombre_producto,

        COALESCE(
            p.categoria,
            'sin_categoria'
        ) AS categoria,

        COALESCE(
            p.marca,
            'sin_marca'
        ) AS marca,

        COUNT(
            DISTINCT d.devolucion_id
        ) AS cantidad_devoluciones,

        ROUND(
            SUM(d.monto_reembolso),
            2
        ) AS monto_total_reembolsado

    FROM electrocasa_dev.silver.devoluciones_silver_ldp d

    LEFT JOIN electrocasa_dev.silver.productos_silver_ldp p
        ON d.producto_id = p.producto_id

    GROUP BY
        d.producto_id,

        COALESCE(
            p.nombre_producto,
            'Producto sin dimension valida'
        ),

        COALESCE(
            p.categoria,
            'sin_categoria'
        ),

        COALESCE(
            p.marca,
            'sin_marca'
        )
)

SELECT
    producto_id,
    nombre_producto,
    categoria,
    marca,
    cantidad_devoluciones,
    monto_total_reembolsado,

    DENSE_RANK() OVER (
        ORDER BY cantidad_devoluciones DESC
    ) AS ranking_devoluciones

FROM base;


-- ============================================================
-- 4. DOTACION ACTIVA POR SUCURSAL
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
electrocasa_dev.gold.dotacion_activa_sucursal_ldp
COMMENT 'Dotación actual activa por sucursal'
AS

SELECT
    sucursal_id,

    COUNT(
        DISTINCT id_empleado
    ) AS empleados_activos,

    ROUND(
        AVG(salario),
        2
    ) AS salario_promedio,

    ROUND(
        SUM(salario),
        2
    ) AS masa_salarial

FROM electrocasa_dev.silver.empleados_silver_ldp

WHERE es_actual = TRUE
  AND estado_empleado = 'activo'

GROUP BY sucursal_id;


-- ============================================================
-- 5. TASA DE RESENAS NEGATIVAS POR CATEGORIA
--
-- Definicion:
-- resena negativa = calificacion 1 o 2.
-- ============================================================

CREATE OR REFRESH MATERIALIZED VIEW
electrocasa_dev.gold.resenas_negativas_categoria_ldp
COMMENT 'Tasa de reseñas negativas por categoría de producto'
AS

SELECT
    COALESCE(
        p.categoria,
        'sin_categoria'
    ) AS categoria,

    COUNT(*) AS total_resenas,

    SUM(
        CASE
            WHEN r.calificacion <= 2
            THEN 1
            ELSE 0
        END
    ) AS resenas_negativas,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN r.calificacion <= 2
                THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS tasa_resenas_negativas_pct,

    ROUND(
        AVG(r.calificacion),
        2
    ) AS calificacion_promedio

FROM electrocasa_dev.silver.resenas_silver_ldp r

LEFT JOIN electrocasa_dev.silver.productos_silver_ldp p
    ON r.producto_id = p.producto_id

GROUP BY
    COALESCE(
        p.categoria,
        'sin_categoria'
    );