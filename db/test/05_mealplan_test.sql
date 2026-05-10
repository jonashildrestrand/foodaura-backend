-- 05_mealplan_test.sql: Meal plan stored procedure tests

SET @owner_id    = (SELECT id FROM users WHERE email = 'owner@test.com');
SET @member_id   = (SELECT id FROM users WHERE email = 'member@test.com');
SET @household_id = (SELECT id FROM households WHERE name = 'Test Household' LIMIT 1);
SET @recipe_a_id  = (SELECT id FROM recipes WHERE title = 'Test Chicken Bowl' LIMIT 1);

SELECT tap.plan(9);

-- Helper: delete a plan and all its children
-- We prefix plans with a comment to know which date to clean up per test.

-- ─── sp_mealplan_get_or_create — creates 28 slots ────────────────────────────

CALL sp_mealplan_get_or_create(@household_id, '2026-06-09', @owner_id);
SET @plan_id = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-06-09' LIMIT 1);
SELECT tap.eq(
  (SELECT COUNT(*) FROM meal_slots WHERE meal_plan_id = @plan_id),
  '28',
  'sp_mealplan_get_or_create: creates 28 slots (7 days × 4 meal types)'
);
DELETE FROM meal_plans WHERE id = @plan_id;

-- ─── sp_mealplan_get_or_create — all household members as participants ────────

CALL sp_mealplan_get_or_create(@household_id, '2026-06-16', @owner_id);
SET @plan_id = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-06-16' LIMIT 1);
SET @slot_id = (SELECT id FROM meal_slots WHERE meal_plan_id = @plan_id AND day_of_week = 0 AND meal_type = 'breakfast' LIMIT 1);
SELECT tap.eq(
  (SELECT COUNT(*) FROM meal_slot_participants WHERE meal_slot_id = @slot_id),
  '2',
  'sp_mealplan_get_or_create: all household members (2) added as default participants'
);
DELETE FROM meal_plans WHERE id = @plan_id;

-- ─── sp_mealplan_get_or_create — idempotent ──────────────────────────────────

CALL sp_mealplan_get_or_create(@household_id, '2026-06-23', @owner_id);
CALL sp_mealplan_get_or_create(@household_id, '2026-06-23', @owner_id);
SELECT tap.eq(
  (SELECT COUNT(*) FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-06-23'),
  '1',
  'sp_mealplan_get_or_create: idempotent — second call returns same plan'
);
DELETE FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-06-23';

-- ─── sp_mealplan_assign_recipe — recipe_id set on slot ───────────────────────

CALL sp_mealplan_get_or_create(@household_id, '2026-06-30', @owner_id);
SET @plan_id = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-06-30' LIMIT 1);
SET @slot_id = (SELECT id FROM meal_slots WHERE meal_plan_id = @plan_id AND day_of_week = 1 AND meal_type = 'dinner' LIMIT 1);
CALL sp_mealplan_assign_recipe(@slot_id, @recipe_a_id, JSON_ARRAY(@owner_id));
SELECT tap.eq(
  (SELECT recipe_id FROM meal_slots WHERE id = @slot_id),
  @recipe_a_id,
  'sp_mealplan_assign_recipe: recipe_id set on slot'
);
DELETE FROM meal_plans WHERE id = @plan_id;

-- ─── sp_mealplan_assign_recipe — participant list replaced ───────────────────

CALL sp_mealplan_get_or_create(@household_id, '2026-07-07', @owner_id);
SET @plan_id = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-07-07' LIMIT 1);
SET @slot_id = (SELECT id FROM meal_slots WHERE meal_plan_id = @plan_id AND day_of_week = 0 AND meal_type = 'lunch' LIMIT 1);
CALL sp_mealplan_assign_recipe(@slot_id, @recipe_a_id, JSON_ARRAY(@owner_id));
SELECT tap.eq(
  (SELECT COUNT(*) FROM meal_slot_participants WHERE meal_slot_id = @slot_id),
  '1',
  'sp_mealplan_assign_recipe: participant list replaced (1 participant)'
);
DELETE FROM meal_plans WHERE id = @plan_id;

-- ─── sp_mealplan_copy — copied slot has same recipe ──────────────────────────

CALL sp_mealplan_get_or_create(@household_id, '2026-07-14', @owner_id);
SET @src_plan = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-07-14' LIMIT 1);
SET @src_slot = (SELECT id FROM meal_slots WHERE meal_plan_id = @src_plan AND day_of_week = 0 AND meal_type = 'lunch' LIMIT 1);
CALL sp_mealplan_assign_recipe(@src_slot, @recipe_a_id, JSON_ARRAY(@owner_id));
CALL sp_mealplan_copy(@src_plan, '2026-07-21', @owner_id);
SET @dst_plan = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-07-21' LIMIT 1);
SET @dst_slot = (SELECT id FROM meal_slots WHERE meal_plan_id = @dst_plan AND day_of_week = 0 AND meal_type = 'lunch' LIMIT 1);
SELECT tap.eq(
  (SELECT recipe_id FROM meal_slots WHERE id = @dst_slot),
  @recipe_a_id,
  'sp_mealplan_copy: copied slot has same recipe_id as source'
);
DELETE FROM meal_plans WHERE id IN (@src_plan, @dst_plan);

-- ─── sp_mealplan_clear_slot — recipe_id set to NULL ──────────────────────────

CALL sp_mealplan_get_or_create(@household_id, '2026-07-28', @owner_id);
SET @plan_id = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-07-28' LIMIT 1);
SET @slot_id = (SELECT id FROM meal_slots WHERE meal_plan_id = @plan_id AND day_of_week = 2 AND meal_type = 'breakfast' LIMIT 1);
CALL sp_mealplan_assign_recipe(@slot_id, @recipe_a_id, JSON_ARRAY(@owner_id));
CALL sp_mealplan_clear_slot(@slot_id);
SELECT tap.ok(
  (SELECT recipe_id FROM meal_slots WHERE id = @slot_id) IS NULL,
  'sp_mealplan_clear_slot: recipe_id set to NULL'
);
DELETE FROM meal_plans WHERE id = @plan_id;

-- ─── sp_mealplan_get_history — most recent week first ───────────────────────

CALL sp_mealplan_get_or_create(@household_id, '2026-08-04', @owner_id);
CALL sp_mealplan_get_or_create(@household_id, '2026-08-11', @owner_id);
SELECT week_start_date INTO @first_week
FROM meal_plans WHERE household_id = @household_id ORDER BY week_start_date DESC LIMIT 1;
SELECT tap.eq(@first_week, '2026-08-11', 'sp_mealplan_get_history: most recent week returned first');
DELETE FROM meal_plans WHERE household_id = @household_id AND week_start_date IN ('2026-08-04', '2026-08-11');

-- ─── sp_mealplan_notify_ready — meal_plan_ready notification created ──────────

CALL sp_mealplan_get_or_create(@household_id, '2026-08-18', @owner_id);
SET @plan_id = (SELECT id FROM meal_plans WHERE household_id = @household_id AND week_start_date = '2026-08-18' LIMIT 1);
CALL sp_mealplan_notify_ready(@plan_id, @owner_id);
SELECT tap.ok(
  (SELECT COUNT(*) FROM notifications
   WHERE user_id = @owner_id AND type = 'meal_plan_ready'
     AND reference_id = @plan_id) = 1,
  'sp_mealplan_notify_ready: meal_plan_ready notification created for requesting user'
);
DELETE FROM meal_plans WHERE id = @plan_id;
CALL sp_notification_mark_all_read(@owner_id);

CALL tap.finish();
