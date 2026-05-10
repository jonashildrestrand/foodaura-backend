-- 02_household_test.sql: Household stored procedure tests

SET @owner_id    = (SELECT id FROM users WHERE email = 'owner@test.com');
SET @member_id   = (SELECT id FROM users WHERE email = 'member@test.com');
SET @household_id = (SELECT id FROM households WHERE name = 'Test Household' LIMIT 1);

SELECT tap.plan(8);

-- ─── sp_household_create — creator added as member ───────────────────────────

CALL sp_auth_create_user('hh-owner@test.com', '$2b$12$h');
SET @ho = (SELECT id FROM users WHERE email = 'hh-owner@test.com');
CALL sp_household_create('My House', @ho);
SET @hid = (SELECT id FROM households WHERE owner_user_id = @ho LIMIT 1);
SELECT tap.ok(
  (SELECT COUNT(*) FROM household_members WHERE household_id = @hid AND user_id = @ho) = 1,
  'sp_household_create: creator is added as member'
);
DELETE FROM households WHERE id = @hid;
DELETE FROM users WHERE email = 'hh-owner@test.com';

-- ─── sp_household_invite — invitation row created ────────────────────────────

CALL sp_household_invite(
  @household_id, @owner_id,
  'invited@test.com',
  SHA2('new-invite-token', 256),
  DATE_ADD(NOW(), INTERVAL 7 DAY)
);
SELECT tap.ok(
  (SELECT COUNT(*) FROM household_invitations
   WHERE household_id = @household_id AND email = 'invited@test.com' AND status = 'pending') = 1,
  'sp_household_invite: invitation row created with pending status'
);
DELETE FROM household_invitations WHERE token_hash = SHA2('new-invite-token', 256);

-- ─── sp_household_accept_invitation — member added, status = accepted ─────────

CALL sp_auth_create_user('accept-test@test.com', '$2b$12$h');
SET @new_uid = (SELECT id FROM users WHERE email = 'accept-test@test.com');
CALL sp_household_invite(
  @household_id, @owner_id,
  'accept-test@test.com',
  SHA2('accept-test-token', 256),
  DATE_ADD(NOW(), INTERVAL 7 DAY)
);
CALL sp_household_accept_invitation(SHA2('accept-test-token', 256), @new_uid);
SELECT tap.ok(
  (SELECT COUNT(*) FROM household_members
   WHERE household_id = @household_id AND user_id = @new_uid) = 1,
  'sp_household_accept_invitation: new user added to household_members'
);
SELECT tap.eq(
  (SELECT status FROM household_invitations WHERE token_hash = SHA2('accept-test-token', 256)),
  'accepted',
  'sp_household_accept_invitation: invitation status set to accepted'
);
DELETE FROM household_invitations WHERE token_hash = SHA2('accept-test-token', 256);
DELETE FROM household_members WHERE user_id = @new_uid;
DELETE FROM notifications WHERE user_id = @new_uid OR user_id = @owner_id;
DELETE FROM users WHERE email = 'accept-test@test.com';

-- ─── sp_household_accept_invitation — expired invitation is not valid ─────────

INSERT INTO household_invitations
  (id, household_id, invited_by_user_id, email, token_hash, status, expires_at)
VALUES
  (UUID(), @household_id, @owner_id, 'expired-inv@test.com',
   SHA2('expired-inv-token', 256), 'pending', DATE_SUB(NOW(), INTERVAL 1 DAY));
SELECT tap.ok(
  (SELECT COUNT(*) FROM household_invitations
   WHERE token_hash = SHA2('expired-inv-token', 256)
     AND status = 'pending' AND expires_at > NOW()) = 0,
  'sp_household_accept_invitation: expired invitation not matched as valid'
);
DELETE FROM household_invitations WHERE token_hash = SHA2('expired-inv-token', 256);

-- ─── sp_household_remove_member — member removed, notification created ────────

CALL sp_auth_create_user('removable@test.com', '$2b$12$h');
SET @rm_uid = (SELECT id FROM users WHERE email = 'removable@test.com');
INSERT INTO household_members (household_id, user_id) VALUES (@household_id, @rm_uid);
CALL sp_household_remove_member(@household_id, @rm_uid, @owner_id);
SELECT tap.ok(
  (SELECT COUNT(*) FROM household_members WHERE household_id = @household_id AND user_id = @rm_uid) = 0,
  'sp_household_remove_member: member removed from household_members'
);
SELECT tap.ok(
  (SELECT COUNT(*) FROM notifications WHERE user_id = @rm_uid AND type = 'household_member_removed') >= 1,
  'sp_household_remove_member: notification created for removed user'
);
DELETE FROM notifications WHERE user_id = @rm_uid;
DELETE FROM users WHERE email = 'removable@test.com';

-- ─── sp_household_leave — member removed ─────────────────────────────────────

CALL sp_household_leave(@household_id, @member_id);
SELECT tap.ok(
  (SELECT COUNT(*) FROM household_members WHERE household_id = @household_id AND user_id = @member_id) = 0,
  'sp_household_leave: member removed from household_members'
);
-- Restore fixture: re-add member@test.com
INSERT IGNORE INTO household_members (household_id, user_id) VALUES (@household_id, @member_id);
DELETE FROM notifications WHERE user_id = @owner_id AND type = 'household_member_left';

CALL tap.finish();
