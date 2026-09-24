"""
Reglas y constantes de calidad de datos del proyecto ElectroCasa.

Este módulo centraliza criterios utilizados por las transformaciones
Bronze -> Silver del Lakehouse.
"""

# Rangos válidos
MIN_REVIEW_RATING = 1
MAX_REVIEW_RATING = 5

# Una reseña se considera negativa para los indicadores Gold
NEGATIVE_REVIEW_MAX_RATING = 2

# Estados normalizados de empleados
EMPLOYEE_EVENTS = [
    "alta",
    "transferencia",
    "cambio_salario",
    "baja",
]

# Reglas críticas documentadas
QUALITY_RULES = {
    "ventas": {
        "monto_valido": "monto_total > 0",
        "cantidad_valida": "cantidad > 0",
        "sucursal_obligatoria": "sucursal_id IS NOT NULL",
    },
    "productos": {
        "precio_valido": "precio_lista > 0",
    },
    "resenas": {
        "calificacion_valida": "calificacion BETWEEN 1 AND 5",
    },
    "devoluciones": {
        "reembolso_valido": "monto_reembolso >= 0",
        "pedido_obligatorio": "pedido_id IS NOT NULL",
    },
    "empleados": {
        "dni_obligatorio": "dni IS NOT NULL",
        "fecha_evento_obligatoria": "fecha_evento IS NOT NULL",
    },
}