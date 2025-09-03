-- queries.sql
-- Coloque aqui suas soluções para os desafios
-- 1. Top 10 clientes com maior saldo consolidado
SELECT
    c.ID,
    c.NOME,
    DECIMAL(SUM(co.SALDO), 18, 2) AS SALDO_TOTAL
FROM
    CLIENTE c
    JOIN CONTA co ON co.CLIENTE_ID = c.ID
GROUP BY
    c.ID,
    c.NOME
ORDER BY
    SALDO_TOTAL DESC
FETCH FIRST
    10 ROWS ONLY -- 2. Extrato de conta com saldo acumulado
SELECT
    t.ID AS TRANSACAO_ID,
    t.DATA,
    t.TIPO,
    t.VALOR,
    SUM(
        CASE
            WHEN t.TIPO = 'CREDITO' THEN t.VALOR
            ELSE - t.VALOR
        END
    ) OVER (
        ORDER BY
            t.DATA,
            t.ID ROWS UNBOUNDED PRECEDING
    ) AS SALDO_ACUMULADO
FROM
    TRANSACAO t
    JOIN CONTA c ON c.ID = t.CONTA_ID
WHERE
    c.AGENCIA = '0001'
    AND c.NUMERO = '12345-6'
ORDER BY
    t.DATA,
    t.ID -- 3. Saldo médio diário em um período
    WITH TRANSACAO_ACUM AS (
        SELECT
            DATE (t.DATA) AS DIA,
            SUM(
                CASE
                    WHEN t.TIPO = 'CREDITO' THEN t.VALOR
                    ELSE - t.VALOR
                END
            ) AS MOV_DIA
        FROM
            TRANSACAO t
            JOIN CONTA c ON c.ID = t.CONTA_ID
        WHERE
            c.AGENCIA = '0001'
            AND c.NUMERO = '12345-6'
            AND t.DATA BETWEEN '2025-07-01'
            AND '2025-08-31'
        GROUP BY
            DATE (t.DATA)
    ),
    SALDO_DIA AS (
        SELECT
            DIA,
            SUM(MOV_DIA) OVER (
                ORDER BY
                    DIA ROWS UNBOUNDED PRECEDING
            ) AS SALDO_FINAL_DIA
        FROM
            TRANSACAO_ACUM
    )
SELECT
    DECIMAL(AVG(SALDO_FINAL_DIA), 18, 2) AS SALDO_MEDIO_DIARIO
FROM
    SALDO_DIA;

-- 4. Contas sem movimentação nos últimos 12 meses
SELECT
    c.ID AS CLIENTE_ID,
    c.NOME AS CLIENTE_NOME,
    co.AGENCIA,
    co.NUMERO
FROM
    CLIENTE c
    JOIN CONTA co ON co.CLIENTE_ID = c.ID
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            TRANSACAO t
        WHERE
            t.CONTA_ID = co.ID
            AND t.DATA >= (CURRENT TIMESTAMP - 12 MONTHS)
    )
ORDER BY
    co.AGENCIA,
    co.NUMERO;

-- 5. View VW_CLIENTE_SALDO
CREATE OR REPLACE VIEW VW_CLIENTE_SALDO AS
SELECT
    c.ID AS CLIENTE_ID,
    c.NOME AS CLIENTE_NOME,
    DECIMAL(SUM(co.SALDO), 18, 2) AS SALDO_TOTAL
FROM
    CLIENTE c
    JOIN CONTA co ON co.CLIENTE_ID = c.ID
GROUP BY
    c.ID,
    c.NOME;

Exemplo de consulta:
SELECT
    *
FROM
    VW_CLIENTE_SALDO
ORDER BY
    SALDO_TOTAL DESC
FETCH FIRST
    10 ROWS ONLY;