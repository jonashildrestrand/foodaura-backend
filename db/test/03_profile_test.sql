-- 03_profile_test.sql: Nutritional profile and target calculation tests

SET @owner_id  = (SELECT id FROM users WHERE email = 'owner@test.com');
SET @member_id = (SELECT id FROM users WHERE email = 'member@test.com');

SELECT tap.plan(12);

-- ─── sp_profile_upsert — creates nutritional_targets row ─────────────────────

CALL sp_profile_upsert(@owner_id, 'male', 30, 80.0, 180.0, 'moderate', 'build_muscle');
SELECT tap.ok(
  (SELECT COUNT(*) FROM nutritional_targets WHERE user_id = @owner_id) = 1,
  'sp_profile_upsert: nutritional_targets row created on first insert'
);
DELETE FROM nutritional_targets WHERE user_id = @owner_id;
DELETE FROM nutritional_profiles  WHERE user_id = @owner_id;

-- ─── build_muscle (male, 30y, 80kg, 180cm, moderate) ─────────────────────────
-- BMR=1780 | TDEE=2759 | Cal=3059 | Pro=160g | Fat=85g | Carbs=414g

CALL sp_profile_upsert(@owner_id, 'male', 30, 80.0, 180.0, 'moderate', 'build_muscle');
SELECT calories  INTO @cal  FROM nutritional_targets WHERE user_id = @owner_id;
SELECT protein_g INTO @pro  FROM nutritional_targets WHERE user_id = @owner_id;
SELECT fat_g     INTO @fat  FROM nutritional_targets WHERE user_id = @owner_id;
SELECT carbs_g   INTO @carb FROM nutritional_targets WHERE user_id = @owner_id;

SELECT tap.eq(@cal,  '3059', 'build_muscle male: calories = 3059');
SELECT tap.eq(@pro,  '160',  'build_muscle male: protein = 160 g');
SELECT tap.eq(@fat,  '85',   'build_muscle male: fat = 85 g');
SELECT tap.eq(@carb, '414',  'build_muscle male: carbs = 414 g');

DELETE FROM nutritional_targets WHERE user_id = @owner_id;
DELETE FROM nutritional_profiles  WHERE user_id = @owner_id;

-- ─── lose_weight (male, 30y, 80kg, 180cm, moderate) ──────────────────────────
-- TDEE=2759 | Cal=2259 | Pro=128g

CALL sp_profile_upsert(@owner_id, 'male', 30, 80.0, 180.0, 'moderate', 'lose_weight');
SELECT calories  INTO @cal FROM nutritional_targets WHERE user_id = @owner_id;
SELECT protein_g INTO @pro FROM nutritional_targets WHERE user_id = @owner_id;

SELECT tap.eq(@cal, '2259', 'lose_weight male: calories = 2259');
SELECT tap.eq(@pro, '128',  'lose_weight male: protein = 128 g');

DELETE FROM nutritional_targets WHERE user_id = @owner_id;
DELETE FROM nutritional_profiles  WHERE user_id = @owner_id;

-- ─── Female worked example from nutritional doc ───────────────────────────────
-- Female, 28y, 65kg, 165cm, light, lose_weight → Cal=1398, Pro=104g, Fat=39g, Carbs=158g

CALL sp_profile_upsert(@member_id, 'female', 28, 65.0, 165.0, 'light', 'lose_weight');
SELECT calories  INTO @cal  FROM nutritional_targets WHERE user_id = @member_id;
SELECT protein_g INTO @pro  FROM nutritional_targets WHERE user_id = @member_id;
SELECT fat_g     INTO @fat  FROM nutritional_targets WHERE user_id = @member_id;
SELECT carbs_g   INTO @carb FROM nutritional_targets WHERE user_id = @member_id;

SELECT tap.eq(@cal,  '1398', 'female lose_weight: calories = 1398');
SELECT tap.eq(@pro,  '104',  'female lose_weight: protein = 104 g');
SELECT tap.eq(@fat,  '39',   'female lose_weight: fat = 39 g');
SELECT tap.eq(@carb, '158',  'female lose_weight: carbs = 158 g');

DELETE FROM nutritional_targets WHERE user_id = @member_id;
DELETE FROM nutritional_profiles  WHERE user_id = @member_id;

-- ─── Trigger fires on UPDATE — targets recalculate ───────────────────────────

CALL sp_profile_upsert(@owner_id, 'male', 30, 80.0, 180.0, 'moderate', 'build_muscle');
SELECT calories INTO @cal_before FROM nutritional_targets WHERE user_id = @owner_id;

CALL sp_profile_upsert(@owner_id, 'male', 30, 80.0, 180.0, 'moderate', 'lose_weight');
SELECT calories INTO @cal_after FROM nutritional_targets WHERE user_id = @owner_id;

SELECT tap.ok(@cal_after < @cal_before,
  'trigger: updating goal from build_muscle to lose_weight reduces target calories');

DELETE FROM nutritional_targets WHERE user_id = @owner_id;
DELETE FROM nutritional_profiles  WHERE user_id = @owner_id;

CALL tap.finish();
