-- R__04: Recipe stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_recipe_find ──────────────────────────────────────────────────────────
-- Return a filtered list of recipes. Excludes recipes containing the user's
-- disliked ingredients and recipes the user has explicitly disliked.
-- Optional filters: cuisine, max_cook_time, free-text search.

CREATE OR REPLACE PROCEDURE sp_recipe_find(
  IN p_user_id             CHAR(36),
  IN p_cuisine             VARCHAR(100),
  IN p_max_cook_time       SMALLINT UNSIGNED,
  IN p_search_term         VARCHAR(255),
  IN p_limit               INT,
  IN p_offset              INT
)
SQL SECURITY DEFINER
BEGIN
  SELECT r.id, r.title, r.cuisine, r.cook_time_minutes, r.calories, r.protein_g
  FROM recipes r
  WHERE
    -- Exclude recipes the user has disliked
    NOT EXISTS (
      SELECT 1 FROM recipe_preferences rp
      WHERE rp.recipe_id = r.id
        AND rp.user_id = p_user_id
        AND rp.preference = 'dislike'
    )
    -- Exclude recipes containing the user's disliked ingredients
    AND NOT EXISTS (
      SELECT 1 FROM recipe_ingredients ri
      JOIN ingredient_dislikes id2 ON id2.ingredient_name = ri.name
      WHERE ri.recipe_id = r.id
        AND id2.user_id = p_user_id
    )
    -- Optional cuisine filter
    AND (p_cuisine IS NULL OR r.cuisine = p_cuisine)
    -- Optional cook time filter
    AND (p_max_cook_time IS NULL OR r.cook_time_minutes <= p_max_cook_time)
    -- Optional free-text search against title
    AND (p_search_term IS NULL OR r.title LIKE CONCAT('%', p_search_term, '%'))
  ORDER BY r.title
  LIMIT p_limit OFFSET p_offset;
END$$

-- ─── sp_recipe_get ───────────────────────────────────────────────────────────
-- Fetch full recipe detail including all ingredients.

CREATE OR REPLACE PROCEDURE sp_recipe_get(
  IN p_recipe_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  SELECT id, title, description, cuisine, cook_time_minutes, servings_base,
         calories, protein_g, carbs_g, fat_g, created_at
  FROM recipes
  WHERE id = p_recipe_id;

  SELECT id, recipe_id, name, quantity, unit, category
  FROM recipe_ingredients
  WHERE recipe_id = p_recipe_id
  ORDER BY category, name;
END$$

-- ─── sp_recipe_scale ─────────────────────────────────────────────────────────
-- Return ingredient quantities scaled to the participants of a given meal slot.
-- Scaling is goal-aware: each participant's calorie target determines their
-- individual portion. Assumes each meal accounts for 1/3 of daily calorie target.

CREATE OR REPLACE PROCEDURE sp_recipe_scale(
  IN p_recipe_id    CHAR(36),
  IN p_meal_slot_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_servings_base    TINYINT UNSIGNED;
  DECLARE v_recipe_calories  SMALLINT UNSIGNED;
  DECLARE v_cal_per_serving  DECIMAL(10,4);
  DECLARE v_total_servings   DECIMAL(10,4) DEFAULT 0;

  -- Cursor over participants and their targets
  DECLARE v_done            BOOLEAN DEFAULT FALSE;
  DECLARE v_participant_calories SMALLINT UNSIGNED;
  DECLARE cur_participants CURSOR FOR
    SELECT COALESCE(nt.calories, 2000)
    FROM meal_slot_participants msp
    LEFT JOIN nutritional_targets nt ON nt.user_id = msp.user_id
    WHERE msp.meal_slot_id = p_meal_slot_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

  SELECT servings_base, calories
  INTO v_servings_base, v_recipe_calories
  FROM recipes WHERE id = p_recipe_id;

  -- calories is total for the whole recipe (for servings_base servings)
  IF v_servings_base > 0 THEN
    SET v_cal_per_serving = v_recipe_calories / v_servings_base;
  ELSE
    SET v_cal_per_serving = v_recipe_calories;
  END IF;

  -- Sum each participant's needed servings (1/3 of daily target per meal)
  OPEN cur_participants;
  participant_loop: LOOP
    FETCH cur_participants INTO v_participant_calories;
    IF v_done THEN LEAVE participant_loop; END IF;
    IF v_cal_per_serving > 0 THEN
      SET v_total_servings = v_total_servings + ((v_participant_calories / 3.0) / v_cal_per_serving);
    ELSE
      SET v_total_servings = v_total_servings + 1;
    END IF;
  END LOOP;
  CLOSE cur_participants;

  -- If no participants, fall back to base servings
  IF v_total_servings = 0 THEN
    SET v_total_servings = v_servings_base;
  END IF;

  -- Return scaled ingredients
  SELECT
    ri.name AS ingredient_name,
    ROUND(ri.quantity * (v_total_servings / v_servings_base), 3) AS scaled_quantity,
    ri.unit,
    ri.category
  FROM recipe_ingredients ri
  WHERE ri.recipe_id = p_recipe_id
  ORDER BY ri.category, ri.name;
END$$

DELIMITER ;
