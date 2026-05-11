package controller

import (
	"database/sql"
	"net/http"
	"strconv"
	"strings"

	"github.com/foodaura/backend/internal/middleware"
	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
	"github.com/go-chi/chi/v5"
)

// tagTone maps a tag category name to a tone string used in the UI.
func tagTone(category string) string {
	switch strings.ToLower(category) {
	case "diet":
		return "brand"
	case "meal":
		return "affirm"
	default:
		return "neutral"
	}
}

// GetDiscover renders the recipe discovery page.
func GetDiscover(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)

		base, err := buildBaseVM(db, userID, "discover")
		if err != nil {
			serverError(w, r, "buildBaseVM discover", err)
			return
		}

		searchTerm := r.URL.Query().Get("q")
		activeTagID := r.URL.Query().Get("filter")

		allTags, err := model.ListTags(db, "")
		if err != nil {
			serverError(w, r, "ListTags", err)
			return
		}

		filters := make([]struct {
			Label  string
			Value  string
			Active bool
		}, 0, len(allTags)+1)

		filters = append(filters, struct {
			Label  string
			Value  string
			Active bool
		}{Label: "All", Value: "", Active: activeTagID == ""})

		for _, t := range allTags {
			filters = append(filters, struct {
				Label  string
				Value  string
				Active bool
			}{
				Label:  t.Name,
				Value:  t.ID,
				Active: t.ID == activeTagID,
			})
		}

		recipes, tags, err := model.FindRecipes(db, userID, "", 0, searchTerm, activeTagID, 50, 0)
		if err != nil {
			serverError(w, r, "FindRecipes", err)
			return
		}

		tagsByRecipe := make(map[string][]vm.TagVM)
		for _, t := range tags {
			tagsByRecipe[t.RecipeID] = append(tagsByRecipe[t.RecipeID], vm.TagVM{
				Tone:  tagTone(t.Category),
				Label: t.TagName,
			})
		}

		recipeVMs := make([]vm.RecipeCardVM, 0, len(recipes))
		for _, rc := range recipes {
			tone := "neutral"
			if tgs := tagsByRecipe[rc.ID]; len(tgs) > 0 {
				tone = tgs[0].Tone
			}
			recipeVMs = append(recipeVMs, vm.RecipeCardVM{
				Name:           rc.Title,
				Tone:           tone,
				MinutesHandsOn: rc.CookTimeMinutes,
				Servings:       rc.ServingsBase,
				Tags:           tagsByRecipe[rc.ID],
			})
		}

		data := vm.DiscoverVM{
			BaseVM: base,
			Topbar: vm.TopbarVM{
				Title: "Discover",
			},
			Search:  searchTerm,
			Filters: filters,
			Recipes: recipeVMs,
		}

		if err := v.Render(w, "discover.gohtml", data); err != nil {
			serverError(w, r, "render discover", err)
		}
	}
}

// GetRecipe renders the recipe detail page.
func GetRecipe(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		recipeID := chi.URLParam(r, "id")

		base, err := buildBaseVM(db, userID, "discover")
		if err != nil {
			serverError(w, r, "buildBaseVM recipe", err)
			return
		}

		detail, ingredients, steps, err := model.GetRecipe(db, recipeID)
		if err != nil {
			serverError(w, r, "GetRecipe", err)
			return
		}
		if detail == nil {
			http.NotFound(w, r)
			return
		}

		ingVMs := make([]struct {
			Quantity string
			Unit     string
			Name     string
		}, 0, len(ingredients))
		for _, ing := range ingredients {
			ingVMs = append(ingVMs, struct {
				Quantity string
				Unit     string
				Name     string
			}{
				Quantity: strconv.FormatFloat(ing.Quantity, 'f', -1, 64),
				Unit:     ing.Unit,
				Name:     ing.Name,
			})
		}

		stepStrs := make([]string, 0, len(steps))
		for _, s := range steps {
			stepStrs = append(stepStrs, s.Instruction)
		}

		data := vm.RecipeVM{
			BaseVM: base,
			Topbar: vm.TopbarVM{
				Title: detail.Title,
				Actions: []vm.ActionVM{
					{
						Label:      "Like",
						Icon:       "heart",
						Variant:    "ghost",
						FormAction: "/recipes/" + recipeID + "/preference",
						FormMethod: "post",
					},
				},
			},
			Name:     detail.Title,
			Tone:     "neutral",
			Servings: detail.ServingsBase,
			Minutes:  detail.CookTimeMinutes,
			Nutrition: vm.NutritionVM{
				Protein: int(detail.ProteinG),
				Carbs:   int(detail.CarbsG),
				Fat:     int(detail.FatG),
				Kcal:    detail.Calories,
			},
			Steps:       stepStrs,
			Ingredients: ingVMs,
		}

		if err := v.Render(w, "recipe.gohtml", data); err != nil {
			serverError(w, r, "render recipe", err)
		}
	}
}

// PostRecipePreference sets a like or dislike for a recipe.
func PostRecipePreference(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)
		recipeID := chi.URLParam(r, "id")

		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		preference := r.FormValue("preference")
		if preference == "" {
			preference = "like"
		}

		if err := model.SetRecipePreference(db, userID, recipeID, preference); err != nil {
			serverError(w, r, "SetRecipePreference", err)
			return
		}

		http.Redirect(w, r, "/recipes/"+recipeID, http.StatusSeeOther)
	}
}
