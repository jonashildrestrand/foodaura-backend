-- db/seed/test_seed.sql
-- Test seed: Jonas, Thuy, Hildrestrand household, invitation, and 40 recipes.
-- Idempotent — safe to run multiple times.
-- Applied only via Docker Compose: docker-compose --profile test up

DELIMITER $$

DROP PROCEDURE IF EXISTS run_seed $$

CREATE PROCEDURE run_seed()
BEGIN
  DECLARE v_jonas_id       CHAR(36);
  DECLARE v_thuy_id        CHAR(36);
  DECLARE v_household_id   CHAR(36);
  DECLARE v_pending_invite INT DEFAULT 0;

  -- Users
  SELECT id INTO v_jonas_id FROM users WHERE email = 'jonas@hildrestrand.no' LIMIT 1;
  IF v_jonas_id IS NULL THEN
    CALL sp_auth_create_user('jonas@hildrestrand.no', '$2a$12$seed.hash.placeholder.jonas');
    SELECT id INTO v_jonas_id FROM users WHERE email = 'jonas@hildrestrand.no' LIMIT 1;
  END IF;

  SELECT id INTO v_thuy_id FROM users WHERE email = 'thuy@hildrestrand.no' LIMIT 1;
  IF v_thuy_id IS NULL THEN
    CALL sp_auth_create_user('thuy@hildrestrand.no', '$2a$12$seed.hash.placeholder.thuy');
    SELECT id INTO v_thuy_id FROM users WHERE email = 'thuy@hildrestrand.no' LIMIT 1;
  END IF;

  -- Household
  SELECT id INTO v_household_id
  FROM households
  WHERE name = 'Hildrestrand' AND owner_user_id = v_jonas_id
  LIMIT 1;

  IF v_household_id IS NULL THEN
    CALL sp_household_create('Hildrestrand', v_jonas_id);
    SELECT id INTO v_household_id
    FROM households
    WHERE name = 'Hildrestrand' AND owner_user_id = v_jonas_id
    LIMIT 1;
  END IF;

  -- Invitation (only if no pending invite already exists)
  SELECT COUNT(*) INTO v_pending_invite
  FROM household_invitations
  WHERE household_id = v_household_id
    AND email = 'thuy@hildrestrand.no'
    AND status = 'pending';

  IF v_pending_invite = 0 THEN
    CALL sp_household_invite(
      v_household_id,
      v_jonas_id,
      'thuy@hildrestrand.no',
      SHA2(CONCAT('seed-token-', v_household_id), 256),
      DATE_ADD(NOW(), INTERVAL 7 DAY)
    );
  END IF;

END$$

DELIMITER ;

CALL run_seed();
DROP PROCEDURE IF EXISTS run_seed;

-- ─── Recipes ─────────────────────────────────────────────────────────────────
-- Fixed UUIDs ensure idempotency via INSERT IGNORE on primary key.
-- Organised by meal type in comments; recipes have no meal_type field.

INSERT IGNORE INTO recipes
  (id, title, description, cuisine, cook_time_minutes, servings_base, calories, protein_g, carbs_g, fat_g)
VALUES

-- Breakfast ------------------------------------------------------------------
('00000000-seed-0000-0000-recipe000001', 'Overnight Oats with Berries',    'Creamy oats soaked overnight, topped with fresh mixed berries and honey',              'American',      10,  2, 350, 12.00, 60.00,  8.00),
('00000000-seed-0000-0000-recipe000002', 'Scrambled Eggs on Toast',        'Fluffy scrambled eggs served on toasted sourdough with fresh chives',                  'British',       10,  2, 380, 20.00, 32.00, 18.00),
('00000000-seed-0000-0000-recipe000003', 'Avocado Toast with Poached Egg', 'Smashed avocado on toasted sourdough topped with a perfectly poached egg',             'American',      15,  2, 420, 18.00, 35.00, 25.00),
('00000000-seed-0000-0000-recipe000004', 'Greek Yogurt Parfait',           'Layered Greek yogurt with crunchy granola, strawberries and a drizzle of honey',       'Mediterranean',  5,  2, 320, 18.00, 52.00,  4.00),
('00000000-seed-0000-0000-recipe000005', 'Banana Smoothie Bowl',           'Thick blended banana and berry bowl topped with granola and chia seeds',               'American',      10,  2, 380, 10.00, 72.00,  8.00),
('00000000-seed-0000-0000-recipe000006', 'Vegetable Omelette',             'Light and fluffy omelette filled with bell pepper, mushrooms, spinach and feta',       'French',        15,  2, 290, 22.00,  8.00, 20.00),
('00000000-seed-0000-0000-recipe000007', 'Blueberry Pancakes',             'Thick and fluffy buttermilk pancakes bursting with fresh blueberries',                 'American',      20,  4, 480, 12.00, 80.00, 14.00),
('00000000-seed-0000-0000-recipe000008', 'Smoked Salmon Bagel',            'Toasted bagel with cream cheese, smoked salmon, red onion, capers and dill',           'American',      10,  2, 450, 28.00, 52.00, 14.00),
('00000000-seed-0000-0000-recipe000009', 'Granola with Milk',              'Crunchy homestyle granola served with cold whole milk and sliced banana',               'American',       5,  2, 410, 14.00, 62.00, 12.00),
('00000000-seed-0000-0000-recipe000010', 'French Toast',                   'Thick-cut brioche dipped in cinnamon egg custard, pan-fried until golden',             'French',        20,  4, 440, 14.00, 62.00, 16.00),

