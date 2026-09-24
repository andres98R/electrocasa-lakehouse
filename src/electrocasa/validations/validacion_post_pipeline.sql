

USE CATALOG IDENTIFIER(:catalog);


WITH validaciones AS (

    SELECT
        (
            SELECT COUNT(*)
            FROM gold.ventas_mensuales_sucursal_ldp
        ) AS ventas_mensuales,

        (
            SELECT COUNT(*)
            FROM gold.productos_mas_vendidos_ldp
        ) AS productos_vendidos,

        (
            SELECT COUNT(*)
            FROM gold.productos_mas_devueltos_ldp
        ) AS productos_devueltos,

        (
            SELECT COUNT(*)
            FROM gold.dotacion_activa_sucursal_ldp
        ) AS sucursales_dotacion,

        (
            SELECT SUM(total_resenas)
            FROM gold.resenas_negativas_categoria_ldp
        ) AS total_resenas,

        (
            SELECT COUNT(*)
            FROM silver.ventas_validas_ldp
            WHERE monto_total IS NULL
               OR monto_total <= 0
               OR cantidad IS NULL
               OR cantidad <= 0
               OR sucursal_id IS NULL
               OR TRIM(sucursal_id) = ''
        ) AS ventas_invalidas

)

SELECT

    assert_true(
        ventas_mensuales > 0,
        'ERROR: Gold ventas_mensuales_sucursal_ldp esta vacia'
    ) AS validar_ventas,

    assert_true(
        productos_vendidos > 0,
        'ERROR: Gold productos_mas_vendidos_ldp esta vacia'
    ) AS validar_productos_vendidos,

    assert_true(
        productos_devueltos > 0,
        'ERROR: Gold productos_mas_devueltos_ldp esta vacia'
    ) AS validar_devoluciones,

    assert_true(
        sucursales_dotacion > 0,
        'ERROR: Gold dotacion_activa_sucursal_ldp esta vacia'
    ) AS validar_dotacion,

    assert_true(
        total_resenas > 0,
        'ERROR: Gold resenas_negativas_categoria_ldp esta vacia'
    ) AS validar_resenas,

    assert_true(
        ventas_invalidas = 0,
        'ERROR: ventas_validas_ldp contiene registros que incumplen calidad'
    ) AS validar_calidad_ventas,

    ventas_mensuales,
    productos_vendidos,
    productos_devueltos,
    sucursales_dotacion,
    total_resenas,
    ventas_invalidas

FROM validaciones;