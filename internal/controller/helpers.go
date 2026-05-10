package controller

import (
	"database/sql"
	"fmt"
	"strings"

	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/vm"
)

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
		return vm.BaseVM{}, fmt.Errorf("buildBaseVM GetUser: %w", err)
	}
	if user == nil {
		return vm.BaseVM{}, fmt.Errorf("buildBaseVM: user not found")
	}

	unread, err := model.UnreadCount(db, userID)
	if err != nil {
		return vm.BaseVM{}, fmt.Errorf("buildBaseVM UnreadCount: %w", err)
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

// httpError writes a plain-text 500 response.
func httpError(w interface{ WriteHeader(int); Write([]byte) (int, error) }, msg string) {
	w.WriteHeader(500)
	fmt.Fprintf(w, "<h1>Internal Server Error</h1><p>%s</p>", msg)
}
