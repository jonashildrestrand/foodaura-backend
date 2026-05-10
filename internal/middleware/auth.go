package middleware

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"net/http"

	"github.com/foodaura/backend/internal/model"
)

// contextKey is an unexported type for context keys in this package.
type contextKey string

// UserIDKey is the context key used to store the authenticated user's ID.
const UserIDKey contextKey = "userID"

// Auth returns a chi-compatible middleware that validates the "session" cookie.
// On success it injects the user_id into the request context.
// On failure it redirects to /login.
func Auth(db *sql.DB) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			cookie, err := r.Cookie("session")
			if err != nil || cookie.Value == "" {
				http.Redirect(w, r, "/login", http.StatusSeeOther)
				return
			}

			// The token stored in the cookie is the raw hex-encoded 32-byte token.
			// The DB stores SHA-256(raw token).
			raw, err := hex.DecodeString(cookie.Value)
			if err != nil {
				http.Redirect(w, r, "/login", http.StatusSeeOther)
				return
			}
			sum := sha256.Sum256(raw)
			tokenHash := hex.EncodeToString(sum[:])

			userID, err := model.GetSession(db, tokenHash)
			if err != nil || userID == "" {
				http.Redirect(w, r, "/login", http.StatusSeeOther)
				return
			}

			ctx := context.WithValue(r.Context(), UserIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
