-- R__01: Auth stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_auth_create_user ──────────────────────────────────────────────────────
-- Create a new user account. Returns the generated user_id.
-- display_name is validated: not null, not empty, max 100 chars.

CREATE OR REPLACE PROCEDURE sp_auth_create_user(
  IN p_email         VARCHAR(255),
  IN p_display_name  VARCHAR(100),
  IN p_password_hash VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_user_id CHAR(36) DEFAULT UUID();

  IF p_email IS NULL OR TRIM(p_email) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'email is required';
  END IF;
  IF p_email NOT LIKE '%@%.%' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'email format is invalid';
  END IF;
  IF p_display_name IS NULL OR TRIM(p_display_name) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'display_name is required';
  END IF;
  IF CHAR_LENGTH(p_display_name) > 100 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'display_name must be 100 characters or fewer';
  END IF;
  IF p_password_hash IS NULL OR TRIM(p_password_hash) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'password_hash is required';
  END IF;

  INSERT INTO users (id, email, display_name, password_hash)
  VALUES (v_user_id, p_email, TRIM(p_display_name), p_password_hash);

  SELECT v_user_id AS user_id;
END$$

-- ─── sp_auth_get_user_by_email ────────────────────────────────────────────────
-- Fetch user record by email for login verification.
-- Returns display_name for sidebar population.

CREATE OR REPLACE PROCEDURE sp_auth_get_user_by_email(
  IN p_email VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
  SELECT id, email, display_name, password_hash
  FROM users
  WHERE email = p_email;
END$$

-- ─── sp_auth_create_session ───────────────────────────────────────────────────
-- Persist a new session after successful login. Returns the generated session_id.

CREATE OR REPLACE PROCEDURE sp_auth_create_session(
  IN p_user_id    CHAR(36),
  IN p_token_hash VARCHAR(255),
  IN p_expires_at DATETIME
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_session_id CHAR(36) DEFAULT UUID();

  INSERT INTO sessions (id, user_id, token_hash, expires_at)
  VALUES (v_session_id, p_user_id, p_token_hash, p_expires_at);

  SELECT v_session_id AS session_id;
END$$

-- ─── sp_auth_get_session ──────────────────────────────────────────────────────
-- Validate a session token, extend its expiry by 30 days (rolling), and return
-- the associated user. Returns empty result if token is not found or expired.

CREATE OR REPLACE PROCEDURE sp_auth_get_session(
  IN p_token_hash VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_new_expires_at DATETIME;

  SET v_new_expires_at = DATE_ADD(NOW(), INTERVAL 30 DAY);

  UPDATE sessions
  SET expires_at = v_new_expires_at
  WHERE token_hash = p_token_hash
    AND expires_at > NOW();

  SELECT user_id, v_new_expires_at AS new_expires_at
  FROM sessions
  WHERE token_hash = p_token_hash
    AND expires_at > NOW();
END$$

-- ─── sp_auth_delete_session ───────────────────────────────────────────────────
-- Delete a session on logout.

CREATE OR REPLACE PROCEDURE sp_auth_delete_session(
  IN p_token_hash VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
  DELETE FROM sessions WHERE token_hash = p_token_hash;
END$$

-- ─── sp_auth_get_user ────────────────────────────────────────────────────────
-- Fetch a user by ID. Returns the row or an empty result set.

CREATE OR REPLACE PROCEDURE sp_auth_get_user(
  IN p_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  SELECT id, email, display_name FROM users WHERE id = p_user_id;
END$$

DELIMITER ;