-- Lunch ----------------------------------------------------------------------
('00000000-seed-0000-0000-recipe000011', 'Caesar Salad with Grilled Chicken', 'Crisp romaine, parmesan and croutons tossed in Caesar dressing with grilled chicken', 'American',   20,  2, 420, 38.00, 18.00, 22.00),
('00000000-seed-0000-0000-recipe000012', 'Chicken Wrap',                   'Grilled chicken, avocado and mixed greens wrapped in a warm tortilla with sour cream', 'American',    15,  2, 480, 32.00, 52.00, 16.00),
('00000000-seed-0000-0000-recipe000013', 'Tomato Basil Soup',              'Silky blended tomato soup with fresh basil, served with crusty bread',                 'Italian',      30,  4, 220,  6.00, 32.00,  8.00),
('00000000-seed-0000-0000-recipe000014', 'BLT Sandwich',                   'Classic bacon, lettuce and tomato sandwich on toasted sourdough with mayonnaise',      'American',     10,  2, 450, 22.00, 42.00, 22.00),
('00000000-seed-0000-0000-recipe000015', 'Quinoa Buddha Bowl',             'Nourishing bowl with quinoa, chickpeas, fresh vegetables and tahini dressing',         'American',     25,  2, 460, 18.00, 72.00, 14.00),
('00000000-seed-0000-0000-recipe000016', 'Tuna Salad Sandwich',            'Creamy tuna salad with celery and lemon on whole grain bread',                         'American',     10,  2, 390, 28.00, 38.00, 14.00),
('00000000-seed-0000-0000-recipe000017', 'Greek Salad',                    'Fresh cucumber, tomatoes, olives and feta drizzled with olive oil and oregano',        'Mediterranean', 10,  2, 280, 10.00, 18.00, 20.00),
('00000000-seed-0000-0000-recipe000018', 'Red Lentil Soup',                'Hearty spiced red lentil soup with cumin and a squeeze of fresh lemon',                'Mediterranean', 35,  4, 340, 18.00, 58.00,  4.00),
('00000000-seed-0000-0000-recipe000019', 'Caprese Salad',                  'Fresh mozzarella, ripe tomatoes and basil with olive oil and balsamic glaze',          'Italian',      10,  2, 320, 18.00, 10.00, 24.00),
('00000000-seed-0000-0000-recipe000020', 'Chicken Noodle Soup',            'Comforting homestyle chicken soup with egg noodles and vegetables',                    'American',     40,  4, 300, 24.00, 32.00,  6.00),

-- Dinner ---------------------------------------------------------------------
('00000000-seed-0000-0000-recipe000021', 'Spaghetti Bolognese',            'Slow-cooked beef ragu with spaghetti and freshly grated parmesan',                    'Italian',      45,  4, 620, 32.00, 82.00, 18.00),
('00000000-seed-0000-0000-recipe000022', 'Grilled Salmon with Roasted Vegetables', 'Pan-grilled salmon fillet with oven-roasted broccoli, tomatoes and zucchini',  'Nordic',       30,  2, 480, 42.00, 24.00, 24.00),
('00000000-seed-0000-0000-recipe000023', 'Chicken Stir Fry with Rice',     'Tender chicken and crisp vegetables wok-fried in soy and sesame with jasmine rice',   'Asian',        25,  4, 540, 36.00, 72.00, 12.00),
('00000000-seed-0000-0000-recipe000024', 'Beef Tacos',                     'Seasoned ground beef in crispy taco shells with cheese, lettuce, tomato and sour cream', 'Mexican',  25,  4, 560, 32.00, 52.00, 24.00),
('00000000-seed-0000-0000-recipe000025', 'Vegetable Coconut Curry',        'Creamy coconut curry with chickpeas and sweet potato served over jasmine rice',        'Asian',        35,  4, 440, 12.00, 68.00, 16.00),
('00000000-seed-0000-0000-recipe000026', 'Roast Chicken with Potatoes',    'Classic Sunday roast chicken with crispy potatoes, garlic, rosemary and lemon',       'British',      90,  4, 620, 48.00, 48.00, 24.00),
('00000000-seed-0000-0000-recipe000027', 'Pork Chops with Apple Sauce',    'Pan-seared pork chops served with warm spiced apple and onion sauce',                  'Nordic',       30,  2, 520, 38.00, 32.00, 26.00),
('00000000-seed-0000-0000-recipe000028', 'Garlic Shrimp Pasta',            'Spaghetti tossed with butter-sautéed garlic shrimp, white wine and fresh parsley',    'Italian',      25,  4, 560, 32.00, 72.00, 16.00),
('00000000-seed-0000-0000-recipe000029', 'Beef Stew',                      'Slow-braised beef chuck with potatoes, carrots and onion in a rich beef stock',       'British',     120,  6, 580, 42.00, 48.00, 18.00),
('00000000-seed-0000-0000-recipe000030', 'Mushroom Risotto',               'Creamy arborio rice slowly cooked with mushrooms, white wine and parmesan',            'Italian',      40,  4, 480, 14.00, 72.00, 16.00),

