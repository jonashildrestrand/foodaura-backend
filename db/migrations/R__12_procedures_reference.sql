-- R__12: Reference data stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_goals_list ───────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE sp_goals_list()
SQL SECURITY DEFINER
BEGIN
  SELECT value, label, icon
  FROM goals
  ORDER BY sort_order;
END$$

-- ─── sp_diet_types_list ──────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE sp_diet_types_list()
SQL SECURITY DEFINER
BEGIN
  SELECT value, label
  FROM diet_types
  ORDER BY sort_order;
END$$

DELIMITER ;
