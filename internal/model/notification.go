package model

import (
	"database/sql"
	"fmt"
	"time"
)

// Notification represents a row from the notifications table.
type Notification struct {
	ID            string
	UserID        string
	Type          string
	Title         string
	Body          string
	ReferenceType string
	ReferenceID   string
	IsRead        bool
	CreatedAt     time.Time
}

// GetAllNotifications calls sp_notification_get_all.
func GetAllNotifications(db *sql.DB, userID string) ([]Notification, error) {
	rows, err := db.Query("CALL sp_notification_get_all(?)", userID)
	if err != nil {
		return nil, fmt.Errorf("model.GetAllNotifications: %w", err)
	}
	defer rows.Close()

	var notifs []Notification
	for rows.Next() {
		var n Notification
		var refType sql.NullString
		var refID sql.NullString
		var readAt sql.NullTime
		if err := rows.Scan(
			&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body,
			&refType, &refID, &n.IsRead, &readAt, &n.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("model.GetAllNotifications scan: %w", err)
		}
		if refType.Valid {
			n.ReferenceType = refType.String
		}
		if refID.Valid {
			n.ReferenceID = refID.String
		}
		notifs = append(notifs, n)
	}
	return notifs, rows.Err()
}

// MarkRead calls sp_notification_mark_read.
func MarkRead(db *sql.DB, notificationID, userID string) error {
	rows, err := db.Query("CALL sp_notification_mark_read(?, ?)", notificationID, userID)
	if err != nil {
		return fmt.Errorf("model.MarkRead: %w", err)
	}
	return rows.Close()
}

// MarkAllRead calls sp_notification_mark_all_read.
func MarkAllRead(db *sql.DB, userID string) error {
	rows, err := db.Query("CALL sp_notification_mark_all_read(?)", userID)
	if err != nil {
		return fmt.Errorf("model.MarkAllRead: %w", err)
	}
	return rows.Close()
}

// UnreadCount calls sp_notification_unread_count and returns the number of unread notifications.
func UnreadCount(db *sql.DB, userID string) (int, error) {
	rows, err := db.Query("CALL sp_notification_unread_count(?)", userID)
	if err != nil {
		return 0, fmt.Errorf("model.UnreadCount: %w", err)
	}
	defer rows.Close()

	var count int
	if rows.Next() {
		if err := rows.Scan(&count); err != nil {
			return 0, fmt.Errorf("model.UnreadCount scan: %w", err)
		}
	}
	return count, rows.Err()
}