-- Snack ----------------------------------------------------------------------
('00000000-seed-0000-0000-recipe000031', 'Apple with Peanut Butter',       'Crisp apple slices served with creamy peanut butter for dipping',                     'American',      5,  1, 250,  8.00, 32.00, 12.00),
('00000000-seed-0000-0000-recipe000032', 'Hummus with Carrot Sticks',      'Smooth chickpea hummus served with fresh carrot and cucumber sticks',                  'Mediterranean',  5,  2, 180,  6.00, 24.00,  8.00),
('00000000-seed-0000-0000-recipe000033', 'Trail Mix',                      'Energy-boosting mix of nuts, dried cranberries, dark chocolate chips and pumpkin seeds', 'American',   5,  4, 280,  8.00, 30.00, 16.00),
('00000000-seed-0000-0000-recipe000034', 'Rice Cakes with Cream Cheese',   'Light rice cakes spread with cream cheese and topped with cucumber and dill',          'American',      5,  2, 190,  4.00, 26.00,  8.00),
('00000000-seed-0000-0000-recipe000035', 'Banana with Almond Butter',      'Fresh banana sliced and served with rich almond butter',                               'American',      5,  1, 270,  6.00, 36.00, 12.00),
('00000000-seed-0000-0000-recipe000036', 'Mixed Nuts',                     'A satisfying blend of almonds, walnuts, cashews and macadamia nuts',                   'American',      5,  4, 320, 10.00, 16.00, 28.00),
('00000000-seed-0000-0000-recipe000037', 'Greek Yogurt with Honey',        'Thick and creamy Greek yogurt drizzled with honey and topped with walnuts',            'Mediterranean',  5,  2, 220, 14.00, 30.00,  4.00),
('00000000-seed-0000-0000-recipe000038', 'Cheese and Whole Grain Crackers','Sliced cheddar on whole grain crackers with fresh apple wedges',                       'American',      5,  2, 260, 12.00, 24.00, 14.00),
('00000000-seed-0000-0000-recipe000039', 'Edamame with Sea Salt',          'Steamed edamame pods sprinkled with flaky sea salt',                                   'Asian',        10,  2, 180, 14.00, 14.00,  8.00),
('00000000-seed-0000-0000-recipe000040', 'Berry Smoothie',                 'Blended frozen berries and banana with Greek yogurt and almond milk',                  'American',      5,  2, 240,  8.00, 44.00,  4.00);

-- ─── Recipe Ingredients ──────────────────────────────────────────────────────

-- Recipe 1: Overnight Oats with Berries
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0001-0001-000000000000', '00000000-seed-0000-0000-recipe000001', 'rolled oats',      200.000, 'g',  'pantry'),
('00000000-seed-0001-0002-000000000000', '00000000-seed-0000-0000-recipe000001', 'mixed berries',    200.000, 'g',  'produce'),
('00000000-seed-0001-0003-000000000000', '00000000-seed-0000-0000-recipe000001', 'chia seeds',        20.000, 'g',  'pantry'),
('00000000-seed-0001-0004-000000000000', '00000000-seed-0000-0000-recipe000001', 'honey',             30.000, 'ml', 'pantry'),
('00000000-seed-0001-0005-000000000000', '00000000-seed-0000-0000-recipe000001', 'almond milk',      400.000, 'ml', 'dairy');

-- Recipe 2: Scrambled Eggs on Toast
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0002-0001-000000000000', '00000000-seed-0000-0000-recipe000002', 'eggs',               4.000, 'each', 'protein'),
('00000000-seed-0002-0002-000000000000', '00000000-seed-0000-0000-recipe000002', 'sourdough bread',    4.000, 'slice', 'bakery'),
('00000000-seed-0002-0003-000000000000', '00000000-seed-0000-0000-recipe000002', 'butter',            20.000, 'g',  'dairy'),
('00000000-seed-0002-0004-000000000000', '00000000-seed-0000-0000-recipe000002', 'chives',            10.000, 'g',  'produce');

-- Recipe 3: Avocado Toast with Poached Egg
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0003-0001-000000000000', '00000000-seed-0000-0000-recipe000003', 'avocado',            2.000, 'each', 'produce'),
('00000000-seed-0003-0002-000000000000', '00000000-seed-0000-0000-recipe000003', 'sourdough bread',    4.000, 'slice', 'bakery'),
('00000000-seed-0003-0003-000000000000', '00000000-seed-0000-0000-recipe000003', 'eggs',               2.000, 'each', 'protein'),
('00000000-seed-0003-0004-000000000000', '00000000-seed-0000-0000-recipe000003', 'lemon',              1.000, 'each', 'produce'),
('00000000-seed-0003-0005-000000000000', '00000000-seed-0000-0000-recipe000003', 'red pepper flakes',  2.000, 'g',  'pantry');

-- Recipe 4: Greek Yogurt Parfait
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0004-0001-000000000000', '00000000-seed-0000-0000-recipe000004', 'Greek yogurt',     400.000, 'g',  'dairy'),
('00000000-seed-0004-0002-000000000000', '00000000-seed-0000-0000-recipe000004', 'granola',           80.000, 'g',  'pantry'),
('00000000-seed-0004-0003-000000000000', '00000000-seed-0000-0000-recipe000004', 'strawberries',     150.000, 'g',  'produce'),
('00000000-seed-0004-0004-000000000000', '00000000-seed-0000-0000-recipe000004', 'honey',             30.000, 'ml', 'pantry');

-- Recipe 5: Banana Smoothie Bowl
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0005-0001-000000000000', '00000000-seed-0000-0000-recipe000005', 'banana',             2.000, 'each', 'produce'),
('00000000-seed-0005-0002-000000000000', '00000000-seed-0000-0000-recipe000005', 'frozen mixed berries', 150.000, 'g', 'frozen'),
('00000000-seed-0005-0003-000000000000', '00000000-seed-0000-0000-recipe000005', 'almond milk',      200.000, 'ml', 'dairy'),
('00000000-seed-0005-0004-000000000000', '00000000-seed-0000-0000-recipe000005', 'granola',           60.000, 'g',  'pantry'),
('00000000-seed-0005-0005-000000000000', '00000000-seed-0000-0000-recipe000005', 'chia seeds',        20.000, 'g',  'pantry');

