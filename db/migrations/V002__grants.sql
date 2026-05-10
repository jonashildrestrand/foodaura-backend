-- V002: Provision application database users (no direct table access).
-- Passwords are injected via Flyway placeholders from environment variables.
-- See .env.example for required env vars: FOODAURA_BACKEND_DB_PASSWORD, FOODAURA_AI_DB_PASSWORD
--
-- EXECUTE grants are in R__99_grants.sql (repeatable) so they run after stored
-- procedures are created and can be updated without a new versioned migration.

SET NAMES utf8mb4;

CREATE USER IF NOT EXISTS 'foodaura_backend'@'%' IDENTIFIED BY '${FOODAURA_BACKEND_DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'foodaura_ai'@'%'      IDENTIFIED BY '${FOODAURA_AI_DB_PASSWORD}';
