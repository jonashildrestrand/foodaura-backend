package model

import (
	"database/sql"
	"fmt"
	"time"
)

// User represents a row from the users table.
type User struct {
	ID           string
	Email        string
	DisplayName  string
	PasswordHash string
}

// CreateUser calls sp_auth_create_user and returns the new user_id.
func CreateUser(db *sql.DB, email, displayName, passwordHash string) (string, error) {
	rows, err := db.Query("CALL sp_auth_create_user(?, ?, ?)", email, displayName, passwordHash)
	if err != nil {
		return "", fmt.Errorf("model.CreateUser: %w", err)
	}
	defer rows.Close()

	var userID string
	if rows.Next() {
		if err := rows.Scan(&userID); err != nil {
			return "", fmt.Errorf("model.CreateUser scan: %w", err)
		}
	}
	return userID, rows.Err()
}

// GetUserByEmail calls sp_auth_get_user_by_email and returns the matching user.
// Returns nil, nil when the user does not exist.
func GetUserByEmail(db *sql.DB, email string) (*User, error) {
	rows, err := db.Query("CALL sp_auth_get_user_by_email(?)", email)
	if err != nil {
		return nil, fmt.Errorf("model.GetUserByEmail: %w", err)
	}
	defer rows.Close()

	if rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Email, &u.DisplayName, &u.PasswordHash); err != nil {
			return nil, fmt.Errorf("model.GetUserByEmail scan: %w", err)
		}
		return &u, rows.Err()
	}
	return nil, rows.Err()
}

// GetUser calls sp_auth_get_user and returns the matching user.
// Returns nil, nil when the user does not exist.
func GetUser(db *sql.DB, userID string) (*User, error) {
	rows, err := db.Query("CALL sp_auth_get_user(?)", userID)
	if err != nil {
		return nil, fmt.Errorf("model.GetUser: %w", err)
	}
	defer rows.Close()

	if rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Email, &u.DisplayName); err != nil {
			return nil, fmt.Errorf("model.GetUser scan: %w", err)
		}
		return &u, rows.Err()
	}
	return nil, rows.Err()
}

// CreateSession calls sp_auth_create_session and returns the new session_id.
func CreateSession(db *sql.DB, userID, tokenHash string, expiresAt time.Time) (string, error) {
	rows, err := db.Query("CALL sp_auth_create_session(?, ?, ?)", userID, tokenHash, expiresAt)
	if err != nil {
		return "", fmt.Errorf("model.CreateSession: %w", err)
	}
	defer rows.Close()

	var sessionID string
	if rows.Next() {
		if err := rows.Scan(&sessionID); err != nil {
			return "", fmt.Errorf("model.CreateSession scan: %w", err)
		}
	}
	return sessionID, rows.Err()
}

// GetSession calls sp_auth_get_session and returns the associated user_id.
// Returns an empty string when the session is not found or expired.
func GetSession(db *sql.DB, tokenHash string) (string, error) {
	rows, err := db.Query("CALL sp_auth_get_session(?)", tokenHash)
	if err != nil {
		return "", fmt.Errorf("model.GetSession: %w", err)
	}
	defer rows.Close()

	var userID string
	var newExpiresAt time.Time
	if rows.Next() {
		if err := rows.Scan(&userID, &newExpiresAt); err != nil {
			return "", fmt.Errorf("model.GetSession scan: %w", err)
		}
	}
	return userID, rows.Err()
}

// DeleteSession calls sp_auth_delete_session.
func DeleteSession(db *sql.DB, tokenHash string) error {
	rows, err := db.Query("CALL sp_auth_delete_session(?)", tokenHash)
	if err != nil {
		return fmt.Errorf("model.DeleteSession: %w", err)
	}
	return rows.Close()
}