-- Recipe 6: Vegetable Omelette
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0006-0001-000000000000', '00000000-seed-0000-0000-recipe000006', 'eggs',               4.000, 'each', 'protein'),
('00000000-seed-0006-0002-000000000000', '00000000-seed-0000-0000-recipe000006', 'bell pepper',        1.000, 'each', 'produce'),
('00000000-seed-0006-0003-000000000000', '00000000-seed-0000-0000-recipe000006', 'mushrooms',        100.000, 'g',  'produce'),
('00000000-seed-0006-0004-000000000000', '00000000-seed-0000-0000-recipe000006', 'spinach',           50.000, 'g',  'produce'),
('00000000-seed-0006-0005-000000000000', '00000000-seed-0000-0000-recipe000006', 'olive oil',         15.000, 'ml', 'pantry'),
('00000000-seed-0006-0006-000000000000', '00000000-seed-0000-0000-recipe000006', 'feta cheese',       50.000, 'g',  'dairy');

-- Recipe 7: Blueberry Pancakes
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0007-0001-000000000000', '00000000-seed-0000-0000-recipe000007', 'flour',            250.000, 'g',  'pantry'),
('00000000-seed-0007-0002-000000000000', '00000000-seed-0000-0000-recipe000007', 'blueberries',      150.000, 'g',  'produce'),
('00000000-seed-0007-0003-000000000000', '00000000-seed-0000-0000-recipe000007', 'eggs',               2.000, 'each', 'protein'),
('00000000-seed-0007-0004-000000000000', '00000000-seed-0000-0000-recipe000007', 'milk',             300.000, 'ml', 'dairy'),
('00000000-seed-0007-0005-000000000000', '00000000-seed-0000-0000-recipe000007', 'butter',            30.000, 'g',  'dairy'),
('00000000-seed-0007-0006-000000000000', '00000000-seed-0000-0000-recipe000007', 'maple syrup',       60.000, 'ml', 'pantry');

-- Recipe 8: Smoked Salmon Bagel
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0008-0001-000000000000', '00000000-seed-0000-0000-recipe000008', 'bagels',             2.000, 'each', 'bakery'),
('00000000-seed-0008-0002-000000000000', '00000000-seed-0000-0000-recipe000008', 'smoked salmon',    150.000, 'g',  'protein'),
('00000000-seed-0008-0003-000000000000', '00000000-seed-0000-0000-recipe000008', 'cream cheese',     100.000, 'g',  'dairy'),
('00000000-seed-0008-0004-000000000000', '00000000-seed-0000-0000-recipe000008', 'red onion',          0.500, 'each', 'produce'),
('00000000-seed-0008-0005-000000000000', '00000000-seed-0000-0000-recipe000008', 'capers',            20.000, 'g',  'pantry'),
('00000000-seed-0008-0006-000000000000', '00000000-seed-0000-0000-recipe000008', 'dill',              10.000, 'g',  'produce');

-- Recipe 9: Granola with Milk
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0009-0001-000000000000', '00000000-seed-0000-0000-recipe000009', 'granola',          120.000, 'g',  'pantry'),
('00000000-seed-0009-0002-000000000000', '00000000-seed-0000-0000-recipe000009', 'whole milk',       300.000, 'ml', 'dairy'),
('00000000-seed-0009-0003-000000000000', '00000000-seed-0000-0000-recipe000009', 'banana',             1.000, 'each', 'produce'),
('00000000-seed-0009-0004-000000000000', '00000000-seed-0000-0000-recipe000009', 'honey',             20.000, 'ml', 'pantry');

-- Recipe 10: French Toast
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0010-0001-000000000000', '00000000-seed-0000-0000-recipe000010', 'brioche bread',      8.000, 'slice', 'bakery'),
('00000000-seed-0010-0002-000000000000', '00000000-seed-0000-0000-recipe000010', 'eggs',               3.000, 'each', 'protein'),
('00000000-seed-0010-0003-000000000000', '00000000-seed-0000-0000-recipe000010', 'milk',             120.000, 'ml', 'dairy'),
('00000000-seed-0010-0004-000000000000', '00000000-seed-0000-0000-recipe000010', 'cinnamon',           5.000, 'g',  'pantry'),
('00000000-seed-0010-0005-000000000000', '00000000-seed-0000-0000-recipe000010', 'vanilla extract',    5.000, 'ml', 'pantry'),
('00000000-seed-0010-0006-000000000000', '00000000-seed-0000-0000-recipe000010', 'maple syrup',       60.000, 'ml', 'pantry');

-- Recipe 11: Caesar Salad with Grilled Chicken
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0011-0001-000000000000', '00000000-seed-0000-0000-recipe000011', 'chicken breast',   300.000, 'g',  'protein'),
('00000000-seed-0011-0002-000000000000', '00000000-seed-0000-0000-recipe000011', 'romaine lettuce',    1.000, 'each', 'produce'),
('00000000-seed-0011-0003-000000000000', '00000000-seed-0000-0000-recipe000011', 'parmesan',          50.000, 'g',  'dairy'),
('00000000-seed-0011-0004-000000000000', '00000000-seed-0000-0000-recipe000011', 'croutons',          60.000, 'g',  'bakery'),
('00000000-seed-0011-0005-000000000000', '00000000-seed-0000-0000-recipe000011', 'Caesar dressing',   60.000, 'ml', 'pantry');

-- Recipe 12: Chicken Wrap
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0012-0001-000000000000', '00000000-seed-0000-0000-recipe000012', 'tortillas',          2.000, 'each', 'bakery'),
('00000000-seed-0012-0002-000000000000', '00000000-seed-0000-0000-recipe000012', 'chicken breast',   250.000, 'g',  'protein'),
('00000000-seed-0012-0003-000000000000', '00000000-seed-0000-0000-recipe000012', 'avocado',            1.000, 'each', 'produce'),
('00000000-seed-0012-0004-000000000000', '00000000-seed-0000-0000-recipe000012', 'mixed greens',      60.000, 'g',  'produce'),
('00000000-seed-0012-0005-000000000000', '00000000-seed-0000-0000-recipe000012', 'tomato',             1.000, 'each', 'produce'),
('00000000-seed-0012-0006-000000000000', '00000000-seed-0000-0000-recipe000012', 'sour cream',        60.000, 'ml', 'dairy');

