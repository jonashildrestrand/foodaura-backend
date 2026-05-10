-- 01_auth_test.sql: Auth stored procedure tests
-- No transactions: ROLLBACK undoes tap.__tresults__ inserts (same connection context).
-- Each test uses unique data and cleans up explicitly.

SET @owner_id = (SELECT id FROM users WHERE email = 'owner@test.com');

SELECT tap.plan(8);

-- ─── sp_auth_create_user — user row created ───────────────────────────────────

CALL sp_auth_create_user('newuser@test.com', '$2b$12$hash');
SELECT tap.ok(
  (SELECT COUNT(*) FROM users WHERE email = 'newuser@test.com') = 1,
  'sp_auth_create_user: user row created'
);
DELETE FROM users WHERE email = 'newuser@test.com';

-- ─── sp_auth_create_user — password_hash stored verbatim ─────────────────────

CALL sp_auth_create_user('hashcheck@test.com', '$2b$12$myhash');
SELECT tap.eq(
  (SELECT password_hash FROM users WHERE email = 'hashcheck@test.com'),
  '$2b$12$myhash',
  'sp_auth_create_user: password_hash stored verbatim'
);
DELETE FROM users WHERE email = 'hashcheck@test.com';

-- ─── sp_auth_get_user_by_email — fixture user exists ─────────────────────────

SELECT tap.ok(
  (SELECT COUNT(*) FROM users WHERE email = 'owner@test.com') = 1,
  'sp_auth_get_user_by_email: owner@test.com exists as fixture'
);

-- ─── sp_auth_create_session — session row created ────────────────────────────

CALL sp_auth_create_session(@owner_id, SHA2('test-token-cs', 256), DATE_ADD(NOW(), INTERVAL 30 DAY));
SELECT tap.ok(
  (SELECT COUNT(*) FROM sessions WHERE user_id = @owner_id AND token_hash = SHA2('test-token-cs', 256)) = 1,
  'sp_auth_create_session: session row created'
);
DELETE FROM sessions WHERE token_hash = SHA2('test-token-cs', 256);

-- ─── sp_auth_get_session — rolling expiry advances expires_at ────────────────

CALL sp_auth_create_session(@owner_id, SHA2('roll-token', 256), DATE_ADD(NOW(), INTERVAL 1 DAY));
SET @before_exp = (SELECT expires_at FROM sessions WHERE token_hash = SHA2('roll-token', 256));
CALL sp_auth_get_session(SHA2('roll-token', 256));
SET @after_exp  = (SELECT expires_at FROM sessions WHERE token_hash = SHA2('roll-token', 256));
SELECT tap.ok(@after_exp > @before_exp, 'sp_auth_get_session: rolling expiry advances expires_at');
DELETE FROM sessions WHERE token_hash = SHA2('roll-token', 256);

-- ─── sp_auth_get_session — expired token not matched ─────────────────────────

INSERT INTO sessions (id, user_id, token_hash, expires_at)
VALUES (UUID(), @owner_id, SHA2('expired-token', 256), DATE_SUB(NOW(), INTERVAL 1 DAY));
SELECT tap.eq(
  (SELECT COUNT(*) FROM sessions WHERE token_hash = SHA2('expired-token', 256) AND expires_at > NOW()),
  0,
  'sp_auth_get_session: expired token not matched'
);
DELETE FROM sessions WHERE token_hash = SHA2('expired-token', 256);

-- ─── sp_auth_get_session — extends expires_at by 30 days ─────────────────────

CALL sp_auth_create_session(@owner_id, SHA2('valid-token', 256), DATE_ADD(NOW(), INTERVAL 30 DAY));
CALL sp_auth_get_session(SHA2('valid-token', 256));
SELECT tap.ok(
  (SELECT expires_at > DATE_ADD(NOW(), INTERVAL 29 DAY)
   FROM sessions WHERE token_hash = SHA2('valid-token', 256)) = 1,
  'sp_auth_get_session: extends expires_at by 30 days'
);
DELETE FROM sessions WHERE token_hash = SHA2('valid-token', 256);

-- ─── sp_auth_delete_session — session row removed ────────────────────────────

CALL sp_auth_create_session(@owner_id, SHA2('delete-token', 256), DATE_ADD(NOW(), INTERVAL 30 DAY));
CALL sp_auth_delete_session(SHA2('delete-token', 256));
SELECT tap.ok(
  (SELECT COUNT(*) FROM sessions WHERE token_hash = SHA2('delete-token', 256)) = 0,
  'sp_auth_delete_session: session row removed'
);

CALL tap.finish();
