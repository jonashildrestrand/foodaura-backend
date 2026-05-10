-- R__04: Recipe stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_recipe_find ──────────────────────────────────────────────────────────
-- Return a filtered list of recipes. Excludes recipes containing the user's
-- disliked ingredients, recipes the user has explicitly disliked, and recipes
-- incompatible with the user's diet_type.
--
-- Optional filters: cuisine, max_cook_time, tag_id, free-text search (title
-- and ingredient name). Returns two result sets:
--   1. Recipe rows (id, title, cuisine, cook_time_minutes, servings_base, calories, protein_g)
--   2. Tags for all returned recipes (recipe_id, tag_id, category, tag_name)

CREATE OR REPLACE PROCEDURE sp_recipe_find(
  IN p_user_id             CHAR(36),
  IN p_cuisine             VARCHAR(100),
  IN p_max_cook_time       SMALLINT UNSIGNED,
  IN p_search_term         VARCHAR(255),
  IN p_tag_id              CHAR(36),
  IN p_limit               INT,
  IN p_offset              INT
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_diet_type ENUM('omnivore','vegetarian','vegan','pescatarian') DEFAULT 'omnivore';

  SELECT COALESCE(diet_type, 'omnivore') INTO v_diet_type
  FROM nutritional_profiles
  WHERE user_id = p_user_id
  LIMIT 1;

  -- Temp table to hold the page of recipe IDs, enabling tag join without repeating WHERE
  CREATE TEMPORARY TABLE IF NOT EXISTS _tmp_recipe_find (
    recipe_id CHAR(36) NOT NULL,
    PRIMARY KEY (recipe_id)
  );
  DELETE FROM _tmp_recipe_find;

  INSERT INTO _tmp_recipe_find (recipe_id)
  SELECT r.id
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
      SELECT 1 FROM recipe_ingredients ri2
      JOIN ingredient_dislikes id2 ON id2.ingredient_name = ri2.name
      WHERE ri2.recipe_id = r.id
        AND id2.user_id = p_user_id
    )
    -- diet_type filtering: exclude structurally incompatible recipes
    AND (
      v_diet_type = 'omnivore'
      OR (v_diet_type = 'pescatarian' AND NOT EXISTS (
        SELECT 1 FROM recipe_ingredients ri3
        WHERE ri3.recipe_id = r.id
          AND ri3.name REGEXP '(?i)beef|chicken|pork|lamb|turkey|veal|bacon|ham|sausage|duck|venison|bison'
      ))
      OR (v_diet_type = 'vegetarian' AND NOT EXISTS (
        SELECT 1 FROM recipe_ingredients ri3
        WHERE ri3.recipe_id = r.id
          AND ri3.name REGEXP '(?i)beef|chicken|pork|lamb|turkey|veal|bacon|ham|sausage|duck|venison|bison|salmon|tuna|shrimp|prawn|fish|seafood|anchov'
      ))
      OR (v_diet_type = 'vegan' AND NOT EXISTS (
        SELECT 1 FROM recipe_ingredients ri3
        WHERE ri3.recipe_id = r.id
          AND (
            ri3.category = 'dairy'
            OR ri3.name REGEXP '(?i)beef|chicken|pork|lamb|turkey|veal|bacon|ham|sausage|duck|venison|bison|salmon|tuna|shrimp|prawn|fish|seafood|anchov|egg|honey|cream cheese|butter|milk|yogurt|cheese'
          )
      ))
    )
    -- Optional cuisine filter
    AND (p_cuisine IS NULL OR r.cuisine = p_cuisine)
    -- Optional cook time filter
    AND (p_max_cook_time IS NULL OR r.cook_time_minutes <= p_max_cook_time)
    -- Optional tag filter
    AND (p_tag_id IS NULL OR EXISTS (
      SELECT 1 FROM recipe_tags rt
      WHERE rt.recipe_id = r.id AND rt.tag_id = p_tag_id
    ))
    -- Optional free-text search: title or ingredient name
    AND (
      p_search_term IS NULL
      OR r.title LIKE CONCAT('%', p_search_term, '%')
      OR EXISTS (
        SELECT 1 FROM recipe_ingredients ri4
        WHERE ri4.recipe_id = r.id
          AND ri4.name LIKE CONCAT('%', p_search_term, '%')
      )
    )
  ORDER BY r.title
  LIMIT p_limit OFFSET p_offset;

  -- Result set 1: recipe rows
  SELECT r.id, r.title, r.cuisine, r.cook_time_minutes, r.servings_base, r.calories, r.protein_g
  FROM recipes r
  JOIN _tmp_recipe_find tmp ON tmp.recipe_id = r.id
  ORDER BY r.title;

  -- Result set 2: tags for all returned recipes
  SELECT rt.recipe_id, t.id AS tag_id, tc.name AS category, t.name AS tag_name
  FROM recipe_tags rt
  JOIN tags t ON t.id = rt.tag_id
  JOIN tag_categories tc ON tc.id = t.category_id
  JOIN _tmp_recipe_find tmp ON tmp.recipe_id = rt.recipe_id
  ORDER BY rt.recipe_id, t.name;
END$$

-- ─── sp_recipe_get ───────────────────────────────────────────────────────────
-- Fetch full recipe detail including ingredients and step-by-step instructions.
-- Returns three result sets:
--   1. Recipe header row
--   2. Ingredients (ordered by category, name)
--   3. Steps (ordered by step_number)

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

  SELECT id, step_number, instruction
  FROM recipe_steps
  WHERE recipe_id = p_recipe_id
  ORDER BY step_number;
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
  DECLARE v_done                 BOOLEAN DEFAULT FALSE;
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

-- ─── sp_tag_category_list ────────────────────────────────────────────────────
-- Return all tag categories, ordered by name.

CREATE OR REPLACE PROCEDURE sp_tag_category_list()
SQL SECURITY DEFINER
BEGIN
  SELECT id, name FROM tag_categories ORDER BY name;
END$$

-- ─── sp_tag_list ─────────────────────────────────────────────────────────────
-- Return all tags, optionally filtered by category. Used to populate discover
-- filter chips. Passing NULL for p_category_id returns all tags.

CREATE OR REPLACE PROCEDURE sp_tag_list(
  IN p_category_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  SELECT t.id, t.name, tc.name AS category_name
  FROM tags t
  JOIN tag_categories tc ON tc.id = t.category_id
  WHERE (p_category_id IS NULL OR t.category_id = p_category_id)
  ORDER BY tc.name, t.name;
END$$

-- ─── sp_recipe_tags_set ──────────────────────────────────────────────────────
-- Replace all tags on a recipe with the provided set.
-- p_tag_ids: JSON array of tag UUIDs, e.g. '["uuid1","uuid2"]'

CREATE OR REPLACE PROCEDURE sp_recipe_tags_set(
  IN p_recipe_id CHAR(36),
  IN p_tag_ids   JSON
)
SQL SECURITY DEFINER
BEGIN
  -- Remove existing tags
  DELETE FROM recipe_tags WHERE recipe_id = p_recipe_id;

  -- Insert new tags
  INSERT IGNORE INTO recipe_tags (recipe_id, tag_id)
  SELECT p_recipe_id, jt.tag_id
  FROM JSON_TABLE(p_tag_ids, '$[*]' COLUMNS(tag_id CHAR(36) PATH '$')) jt;
END$$

DELIMITER ;
