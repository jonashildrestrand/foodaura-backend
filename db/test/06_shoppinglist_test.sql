-- 06_shoppinglist_test.sql: Shopping list stored procedure tests

SET @owner_id    = (SELECT id FROM users WHERE email = 'owner@test.com');
SET @household_id = (SELECT id FROM households WHERE name = 'Test Household' LIMIT 1);
SET @recipe_a_id  = (SELECT id FROM recipes WHERE title = 'Test Chicken Bowl' LIMIT 1);
SET @recipe_b_id  = (SELECT id FROM recipes WHERE title = 'Test Salad' LIMIT 1);

SELECT tap.plan(5);

-- ─── sp_shoppinglist_derive — same ingredient+unit consolidated ───────────────
-- Chicken Bowl:  broccoli 200g, chicken breast 500g, olive oil 20ml
-- Salad:         broccoli 150g, tomato 80g
-- broccoli → 350g total; 4 distinct items

CALL sp_mealplan_get_or_create(@household_id, '2026-08-18', @owner_id);
SET @plan_id = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-08-18' LIMIT 1);
SET @slot_a  = (SELECT id FROM meal_slots WHERE meal_plan_id = @plan_id AND day_of_week = 0 AND meal_type = 'lunch'  LIMIT 1);
SET @slot_b  = (SELECT id FROM meal_slots WHERE meal_plan_id = @plan_id AND day_of_week = 0 AND meal_type = 'dinner' LIMIT 1);
CALL sp_mealplan_assign_recipe(@slot_a, @recipe_a_id, JSON_ARRAY(@owner_id));
CALL sp_mealplan_assign_recipe(@slot_b, @recipe_b_id, JSON_ARRAY(@owner_id));

SELECT tap.eq(
  (SELECT total_quantity FROM shopping_list_items
   WHERE meal_plan_id = @plan_id AND ingredient_name = 'broccoli' AND unit = 'g'),
  '350.000',
  'sp_shoppinglist_derive: broccoli from two recipes consolidated to 350g'
);
SELECT tap.eq(
  (SELECT COUNT(*) FROM shopping_list_items
   WHERE meal_plan_id = @plan_id AND ingredient_name = 'chicken breast'),
  '1',
  'sp_shoppinglist_derive: chicken breast appears exactly once'
);
SELECT tap.eq(
  (SELECT COUNT(*) FROM shopping_list_items WHERE meal_plan_id = @plan_id),
  '4',
  'sp_shoppinglist_derive: 4 total items after consolidation'
);

DELETE FROM meal_plans WHERE id = @plan_id;

-- ─── sp_shoppinglist_toggle_item — is_checked flips ──────────────────────────

CALL sp_mealplan_get_or_create(@household_id, '2026-08-25', @owner_id);
SET @plan_id = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-08-25' LIMIT 1);
SET @slot_a  = (SELECT id FROM meal_slots WHERE meal_plan_id = @plan_id AND day_of_week = 0 AND meal_type = 'lunch' LIMIT 1);
CALL sp_mealplan_assign_recipe(@slot_a, @recipe_a_id, JSON_ARRAY(@owner_id));

SET @item_id = (SELECT id FROM shopping_list_items
  WHERE meal_plan_id = @plan_id AND ingredient_name = 'chicken breast' LIMIT 1);

CALL sp_shoppinglist_toggle_item(@item_id, TRUE);
SELECT tap.ok(
  (SELECT is_checked FROM shopping_list_items WHERE id = @item_id) = TRUE,
  'sp_shoppinglist_toggle_item: is_checked set to TRUE'
);

CALL sp_shoppinglist_toggle_item(@item_id, FALSE);
SELECT tap.ok(
  (SELECT is_checked FROM shopping_list_items WHERE id = @item_id) = FALSE,
  'sp_shoppinglist_toggle_item: is_checked toggled back to FALSE'
);

DELETE FROM meal_plans WHERE id = @plan_id;

CALL tap.finish();