-- Recipe 13: Tomato Basil Soup
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0013-0001-000000000000', '00000000-seed-0000-0000-recipe000013', 'canned tomatoes',  800.000, 'g',  'pantry'),
('00000000-seed-0013-0002-000000000000', '00000000-seed-0000-0000-recipe000013', 'onion',              1.000, 'each', 'produce'),
('00000000-seed-0013-0003-000000000000', '00000000-seed-0000-0000-recipe000013', 'garlic',             4.000, 'clove', 'produce'),
('00000000-seed-0013-0004-000000000000', '00000000-seed-0000-0000-recipe000013', 'fresh basil',       20.000, 'g',  'produce'),
('00000000-seed-0013-0005-000000000000', '00000000-seed-0000-0000-recipe000013', 'olive oil',         30.000, 'ml', 'pantry'),
('00000000-seed-0013-0006-000000000000', '00000000-seed-0000-0000-recipe000013', 'vegetable stock',  500.000, 'ml', 'pantry');

-- Recipe 14: BLT Sandwich
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0014-0001-000000000000', '00000000-seed-0000-0000-recipe000014', 'sourdough bread',    4.000, 'slice', 'bakery'),
('00000000-seed-0014-0002-000000000000', '00000000-seed-0000-0000-recipe000014', 'bacon',            150.000, 'g',  'protein'),
('00000000-seed-0014-0003-000000000000', '00000000-seed-0000-0000-recipe000014', 'lettuce',            2.000, 'leaf', 'produce'),
('00000000-seed-0014-0004-000000000000', '00000000-seed-0000-0000-recipe000014', 'tomato',             1.000, 'each', 'produce'),
('00000000-seed-0014-0005-000000000000', '00000000-seed-0000-0000-recipe000014', 'mayonnaise',        30.000, 'ml', 'pantry');

-- Recipe 15: Quinoa Buddha Bowl
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0015-0001-000000000000', '00000000-seed-0000-0000-recipe000015', 'quinoa',           200.000, 'g',  'pantry'),
('00000000-seed-0015-0002-000000000000', '00000000-seed-0000-0000-recipe000015', 'chickpeas',        200.000, 'g',  'pantry'),
('00000000-seed-0015-0003-000000000000', '00000000-seed-0000-0000-recipe000015', 'cucumber',           0.500, 'each', 'produce'),
('00000000-seed-0015-0004-000000000000', '00000000-seed-0000-0000-recipe000015', 'cherry tomatoes',  150.000, 'g',  'produce'),
('00000000-seed-0015-0005-000000000000', '00000000-seed-0000-0000-recipe000015', 'avocado',            1.000, 'each', 'produce'),
('00000000-seed-0015-0006-000000000000', '00000000-seed-0000-0000-recipe000015', 'tahini',            60.000, 'ml', 'pantry');

-- Recipe 16: Tuna Salad Sandwich
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0016-0001-000000000000', '00000000-seed-0000-0000-recipe000016', 'canned tuna',      320.000, 'g',  'protein'),
('00000000-seed-0016-0002-000000000000', '00000000-seed-0000-0000-recipe000016', 'whole grain bread',  4.000, 'slice', 'bakery'),
('00000000-seed-0016-0003-000000000000', '00000000-seed-0000-0000-recipe000016', 'celery',             2.000, 'stalk', 'produce'),
('00000000-seed-0016-0004-000000000000', '00000000-seed-0000-0000-recipe000016', 'mayonnaise',        40.000, 'ml', 'pantry'),
('00000000-seed-0016-0005-000000000000', '00000000-seed-0000-0000-recipe000016', 'lemon',              0.500, 'each', 'produce');

-- Recipe 17: Greek Salad
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0017-0001-000000000000', '00000000-seed-0000-0000-recipe000017', 'cucumber',           0.500, 'each', 'produce'),
('00000000-seed-0017-0002-000000000000', '00000000-seed-0000-0000-recipe000017', 'tomatoes',           2.000, 'each', 'produce'),
('00000000-seed-0017-0003-000000000000', '00000000-seed-0000-0000-recipe000017', 'olives',            60.000, 'g',  'pantry'),
('00000000-seed-0017-0004-000000000000', '00000000-seed-0000-0000-recipe000017', 'feta cheese',      100.000, 'g',  'dairy'),
('00000000-seed-0017-0005-000000000000', '00000000-seed-0000-0000-recipe000017', 'red onion',          0.500, 'each', 'produce'),
('00000000-seed-0017-0006-000000000000', '00000000-seed-0000-0000-recipe000017', 'olive oil',         30.000, 'ml', 'pantry');

-- Recipe 18: Red Lentil Soup
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0018-0001-000000000000', '00000000-seed-0000-0000-recipe000018', 'red lentils',      300.000, 'g',  'pantry'),
('00000000-seed-0018-0002-000000000000', '00000000-seed-0000-0000-recipe000018', 'onion',              1.000, 'each', 'produce'),
('00000000-seed-0018-0003-000000000000', '00000000-seed-0000-0000-recipe000018', 'garlic',             4.000, 'clove', 'produce'),
('00000000-seed-0018-0004-000000000000', '00000000-seed-0000-0000-recipe000018', 'cumin',             10.000, 'g',  'pantry'),
('00000000-seed-0018-0005-000000000000', '00000000-seed-0000-0000-recipe000018', 'vegetable stock', 1000.000, 'ml', 'pantry'),
('00000000-seed-0018-0006-000000000000', '00000000-seed-0000-0000-recipe000018', 'lemon',              0.500, 'each', 'produce');

