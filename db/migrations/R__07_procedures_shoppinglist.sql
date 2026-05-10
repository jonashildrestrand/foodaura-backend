-- R__07: Shopping list stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_shoppinglist_derive ──────────────────────────────────────────────────
-- Generate or regenerate the shopping list for a meal plan.
-- Uses participant-scaled quantities via the same formula as sp_recipe_scale:
--   scale_factor = SUM(participant_calories) / (3.0 * recipe_calories)
-- Groups scaled quantities by (ingredient_name, unit). Preserves is_checked
-- state for items that still appear after regeneration.

CREATE OR REPLACE PROCEDURE sp_shoppinglist_derive(
  IN p_meal_plan_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  -- Capture currently-checked items before wiping the list
  CREATE TEMPORARY TABLE IF NOT EXISTS _tmp_checked_items (
    ingredient_name VARCHAR(255) NOT NULL,
    unit            VARCHAR(50)  NOT NULL,
    PRIMARY KEY (ingredient_name, unit)
  );

  DELETE FROM _tmp_checked_items;

  INSERT INTO _tmp_checked_items (ingredient_name, unit)
  SELECT ingredient_name, unit
  FROM shopping_list_items
  WHERE meal_plan_id = p_meal_plan_id AND is_checked = TRUE;

  -- Delete current shopping list
  DELETE FROM shopping_list_items WHERE meal_plan_id = p_meal_plan_id;

  -- Rebuild with participant-scaled quantities
  -- scale_factor per slot = SUM(participant_calories) / (3.0 * recipe_calories)
  -- Falls back to 1.0 when recipe_calories = 0 or slot has no participants.
  INSERT INTO shopping_list_items (id, meal_plan_id, ingredient_name, total_quantity, unit, category, is_checked)
  SELECT
    UUID(),
    p_meal_plan_id,
    ri.name,
    ROUND(SUM(
      ri.quantity * CASE
        WHEN r.calories > 0 THEN
          COALESCE(
            (SELECT SUM(COALESCE(nt.calories, 2000)) / (3.0 * r.calories)
             FROM meal_slot_participants msp
             LEFT JOIN nutritional_targets nt ON nt.user_id = msp.user_id
             WHERE msp.meal_slot_id = ms.id),
            1.0
          )
        ELSE 1.0
      END
    ), 3) AS total_quantity,
    ri.unit,
    ri.category,
    IF(tc.ingredient_name IS NOT NULL, TRUE, FALSE) AS is_checked
  FROM meal_slots ms
  JOIN recipes r ON r.id = ms.recipe_id
  JOIN recipe_ingredients ri ON ri.recipe_id = ms.recipe_id
  LEFT JOIN _tmp_checked_items tc ON tc.ingredient_name = ri.name AND tc.unit = ri.unit
  WHERE ms.meal_plan_id = p_meal_plan_id
    AND ms.recipe_id IS NOT NULL
  GROUP BY ri.name, ri.unit, ri.category, tc.ingredient_name;
END$$

-- ─── sp_shoppinglist_get ─────────────────────────────────────────────────────
-- Fetch the shopping list for a meal plan, ordered by category then ingredient name.
-- Scoped to the requesting user's household.

CREATE OR REPLACE PROCEDURE sp_shoppinglist_get(
  IN p_meal_plan_id       CHAR(36),
  IN p_requesting_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  -- Scope check: requesting user must belong to the plan's household
  IF NOT EXISTS (
    SELECT 1 FROM meal_plans mp
    JOIN household_members hm ON hm.household_id = mp.household_id
    WHERE mp.id = p_meal_plan_id AND hm.user_id = p_requesting_user_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: user is not a member of this household';
  END IF;

  SELECT id, meal_plan_id, ingredient_name, total_quantity, unit, category, is_checked, created_at
  FROM shopping_list_items
  WHERE meal_plan_id = p_meal_plan_id
  ORDER BY category, ingredient_name;
END$$

-- ─── sp_shoppinglist_toggle_item ─────────────────────────────────────────────
-- Set the is_checked state of a shopping list item.

CREATE OR REPLACE PROCEDURE sp_shoppinglist_toggle_item(
  IN p_item_id    CHAR(36),
  IN p_is_checked BOOLEAN
)
SQL SECURITY DEFINER
BEGIN
  UPDATE shopping_list_items
  SET is_checked = p_is_checked
  WHERE id = p_item_id;
END$$

DELIMITER ;
