-- V003: Add display_name to users table
-- Supports MemberVM.Name and MemberVM.Initials across all pages.
-- NOT NULL with DEFAULT '' allows the migration to run on existing rows;
-- the application enforces a non-empty value at registration time.

SET NAMES utf8mb4;

ALTER TABLE users
  ADD COLUMN display_name VARCHAR(100) NOT NULL DEFAULT '' AFTER email;
