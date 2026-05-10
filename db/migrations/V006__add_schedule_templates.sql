-- V006: Add weekly schedule templates table
-- Stores per-member meal-slot availability to pre-populate meal plan participants.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS schedule_templates (
  id           CHAR(36)                                   NOT NULL DEFAULT (UUID()),
  household_id CHAR(36)                                   NOT NULL,
  user_id      CHAR(36)                                   NOT NULL,
  day_of_week  TINYINT UNSIGNED                           NOT NULL,  -- 0=Monday … 6=Sunday
  meal_type    ENUM('breakfast','lunch','dinner','snack') NOT NULL,
  is_present   BOOLEAN                                    NOT NULL DEFAULT TRUE,
  PRIMARY KEY (household_id, user_id, day_of_week, meal_type),
  CONSTRAINT fk_st_household FOREIGN KEY (household_id) REFERENCES households (id) ON DELETE CASCADE,
  CONSTRAINT fk_st_user      FOREIGN KEY (user_id)      REFERENCES users      (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
