-- R__11: Schedule template stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_schedule_template_upsert ─────────────────────────────────────────────
-- Set or update a member's attendance flag for a specific day + meal type.
-- Used to build the household's repeating weekly availability grid.

CREATE OR REPLACE PROCEDURE sp_schedule_template_upsert(
  IN p_household_id CHAR(36),
  IN p_user_id      CHAR(36),
  IN p_day_of_week  TINYINT UNSIGNED,
  IN p_meal_type    ENUM('breakfast','lunch','dinner','snack'),
  IN p_is_present   BOOLEAN
)
SQL SECURITY DEFINER
BEGIN
  IF p_day_of_week > 6 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'day_of_week must be 0 (Monday) to 6 (Sunday)';
  END IF;

  -- Verify the user is a member of the household
  IF NOT EXISTS (
    SELECT 1 FROM household_members
    WHERE household_id = p_household_id AND user_id = p_user_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: user is not a member of this household';
  END IF;

  INSERT INTO schedule_templates (household_id, user_id, day_of_week, meal_type, is_present)
  VALUES (p_household_id, p_user_id, p_day_of_week, p_meal_type, p_is_present)
  ON DUPLICATE KEY UPDATE is_present = p_is_present;
END$$

-- ─── sp_schedule_template_get ────────────────────────────────────────────────
-- Return all schedule template rows for a household.
-- Each row: user_id, day_of_week, meal_type, is_present.

CREATE OR REPLACE PROCEDURE sp_schedule_template_get(
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

  SELECT user_id, day_of_week, meal_type, is_present
  FROM schedule_templates
  WHERE household_id = p_household_id
  ORDER BY user_id, day_of_week, meal_type;
END$$

-- ─── sp_schedule_template_apply ──────────────────────────────────────────────
-- Apply the household's schedule template to an existing meal plan.
-- For each slot, replaces participants with those marked is_present = TRUE
-- for that day + meal_type. If no template row exists for a member, they are
-- included by default (present unless explicitly marked absent).

CREATE OR REPLACE PROCEDURE sp_schedule_template_apply(
  IN p_household_id       CHAR(36),
  IN p_meal_plan_id       CHAR(36),
  IN p_requesting_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_slot_id    CHAR(36);
  DECLARE v_day        TINYINT UNSIGNED;
  DECLARE v_meal_type  VARCHAR(20);
  DECLARE v_done       BOOLEAN DEFAULT FALSE;

  DECLARE cur_slots CURSOR FOR
    SELECT id, day_of_week, meal_type
    FROM meal_slots
    WHERE meal_plan_id = p_meal_plan_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

  -- Scope check
  IF NOT EXISTS (
    SELECT 1 FROM household_members
    WHERE household_id = p_household_id AND user_id = p_requesting_user_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: user is not a member of this household';
  END IF;

  OPEN cur_slots;
  slot_loop: LOOP
    FETCH cur_slots INTO v_slot_id, v_day, v_meal_type;
    IF v_done THEN LEAVE slot_loop; END IF;

    -- Replace participants: include members that are present (or have no template row → present by default)
    DELETE FROM meal_slot_participants WHERE meal_slot_id = v_slot_id;

    INSERT INTO meal_slot_participants (meal_slot_id, user_id)
    SELECT v_slot_id, hm.user_id
    FROM household_members hm
    LEFT JOIN schedule_templates st
      ON st.household_id = p_household_id
      AND st.user_id      = hm.user_id
      AND st.day_of_week  = v_day
      AND st.meal_type    = v_meal_type
    WHERE hm.household_id = p_household_id
      AND COALESCE(st.is_present, TRUE) = TRUE;
  END LOOP;
  CLOSE cur_slots;

  -- Regenerate shopping list to reflect new participants
  CALL sp_shoppinglist_derive(p_meal_plan_id);
END$$

DELIMITER ;
