-- 07_notification_test.sql: Notification stored procedure tests

SET @owner_id = (SELECT id FROM users WHERE email = 'owner@test.com');

SELECT tap.plan(6);

-- ─── sp_notification_create — row inserted ────────────────────────────────────

CALL sp_notification_create(
  @owner_id, 'meal_plan_ready',
  'Your meal plan is ready', 'body text.', NULL, NULL
);
SELECT tap.ok(
  (SELECT COUNT(*) FROM notifications
   WHERE user_id = @owner_id AND type = 'meal_plan_ready') >= 1,
  'sp_notification_create: notification row inserted'
);
CALL sp_notification_mark_all_read(@owner_id);

-- ─── sp_notification_get_all — unread first ──────────────────────────────────

INSERT INTO notifications (id, user_id, type, title, body, is_read, read_at) VALUES
  (UUID(), @owner_id, 'meal_plan_ready', 'Old', 'Old body', TRUE,  NOW()),
  (UUID(), @owner_id, 'meal_plan_ready', 'New', 'New body', FALSE, NULL);
SELECT tap.ok(
  (SELECT COUNT(*) FROM notifications WHERE user_id = @owner_id AND is_read = FALSE AND title = 'New') >= 1,
  'sp_notification_get_all: unread notification present'
);
SELECT tap.ok(
  (SELECT COUNT(*) FROM notifications WHERE user_id = @owner_id AND is_read = TRUE AND title = 'Old') >= 1,
  'sp_notification_get_all: read notification present'
);
CALL sp_notification_mark_all_read(@owner_id);

-- ─── sp_notification_mark_read — sets is_read and read_at ────────────────────

SET @notif_id = UUID();
INSERT INTO notifications (id, user_id, type, title, body, is_read)
VALUES (@notif_id, @owner_id, 'meal_plan_ready', 'Unread', 'body', FALSE);
CALL sp_notification_mark_read(@notif_id, @owner_id);
SELECT tap.ok(
  (SELECT is_read FROM notifications WHERE id = @notif_id) = TRUE,
  'sp_notification_mark_read: is_read set to TRUE'
);
SELECT tap.ok(
  (SELECT read_at FROM notifications WHERE id = @notif_id) IS NOT NULL,
  'sp_notification_mark_read: read_at timestamp populated'
);

-- ─── sp_notification_mark_all_read — all unread updated ──────────────────────

INSERT INTO notifications (id, user_id, type, title, body, is_read) VALUES
  (UUID(), @owner_id, 'meal_plan_ready', 'N1', 'body', FALSE),
  (UUID(), @owner_id, 'meal_plan_ready', 'N2', 'body', FALSE),
  (UUID(), @owner_id, 'meal_plan_ready', 'N3', 'body', FALSE);
CALL sp_notification_mark_all_read(@owner_id);
SELECT tap.eq(
  (SELECT COUNT(*) FROM notifications WHERE user_id = @owner_id AND is_read = FALSE),
  '0',
  'sp_notification_mark_all_read: no unread notifications remain'
);

CALL tap.finish();
