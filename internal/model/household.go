package model

import (
	"database/sql"
	"fmt"
	"time"
)

// Household represents a row from the households table.
type Household struct {
	ID          string
	Name        string
	OwnerUserID string
	CreatedAt   time.Time
}

// HouseholdMember represents a member row returned by sp_household_get.
type HouseholdMember struct {
	UserID      string
	Email       string
	DisplayName string
	Initials    string
	AvatarTint  string
	JoinedAt    time.Time
}

// CreateHousehold calls sp_household_create and returns the new household_id.
func CreateHousehold(db *sql.DB, name, ownerUserID string) (string, error) {
	rows, err := db.Query("CALL sp_household_create(?, ?)", name, ownerUserID)
	if err != nil {
		return "", fmt.Errorf("model.CreateHousehold: %w", err)
	}
	defer rows.Close()

	var householdID string
	if rows.Next() {
		if err := rows.Scan(&householdID); err != nil {
			return "", fmt.Errorf("model.CreateHousehold scan: %w", err)
		}
	}
	return householdID, rows.Err()
}

// GetHousehold calls sp_household_get and returns the household plus its members.
// Returns two result sets from the stored procedure.
func GetHousehold(db *sql.DB, householdID, requestingUserID string) (*Household, []HouseholdMember, error) {
	rows, err := db.Query("CALL sp_household_get(?, ?)", householdID, requestingUserID)
	if err != nil {
		return nil, nil, fmt.Errorf("model.GetHousehold: %w", err)
	}
	defer rows.Close()

	// First result set: household header.
	var h Household
	if rows.Next() {
		if err := rows.Scan(&h.ID, &h.Name, &h.OwnerUserID, &h.CreatedAt); err != nil {
			return nil, nil, fmt.Errorf("model.GetHousehold household scan: %w", err)
		}
	}

	// Second result set: members.
	var members []HouseholdMember
	if rows.NextResultSet() {
		for rows.Next() {
			var m HouseholdMember
			if err := rows.Scan(&m.UserID, &m.Email, &m.DisplayName, &m.Initials, &m.AvatarTint, &m.JoinedAt); err != nil {
				return nil, nil, fmt.Errorf("model.GetHousehold member scan: %w", err)
			}
			members = append(members, m)
		}
	}
	return &h, members, rows.Err()
}

// InviteMember calls sp_household_invite and returns the invitation_id.
func InviteMember(db *sql.DB, householdID, invitedByUserID, email, tokenHash string, expiresAt time.Time) (string, error) {
	rows, err := db.Query(
		"CALL sp_household_invite(?, ?, ?, ?, ?)",
		householdID, invitedByUserID, email, tokenHash, expiresAt,
	)
	if err != nil {
		return "", fmt.Errorf("model.InviteMember: %w", err)
	}
	defer rows.Close()

	var invitationID string
	if rows.Next() {
		if err := rows.Scan(&invitationID); err != nil {
			return "", fmt.Errorf("model.InviteMember scan: %w", err)
		}
	}
	return invitationID, rows.Err()
}

// AcceptInvitation calls sp_household_accept_invitation and returns the household_id.
func AcceptInvitation(db *sql.DB, tokenHash, acceptingUserID string) (string, error) {
	rows, err := db.Query("CALL sp_household_accept_invitation(?, ?)", tokenHash, acceptingUserID)
	if err != nil {
		return "", fmt.Errorf("model.AcceptInvitation: %w", err)
	}
	defer rows.Close()

	var householdID string
	if rows.Next() {
		if err := rows.Scan(&householdID); err != nil {
			return "", fmt.Errorf("model.AcceptInvitation scan: %w", err)
		}
	}
	return householdID, rows.Err()
}

// RemoveMember calls sp_household_remove_member.
func RemoveMember(db *sql.DB, householdID, targetUserID, requestingUserID string) error {
	rows, err := db.Query("CALL sp_household_remove_member(?, ?, ?)", householdID, targetUserID, requestingUserID)
	if err != nil {
		return fmt.Errorf("model.RemoveMember: %w", err)
	}
	return rows.Close()
}

// LeaveHousehold calls sp_household_leave.
func LeaveHousehold(db *sql.DB, householdID, userID string) error {
	rows, err := db.Query("CALL sp_household_leave(?, ?)", householdID, userID)
	if err != nil {
		return fmt.Errorf("model.LeaveHousehold: %w", err)
	}
	return rows.Close()
}

// FindHouseholdByUser calls sp_household_find_by_user and returns the household_id.
// It returns an empty string (and no error) when the user has no household.
func FindHouseholdByUser(db *sql.DB, userID string) (string, error) {
	rows, err := db.Query("CALL sp_household_find_by_user(?)", userID)
	if err != nil {
		return "", fmt.Errorf("model.FindHouseholdByUser: %w", err)
	}
	defer rows.Close()

	var householdID string
	if rows.Next() {
		if err := rows.Scan(&householdID); err != nil {
			return "", fmt.Errorf("model.FindHouseholdByUser scan: %w", err)
		}
	}
	return householdID, rows.Err()
}