-- Recipe 19: Caprese Salad
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0019-0001-000000000000', '00000000-seed-0000-0000-recipe000019', 'mozzarella',       250.000, 'g',  'dairy'),
('00000000-seed-0019-0002-000000000000', '00000000-seed-0000-0000-recipe000019', 'tomatoes',           3.000, 'each', 'produce'),
('00000000-seed-0019-0003-000000000000', '00000000-seed-0000-0000-recipe000019', 'fresh basil',       20.000, 'g',  'produce'),
('00000000-seed-0019-0004-000000000000', '00000000-seed-0000-0000-recipe000019', 'olive oil',         30.000, 'ml', 'pantry'),
('00000000-seed-0019-0005-000000000000', '00000000-seed-0000-0000-recipe000019', 'balsamic glaze',    20.000, 'ml', 'pantry');

-- Recipe 20: Chicken Noodle Soup
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0020-0001-000000000000', '00000000-seed-0000-0000-recipe000020', 'chicken breast',   400.000, 'g',  'protein'),
('00000000-seed-0020-0002-000000000000', '00000000-seed-0000-0000-recipe000020', 'egg noodles',      200.000, 'g',  'pantry'),
('00000000-seed-0020-0003-000000000000', '00000000-seed-0000-0000-recipe000020', 'carrots',            2.000, 'each', 'produce'),
('00000000-seed-0020-0004-000000000000', '00000000-seed-0000-0000-recipe000020', 'celery',             2.000, 'stalk', 'produce'),
('00000000-seed-0020-0005-000000000000', '00000000-seed-0000-0000-recipe000020', 'onion',              1.000, 'each', 'produce'),
('00000000-seed-0020-0006-000000000000', '00000000-seed-0000-0000-recipe000020', 'chicken stock',   1000.000, 'ml', 'pantry');

-- Recipe 21: Spaghetti Bolognese
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0021-0001-000000000000', '00000000-seed-0000-0000-recipe000021', 'spaghetti',        400.000, 'g',  'pantry'),
('00000000-seed-0021-0002-000000000000', '00000000-seed-0000-0000-recipe000021', 'ground beef',      500.000, 'g',  'protein'),
('00000000-seed-0021-0003-000000000000', '00000000-seed-0000-0000-recipe000021', 'canned tomatoes',  400.000, 'g',  'pantry'),
('00000000-seed-0021-0004-000000000000', '00000000-seed-0000-0000-recipe000021', 'onion',              1.000, 'each', 'produce'),
('00000000-seed-0021-0005-000000000000', '00000000-seed-0000-0000-recipe000021', 'garlic',             4.000, 'clove', 'produce'),
('00000000-seed-0021-0006-000000000000', '00000000-seed-0000-0000-recipe000021', 'parmesan',          50.000, 'g',  'dairy');

-- Recipe 22: Grilled Salmon with Roasted Vegetables
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0022-0001-000000000000', '00000000-seed-0000-0000-recipe000022', 'salmon fillet',    400.000, 'g',  'protein'),
('00000000-seed-0022-0002-000000000000', '00000000-seed-0000-0000-recipe000022', 'broccoli',         200.000, 'g',  'produce'),
('00000000-seed-0022-0003-000000000000', '00000000-seed-0000-0000-recipe000022', 'cherry tomatoes',  150.000, 'g',  'produce'),
('00000000-seed-0022-0004-000000000000', '00000000-seed-0000-0000-recipe000022', 'zucchini',           1.000, 'each', 'produce'),
('00000000-seed-0022-0005-000000000000', '00000000-seed-0000-0000-recipe000022', 'olive oil',         30.000, 'ml', 'pantry'),
('00000000-seed-0022-0006-000000000000', '00000000-seed-0000-0000-recipe000022', 'lemon',              1.000, 'each', 'produce');

-- Recipe 23: Chicken Stir Fry with Rice
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0023-0001-000000000000', '00000000-seed-0000-0000-recipe000023', 'chicken breast',   500.000, 'g',  'protein'),
('00000000-seed-0023-0002-000000000000', '00000000-seed-0000-0000-recipe000023', 'jasmine rice',     320.000, 'g',  'pantry'),
('00000000-seed-0023-0003-000000000000', '00000000-seed-0000-0000-recipe000023', 'broccoli',         200.000, 'g',  'produce'),
('00000000-seed-0023-0004-000000000000', '00000000-seed-0000-0000-recipe000023', 'bell pepper',        1.000, 'each', 'produce'),
('00000000-seed-0023-0005-000000000000', '00000000-seed-0000-0000-recipe000023', 'soy sauce',         60.000, 'ml', 'pantry'),
('00000000-seed-0023-0006-000000000000', '00000000-seed-0000-0000-recipe000023', 'sesame oil',        15.000, 'ml', 'pantry');

-- Recipe 24: Beef Tacos
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0024-0001-000000000000', '00000000-seed-0000-0000-recipe000024', 'ground beef',      500.000, 'g',  'protein'),
('00000000-seed-0024-0002-000000000000', '00000000-seed-0000-0000-recipe000024', 'taco shells',        8.000, 'each', 'bakery'),
('00000000-seed-0024-0003-000000000000', '00000000-seed-0000-0000-recipe000024', 'cheddar cheese',   100.000, 'g',  'dairy'),
('00000000-seed-0024-0004-000000000000', '00000000-seed-0000-0000-recipe000024', 'lettuce',          100.000, 'g',  'produce'),
('00000000-seed-0024-0005-000000000000', '00000000-seed-0000-0000-recipe000024', 'tomatoes',           2.000, 'each', 'produce'),
('00000000-seed-0024-0006-000000000000', '00000000-seed-0000-0000-recipe000024', 'sour cream',       120.000, 'ml', 'dairy');

