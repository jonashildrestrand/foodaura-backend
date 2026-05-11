package controller

import (
	"database/sql"
	"net/http"
	"strconv"

	"github.com/foodaura/backend/internal/middleware"
	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
)

// GetProfileSetup renders the initial profile setup form.
func GetProfileSetup(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)

		base, err := buildBaseVM(db, userID, "settings")
		if err != nil {
			serverError(w, r, "buildBaseVM profile/setup", err)
			return
		}

		data := vm.SettingsVM{
			BaseVM: base,
			Topbar: vm.TopbarVM{
				Title: "Profile setup",
				Sub:   "Tell us about yourself so we can personalise your plan.",
			},
			Sections: profileSections("", "", "", "", "", "", ""),
		}

		if err := v.Render(w, "settings.gohtml", data); err != nil {
			serverError(w, r, "render profile/setup", err)
		}
	}
}

// PostProfileSetup saves the initial profile and redirects to /plan.
func PostProfileSetup(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		if err := saveProfile(db, userID, r); err != nil {
			serverError(w, r, "saveProfile setup", err)
			return
		}

		http.Redirect(w, r, "/plan", http.StatusSeeOther)
	}
}

// GetProfileEdit renders the profile edit form pre-filled with existing data.
func GetProfileEdit(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)

		base, err := buildBaseVM(db, userID, "settings")
		if err != nil {
			serverError(w, r, "buildBaseVM profile/edit", err)
			return
		}

		profile, _ := model.GetProfile(db, userID)

		var bioSex, age, weightKg, heightCm, activity, goal, dietType string
		if profile != nil {
			bioSex = profile.BiologicalSex
			age = strconv.Itoa(profile.Age)
			weightKg = strconv.FormatFloat(profile.WeightKg, 'f', 1, 64)
			heightCm = strconv.FormatFloat(profile.HeightCm, 'f', 1, 64)
			activity = profile.ActivityLevel
			goal = profile.Goal
			dietType = profile.DietType
		}

		data := vm.SettingsVM{
			BaseVM: base,
			Topbar: vm.TopbarVM{
				Title: "Edit profile",
			},
			Sections: profileSections(bioSex, age, weightKg, heightCm, activity, goal, dietType),
		}

		if err := v.Render(w, "settings.gohtml", data); err != nil {
			serverError(w, r, "render profile/edit", err)
		}
	}
}

// PostProfileEdit saves profile changes and redirects back to the edit page.
func PostProfileEdit(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		if err := saveProfile(db, userID, r); err != nil {
			serverError(w, r, "saveProfile edit", err)
			return
		}

		http.Redirect(w, r, "/profile/edit", http.StatusSeeOther)
	}
}

// saveProfile parses form values and calls UpsertProfile.
func saveProfile(db *sql.DB, userID string, r *http.Request) error {
	bioSex := r.FormValue("biological_sex")
	if bioSex == "" {
		bioSex = "male"
	}

	ageStr := r.FormValue("age")
	age := 30
	if v, err := strconv.Atoi(ageStr); err == nil && v > 0 {
		age = v
	}

	weightStr := r.FormValue("weight_kg")
	weightKg := 70.0
	if v, err := strconv.ParseFloat(weightStr, 64); err == nil && v > 0 {
		weightKg = v
	}

	heightStr := r.FormValue("height_cm")
	heightCm := 175.0
	if v, err := strconv.ParseFloat(heightStr, 64); err == nil && v > 0 {
		heightCm = v
	}

	activity := r.FormValue("activity_level")
	if activity == "" {
		activity = "moderate"
	}

	goal := r.FormValue("goal")
	if goal == "" {
		goal = "eat_better"
	}

	dietType := r.FormValue("diet_type")
	if dietType == "" {
		dietType = "omnivore"
	}

	return model.UpsertProfile(db, userID, bioSex, age, weightKg, heightCm, activity, goal, dietType)
}

// profileSections returns SettingsSectionVM slice for the profile form.
func profileSections(bioSex, age, weightKg, heightCm, activity, goal, dietType string) []vm.SettingsSectionVM {
	return []vm.SettingsSectionVM{
		{
			ID:    "profile",
			Title: "Your profile",
			Sub:   "We use this to calculate your nutritional targets.",
			Icon:  "user",
			Rows: []vm.SettingsRowVM{
				{
					Label: "Biological sex",
					Control: vm.SettingsControlVM{
						Kind:    "seg",
						Name:    "biological_sex",
						Value:   bioSex,
						Options: []string{"male", "female"},
					},
				},
				{
					Label: "Age",
					Control: vm.SettingsControlVM{
						Kind:  "text",
						Name:  "age",
						Value: age,
					},
				},
				{
					Label: "Weight (kg)",
					Control: vm.SettingsControlVM{
						Kind:  "text",
						Name:  "weight_kg",
						Value: weightKg,
					},
				},
				{
					Label: "Height (cm)",
					Control: vm.SettingsControlVM{
						Kind:  "text",
						Name:  "height_cm",
						Value: heightCm,
					},
				},
				{
					Label: "Activity level",
					Control: vm.SettingsControlVM{
						Kind:    "seg",
						Name:    "activity_level",
						Value:   activity,
						Options: []string{"sedentary", "light", "moderate", "active", "very_active"},
					},
				},
				{
					Label: "Goal",
					Control: vm.SettingsControlVM{
						Kind:    "seg",
						Name:    "goal",
						Value:   goal,
						Options: []string{"lose_weight", "maintain", "build_muscle", "eat_better"},
					},
				},
				{
					Label: "Diet type",
					Control: vm.SettingsControlVM{
						Kind:    "seg",
						Name:    "diet_type",
						Value:   dietType,
						Options: []string{"omnivore", "vegetarian", "vegan", "pescatarian"},
					},
				},
			},
		},
	}
}
