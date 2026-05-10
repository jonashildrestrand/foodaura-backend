package controller

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"net/http"
	"strings"
	"time"

	"github.com/foodaura/backend/internal/middleware"
	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
	"golang.org/x/crypto/bcrypt"
)

var onbStepNames = []string{"Account", "Household", "Invite", "Diet & Goals", "Review"}

func onbBase(step int) vm.OnboardingVM {
	return vm.OnboardingVM{
		BaseVM: vm.BaseVM{
			Chrome: vm.ChromeVM{ShowSidebar: false},
		},
		Step:      step,
		StepNames: onbStepNames,
	}
}

// GetOnboarding0 renders step 0: account creation.
func GetOnboarding0(v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		data := onbBase(0)
		if err := v.Render(w, "onboarding.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostOnboarding0 creates a user account and session, then redirects to step 1.
func PostOnboarding0(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		email := strings.TrimSpace(r.FormValue("email"))
		displayName := strings.TrimSpace(r.FormValue("display_name"))
		password := r.FormValue("password")

		hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		userID, err := model.CreateUser(db, email, displayName, string(hash))
		if err != nil {
			http.Error(w, "could not create account: "+err.Error(), http.StatusInternalServerError)
			return
		}

		// Create session immediately.
		raw := make([]byte, 32)
		if _, err := rand.Read(raw); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		token := hex.EncodeToString(raw)
		sum := sha256.Sum256(raw)
		tokenHash := hex.EncodeToString(sum[:])

		expiresAt := time.Now().Add(30 * 24 * time.Hour)
		if _, err := model.CreateSession(db, userID, tokenHash, expiresAt); err != nil {
			http.Error(w, "session error", http.StatusInternalServerError)
			return
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

		http.Redirect(w, r, "/onboarding/1", http.StatusSeeOther)
	}
}

// GetOnboarding1 renders step 1: household name.
func GetOnboarding1(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		data := onbBase(1)

		// Pre-fill household name if one already exists.
		householdID, _ := model.FindHouseholdByUser(db, userID)
		if householdID != "" {
			h, _, _ := model.GetHousehold(db, householdID, userID)
			if h != nil {
				data.Form.Household = h.Name
			}
		}

		if err := v.Render(w, "onboarding.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostOnboarding1 creates a household and redirects to step 2.
func PostOnboarding1(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		householdName := strings.TrimSpace(r.FormValue("household_name"))
		if householdName == "" {
			http.Error(w, "household name is required", http.StatusBadRequest)
			return
		}

		if _, err := model.CreateHousehold(db, householdName, userID); err != nil {
			http.Error(w, "could not create household: "+err.Error(), http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/onboarding/2", http.StatusSeeOther)
	}
}

// GetOnboarding2 renders step 2: invite members.
func GetOnboarding2(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		data := onbBase(2)

		// Show existing members in the form.
		householdID, _ := model.FindHouseholdByUser(db, userID)
		if householdID != "" {
			_, members, _ := model.GetHousehold(db, householdID, userID)
			for _, m := range members {
				if m.UserID != userID {
					data.Form.Members = append(data.Form.Members, vm.MemberVM{
						Name:     m.DisplayName,
						Initials: m.Initials,
						Tint:     m.AvatarTint,
					})
				}
			}
		}

		if err := v.Render(w, "onboarding.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostOnboarding2 sends an invitation (if email provided) and redirects to step 3.
func PostOnboarding2(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		inviteEmail := strings.TrimSpace(r.FormValue("invite_email"))
		if inviteEmail != "" {
			householdID, err := model.FindHouseholdByUser(db, userID)
			if err != nil || householdID == "" {
				http.Redirect(w, r, "/onboarding/3", http.StatusSeeOther)
				return
			}

			raw := make([]byte, 32)
			if _, err := rand.Read(raw); err == nil {
				sum := sha256.Sum256(raw)
				tokenHash := hex.EncodeToString(sum[:])
				expiresAt := time.Now().Add(7 * 24 * time.Hour)
				_, _ = model.InviteMember(db, householdID, userID, inviteEmail, tokenHash, expiresAt)
			}
		}

		http.Redirect(w, r, "/onboarding/3", http.StatusSeeOther)
	}
}

// GetOnboarding3 renders step 3: diet & goals.
func GetOnboarding3(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		data := onbBase(3)

		profile, _ := model.GetProfile(db, userID)
		if profile != nil {
			data.Form.Goal = profile.Goal
			data.Form.DietType = profile.DietType
		}

		if err := v.Render(w, "onboarding.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostOnboarding3 saves profile and ingredient dislikes, then redirects to step 4.
func PostOnboarding3(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		goal := r.FormValue("goal")
		if goal == "" {
			goal = "eat_better"
		}
		dietType := r.FormValue("diet_type")
		if dietType == "" {
			dietType = "omnivore"
		}

		if err := model.UpsertProfile(
			db, userID,
			"male",   // biological_sex default
			30,       // age default
			70.0,     // weight_kg default
			175.0,    // height_cm default
			"moderate", // activity_level default
			goal,
			dietType,
		); err != nil {
			http.Error(w, "profile error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		// Process comma-separated ingredient dislikes.
		avoid := r.FormValue("avoid")
		for _, ing := range strings.Split(avoid, ",") {
			ing = strings.TrimSpace(ing)
			if ing != "" {
				_ = model.AddIngredientDislike(db, userID, ing)
			}
		}

		http.Redirect(w, r, "/onboarding/4", http.StatusSeeOther)
	}
}

// GetOnboarding4 renders step 4: review summary.
func GetOnboarding4(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		data := onbBase(4)

		// Populate summary from DB.
		householdID, _ := model.FindHouseholdByUser(db, userID)
		if householdID != "" {
			h, _, _ := model.GetHousehold(db, householdID, userID)
			if h != nil {
				data.Form.Household = h.Name
			}
		}

		profile, _ := model.GetProfile(db, userID)
		if profile != nil {
			data.Form.Goal = profile.Goal
			data.Form.DietType = profile.DietType
		}

		if err := v.Render(w, "onboarding.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostOnboarding4 redirects to the plan page.
func PostOnboarding4() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/plan", http.StatusSeeOther)
	}
}
