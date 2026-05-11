-- V008: Add goals and diet_types reference tables
-- Replaces ENUM constraints on nutritional_profiles with proper FK-backed reference tables.
-- Single source of truth for UI options and validation.

SET NAMES utf8mb4;

-- ─── Reference tables ────────────────────────────────────────────────────────

CREATE TABLE goals (
  value      VARCHAR(50)  NOT NULL,
  label      VARCHAR(100) NOT NULL,
  icon       VARCHAR(50)  NOT NULL DEFAULT '',
  sort_order TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

INSERT INTO goals (value, label, icon, sort_order) VALUES
  ('lose_weight',  'Lose Weight',     'trending-down', 1),
  ('maintain',     'Maintain Weight', 'minus',         2),
  ('build_muscle', 'Build Muscle',    'dumbbell',      3),
  ('eat_better',   'Eat Better',      'leaf',          4);

CREATE TABLE diet_types (
  value      VARCHAR(50)  NOT NULL,
  label      VARCHAR(100) NOT NULL,
  sort_order TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

INSERT INTO diet_types (value, label, sort_order) VALUES
  ('omnivore',    'Omnivore',    1),
  ('pescatarian', 'Pescatarian', 2),
  ('vegetarian',  'Vegetarian',  3),
  ('vegan',       'Vegan',       4);

-- ─── Migrate nutritional_profiles ────────────────────────────────────────────

ALTER TABLE nutritional_profiles
  MODIFY COLUMN goal      VARCHAR(50) NOT NULL DEFAULT 'eat_better',
  MODIFY COLUMN diet_type VARCHAR(50) NOT NULL DEFAULT 'omnivore';

ALTER TABLE nutritional_profiles
  ADD CONSTRAINT fk_profiles_goal      FOREIGN KEY (goal)      REFERENCES goals(value),
  ADD CONSTRAINT fk_profiles_diet_type FOREIGN KEY (diet_type) REFERENCES diet_types(value);
