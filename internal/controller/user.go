package controller

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/foodaura/backend/internal/model"
	"golang.org/x/crypto/bcrypt"
)

type registerRequest struct {
	Email         string   `json:"email"`
	DisplayName   string   `json:"display_name"`
	Password      string   `json:"password"`
	HouseholdName string   `json:"household_name"`
	Goal          string   `json:"goal"`
	DietType      string   `json:"diet_type"`
	Dislikes      []string `json:"dislikes"`
	InviteEmail   string   `json:"invite_email"`
}

// PostUsers accepts all registration data in one JSON request and atomically
// creates the user, household, profile, dislikes, and session.
func PostUsers(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req registerRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		req.Email = strings.TrimSpace(req.Email)
		req.DisplayName = strings.TrimSpace(req.DisplayName)
		req.HouseholdName = strings.TrimSpace(req.HouseholdName)
		req.InviteEmail = strings.TrimSpace(req.InviteEmail)
		if req.Goal == "" {
			req.Goal = "eat_better"
		}
		if req.DietType == "" {
			req.DietType = "omnivore"
		}

		if req.Email == "" || req.Password == "" || req.DisplayName == "" || req.HouseholdName == "" {
			http.Error(w, "email, password, name, and household name are required", http.StatusBadRequest)
			return
		}

		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		tx, err := db.Begin()
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		defer tx.Rollback() //nolint:errcheck

		userID, err := txQueryScalar(tx, "CALL sp_auth_create_user(?, ?, ?)", req.Email, req.DisplayName, string(hash))
		if err != nil {
			http.Error(w, "could not create account: "+err.Error(), http.StatusInternalServerError)
			return
		}
		if userID == "" {
			http.Error(w, "could not create account", http.StatusInternalServerError)
			return
		}

		householdID, err := txQueryScalar(tx, "CALL sp_household_create(?, ?)", req.HouseholdName, userID)
		if err != nil {
			http.Error(w, "could not create household: "+err.Error(), http.StatusInternalServerError)
			return
		}

		if err := txExec(tx, "CALL sp_profile_upsert(?, ?, ?, ?, ?, ?, ?, ?)",
			userID, "male", 30, 70.0, 175.0, "moderate", req.Goal, req.DietType,
		); err != nil {
			http.Error(w, "profile error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		for _, ing := range req.Dislikes {
			ing = strings.TrimSpace(ing)
			if ing == "" {
				continue
			}
			_ = txExec(tx, "CALL sp_preference_add_ingredient_dislike(?, ?)", userID, ing)
		}

		raw := make([]byte, 32)
		if _, err := rand.Read(raw); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		token := hex.EncodeToString(raw)
		sum := sha256.Sum256(raw)
		tokenHash := hex.EncodeToString(sum[:])
		expiresAt := time.Now().Add(30 * 24 * time.Hour)

		if err := txExec(tx, "CALL sp_auth_create_session(?, ?, ?)", userID, tokenHash, expiresAt); err != nil {
			http.Error(w, "session error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		if err := tx.Commit(); err != nil {
			http.Error(w, "commit error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		// Best-effort invite — runs after commit so it uses the committed user/household.
		if req.InviteEmail != "" && householdID != "" {
			invRaw := make([]byte, 32)
			if _, err := rand.Read(invRaw); err == nil {
				invSum := sha256.Sum256(invRaw)
				invExpires := time.Now().Add(7 * 24 * time.Hour)
				_, _ = model.InviteMember(db, householdID, userID, req.InviteEmail, hex.EncodeToString(invSum[:]), invExpires)
			}
		}

		http.SetCookie(w, &http.Cookie{
			Name:     "session",
			Value:    token,
			Path:     "/",
			MaxAge:   2592000,
			HttpOnly: true,
			Secure:   true,
			SameSite: http.SameSiteStrictMode,
		})

		w.WriteHeader(http.StatusCreated)
	}
}

// txQueryScalar runs a stored procedure on tx and returns the first column of
// the first row as a string.
func txQueryScalar(tx *sql.Tx, query string, args ...any) (string, error) {
	rows, err := tx.Query(query, args...)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	var val string
	if rows.Next() {
		if err := rows.Scan(&val); err != nil {
			return "", err
		}
	}
	return val, rows.Err()
}

// txExec runs a stored procedure on tx and discards the result set.
func txExec(tx *sql.Tx, query string, args ...any) error {
	rows, err := tx.Query(query, args...)
	if err != nil {
		return err
	}
	return rows.Close()
}
