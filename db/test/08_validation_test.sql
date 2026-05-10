-- 08_validation_test.sql: Input validation tests for stored procedures
--
-- To catch SIGNAL errors, each negative test is wrapped in a tiny helper
-- procedure that declares a CONTINUE HANDLER. The helper sets a session
-- variable (@err) to 1 if the expected SIGNAL fires, then drops itself.

SET @owner_id    = (SELECT id FROM users WHERE email = 'owner@test.com');
SET @household_id = (SELECT id FROM households WHERE name = 'Test Household' LIMIT 1);

SELECT tap.plan(12);

-- ─── sp_auth_create_user — null email ────────────────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_auth_create_user(NULL, '$2b$12$hash');
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_auth_create_user: rejects NULL email');

-- ─── sp_auth_create_user — empty email ───────────────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_auth_create_user('', '$2b$12$hash');
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_auth_create_user: rejects empty email');

-- ─── sp_auth_create_user — invalid email format ───────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_auth_create_user('notanemail', '$2b$12$hash');
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_auth_create_user: rejects email without @ and domain');

-- ─── sp_auth_create_user — null password_hash ────────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_auth_create_user('valid@test.com', NULL);
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_auth_create_user: rejects NULL password_hash');

-- ─── sp_household_create — null name ─────────────────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_household_create(NULL, @owner_id);
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_household_create: rejects NULL name');

-- ─── sp_household_create — empty name ────────────────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_household_create('   ', @owner_id);
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_household_create: rejects blank name');

-- ─── sp_household_invite — invalid email ─────────────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_household_invite(@household_id, @owner_id, 'notanemail', SHA2('tok', 256), DATE_ADD(NOW(), INTERVAL 7 DAY));
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_household_invite: rejects email without @ and domain');

-- ─── sp_household_invite — expires_at in the past ────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_household_invite(@household_id, @owner_id, 'x@y.com', SHA2('tok2', 256), DATE_SUB(NOW(), INTERVAL 1 DAY));
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_household_invite: rejects expires_at in the past');

-- ─── sp_profile_upsert — age out of range ────────────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_profile_upsert(@owner_id, 'male', 0, 80.0, 180.0, 'moderate', 'maintain');
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_profile_upsert: rejects age = 0');

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_profile_upsert(@owner_id, 'male', 121, 80.0, 180.0, 'moderate', 'maintain');
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_profile_upsert: rejects age = 121');

-- ─── sp_profile_upsert — weight out of range ─────────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_profile_upsert(@owner_id, 'male', 30, 9.0, 180.0, 'moderate', 'maintain');
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_profile_upsert: rejects weight_kg < 10');

-- ─── sp_profile_upsert — height out of range ─────────────────────────────────

DELIMITER $$
CREATE PROCEDURE _t() BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET @err = 1;
  SET @err = 0;
  CALL sp_profile_upsert(@owner_id, 'male', 30, 80.0, 301.0, 'moderate', 'maintain');
END$$
DELIMITER ;
CALL _t(); DROP PROCEDURE _t;
SELECT tap.ok(@err = 1, 'sp_profile_upsert: rejects height_cm > 300');

CALL tap.finish();
