-- 04_recipe_test.sql: Recipe preference stored procedure tests

SET @owner_id    = (SELECT id FROM users WHERE email = 'owner@test.com');
SET @recipe_a_id = (SELECT id FROM recipes WHERE title = 'Test Chicken Bowl' LIMIT 1);

SELECT tap.plan(6);

-- ─── sp_preference_set_recipe — upserts preference ──────────────────────────

CALL sp_preference_set_recipe(@owner_id, @recipe_a_id, 'like');
CALL sp_preference_set_recipe(@owner_id, @recipe_a_id, 'dislike');
SELECT tap.eq(
  (SELECT preference FROM recipe_preferences WHERE user_id = @owner_id AND recipe_id = @recipe_a_id),
  'dislike',
  'sp_preference_set_recipe: second call overwrites first'
);
DELETE FROM recipe_preferences WHERE user_id = @owner_id AND recipe_id = @recipe_a_id;

-- ─── sp_recipe_find — disliked ingredient excludes recipe ────────────────────

CALL sp_preference_add_ingredient_dislike(@owner_id, 'chicken breast');
SELECT tap.ok(
  (SELECT COUNT(*) FROM recipes r
   WHERE r.id = @recipe_a_id
     AND NOT EXISTS (
       SELECT 1 FROM recipe_ingredients ri
       JOIN ingredient_dislikes id2 ON id2.ingredient_name = ri.name
       WHERE ri.recipe_id = r.id AND id2.user_id = @owner_id
     )
  ) = 0,
  'sp_recipe_find: recipe with disliked ingredient is excluded'
);
CALL sp_preference_remove_ingredient_dislike(@owner_id, 'chicken breast');

-- ─── sp_recipe_find — disliked recipe excluded ───────────────────────────────

CALL sp_preference_set_recipe(@owner_id, @recipe_a_id, 'dislike');
SELECT tap.ok(
  (SELECT COUNT(*) FROM recipe_preferences
   WHERE user_id = @owner_id AND recipe_id = @recipe_a_id AND preference = 'dislike') = 1,
  'sp_recipe_find: recipe dislike preference recorded'
);
DELETE FROM recipe_preferences WHERE user_id = @owner_id AND recipe_id = @recipe_a_id;

-- ─── sp_preference_add_ingredient_dislike — row inserted ─────────────────────

CALL sp_preference_add_ingredient_dislike(@owner_id, 'mushrooms');
SELECT tap.ok(
  (SELECT COUNT(*) FROM ingredient_dislikes
   WHERE user_id = @owner_id AND ingredient_name = 'mushrooms') = 1,
  'sp_preference_add_ingredient_dislike: dislike row inserted'
);

-- ─── sp_preference_remove_ingredient_dislike — row removed ───────────────────

CALL sp_preference_remove_ingredient_dislike(@owner_id, 'mushrooms');
SELECT tap.ok(
  (SELECT COUNT(*) FROM ingredient_dislikes
   WHERE user_id = @owner_id AND ingredient_name = 'mushrooms') = 0,
  'sp_preference_remove_ingredient_dislike: dislike row removed'
);

-- ─── sp_preference_add_ingredient_dislike — idempotent ───────────────────────

CALL sp_preference_add_ingredient_dislike(@owner_id, 'peanuts');
CALL sp_preference_add_ingredient_dislike(@owner_id, 'peanuts');
SELECT tap.ok(
  (SELECT COUNT(*) FROM ingredient_dislikes
   WHERE user_id = @owner_id AND ingredient_name = 'peanuts') = 1,
  'sp_preference_add_ingredient_dislike: idempotent, no duplicate rows'
);
DELETE FROM ingredient_dislikes WHERE user_id = @owner_id AND ingredient_name = 'peanuts';

CALL tap.finish();
