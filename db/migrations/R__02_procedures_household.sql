-- R__02: Household stored procedures
-- Repeatable migration — re-runs whenever this file changes.

DELIMITER $$

-- ─── sp_household_create ─────────────────────────────────────────────────────
-- Create a new household and add the creator as owner and first member.

CREATE OR REPLACE PROCEDURE sp_household_create(
  IN p_name          VARCHAR(255),
  IN p_owner_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_household_id CHAR(36) DEFAULT UUID();

  IF p_name IS NULL OR TRIM(p_name) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'household name is required';
  END IF;
  IF p_owner_user_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'owner_user_id is required';
  END IF;

  INSERT INTO households (id, name, owner_user_id)
  VALUES (v_household_id, p_name, p_owner_user_id);

  INSERT INTO household_members (household_id, user_id)
  VALUES (v_household_id, p_owner_user_id);

  SELECT v_household_id AS household_id;
END$$

-- ─── sp_household_get ────────────────────────────────────────────────────────
-- Fetch household details and member list. Only succeeds if requesting user is a member.

CREATE OR REPLACE PROCEDURE sp_household_get(
  IN p_household_id       CHAR(36),
  IN p_requesting_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM household_members
    WHERE household_id = p_household_id AND user_id = p_requesting_user_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: user is not a member of this household';
  END IF;

  SELECT h.id, h.name, h.owner_user_id, h.created_at
  FROM households h
  WHERE h.id = p_household_id;

  SELECT hm.user_id, u.email, hm.joined_at
  FROM household_members hm
  JOIN users u ON u.id = hm.user_id
  WHERE hm.household_id = p_household_id;
END$$

-- ─── sp_household_invite ─────────────────────────────────────────────────────
-- Create a household invitation for the given email address. Returns invitation_id.

CREATE OR REPLACE PROCEDURE sp_household_invite(
  IN p_household_id       CHAR(36),
  IN p_invited_by_user_id CHAR(36),
  IN p_email              VARCHAR(255),
  IN p_token_hash         VARCHAR(255),
  IN p_expires_at         DATETIME
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_invitation_id  CHAR(36) DEFAULT UUID();
  DECLARE v_invitee_id     CHAR(36);
  DECLARE v_household_name VARCHAR(255);

  IF p_email IS NULL OR p_email NOT LIKE '%@%.%' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'a valid email address is required';
  END IF;
  IF p_expires_at IS NULL OR p_expires_at <= NOW() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'expires_at must be a future datetime';
  END IF;

  -- Only household members can invite
  IF NOT EXISTS (
    SELECT 1 FROM household_members
    WHERE household_id = p_household_id AND user_id = p_invited_by_user_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: only household members can send invitations';
  END IF;

  INSERT INTO household_invitations (id, household_id, invited_by_user_id, email, token_hash, expires_at)
  VALUES (v_invitation_id, p_household_id, p_invited_by_user_id, p_email, p_token_hash, p_expires_at);

  -- Notify the invitee if they already have a Foodaura account
  SELECT id INTO v_invitee_id FROM users WHERE email = p_email LIMIT 1;
  IF v_invitee_id IS NOT NULL THEN
    SELECT name INTO v_household_name FROM households WHERE id = p_household_id;
    CALL sp_notification_create(
      v_invitee_id,
      'household_invitation_received',
      'Household invitation',
      CONCAT('You have been invited to join ', v_household_name),
      'household_invitation',
      v_invitation_id
    );
  END IF;

  SELECT v_invitation_id AS invitation_id;
END$$

-- ─── sp_household_accept_invitation ──────────────────────────────────────────
-- Validate token, add accepting user to household, mark invitation accepted,
-- and notify the inviter that their invitation was accepted.
-- Note: the invitee was already notified when sp_household_invite was called.

CREATE OR REPLACE PROCEDURE sp_household_accept_invitation(
  IN p_token_hash        VARCHAR(255),
  IN p_accepting_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_invitation_id   CHAR(36);
  DECLARE v_household_id    CHAR(36);
  DECLARE v_inviter_id      CHAR(36);
  DECLARE v_household_name  VARCHAR(255);
  DECLARE v_accepting_email VARCHAR(255);

  -- Fetch and validate the invitation
  SELECT i.id, i.household_id, i.invited_by_user_id
  INTO v_invitation_id, v_household_id, v_inviter_id
  FROM household_invitations i
  WHERE i.token_hash = p_token_hash
    AND i.status = 'pending'
    AND i.expires_at > NOW()
  LIMIT 1;

  IF v_invitation_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or expired invitation token';
  END IF;

  SELECT name INTO v_household_name FROM households WHERE id = v_household_id;
  SELECT email INTO v_accepting_email FROM users WHERE id = p_accepting_user_id;

  -- Add member (ignore duplicate in case of retry)
  INSERT IGNORE INTO household_members (household_id, user_id)
  VALUES (v_household_id, p_accepting_user_id);

  -- Mark invitation accepted
  UPDATE household_invitations
  SET status = 'accepted'
  WHERE id = v_invitation_id;

  -- Notify inviter: their invitation was accepted
  CALL sp_notification_create(
    v_inviter_id,
    'household_invitation_accepted',
    'Invitation accepted',
    CONCAT(v_accepting_email, ' has joined ', v_household_name),
    'household',
    v_household_id
  );

  SELECT v_household_id AS household_id;
END$$

-- ─── sp_household_remove_member ──────────────────────────────────────────────
-- Remove a member from a household. Only the household owner can call this.
-- Creates a notification for the removed user.

CREATE OR REPLACE PROCEDURE sp_household_remove_member(
  IN p_household_id       CHAR(36),
  IN p_target_user_id     CHAR(36),
  IN p_requesting_user_id CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_owner_id       CHAR(36);
  DECLARE v_household_name VARCHAR(255);
  DECLARE v_target_email   VARCHAR(255);

  SELECT owner_user_id, name INTO v_owner_id, v_household_name
  FROM households WHERE id = p_household_id;

  -- Only the owner can remove members
  IF p_requesting_user_id != v_owner_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: only the household owner can remove members';
  END IF;

  -- Owner cannot remove themselves via this procedure
  IF p_target_user_id = v_owner_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The household owner cannot be removed';
  END IF;

  SELECT email INTO v_target_email FROM users WHERE id = p_target_user_id;

  DELETE FROM household_members
  WHERE household_id = p_household_id AND user_id = p_target_user_id;

  -- Notify removed user
  CALL sp_notification_create(
    p_target_user_id,
    'household_member_removed',
    'Removed from household',
    CONCAT('You have been removed from ', v_household_name),
    'household',
    p_household_id
  );
END$$

-- ─── sp_household_leave ──────────────────────────────────────────────────────
-- Allow a non-owner member to leave a household.
-- Creates a notification for the household owner.

CREATE OR REPLACE PROCEDURE sp_household_leave(
  IN p_household_id CHAR(36),
  IN p_user_id      CHAR(36)
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_owner_id       CHAR(36);
  DECLARE v_household_name VARCHAR(255);
  DECLARE v_leaving_email  VARCHAR(255);

  SELECT owner_user_id, name INTO v_owner_id, v_household_name
  FROM households WHERE id = p_household_id;

  -- Owner cannot leave; they must delete the household or transfer ownership
  IF p_user_id = v_owner_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The household owner cannot leave; delete the household instead';
  END IF;

  -- User must be a member
  IF NOT EXISTS (
    SELECT 1 FROM household_members
    WHERE household_id = p_household_id AND user_id = p_user_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not a member of this household';
  END IF;

  SELECT email INTO v_leaving_email FROM users WHERE id = p_user_id;

  DELETE FROM household_members
  WHERE household_id = p_household_id AND user_id = p_user_id;

  -- Notify the owner
  CALL sp_notification_create(
    v_owner_id,
    'household_member_left',
    'Member left household',
    CONCAT(v_leaving_email, ' has left ', v_household_name),
    'household',
    p_household_id
  );
END$$

DELIMITER ;
