package controller

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"net/http"
	"time"

	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
	"golang.org/x/crypto/bcrypt"
)

// GetLogin renders the login page.
func GetLogin(v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		data := vm.LoginVM{
			BaseVM: vm.BaseVM{
				Chrome: vm.ChromeVM{ShowSidebar: false},
			},
		}
		if err := v.Render(w, "login.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostLogin authenticates a user and creates a session.
func PostLogin(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		email := r.FormValue("email")
		password := r.FormValue("password")

		renderError := func(msg string) {
			data := vm.LoginVM{
				BaseVM: vm.BaseVM{Chrome: vm.ChromeVM{ShowSidebar: false}},
				Error:  msg,
			}
			w.WriteHeader(http.StatusUnauthorized)
			_ = v.Render(w, "login.gohtml", data)
		}

		user, err := model.GetUserByEmail(db, email)
		if err != nil {
			renderError("Something went wrong. Please try again.")
			return
		}
		if user == nil {
			renderError("Invalid email or password.")
			return
		}

		if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
			renderError("Invalid email or password.")
			return
		}

		// Generate a 32-byte random token and hex-encode it for the cookie.
		raw := make([]byte, 32)
		if _, err := rand.Read(raw); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		token := hex.EncodeToString(raw) // 64-char hex string stored in the cookie.

		// The DB stores the SHA-256 of the raw bytes.
		sum := sha256.Sum256(raw)
		tokenHash := hex.EncodeToString(sum[:])

		expiresAt := time.Now().Add(30 * 24 * time.Hour)
		if _, err := model.CreateSession(db, user.ID, tokenHash, expiresAt); err != nil {
			http.Error(w, "session error", http.StatusInternalServerError)
			return
		}

		http.SetCookie(w, &http.Cookie{
			Name:     "session",
			Value:    token,
			Path:     "/",
			MaxAge:   2592000, // 30 days in seconds
			HttpOnly: true,
			Secure:   true,
			SameSite: http.SameSiteStrictMode,
		})

		http.Redirect(w, r, "/plan", http.StatusSeeOther)
	}
}

// PostLogout clears the session cookie and deletes the session from the DB.
func PostLogout(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("session")
		if err == nil && cookie.Value != "" {
			raw, err := hex.DecodeString(cookie.Value)
			if err == nil {
				sum := sha256.Sum256(raw)
				tokenHash := hex.EncodeToString(sum[:])
				_ = model.DeleteSession(db, tokenHash)
			}
		}

		http.SetCookie(w, &http.Cookie{
			Name:     "session",
			Value:    "",
			Path:     "/",
			MaxAge:   -1,
			HttpOnly: true,
			Secure:   true,
			SameSite: http.SameSiteStrictMode,
		})

		http.Redirect(w, r, "/login", http.StatusSeeOther)
	}
}
