# Desafio Técnico - DB2 (Senior)

Bem-vindo(a)! Este é o desafio técnico para candidatos a vaga **DBA/Desenvolvedor Senior DB2**. O objetivo é avaliar sua capacidade de **modelagem**, **consultas SQL avançadas**, **performance** e **boas práticas** em DB2.

---

## 🎯 Contexto
Você trabalha em uma instituição financeira que precisa gerenciar **Clientes**, **Contas** e **Transações**. O banco de dados usado é **IBM DB2**.

---

## 🗄️ Estrutura Inicial
O schema inicial já está em `scripts/schema.sql` e contém as tabelas:
- **CLIENTE** (ID, NOME, CPF, DATA_CADASTRO)
- **CONTA** (ID, CLIENTE_ID, AGENCIA, NUMERO, SALDO)
- **TRANSACAO** (ID, CONTA_ID, DATA, TIPO, VALOR)

> Abaixo estão os **ajustes de modelagem**, **índices de performance**, **consultas** e **objetos de segurança** implementados para atender aos requisitos.



-#########################################################################################################--


## 📌 Desafios

### Parte 1 — Modelagem
**Objetivo:** Propor ajustes no schema para melhorar **normalização**, **performance** e **integridade**; e criar **índices** para consultas comuns.

#### 1.1 Ajustes de Integridade/Qualidade de Dados (`scripts/ajustes.sql`)
- **Validação de CPF** (11 dígitos numéricos):
Valida formato e evita lixo na base; regra de domínio deve residir no banco para impedir bypass por integrações.

```sql
ALTER TABLE CLIENTE
  ADD CONSTRAINT CK_CLIENTE_CPF_FMT
  CHECK (CPF BETWEEN '00000000000' AND '99999999999');


```
- **CPF único** (reforço por índice):
Reforça unicidade e acelera busca por CPF (cadastro/consulta)
```sql
CREATE UNIQUE INDEX UQ_CLIENTE_CPF ON CLIENTE (CPF);


```
- **Agência + Número únicos por conta** (evita duplicidade do par):
O par (agência,número) identifica a conta; garante integridade e melhora filtros por extrato.

```sql
CREATE UNIQUE INDEX UQ_CONTA_AGENCIA_NUMERO ON CONTA (AGENCIA, NUMERO);


```
- **Tipo de transação válido** (somente `CREDITO` ou `DEBITO`):
 Restringe domínio a `CREDITO`/`DEBITO`.

```sql
ALTER TABLE TRANSACAO
  ADD CONSTRAINT CK_TRANSACAO_TIPO
  CHECK (TIPO IN ('CREDITO','DEBITO'));
```

#### 1.2 Índices de Performance + Estatísticas (`scripts/indices.sql`)
- **Acelerar joins Cliente→Conta**:

```sql
CREATE INDEX IX_CONTA_CLIENTE        ON CONTA (CLIENTE_ID);

```
- **Extratos e buscas por conta e período**:

```sql
CREATE INDEX IX_TRANSACAO_CONTA_DATA ON TRANSACAO (CONTA_ID, DATA);


```
- **Atualização de estatísticas (otimizador)** — recomendada após carga/índices:
```sql
RUNSTATS ON TABLE CLIENTE   WITH DISTRIBUTION ON ALL COLUMNS AND SAMPLED DETAILED INDEXES ALL;
RUNSTATS ON TABLE CONTA     WITH DISTRIBUTION ON ALL COLUMNS AND SAMPLED DETAILED INDEXES ALL;
RUNSTATS ON TABLE TRANSACAO WITH DISTRIBUTION ON ALL COLUMNS AND SAMPLED DETAILED INDEXES ALL;
```

> **Justificativa:**
> - `IX_CONTA_CLIENTE` ajuda em relatórios por cliente (ex.: saldo consolidado, listagem de contas).
> - `IX_TRANSACAO_CONTA_DATA` sustenta **extrato**, **saldo médio no período** e **inatividade** (filtro por `CONTA_ID` + ordenação por `DATA`).
> - `RUNSTATS` garante plano de execução



-#########################################################################################################--



### Parte 2 — SQL Avançado (`scripts/queries.sql`)

#### 2.1 Top 10 clientes com maior saldo consolidado

 `DECIMAL(...,18,2)` padroniza escala financeira

```sql
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
    10 ROWS ONLY
```


#### 2.2 Extrato de conta com saldo acumulado
função janela `SUM() OVER(ORDER BY ...)` entrega saldo linha a linha; `t.ID` quebra empates de timestamp

```sql
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
    t.ID;

```



#### 2.3 Saldo médio diário em um período
```sql
WITH
    TRANSACAO_ACUM AS (
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
            AND t.DATA BETWEEN '2025-07-01' AND '2025-08-31'
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
```


