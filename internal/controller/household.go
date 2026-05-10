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
	"github.com/go-chi/chi/v5"
)

// GetHousehold renders the household page with members and schedule.
func GetHousehold(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)

		base, err := buildBaseVM(db, userID, "household")
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		householdID, err := model.FindHouseholdByUser(db, userID)
		if err != nil || householdID == "" {
			// User has no household yet — redirect to onboarding.
			http.Redirect(w, r, "/onboarding/1", http.StatusSeeOther)
			return
		}

		household, members, err := model.GetHousehold(db, householdID, userID)
		if err != nil {
			http.Error(w, "household error", http.StatusInternalServerError)
			return
		}

		// Build member VMs.
		memberVMs := make([]vm.MemberVM, 0, len(members))
		for _, m := range members {
			memberVMs = append(memberVMs, vm.MemberVM{
				Name:     m.DisplayName,
				Initials: m.Initials,
				Tint:     m.AvatarTint,
			})
		}

		// Build a static schedule template (7 days, all members "in").
		days := []string{"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
		var scheduleRows []vm.ScheduleRowVM
		for _, m := range members {
			name := m.DisplayName
			if len([]rune(name)) > 3 {
				name = string([]rune(name)[:3])
			}
			row := vm.ScheduleRowVM{
				MemberShort: name,
				In:          []bool{true, true, true, true, true, true, true},
			}
			scheduleRows = append(scheduleRows, row)
		}

		data := vm.HouseholdVM{
			BaseVM: base,
			Topbar: vm.TopbarVM{
				Title: household.Name,
				Actions: []vm.ActionVM{
					{
						Label:   "Invite member",
						Icon:    "user-plus",
						Variant: "primary",
						Href:    "/household?invite=1",
					},
				},
			},
			Name:    household.Name,
			Members: memberVMs,
			Schedule: struct {
				Days []string
				Rows []vm.ScheduleRowVM
			}{
				Days: days,
				Rows: scheduleRows,
			},
			InviteOpen: r.URL.Query().Get("invite") == "1",
		}

		if err := v.Render(w, "household.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostInvite sends a household invitation.
func PostInvite(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		email := strings.TrimSpace(r.FormValue("email"))
		if email == "" {
			http.Redirect(w, r, "/household?invite=1", http.StatusSeeOther)
			return
		}

		householdID, err := model.FindHouseholdByUser(db, userID)
		if err != nil || householdID == "" {
			http.Error(w, "no household", http.StatusBadRequest)
			return
		}

		raw := make([]byte, 32)
		if _, err := rand.Read(raw); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		sum := sha256.Sum256(raw)
		tokenHash := hex.EncodeToString(sum[:])
		expiresAt := time.Now().Add(7 * 24 * time.Hour)

		if _, err := model.InviteMember(db, householdID, userID, email, tokenHash, expiresAt); err != nil {
			http.Error(w, "invite error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/household", http.StatusSeeOther)
	}
}

// GetJoinHousehold accepts a household invitation via a token in the URL.
func GetJoinHousehold(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		rawToken := chi.URLParam(r, "token")

		raw, err := hex.DecodeString(rawToken)
		if err != nil {
			http.Error(w, "invalid token", http.StatusBadRequest)
			return
		}
		sum := sha256.Sum256(raw)
		tokenHash := hex.EncodeToString(sum[:])

		householdID, err := model.AcceptInvitation(db, tokenHash, userID)
		if err != nil {
			http.Error(w, "invitation error: "+err.Error(), http.StatusBadRequest)
			return
		}

		_ = householdID
		http.Redirect(w, r, "/household", http.StatusSeeOther)
	}
}

// PostLeaveHousehold lets the current user leave their household.
func PostLeaveHousehold(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)

		householdID, err := model.FindHouseholdByUser(db, userID)
		if err != nil || householdID == "" {
			http.Error(w, "no household", http.StatusBadRequest)
			return
		}

		if err := model.LeaveHousehold(db, householdID, userID); err != nil {
			http.Error(w, "leave error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/onboarding/1", http.StatusSeeOther)
	}
}

// PostRemoveMember removes a member from the household (owner only).
func PostRemoveMember(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		targetUserID := r.FormValue("user_id")
		if targetUserID == "" {
			http.Error(w, "user_id required", http.StatusBadRequest)
			return
		}

		householdID, err := model.FindHouseholdByUser(db, userID)
		if err != nil || householdID == "" {
			http.Error(w, "no household", http.StatusBadRequest)
			return
		}

		if err := model.RemoveMember(db, householdID, targetUserID, userID); err != nil {
			http.Error(w, "remove error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/household", http.StatusSeeOther)
	}
}
