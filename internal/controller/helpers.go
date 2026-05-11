package controller

import (
	"database/sql"
	"log/slog"
	"net/http"
	"strings"

	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
)

var errRenderer *view.Renderer

// InitErrorRenderer sets the renderer used by serverError and notFound.
// Must be called from main before any routes are registered.
func InitErrorRenderer(r *view.Renderer) { errRenderer = r }

// serverError logs err and renders the 500 error page (falls back to plain text).
func serverError(w http.ResponseWriter, r *http.Request, msg string, err error) {
	slog.ErrorContext(r.Context(), msg, "error", err, "path", r.URL.Path)
	if errRenderer != nil {
		errRenderer.RenderError(w, http.StatusInternalServerError)
		return
	}
	http.Error(w, "internal server error", http.StatusInternalServerError)
}

// NotFoundHandler returns an http.HandlerFunc that renders the 404 error page.
func NotFoundHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if errRenderer != nil {
			errRenderer.RenderError(w, http.StatusNotFound)
			return
		}
		http.NotFound(w, r)
	}
}

// initials computes up to two-character uppercase initials from a display name.
func initials(name string) string {
	name = strings.TrimSpace(name)
	words := strings.Fields(name)
	if len(words) == 0 {
		return ""
	}
	if len(words) == 1 {
		runes := []rune(name)
		if len(runes) >= 2 {
			return strings.ToUpper(string(runes[:2]))
		}
		return strings.ToUpper(name)
	}
	r0 := []rune(words[0])
	r1 := []rune(words[1])
	return strings.ToUpper(string(r0[0])) + strings.ToUpper(string(r1[0]))
}

// buildBaseVM fetches sidebar data and builds a BaseVM for the given user.
func buildBaseVM(db *sql.DB, userID, activeRoute string) (vm.BaseVM, error) {
	user, err := model.GetUser(db, userID)
	if err != nil {
		return vm.BaseVM{}, err
	}
	if user == nil {
		return vm.BaseVM{}, sql.ErrNoRows
	}

	unread, err := model.UnreadCount(db, userID)
	if err != nil {
		return vm.BaseVM{}, err
	}

	return vm.BaseVM{
		Chrome: vm.ChromeVM{ShowSidebar: true},
		Sidebar: vm.SidebarVM{
			ActiveRoute:  activeRoute,
			UnreadNotifs: unread,
			CurrentUser: vm.MemberVM{
				Name:     user.DisplayName,
				Initials: initials(user.DisplayName),
				Tint:     "p",
			},
		},
	}, nil
}
