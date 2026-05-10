-- R__09: AI service stored procedures (read-only, no personal data)
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_ai_get_household_profiles ────────────────────────────────────────────
-- Return nutritional profiles and targets for all members of a household.
-- Excludes email, password_hash, session data, and all other PII.
-- The only procedure through which the AI service accesses user data.

CREATE OR REPLACE PROCEDURE sp_ai_get_household_profiles(
  IN p_household_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  SELECT
    hm.user_id,
    np.biological_sex,
    np.age,
    np.weight_kg,
    np.height_cm,
    np.activity_level,
    np.goal,
    nt.calories,
    nt.protein_g,
    nt.carbs_g,
    nt.fat_g
  FROM household_members hm
  JOIN nutritional_profiles np ON np.user_id = hm.user_id
  JOIN nutritional_targets  nt ON nt.user_id = hm.user_id
  WHERE hm.household_id = p_household_id;
END$$

DELIMITER ;
