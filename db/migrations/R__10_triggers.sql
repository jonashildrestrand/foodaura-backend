-- R__10: Triggers
-- Repeatable migration — re-runs whenever this file changes.
-- Numbered 10 so it runs after all procedure files (R__01–R__09).

DELIMITER $$

-- ─── trg_nutritional_profiles_after_upsert ───────────────────────────────────
-- Fires after INSERT or UPDATE on nutritional_profiles.
-- Delegates recalculation to sp_profile_calculate_targets so that calorie and
-- macro logic lives in exactly one place — the stored procedure — not here.

CREATE OR REPLACE TRIGGER trg_nutritional_profiles_after_insert
AFTER INSERT ON nutritional_profiles
FOR EACH ROW
BEGIN
  CALL sp_profile_calculate_targets(NEW.user_id);
END$$

CREATE OR REPLACE TRIGGER trg_nutritional_profiles_after_update
AFTER UPDATE ON nutritional_profiles
FOR EACH ROW
BEGIN
  CALL sp_profile_calculate_targets(NEW.user_id);
END$$

-- ─── Future triggers (not yet implemented) ────────────────────────────────────
-- trg_meal_slot_after_assign — auto-derive shopping list on slot change.
-- Currently handled manually via sp_mealplan_assign_recipe calling sp_shoppinglist_derive.

DELIMITER ;
