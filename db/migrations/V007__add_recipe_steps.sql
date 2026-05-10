-- V007: Add recipe_steps table for step-by-step cooking instructions.
-- sp_recipe_get is updated (in R__04) to return steps as a third result set.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS recipe_steps (
  id          CHAR(36)         NOT NULL DEFAULT (UUID()),
  recipe_id   CHAR(36)         NOT NULL,
  step_number TINYINT UNSIGNED NOT NULL,
  instruction TEXT             NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_rs_recipe_step (recipe_id, step_number),
  CONSTRAINT fk_rs_recipe FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
