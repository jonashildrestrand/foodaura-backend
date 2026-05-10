package controller

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/foodaura/backend/internal/middleware"
	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
	"github.com/go-chi/chi/v5"
)

// notifIconTint maps a notification type to an icon name and tint.
func notifIconTint(notifType string) (icon, tint string) {
	switch notifType {
	case "household_invitation_received":
		return "mail", "p"
	case "household_invitation_accepted":
		return "user-check", "sage"
	case "household_member_left":
		return "log-out", "neutral"
	case "household_member_removed":
		return "user-minus", "neutral"
	case "meal_plan_ready":
		return "calendar-check", "p"
	default:
		return "bell", "neutral"
	}
}

// GetNotifications renders the notifications page with Today/Week bucketing.
func GetNotifications(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)

		base, err := buildBaseVM(db, userID, "notifications")
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		notifs, err := model.GetAllNotifications(db, userID)
		if err != nil {
			http.Error(w, "notifications error", http.StatusInternalServerError)
			return
		}

		today := time.Now().Truncate(24 * time.Hour)
		mondayOfWeek := currentWeekMonday()

		var todayVMs []vm.NotifVM
		var weekVMs []vm.NotifVM

		for _, n := range notifs {
			icon, tint := notifIconTint(n.Type)

			var cta *vm.ActionVM
			if n.ReferenceType == "household" && n.ReferenceID != "" {
				cta = &vm.ActionVM{
					Label:   "View household",
					Icon:    "users",
					Variant: "ghost",
					Href:    "/household",
				}
			} else if n.ReferenceType == "meal_plan" && n.ReferenceID != "" {
				cta = &vm.ActionVM{
					Label:   "View plan",
					Icon:    "calendar-days",
					Variant: "ghost",
					Href:    "/plan",
				}
			}

			notifVM := vm.NotifVM{
				Tint:   tint,
				Icon:   icon,
				Title:  n.Title,
				Body:   n.Body,
				Time:   n.CreatedAt.Format("Jan 2, 15:04"),
				Unread: !n.IsRead,
				CTA:    cta,
			}

			// Bucket: today vs earlier this week.
			createdDay := n.CreatedAt.Truncate(24 * time.Hour)
			if !createdDay.Before(today) {
				todayVMs = append(todayVMs, notifVM)
			} else if !createdDay.Before(mondayOfWeek) {
				weekVMs = append(weekVMs, notifVM)
			} else {
				// Issue #39: all others also go into Week.
				weekVMs = append(weekVMs, notifVM)
			}
		}

		data := vm.NotifsVM{
			BaseVM: base,
			Topbar: vm.TopbarVM{
				Title: "Notifications",
			},
			Today: todayVMs,
			Week:  weekVMs,
		}

		if err := v.Render(w, "notifications.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostMarkAllRead marks all notifications as read for the current user.
func PostMarkAllRead(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)

		if err := model.MarkAllRead(db, userID); err != nil {
			http.Error(w, "mark all read error", http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/notifications", http.StatusSeeOther)
	}
}

// PostMarkRead marks a single notification as read.
func PostMarkRead(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		notifID := chi.URLParam(r, "id")

		if err := model.MarkRead(db, notifID, userID); err != nil {
			http.Error(w, "mark read error", http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/notifications", http.StatusSeeOther)
	}
}
