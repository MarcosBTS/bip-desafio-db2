# Desafio Técnico - DB2 (Senior)

Bem-vindo(a)! Este é o desafio técnico para candidatos a vaga **DBA/Desenvolvedor Senior DB2**.  
O objetivo é avaliar sua capacidade de **modelagem, consultas SQL avançadas, performance e boas práticas em DB2**.

## 🎯 Contexto

Você trabalha em uma instituição financeira que precisa gerenciar **Clientes, Contas e Transações**.  
O banco de dados usado é **IBM DB2**.

## 🗄️ Estrutura Inicial

O schema inicial já está em `scripts/schema.sql`.  
Ele contém as tabelas: CLIENTE, CONTA, TRANSACAO.

## 📌 Desafios

### Parte 1 - Modelagem
1. Proponha ajustes no schema para melhorar **normalização, performance e integridade**.
2. Crie índices que justifiquem melhorias de performance em consultas comuns.

### Parte 2 - SQL Avançado
Implemente as queries no arquivo `scripts/queries.sql`:
- Top 10 clientes com maior saldo consolidado.
- Extrato de conta com saldo acumulado.
- Saldo médio diário em um período.
- Contas sem movimentação nos últimos 12 meses.
- View VW_CLIENTE_SALDO.

### Parte 3 - Procedimentos & Segurança
1. Procedure de transferência entre contas (commit/rollback).
2. Trigger para bloquear débito sem saldo suficiente.
3. Estratégias de auditoria (logs, histórico).

## ✅ O que será avaliado
- Modelagem & integridade (20%)
- Consultas SQL (25%)
- Performance & índices (15%)
- Procedures & triggers (20%)
- Segurança & auditoria (10%)
- Documentação (10%)

## 🚀 Instruções
1. Faça um fork deste repositório.
2. Complete os arquivos em `scripts/`.
3. Documente decisões no README.
4. Abra um Pull Request.
