package controller

import (
	"database/sql"
	"net/http"

	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
)

func GetOnboarding(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		goals, err := model.GetGoals(db)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		dietTypes, err := model.GetDietTypes(db)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		goalOpts := make([]vm.GoalOption, len(goals))
		for i, g := range goals {
			goalOpts[i] = vm.GoalOption{Value: g.Value, Label: g.Label, Icon: g.Icon}
		}
		dietOpts := make([]vm.DietTypeOption, len(dietTypes))
		for i, d := range dietTypes {
			dietOpts[i] = vm.DietTypeOption{Value: d.Value, Label: d.Label}
		}

		data := vm.OnboardingVM{
			BaseVM:    vm.BaseVM{Chrome: vm.ChromeVM{ShowSidebar: false}},
			Goals:     goalOpts,
			DietTypes: dietOpts,
		}
		if err := v.Render(w, "onboarding.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}
