-- R__08: Notification stored procedures
-- Repeatable migration — re-runs whenever this file changes.
-- Defined before other procedure files that call sp_notification_create
-- (Flyway runs R__ files alphabetically, but MariaDB resolves cross-procedure
--  calls at runtime, not definition time — ordering here is documentation only).

DELIMITER $$

-- ─── sp_notification_create ──────────────────────────────────────────────────
-- Insert a notification row for a user. Called internally by other procedures.

CREATE OR REPLACE PROCEDURE sp_notification_create(
  IN p_user_id       CHAR(36),
  IN p_type          ENUM(
                       'household_invitation_received',
                       'household_invitation_accepted',
                       'household_member_left',
                       'household_member_removed',
                       'meal_plan_ready'
                     ),
  IN p_title         VARCHAR(255),
  IN p_body          TEXT,
  IN p_reference_type VARCHAR(50),
  IN p_reference_id  CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_notification_id CHAR(36) DEFAULT UUID();

  INSERT INTO notifications (id, user_id, type, title, body, reference_type, reference_id)
  VALUES (v_notification_id, p_user_id, p_type, p_title, p_body, p_reference_type, p_reference_id);

  SELECT v_notification_id AS notification_id;
END$$

-- ─── sp_notification_get_all ─────────────────────────────────────────────────
-- Fetch all notifications for a user, unread first then by created_at descending.

CREATE OR REPLACE PROCEDURE sp_notification_get_all(
  IN p_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  SELECT id, user_id, type, title, body, reference_type, reference_id, is_read, read_at, created_at
  FROM notifications
  WHERE user_id = p_user_id
  ORDER BY is_read ASC, created_at DESC;
END$$

-- ─── sp_notification_mark_read ───────────────────────────────────────────────
-- Mark a single notification as read. Only succeeds if it belongs to the requesting user.

CREATE OR REPLACE PROCEDURE sp_notification_mark_read(
  IN p_notification_id CHAR(36),
  IN p_user_id         CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  UPDATE notifications
  SET is_read = TRUE, read_at = NOW()
  WHERE id = p_notification_id
    AND user_id = p_user_id
    AND is_read = FALSE;
END$$

-- ─── sp_notification_mark_all_read ───────────────────────────────────────────
-- Mark all unread notifications for a user as read.

CREATE OR REPLACE PROCEDURE sp_notification_mark_all_read(
  IN p_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  UPDATE notifications
  SET is_read = TRUE, read_at = NOW()
  WHERE user_id = p_user_id
    AND is_read = FALSE;
END$$

DELIMITER ;