-- Recipe 25: Vegetable Coconut Curry
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0025-0001-000000000000', '00000000-seed-0000-0000-recipe000025', 'coconut milk',     400.000, 'ml', 'pantry'),
('00000000-seed-0025-0002-000000000000', '00000000-seed-0000-0000-recipe000025', 'chickpeas',        400.000, 'g',  'pantry'),
('00000000-seed-0025-0003-000000000000', '00000000-seed-0000-0000-recipe000025', 'sweet potato',     300.000, 'g',  'produce'),
('00000000-seed-0025-0004-000000000000', '00000000-seed-0000-0000-recipe000025', 'spinach',          100.000, 'g',  'produce'),
('00000000-seed-0025-0005-000000000000', '00000000-seed-0000-0000-recipe000025', 'curry paste',       60.000, 'g',  'pantry'),
('00000000-seed-0025-0006-000000000000', '00000000-seed-0000-0000-recipe000025', 'jasmine rice',     320.000, 'g',  'pantry');

-- Recipe 26: Roast Chicken with Potatoes
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0026-0001-000000000000', '00000000-seed-0000-0000-recipe000026', 'whole chicken',   1500.000, 'g',  'protein'),
('00000000-seed-0026-0002-000000000000', '00000000-seed-0000-0000-recipe000026', 'potatoes',         800.000, 'g',  'produce'),
('00000000-seed-0026-0003-000000000000', '00000000-seed-0000-0000-recipe000026', 'garlic',             6.000, 'clove', 'produce'),
('00000000-seed-0026-0004-000000000000', '00000000-seed-0000-0000-recipe000026', 'rosemary',          10.000, 'g',  'produce'),
('00000000-seed-0026-0005-000000000000', '00000000-seed-0000-0000-recipe000026', 'olive oil',         45.000, 'ml', 'pantry'),
('00000000-seed-0026-0006-000000000000', '00000000-seed-0000-0000-recipe000026', 'lemon',              1.000, 'each', 'produce');

-- Recipe 27: Pork Chops with Apple Sauce
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0027-0001-000000000000', '00000000-seed-0000-0000-recipe000027', 'pork chops',       400.000, 'g',  'protein'),
('00000000-seed-0027-0002-000000000000', '00000000-seed-0000-0000-recipe000027', 'apples',             2.000, 'each', 'produce'),
('00000000-seed-0027-0003-000000000000', '00000000-seed-0000-0000-recipe000027', 'onion',              1.000, 'each', 'produce'),
('00000000-seed-0027-0004-000000000000', '00000000-seed-0000-0000-recipe000027', 'butter',            30.000, 'g',  'dairy'),
('00000000-seed-0027-0005-000000000000', '00000000-seed-0000-0000-recipe000027', 'cinnamon',           5.000, 'g',  'pantry'),
('00000000-seed-0027-0006-000000000000', '00000000-seed-0000-0000-recipe000027', 'brown sugar',       15.000, 'g',  'pantry');

-- Recipe 28: Garlic Shrimp Pasta
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0028-0001-000000000000', '00000000-seed-0000-0000-recipe000028', 'spaghetti',        400.000, 'g',  'pantry'),
('00000000-seed-0028-0002-000000000000', '00000000-seed-0000-0000-recipe000028', 'shrimp',           500.000, 'g',  'protein'),
('00000000-seed-0028-0003-000000000000', '00000000-seed-0000-0000-recipe000028', 'garlic',             6.000, 'clove', 'produce'),
('00000000-seed-0028-0004-000000000000', '00000000-seed-0000-0000-recipe000028', 'butter',            40.000, 'g',  'dairy'),
('00000000-seed-0028-0005-000000000000', '00000000-seed-0000-0000-recipe000028', 'white wine',       120.000, 'ml', 'pantry'),
('00000000-seed-0028-0006-000000000000', '00000000-seed-0000-0000-recipe000028', 'parsley',           20.000, 'g',  'produce');

-- Recipe 29: Beef Stew
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0029-0001-000000000000', '00000000-seed-0000-0000-recipe000029', 'beef chuck',       900.000, 'g',  'protein'),
('00000000-seed-0029-0002-000000000000', '00000000-seed-0000-0000-recipe000029', 'potatoes',         600.000, 'g',  'produce'),
('00000000-seed-0029-0003-000000000000', '00000000-seed-0000-0000-recipe000029', 'carrots',            3.000, 'each', 'produce'),
('00000000-seed-0029-0004-000000000000', '00000000-seed-0000-0000-recipe000029', 'onion',              1.000, 'each', 'produce'),
('00000000-seed-0029-0005-000000000000', '00000000-seed-0000-0000-recipe000029', 'beef stock',      1000.000, 'ml', 'pantry'),
('00000000-seed-0029-0006-000000000000', '00000000-seed-0000-0000-recipe000029', 'tomato paste',      60.000, 'g',  'pantry');

-- Recipe 30: Mushroom Risotto
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0030-0001-000000000000', '00000000-seed-0000-0000-recipe000030', 'arborio rice',     320.000, 'g',  'pantry'),
('00000000-seed-0030-0002-000000000000', '00000000-seed-0000-0000-recipe000030', 'mushrooms',        300.000, 'g',  'produce'),
('00000000-seed-0030-0003-000000000000', '00000000-seed-0000-0000-recipe000030', 'onion',              1.000, 'each', 'produce'),
('00000000-seed-0030-0004-000000000000', '00000000-seed-0000-0000-recipe000030', 'parmesan',          60.000, 'g',  'dairy'),
('00000000-seed-0030-0005-000000000000', '00000000-seed-0000-0000-recipe000030', 'white wine',       150.000, 'ml', 'pantry'),
('00000000-seed-0030-0006-000000000000', '00000000-seed-0000-0000-recipe000030', 'vegetable stock', 1000.000, 'ml', 'pantry');

