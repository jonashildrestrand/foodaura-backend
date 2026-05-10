-- R__06: Meal plan stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_mealplan_get_or_create ───────────────────────────────────────────────
-- Return the meal plan for a household + week, creating it if it doesn't exist.
-- New plans get 28 slots (7 days × 4 meal types). All household members are
-- added as default participants on every slot.

CREATE OR REPLACE PROCEDURE sp_mealplan_get_or_create(
  IN  p_household_id       CHAR(36),
  IN  p_week_start_date    DATE,
  IN  p_requesting_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_plan_id   CHAR(36);
  DECLARE v_slot_id   CHAR(36);
  DECLARE v_day       TINYINT UNSIGNED;
  DECLARE v_meal_idx  TINYINT UNSIGNED;
  DECLARE v_meal_type VARCHAR(20);

  -- Scope check: requesting user must be a household member
  IF NOT EXISTS (
    SELECT 1 FROM household_members
    WHERE household_id = p_household_id AND user_id = p_requesting_user_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: user is not a member of this household';
  END IF;

  -- Return existing plan if present
  SELECT id INTO v_plan_id
  FROM meal_plans
  WHERE household_id = p_household_id AND week_start_date = p_week_start_date
  LIMIT 1;

  IF v_plan_id IS NULL THEN
    SET v_plan_id = UUID();

    INSERT INTO meal_plans (id, household_id, week_start_date)
    VALUES (v_plan_id, p_household_id, p_week_start_date);

    -- Create 28 slots: 7 days × 4 meal types
    SET v_day = 0;
    WHILE v_day <= 6 DO
      SET v_meal_idx = 0;
      WHILE v_meal_idx <= 3 DO
        SET v_meal_type = CASE v_meal_idx
          WHEN 0 THEN 'breakfast'
          WHEN 1 THEN 'lunch'
          WHEN 2 THEN 'dinner'
          ELSE        'snack'
        END;

        SET v_slot_id = UUID();

        INSERT INTO meal_slots (id, meal_plan_id, day_of_week, meal_type)
        VALUES (v_slot_id, v_plan_id, v_day, v_meal_type);

        -- Add all household members as default participants
        INSERT INTO meal_slot_participants (meal_slot_id, user_id)
        SELECT v_slot_id, user_id
        FROM household_members
        WHERE household_id = p_household_id;

        SET v_meal_idx = v_meal_idx + 1;
      END WHILE;
      SET v_day = v_day + 1;
    END WHILE;
  END IF;

  SELECT v_plan_id AS meal_plan_id;
END$$

-- ─── sp_mealplan_get ─────────────────────────────────────────────────────────
-- Fetch a full meal plan: plan row, all slots with recipe info, and participants.
-- Scoped to the requesting user's household.

CREATE OR REPLACE PROCEDURE sp_mealplan_get(
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

  -- Meal plan header
  SELECT id, household_id, week_start_date, created_at
  FROM meal_plans
  WHERE id = p_meal_plan_id;

  -- Slots with recipe summary
  SELECT ms.id, ms.day_of_week, ms.meal_type, ms.recipe_id,
         r.title AS recipe_title, r.calories AS recipe_calories
  FROM meal_slots ms
  LEFT JOIN recipes r ON r.id = ms.recipe_id
  WHERE ms.meal_plan_id = p_meal_plan_id
  ORDER BY ms.day_of_week, ms.meal_type;

  -- Participants per slot
  SELECT msp.meal_slot_id, msp.user_id, u.email
  FROM meal_slot_participants msp
  JOIN meal_slots ms ON ms.id = msp.meal_slot_id
  JOIN users u ON u.id = msp.user_id
  WHERE ms.meal_plan_id = p_meal_plan_id
  ORDER BY msp.meal_slot_id;
END$$

-- ─── sp_mealplan_assign_recipe ───────────────────────────────────────────────
-- Assign a recipe to a meal slot and set the participant list.
-- Replaces any existing assignment. Regenerates the shopping list for the plan.

CREATE OR REPLACE PROCEDURE sp_mealplan_assign_recipe(
  IN p_meal_slot_id         CHAR(36),
  IN p_recipe_id            CHAR(36),
  IN p_participant_user_ids JSON
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_meal_plan_id CHAR(36);

  SELECT meal_plan_id INTO v_meal_plan_id
  FROM meal_slots WHERE id = p_meal_slot_id;

  -- Set recipe on slot
  UPDATE meal_slots SET recipe_id = p_recipe_id WHERE id = p_meal_slot_id;

  -- Replace participants
  DELETE FROM meal_slot_participants WHERE meal_slot_id = p_meal_slot_id;

  INSERT INTO meal_slot_participants (meal_slot_id, user_id)
  SELECT p_meal_slot_id, jt.user_id
  FROM JSON_TABLE(p_participant_user_ids, '$[*]' COLUMNS(user_id CHAR(36) PATH '$')) jt;

  -- Regenerate shopping list
  CALL sp_shoppinglist_derive(v_meal_plan_id);
END$$

-- ─── sp_mealplan_clear_slot ──────────────────────────────────────────────────
-- Remove the recipe and all participants from a meal slot, leaving it empty.
-- Regenerates the shopping list for the parent plan.

CREATE OR REPLACE PROCEDURE sp_mealplan_clear_slot(
  IN p_meal_slot_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_meal_plan_id CHAR(36);

  SELECT meal_plan_id INTO v_meal_plan_id
  FROM meal_slots WHERE id = p_meal_slot_id;

  UPDATE meal_slots SET recipe_id = NULL WHERE id = p_meal_slot_id;
  DELETE FROM meal_slot_participants WHERE meal_slot_id = p_meal_slot_id;

  CALL sp_shoppinglist_derive(v_meal_plan_id);
END$$

-- ─── sp_mealplan_get_history ─────────────────────────────────────────────────
-- Return all meal plans for a household, most recent first.

CREATE OR REPLACE PROCEDURE sp_mealplan_get_history(
  IN p_household_id       CHAR(36),
  IN p_requesting_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM household_members
    WHERE household_id = p_household_id AND user_id = p_requesting_user_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: user is not a member of this household';
  END IF;

  SELECT id AS meal_plan_id, week_start_date
  FROM meal_plans
  WHERE household_id = p_household_id
  ORDER BY week_start_date DESC;
END$$

-- ─── sp_mealplan_copy ────────────────────────────────────────────────────────
-- Copy all slots (recipe + participants) from a source plan into a new plan
-- for a given target week. Returns the new meal_plan_id.

CREATE OR REPLACE PROCEDURE sp_mealplan_copy(
  IN  p_source_meal_plan_id    CHAR(36),
  IN  p_target_week_start_date DATE,
  IN  p_requesting_user_id     CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_household_id   CHAR(36);
  DECLARE v_new_plan_id    CHAR(36);
  DECLARE v_done           BOOLEAN DEFAULT FALSE;
  DECLARE v_src_slot_id    CHAR(36);
  DECLARE v_day_of_week    TINYINT UNSIGNED;
  DECLARE v_meal_type      VARCHAR(20);
  DECLARE v_recipe_id      CHAR(36);
  DECLARE v_new_slot_id    CHAR(36);

  DECLARE cur_slots CURSOR FOR
    SELECT id, day_of_week, meal_type, recipe_id
    FROM meal_slots
    WHERE meal_plan_id = p_source_meal_plan_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

  SELECT household_id INTO v_household_id
  FROM meal_plans WHERE id = p_source_meal_plan_id;

  -- Scope check
  IF NOT EXISTS (
    SELECT 1 FROM household_members
    WHERE household_id = v_household_id AND user_id = p_requesting_user_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: user is not a member of this household';
  END IF;

  -- Create target plan (INSERT IGNORE so existing plans are not overwritten)
  SET v_new_plan_id = UUID();
  INSERT IGNORE INTO meal_plans (id, household_id, week_start_date)
  VALUES (v_new_plan_id, v_household_id, p_target_week_start_date);

  -- Fetch the actual plan id (may have been pre-existing)
  SELECT id INTO v_new_plan_id
  FROM meal_plans
  WHERE household_id = v_household_id AND week_start_date = p_target_week_start_date;

  -- Copy each source slot into the target plan
  OPEN cur_slots;
  slot_loop: LOOP
    FETCH cur_slots INTO v_src_slot_id, v_day_of_week, v_meal_type, v_recipe_id;
    IF v_done THEN LEAVE slot_loop; END IF;

    SET v_new_slot_id = UUID();

    -- Insert slot (IGNORE if already exists for this day+meal_type combination)
    INSERT IGNORE INTO meal_slots (id, meal_plan_id, day_of_week, meal_type, recipe_id)
    VALUES (v_new_slot_id, v_new_plan_id, v_day_of_week, v_meal_type, v_recipe_id);

    -- Resolve the actual slot id (handles pre-existing slots)
    SELECT id INTO v_new_slot_id
    FROM meal_slots
    WHERE meal_plan_id = v_new_plan_id
      AND day_of_week = v_day_of_week
      AND meal_type   = v_meal_type;

    -- Update recipe on pre-existing slots
    UPDATE meal_slots SET recipe_id = v_recipe_id WHERE id = v_new_slot_id;

    -- Copy participants
    DELETE FROM meal_slot_participants WHERE meal_slot_id = v_new_slot_id;
    INSERT INTO meal_slot_participants (meal_slot_id, user_id)
    SELECT v_new_slot_id, user_id
    FROM meal_slot_participants
    WHERE meal_slot_id = v_src_slot_id;
  END LOOP;
  CLOSE cur_slots;

  -- Derive shopping list for the new plan
  CALL sp_shoppinglist_derive(v_new_plan_id);

  SELECT v_new_plan_id AS meal_plan_id;
END$$

-- ─── sp_mealplan_notify_ready ────────────────────────────────────────────────
-- Create a meal_plan_ready notification for the user who requested AI generation.
-- Called by the backend after the AI service returns and the plan has been saved.

CREATE OR REPLACE PROCEDURE sp_mealplan_notify_ready(
  IN p_meal_plan_id CHAR(36),
  IN p_user_id      CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_week_start DATE;

  SELECT week_start_date INTO v_week_start
  FROM meal_plans WHERE id = p_meal_plan_id;

  IF v_week_start IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'meal plan not found';
  END IF;

  CALL sp_notification_create(
    p_user_id,
    'meal_plan_ready',
    'Your meal plan is ready',
    CONCAT('Your meal plan for the week of ', v_week_start, ' has been generated'),
    'meal_plan',
    p_meal_plan_id
  );
END$$

DELIMITER ;
