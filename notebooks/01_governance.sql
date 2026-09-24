-- ============================================================
-- ELECTROCASA
-- GOBIERNO Y CONTROL DE ACCESO - UNITY CATALOG
-- ============================================================


-- ============================================================
-- 1. INGENIERIA
-- Lectura y escritura sobre Bronze, Silver y Gold.
-- Lectura de Audit para troubleshooting.
-- ============================================================

-- DEV
GRANT USE CATALOG
ON CATALOG electrocasa_dev
TO `electrocasa_ingenieria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_dev.bronze
TO `electrocasa_ingenieria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_dev.silver
TO `electrocasa_ingenieria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_dev.gold
TO `electrocasa_ingenieria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_dev.audit
TO `electrocasa_ingenieria`;

GRANT SELECT, MODIFY
ON SCHEMA electrocasa_dev.bronze
TO `electrocasa_ingenieria`;

GRANT SELECT, MODIFY
ON SCHEMA electrocasa_dev.silver
TO `electrocasa_ingenieria`;

GRANT SELECT, MODIFY
ON SCHEMA electrocasa_dev.gold
TO `electrocasa_ingenieria`;

GRANT SELECT
ON SCHEMA electrocasa_dev.audit
TO `electrocasa_ingenieria`;


-- PROD
GRANT USE CATALOG
ON CATALOG electrocasa_prod
TO `electrocasa_ingenieria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_prod.bronze
TO `electrocasa_ingenieria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_prod.silver
TO `electrocasa_ingenieria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_prod.gold
TO `electrocasa_ingenieria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_prod.audit
TO `electrocasa_ingenieria`;

GRANT SELECT, MODIFY
ON SCHEMA electrocasa_prod.bronze
TO `electrocasa_ingenieria`;

GRANT SELECT, MODIFY
ON SCHEMA electrocasa_prod.silver
TO `electrocasa_ingenieria`;

GRANT SELECT, MODIFY
ON SCHEMA electrocasa_prod.gold
TO `electrocasa_ingenieria`;

GRANT SELECT
ON SCHEMA electrocasa_prod.audit
TO `electrocasa_ingenieria`;


-- ============================================================
-- 2. ANALISTAS
-- Solo lectura sobre Gold.
-- ============================================================

-- DEV
REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_dev.bronze
FROM `electrocasa_analistas`;

REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_dev.silver
FROM `electrocasa_analistas`;

REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_dev.audit
FROM `electrocasa_analistas`;

GRANT USE CATALOG
ON CATALOG electrocasa_dev
TO `electrocasa_analistas`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_dev.gold
TO `electrocasa_analistas`;

GRANT SELECT
ON SCHEMA electrocasa_dev.gold
TO `electrocasa_analistas`;


-- PROD
REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_prod.bronze
FROM `electrocasa_analistas`;

REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_prod.silver
FROM `electrocasa_analistas`;

REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_prod.audit
FROM `electrocasa_analistas`;

GRANT USE CATALOG
ON CATALOG electrocasa_prod
TO `electrocasa_analistas`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_prod.gold
TO `electrocasa_analistas`;

GRANT SELECT
ON SCHEMA electrocasa_prod.gold
TO `electrocasa_analistas`;


-- ============================================================
-- 3. AUDITORIA
-- Lectura sobre Gold y Audit.
-- ============================================================

-- DEV
REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_dev.bronze
FROM `electrocasa_auditoria`;

REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_dev.silver
FROM `electrocasa_auditoria`;

GRANT USE CATALOG
ON CATALOG electrocasa_dev
TO `electrocasa_auditoria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_dev.gold
TO `electrocasa_auditoria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_dev.audit
TO `electrocasa_auditoria`;

GRANT SELECT
ON SCHEMA electrocasa_dev.gold
TO `electrocasa_auditoria`;

GRANT SELECT
ON SCHEMA electrocasa_dev.audit
TO `electrocasa_auditoria`;


-- PROD
REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_prod.bronze
FROM `electrocasa_auditoria`;

REVOKE ALL PRIVILEGES
ON SCHEMA electrocasa_prod.silver
FROM `electrocasa_auditoria`;

GRANT USE CATALOG
ON CATALOG electrocasa_prod
TO `electrocasa_auditoria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_prod.gold
TO `electrocasa_auditoria`;

GRANT USE SCHEMA
ON SCHEMA electrocasa_prod.audit
TO `electrocasa_auditoria`;

GRANT SELECT
ON SCHEMA electrocasa_prod.gold
TO `electrocasa_auditoria`;

GRANT SELECT
ON SCHEMA electrocasa_prod.audit
TO `electrocasa_auditoria`;


SHOW GRANTS ON SCHEMA electrocasa_dev.bronze;

SHOW GRANTS ON SCHEMA electrocasa_prod.gold;



-- ============================================================
-- 4. FUNCIONES DE MASKING
-- Solo Ingenieria puede visualizar los valores reales.
-- ============================================================


-- =========================
-- DEV
-- =========================

CREATE OR REPLACE FUNCTION electrocasa_dev.silver.mask_dni(valor STRING)
RETURNS STRING
RETURN
    CASE
        WHEN is_account_group_member('electrocasa_ingenieria')
            THEN valor
        WHEN valor IS NULL
            THEN NULL
        ELSE concat('****', right(valor, 4))
    END;


CREATE OR REPLACE FUNCTION electrocasa_dev.silver.mask_salario(valor DECIMAL(18,2))
RETURNS DECIMAL(18,2)
RETURN
    CASE
        WHEN is_account_group_member('electrocasa_ingenieria')
            THEN valor
        ELSE NULL
    END;


-- =========================
-- PROD
-- =========================

CREATE OR REPLACE FUNCTION electrocasa_prod.silver.mask_dni(valor STRING)
RETURNS STRING
RETURN
    CASE
        WHEN is_account_group_member('electrocasa_ingenieria')
            THEN valor
        WHEN valor IS NULL
            THEN NULL
        ELSE concat('****', right(valor, 4))
    END;


CREATE OR REPLACE FUNCTION electrocasa_prod.silver.mask_salario(valor DECIMAL(18,2))
RETURNS DECIMAL(18,2)
RETURN
    CASE
        WHEN is_account_group_member('electrocasa_ingenieria')
            THEN valor
        ELSE NULL
    END;





SELECT
    is_account_group_member('electrocasa_ingenieria') AS soy_ingenieria,
    electrocasa_dev.silver.mask_dni('12345678') AS prueba_dni,
    electrocasa_dev.silver.mask_salario(CAST(3500.00 AS DECIMAL(18,2))) AS prueba_salario;




    DESCRIBE TABLE electrocasa_dev.silver.empleados_silver_ldp;