-- Recipe 31: Apple with Peanut Butter
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0031-0001-000000000000', '00000000-seed-0000-0000-recipe000031', 'apple',              1.000, 'each', 'produce'),
('00000000-seed-0031-0002-000000000000', '00000000-seed-0000-0000-recipe000031', 'peanut butter',     60.000, 'g',  'pantry');

-- Recipe 32: Hummus with Carrot Sticks
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0032-0001-000000000000', '00000000-seed-0000-0000-recipe000032', 'hummus',           200.000, 'g',  'pantry'),
('00000000-seed-0032-0002-000000000000', '00000000-seed-0000-0000-recipe000032', 'carrots',            3.000, 'each', 'produce'),
('00000000-seed-0032-0003-000000000000', '00000000-seed-0000-0000-recipe000032', 'cucumber',           0.500, 'each', 'produce');

-- Recipe 33: Trail Mix
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0033-0001-000000000000', '00000000-seed-0000-0000-recipe000033', 'mixed nuts',       100.000, 'g',  'pantry'),
('00000000-seed-0033-0002-000000000000', '00000000-seed-0000-0000-recipe000033', 'dried cranberries', 60.000, 'g',  'pantry'),
('00000000-seed-0033-0003-000000000000', '00000000-seed-0000-0000-recipe000033', 'dark chocolate chips', 40.000, 'g', 'pantry'),
('00000000-seed-0033-0004-000000000000', '00000000-seed-0000-0000-recipe000033', 'pumpkin seeds',     40.000, 'g',  'pantry');

-- Recipe 34: Rice Cakes with Cream Cheese
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0034-0001-000000000000', '00000000-seed-0000-0000-recipe000034', 'rice cakes',         4.000, 'each', 'pantry'),
('00000000-seed-0034-0002-000000000000', '00000000-seed-0000-0000-recipe000034', 'cream cheese',      80.000, 'g',  'dairy'),
('00000000-seed-0034-0003-000000000000', '00000000-seed-0000-0000-recipe000034', 'cucumber',           0.500, 'each', 'produce'),
('00000000-seed-0034-0004-000000000000', '00000000-seed-0000-0000-recipe000034', 'dill',               5.000, 'g',  'produce');

-- Recipe 35: Banana with Almond Butter
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0035-0001-000000000000', '00000000-seed-0000-0000-recipe000035', 'banana',             1.000, 'each', 'produce'),
('00000000-seed-0035-0002-000000000000', '00000000-seed-0000-0000-recipe000035', 'almond butter',     60.000, 'g',  'pantry');

-- Recipe 36: Mixed Nuts
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0036-0001-000000000000', '00000000-seed-0000-0000-recipe000036', 'almonds',           80.000, 'g',  'pantry'),
('00000000-seed-0036-0002-000000000000', '00000000-seed-0000-0000-recipe000036', 'walnuts',           60.000, 'g',  'pantry'),
('00000000-seed-0036-0003-000000000000', '00000000-seed-0000-0000-recipe000036', 'cashews',           60.000, 'g',  'pantry'),
('00000000-seed-0036-0004-000000000000', '00000000-seed-0000-0000-recipe000036', 'macadamia nuts',    40.000, 'g',  'pantry');

-- Recipe 37: Greek Yogurt with Honey
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0037-0001-000000000000', '00000000-seed-0000-0000-recipe000037', 'Greek yogurt',     300.000, 'g',  'dairy'),
('00000000-seed-0037-0002-000000000000', '00000000-seed-0000-0000-recipe000037', 'honey',             30.000, 'ml', 'pantry'),
('00000000-seed-0037-0003-000000000000', '00000000-seed-0000-0000-recipe000037', 'walnuts',           30.000, 'g',  'pantry');

-- Recipe 38: Cheese and Whole Grain Crackers
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0038-0001-000000000000', '00000000-seed-0000-0000-recipe000038', 'whole grain crackers', 8.000, 'each', 'bakery'),
('00000000-seed-0038-0002-000000000000', '00000000-seed-0000-0000-recipe000038', 'cheddar cheese',    80.000, 'g',  'dairy'),
('00000000-seed-0038-0003-000000000000', '00000000-seed-0000-0000-recipe000038', 'apple',              1.000, 'each', 'produce');

-- Recipe 39: Edamame with Sea Salt
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0039-0001-000000000000', '00000000-seed-0000-0000-recipe000039', 'edamame',          300.000, 'g',  'frozen'),
('00000000-seed-0039-0002-000000000000', '00000000-seed-0000-0000-recipe000039', 'sea salt',           3.000, 'g',  'pantry');

-- Recipe 40: Berry Smoothie
INSERT IGNORE INTO recipe_ingredients (id, recipe_id, name, quantity, unit, category) VALUES
('00000000-seed-0040-0001-000000000000', '00000000-seed-0000-0000-recipe000040', 'frozen mixed berries', 200.000, 'g', 'frozen'),
('00000000-seed-0040-0002-000000000000', '00000000-seed-0000-0000-recipe000040', 'banana',             1.000, 'each', 'produce'),
('00000000-seed-0040-0003-000000000000', '00000000-seed-0000-0000-recipe000040', 'Greek yogurt',     150.000, 'g',  'dairy'),
('00000000-seed-0040-0004-000000000000', '00000000-seed-0000-0000-recipe000040', 'almond milk',      200.000, 'ml', 'dairy');
