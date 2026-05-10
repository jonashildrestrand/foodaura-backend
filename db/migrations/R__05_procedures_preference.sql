-- R__05: Recipe preference stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_preference_set_recipe ────────────────────────────────────────────────
-- Set or update a like or dislike for a recipe. Replaces any existing preference.

CREATE OR REPLACE PROCEDURE sp_preference_set_recipe(
  IN p_user_id    CHAR(36),
  IN p_recipe_id  CHAR(36),
  IN p_preference ENUM('like', 'dislike')
)
SQL SECURITY DEFINER
BEGIN
  INSERT INTO recipe_preferences (id, user_id, recipe_id, preference)
  VALUES (UUID(), p_user_id, p_recipe_id, p_preference)
  ON DUPLICATE KEY UPDATE preference = p_preference;
END$$

-- ─── sp_preference_add_ingredient_dislike ────────────────────────────────────
-- Add an ingredient dislike for a user. Idempotent — no error on duplicate.

CREATE OR REPLACE PROCEDURE sp_preference_add_ingredient_dislike(
  IN p_user_id         CHAR(36),
  IN p_ingredient_name VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
  INSERT IGNORE INTO ingredient_dislikes (id, user_id, ingredient_name)
  VALUES (UUID(), p_user_id, p_ingredient_name);
END$$

-- ─── sp_preference_remove_ingredient_dislike ─────────────────────────────────
-- Remove an ingredient dislike for a user.

CREATE OR REPLACE PROCEDURE sp_preference_remove_ingredient_dislike(
  IN p_user_id         CHAR(36),
  IN p_ingredient_name VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
  DELETE FROM ingredient_dislikes
  WHERE user_id = p_user_id AND ingredient_name = p_ingredient_name;
END$$

DELIMITER ;
