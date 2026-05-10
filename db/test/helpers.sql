-- helpers.sql: Standing fixtures shared across all test files.
-- Loaded once before any test file runs; persists for the entire test session.
-- Each test wraps its own mutations in START TRANSACTION / ROLLBACK.

SET NAMES utf8mb4;

-- ─── Users ────────────────────────────────────────────────────────────────────

CALL sp_auth_create_user('owner@test.com',    '$2b$12$testhash');
CALL sp_auth_create_user('member@test.com',   '$2b$12$testhash');
CALL sp_auth_create_user('outsider@test.com', '$2b$12$testhash');

-- ─── Household ────────────────────────────────────────────────────────────────

SET @owner_id    = (SELECT id FROM users WHERE email = 'owner@test.com');
SET @member_id   = (SELECT id FROM users WHERE email = 'member@test.com');
SET @outsider_id = (SELECT id FROM users WHERE email = 'outsider@test.com');

CALL sp_household_create('Test Household', @owner_id);
SET @household_id = (SELECT id FROM households WHERE owner_user_id = @owner_id LIMIT 1);

-- Add member@test.com via the invitation flow
CALL sp_household_invite(
  @household_id,
  @owner_id,
  'member@test.com',
  SHA2('fixture-invite-token', 256),
  DATE_ADD(NOW(), INTERVAL 7 DAY)
);
SET @invite_token_hash = SHA2('fixture-invite-token', 256);
CALL sp_household_accept_invitation(@invite_token_hash, @member_id);

-- ─── Recipes ─────────────────────────────────────────────────────────────────

-- Recipe A: 400 kcal per serving, 2 base servings → 800 kcal total
INSERT INTO recipes (id, title, servings_base, calories, protein_g, carbs_g, fat_g)
VALUES (UUID(), 'Test Chicken Bowl', 2, 800, 60.00, 80.00, 20.00);
SET @recipe_a_id = (SELECT id FROM recipes WHERE title = 'Test Chicken Bowl' LIMIT 1);

INSERT INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
  (UUID(), @recipe_a_id, 'chicken breast', 500.000, 'g',   'protein'),
  (UUID(), @recipe_a_id, 'broccoli',       200.000, 'g',   'produce'),
  (UUID(), @recipe_a_id, 'olive oil',       20.000, 'ml',  'pantry');

-- Recipe B: used for shopping list consolidation tests
INSERT INTO recipes (id, title, servings_base, calories, protein_g, carbs_g, fat_g)
VALUES (UUID(), 'Test Salad', 1, 300, 10.00, 30.00, 15.00);
SET @recipe_b_id = (SELECT id FROM recipes WHERE title = 'Test Salad' LIMIT 1);

INSERT INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
  (UUID(), @recipe_b_id, 'broccoli', 150.000, 'g', 'produce'),  -- same ingredient as recipe A, same unit → should sum
  (UUID(), @recipe_b_id, 'tomato',    80.000, 'g', 'produce');