#### 2.4 Contas sem movimentação nos últimos 12 meses
```sql
SELECT
    c.ID   AS CLIENTE_ID,
    c.NOME AS CLIENTE_NOME,
    co.AGENCIA,
    co.NUMERO
FROM 
    CLIENTE c
JOIN CONTA co ON co.CLIENTE_ID = c.ID
WHERE NOT EXISTS (
    SELECT 1
    FROM 
        TRANSACAO t
    WHERE 
        t.CONTA_ID = co.ID
        AND t.DATA >= (CURRENT TIMESTAMP - 12 MONTHS)
)
ORDER BY co.AGENCIA, co.NUMERO;
```



#### 2.5 View `VW_CLIENTE_SALDO`
A view consolida o saldo total de cada cliente (somando todas as contas vinculadas).

```sql
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
FETCH FIRST 10 ROWS ONLY;
```


-#########################################################################################################--



### Parte 3 — Procedimentos & Segurança (`scripts/seguranca.sql`)

#### 3.1 Procedure de transferência entre contas (com `COMMIT/ROLLBACK`)
```sql
CREATE OR REPLACE PROCEDURE SP_TRANSFERENCIA (
  IN P_CONTA_DE   INT,
  IN P_CONTA_PARA INT,
  IN P_VALOR      DECIMAL(15,2)
)
LANGUAGE SQL
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  INSERT INTO TRANSACAO (CONTA_ID, DATA, TIPO, VALOR)
  VALUES (P_CONTA_DE, CURRENT TIMESTAMP, 'DEBITO', P_VALOR);

  INSERT INTO TRANSACAO (CONTA_ID, DATA, TIPO, VALOR)
  VALUES (P_CONTA_PARA, CURRENT TIMESTAMP, 'CREDITO', P_VALOR);

  COMMIT;
END;
```


#### 3.2 Trigger para bloquear débito sem saldo suficiente
```sql
CREATE OR REPLACE TRIGGER TRG_DEBITO_SEM_SALDO
NO CASCADE BEFORE INSERT ON TRANSACAO
REFERENCING NEW AS N
FOR EACH ROW
BEGIN ATOMIC
  DECLARE SALDO_ATUAL DECIMAL(15,2);

  IF N.TIPO = 'DEBITO' THEN
    SET SALDO_ATUAL = (SELECT C.SALDO FROM CONTA C WHERE C.ID = N.CONTA_ID)
                      + COALESCE((SELECT SUM(T.VALOR) FROM TRANSACAO T WHERE T.CONTA_ID = N.CONTA_ID AND T.TIPO='CREDITO'), 0)
                      - COALESCE((SELECT SUM(T.VALOR) FROM TRANSACAO T WHERE T.CONTA_ID = N.CONTA_ID AND T.TIPO='DEBITO'), 0);

    IF SALDO_ATUAL < N.VALOR THEN
      SIGNAL SQLSTATE '75001'
        SET MESSAGE_TEXT = 'Débito bloqueado: saldo insuficiente.';
    END IF;
  END IF;
END;
```



#### 3.3 Auditoria: tabela de log + trigger
```sql
CREATE TABLE IF NOT EXISTS LOG_TRANSACAO (
  ID            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  CONTA_ID      INT           NOT NULL,
  TIPO          VARCHAR(10)   NOT NULL,
  VALOR         DECIMAL(15,2) NOT NULL,
  SALDO_ANTES   DECIMAL(15,2),
  SALDO_DEPOIS  DECIMAL(15,2),
  DATA_EVENTO   TIMESTAMP     NOT NULL DEFAULT CURRENT TIMESTAMP,
  ORIGEM        VARCHAR(64)   DEFAULT 'APP',
  OBS           VARCHAR(256)
);

CREATE OR REPLACE TRIGGER TRG_AUDITA_TRANSACAO
AFTER INSERT ON TRANSACAO
REFERENCING NEW AS N
FOR EACH ROW
BEGIN ATOMIC
  DECLARE S_ANTES  DECIMAL(15,2);
  DECLARE S_DEPOIS DECIMAL(15,2);

  SET S_DEPOIS = (SELECT SALDO FROM CONTA WHERE ID = N.CONTA_ID);
  SET S_ANTES  = CASE WHEN N.TIPO = 'CREDITO' THEN S_DEPOIS - N.VALOR
                      ELSE                         S_DEPOIS + N.VALOR
                 END;

  INSERT INTO LOG_TRANSACAO (CONTA_ID, TIPO, VALOR, SALDO_ANTES, SALDO_DEPOIS, ORIGEM)
  VALUES (N.CONTA_ID, N.TIPO, N.VALOR, S_ANTES, S_DEPOIS, 'APP');
END;
```



#### 3.4 Papéis e privilégios (opcional)
```sql
CREATE ROLE IF NOT EXISTS APP_USER;
CREATE ROLE IF NOT EXISTS AUDITOR;

GRANT SELECT, INSERT ON CLIENTE   TO ROLE APP_USER;
GRANT SELECT, INSERT ON CONTA     TO ROLE APP_USER;
GRANT SELECT, INSERT ON TRANSACAO TO ROLE APP_USER;

GRANT SELECT ON LOG_TRANSACAO TO ROLE AUDITOR;
```





