package controller

import (
	"database/sql"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/foodaura/backend/internal/middleware"
	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
	"github.com/go-chi/chi/v5"
)

// currentWeekMonday returns the Monday of the current week at midnight local time.
func currentWeekMonday() time.Time {
	now := time.Now()
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7 // Sunday = 7 in ISO 8601
	}
	monday := now.AddDate(0, 0, -(weekday - 1))
	return time.Date(monday.Year(), monday.Month(), monday.Day(), 0, 0, 0, 0, monday.Location())
}

// dayAbbrev converts a day_of_week index (0=Monday) to a 3-letter abbreviation.
func dayAbbrev(d int) string {
	days := []string{"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
	if d >= 0 && d < len(days) {
		return days[d]
	}
	return ""
}

// mealTypeLabel maps a meal_type string to its short label and tone.
func mealTypeLabel(mt string) (label, tone string) {
	switch strings.ToLower(mt) {
	case "breakfast":
		return "Brk", "peach"
	case "lunch":
		return "Lun", "oat"
	case "dinner":
		return "Din", "peach"
	case "snack":
		return "Snk", "sage"
	default:
		return mt, "neutral"
	}
}

// GetPlan renders the current week's meal plan.
func GetPlan(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)

		base, err := buildBaseVM(db, userID, "plan")
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		householdID, err := model.FindHouseholdByUser(db, userID)
		if err != nil || householdID == "" {
			http.Redirect(w, r, "/onboarding/1", http.StatusSeeOther)
			return
		}

		monday := currentWeekMonday()

		planID, err := model.GetOrCreateMealPlan(db, householdID, monday, userID)
		if err != nil {
			http.Error(w, "plan error", http.StatusInternalServerError)
			return
		}

		plan, slots, participants, err := model.GetMealPlan(db, planID, userID)
		if err != nil {
			http.Error(w, "plan fetch error", http.StatusInternalServerError)
			return
		}
		_ = plan

		// Group slots by day.
		slotsByDay := make(map[int][]model.MealSlot)
		for _, s := range slots {
			slotsByDay[s.DayOfWeek] = append(slotsByDay[s.DayOfWeek], s)
		}

		// Build per-day nutrition totals.
		type dayNutrition struct {
			Kcal    int
			Protein int
			Carbs   int
			Fat     int
		}
		dayNutritions := make(map[int]dayNutrition)
		for _, s := range slots {
			if s.RecipeID != "" {
				dn := dayNutritions[s.DayOfWeek]
				dn.Kcal += s.RecipeCalories
				dn.Protein += int(s.RecipeProteinG)
				dn.Carbs += int(s.RecipeCarbsG)
				dn.Fat += int(s.RecipeFatG)
				dayNutritions[s.DayOfWeek] = dn
			}
		}

		// Build DayColumnVMs.
		days := make([]vm.DayColumnVM, 7)
		for d := 0; d < 7; d++ {
			date := monday.AddDate(0, 0, d)
			daySlots := slotsByDay[d]

			slotVMs := make([]vm.SlotVM, 0, len(daySlots))
			for _, s := range daySlots {
				label, tone := mealTypeLabel(s.MealType)
				if s.RecipeID == "" {
					slotVMs = append(slotVMs, vm.SlotVM{
						Meal:   label,
						Tone:   tone,
						Empty:  true,
						AddURL: fmt.Sprintf("/discover?slot=%s", s.ID),
					})
				} else {
					slotVMs = append(slotVMs, vm.SlotVM{
						Meal:      label,
						Name:      s.RecipeTitle,
						Kcal:      s.RecipeCalories,
						Tone:      tone,
						RecipeURL: "/recipes/" + s.RecipeID,
						Empty:     false,
					})
				}
			}

			dn := dayNutritions[d]
			days[d] = vm.DayColumnVM{
				Day:   dayAbbrev(d),
				Date:  fmt.Sprintf("%d", date.Day()),
				Slots: slotVMs,
				DayTotal: vm.NutritionVM{
					Kcal:    dn.Kcal,
					Protein: dn.Protein,
					Carbs:   dn.Carbs,
					Fat:     dn.Fat,
				},
			}
		}

		// Calculate plan stats.
		mealsPlanned := 0
		emptySlots := 0
		for _, s := range slots {
			if s.RecipeID != "" {
				mealsPlanned++
			} else {
				emptySlots++
			}
		}

		// Count distinct participants across all slots.
		distinctUsers := make(map[string]struct{})
		for _, p := range participants {
			distinctUsers[p.UserID] = struct{}{}
		}
		membersIn := len(distinctUsers)

		weekEnd := monday.AddDate(0, 0, 6)
		topbarSub := fmt.Sprintf(
			"%s %d – %s %d",
			monday.Format("Jan"), monday.Day(),
			weekEnd.Format("Jan"), weekEnd.Day(),
		)

		data := vm.PlanVM{
			BaseVM: base,
			Topbar: vm.TopbarVM{
				Eyebrow: "Week of",
				Title:   topbarSub,
			},
			Days: days,
		}
		data.Stats.MealsPlanned = mealsPlanned
		data.Stats.EmptySlots = emptySlots
		data.Stats.MembersIn = membersIn

		if err := v.Render(w, "plan.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostAssignRecipe assigns a recipe to a meal slot.
func PostAssignRecipe(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		slotID := chi.URLParam(r, "slotID")

		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		recipeID := r.FormValue("recipe_id")
		if recipeID == "" {
			http.Error(w, "recipe_id required", http.StatusBadRequest)
			return
		}

		if err := model.AssignRecipe(db, slotID, recipeID, []string{userID}); err != nil {
			http.Error(w, "assign error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/plan", http.StatusSeeOther)
	}
}

// PostClearSlot removes the recipe assignment from a meal slot.
func PostClearSlot(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		slotID := chi.URLParam(r, "slotID")

		if err := model.ClearSlot(db, slotID); err != nil {
			http.Error(w, "clear error: "+err.Error(), http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/plan", http.StatusSeeOther)
	}
}
