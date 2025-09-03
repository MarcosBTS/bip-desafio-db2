CONNECT TO DESAFIO@

------------------------------------------------------------------------
-- 1) TRIGGER: bloquear débito sem saldo suficiente
------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_DEBITO_SEM_SALDO
NO CASCADE BEFORE INSERT ON TRANSACAO
REFERENCING NEW AS N
FOR EACH ROW
BEGIN ATOMIC
  DECLARE SALDO_ATUAL DECIMAL(15,2);

  IF N.TIPO = 'DEBITO' THEN
    -- saldo base da conta
    SET SALDO_ATUAL = (SELECT C.SALDO FROM CONTA C WHERE C.ID = N.CONTA_ID);

    -- somas já registradas (créditos - débitos)
    SET SALDO_ATUAL = SALDO_ATUAL
      + COALESCE((SELECT SUM(T.VALOR) FROM TRANSACAO T WHERE T.CONTA_ID = N.CONTA_ID AND T.TIPO='CREDITO'), 0)
      - COALESCE((SELECT SUM(T.VALOR) FROM TRANSACAO T WHERE T.CONTA_ID = N.CONTA_ID AND T.TIPO='DEBITO'), 0);

    IF SALDO_ATUAL < N.VALOR THEN
      SIGNAL SQLSTATE '75001'
        SET MESSAGE_TEXT = 'Débito bloqueado: saldo insuficiente.';
    END IF;
  END IF;
END
@

------------------------------------------------------------------------
-- 2) TRIGGER: atualizar saldo da conta após cada transação
------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_ATUALIZA_SALDO
AFTER INSERT ON TRANSACAO
REFERENCING NEW AS N
FOR EACH ROW
BEGIN ATOMIC
  UPDATE CONTA
     SET SALDO = CASE
                   WHEN N.TIPO = 'CREDITO' THEN SALDO + N.VALOR
                   ELSE                            SALDO - N.VALOR
                 END
   WHERE ID = N.CONTA_ID;
END
@

------------------------------------------------------------------------
-- 3) PROCEDURE: transferência com COMMIT/ROLLBACK
------------------------------------------------------------------------
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

  -- débito (passa pelo trigger de saldo)
  INSERT INTO TRANSACAO (CONTA_ID, DATA, TIPO, VALOR)
  VALUES (P_CONTA_DE, CURRENT TIMESTAMP, 'DEBITO', P_VALOR);

  -- crédito
  INSERT INTO TRANSACAO (CONTA_ID, DATA, TIPO, VALOR)
  VALUES (P_CONTA_PARA, CURRENT TIMESTAMP, 'CREDITO', P_VALOR);

  COMMIT;
END
@

------------------------------------------------------------------------
-- 4) AUDITORIA: tabela de log + trigger
------------------------------------------------------------------------
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
)
@

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
END
@

------------------------------------------------------------------------
-- 5) (Opcional) Papéis e privilégios
------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS APP_USER
@
CREATE ROLE IF NOT EXISTS AUDITOR
@

GRANT SELECT, INSERT ON CLIENTE   TO ROLE APP_USER
@
GRANT SELECT, INSERT ON CONTA     TO ROLE APP_USER
@
GRANT SELECT, INSERT ON TRANSACAO TO ROLE APP_USER
@

GRANT SELECT ON LOG_TRANSACAO TO ROLE AUDITOR
@
