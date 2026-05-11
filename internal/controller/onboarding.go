package controller

import (
	"database/sql"
	"encoding/json"
	"html/template"
	"net/http"

	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
)

func GetOnboarding(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		goals, err := model.GetGoals(db)
		if err != nil {
			serverError(w, r, "GetGoals", err)
			return
		}
		dietTypes, err := model.GetDietTypes(db)
		if err != nil {
			serverError(w, r, "GetDietTypes", err)
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

		goalsJSON, err := json.Marshal(goalOpts)
		if err != nil {
			serverError(w, r, "marshal goals", err)
			return
		}
		dietJSON, err := json.Marshal(dietOpts)
		if err != nil {
			serverError(w, r, "marshal diet types", err)
			return
		}

		data := vm.OnboardingVM{
			BaseVM:      vm.BaseVM{Chrome: vm.ChromeVM{ShowSidebar: false}},
			Goals:       goalOpts,
			DietTypes:   dietOpts,
			GoalsJS:     template.JS(goalsJSON),
			DietTypesJS: template.JS(dietJSON),
		}
		if err := v.Render(w, "onboarding.gohtml", data); err != nil {
			serverError(w, r, "render onboarding", err)
		}
	}
}
