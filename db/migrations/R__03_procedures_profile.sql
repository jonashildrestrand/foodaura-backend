-- R__03: Profile and nutritional target stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_profile_upsert ───────────────────────────────────────────────────────
-- Create or update a user's nutritional profile.
-- The trg_nutritional_profiles_after_upsert trigger fires after this to recalculate targets.

CREATE OR REPLACE PROCEDURE sp_profile_upsert(
  IN p_user_id        CHAR(36),
  IN p_biological_sex ENUM('male', 'female'),
  IN p_age            TINYINT UNSIGNED,
  IN p_weight_kg      DECIMAL(5,2),
  IN p_height_cm      DECIMAL(5,2),
  IN p_activity_level ENUM('sedentary', 'light', 'moderate', 'active', 'very_active'),
  IN p_goal           ENUM('lose_weight', 'maintain', 'build_muscle', 'eat_better')
)
SQL SECURITY DEFINER
BEGIN
  INSERT INTO nutritional_profiles
    (id, user_id, biological_sex, age, weight_kg, height_cm, activity_level, goal)
  VALUES
    (UUID(), p_user_id, p_biological_sex, p_age, p_weight_kg, p_height_cm, p_activity_level, p_goal)
  ON DUPLICATE KEY UPDATE
    biological_sex = p_biological_sex,
    age            = p_age,
    weight_kg      = p_weight_kg,
    height_cm      = p_height_cm,
    activity_level = p_activity_level,
    goal           = p_goal,
    updated_at     = CURRENT_TIMESTAMP;
END$$

-- ─── sp_profile_get ──────────────────────────────────────────────────────────
-- Fetch a user's nutritional profile.

CREATE OR REPLACE PROCEDURE sp_profile_get(
  IN p_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  SELECT id, user_id, biological_sex, age, weight_kg, height_cm, activity_level, goal, updated_at
  FROM nutritional_profiles
  WHERE user_id = p_user_id;
END$$

-- ─── sp_profile_calculate_targets ────────────────────────────────────────────
-- Calculate nutritional targets using Mifflin-St Jeor and write to nutritional_targets.
-- Called by trg_nutritional_profiles_after_upsert — not called directly by the backend.
--
-- Formula:
--   BMR (male)   = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + 5
--   BMR (female) = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) - 161
--   TDEE         = BMR * activity_multiplier
--   calories     = TDEE + goal_adjustment
--   protein_g    = protein_per_kg * weight_kg
--   fat_g        = ROUND((calories * fat_ratio) / 9)
--   carbs_g      = ROUND((calories - protein_g*4 - fat_g*9) / 4)

CREATE OR REPLACE PROCEDURE sp_profile_calculate_targets(
  IN p_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_sex            ENUM('male','female');
  DECLARE v_age            TINYINT UNSIGNED;
  DECLARE v_weight_kg      DECIMAL(5,2);
  DECLARE v_height_cm      DECIMAL(5,2);
  DECLARE v_activity_level ENUM('sedentary','light','moderate','active','very_active');
  DECLARE v_goal           ENUM('lose_weight','maintain','build_muscle','eat_better');

  DECLARE v_bmr            DECIMAL(10,2);
  DECLARE v_activity_mult  DECIMAL(4,3);
  DECLARE v_tdee           DECIMAL(10,2);
  DECLARE v_goal_adj       SMALLINT;
  DECLARE v_calories       SMALLINT UNSIGNED;
  DECLARE v_protein_per_kg DECIMAL(3,1);
  DECLARE v_fat_ratio      DECIMAL(3,2);
  DECLARE v_protein_g      SMALLINT UNSIGNED;
  DECLARE v_fat_g          SMALLINT UNSIGNED;
  DECLARE v_carbs_g        SMALLINT UNSIGNED;

  SELECT biological_sex, age, weight_kg, height_cm, activity_level, goal
  INTO v_sex, v_age, v_weight_kg, v_height_cm, v_activity_level, v_goal
  FROM nutritional_profiles
  WHERE user_id = p_user_id;

  -- Step 1: BMR (Mifflin-St Jeor)
  IF v_sex = 'male' THEN
    SET v_bmr = (10 * v_weight_kg) + (6.25 * v_height_cm) - (5 * v_age) + 5;
  ELSE
    SET v_bmr = (10 * v_weight_kg) + (6.25 * v_height_cm) - (5 * v_age) - 161;
  END IF;

  -- Step 2: Activity multiplier → TDEE
  SET v_activity_mult = CASE v_activity_level
    WHEN 'sedentary'   THEN 1.200
    WHEN 'light'       THEN 1.375
    WHEN 'moderate'    THEN 1.550
    WHEN 'active'      THEN 1.725
    WHEN 'very_active' THEN 1.900
    ELSE 1.200
  END;
  SET v_tdee = v_bmr * v_activity_mult;

  -- Step 3: Goal calorie adjustment
  SET v_goal_adj = CASE v_goal
    WHEN 'lose_weight'  THEN -500
    WHEN 'maintain'     THEN 0
    WHEN 'build_muscle' THEN 300
    WHEN 'eat_better'   THEN 0
    ELSE 0
  END;
  SET v_calories = GREATEST(ROUND(v_tdee + v_goal_adj), 1200);  -- floor at 1200 kcal for safety

  -- Step 4: Protein (g per kg of body weight)
  SET v_protein_per_kg = CASE v_goal
    WHEN 'lose_weight'  THEN 1.6
    WHEN 'maintain'     THEN 1.2
    WHEN 'build_muscle' THEN 2.0
    WHEN 'eat_better'   THEN 1.2
    ELSE 1.2
  END;
  SET v_protein_g = ROUND(v_protein_per_kg * v_weight_kg);

  -- Step 5: Fat (% of calories / 9 kcal per gram)
  SET v_fat_ratio = CASE v_goal
    WHEN 'lose_weight'  THEN 0.25
    WHEN 'maintain'     THEN 0.30
    WHEN 'build_muscle' THEN 0.25
    WHEN 'eat_better'   THEN 0.30
    ELSE 0.30
  END;
  SET v_fat_g = ROUND((v_calories * v_fat_ratio) / 9);

  -- Step 6: Carbs absorb the remainder
  SET v_carbs_g = ROUND((v_calories - (v_protein_g * 4) - (v_fat_g * 9)) / 4);
  -- Guard against negative carbs (shouldn't happen with reasonable inputs)
  IF v_carbs_g < 0 THEN SET v_carbs_g = 0; END IF;

  -- Upsert nutritional_targets
  INSERT INTO nutritional_targets (id, user_id, calories, protein_g, carbs_g, fat_g, calculated_at)
  VALUES (UUID(), p_user_id, v_calories, v_protein_g, v_carbs_g, v_fat_g, NOW())
  ON DUPLICATE KEY UPDATE
    calories      = v_calories,
    protein_g     = v_protein_g,
    carbs_g       = v_carbs_g,
    fat_g         = v_fat_g,
    calculated_at = NOW();
END$$

-- ─── sp_targets_get ──────────────────────────────────────────────────────────
-- Fetch a user's stored nutritional targets.

CREATE OR REPLACE PROCEDURE sp_targets_get(
  IN p_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  SELECT id, user_id, calories, protein_g, carbs_g, fat_g, calculated_at
  FROM nutritional_targets
  WHERE user_id = p_user_id;
END$$

DELIMITER ;
