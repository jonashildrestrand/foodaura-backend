package controller

import (
	"database/sql"
	"fmt"
	"net/http"
	"strconv"

	"github.com/foodaura/backend/internal/middleware"
	"github.com/foodaura/backend/internal/model"
	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
	"github.com/go-chi/chi/v5"
)

// GetShopping handles both GET /shoppinglist (redirect) and GET /shoppinglist/{planID}.
func GetShopping(db *sql.DB, v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value(middleware.UserIDKey).(string)

		planID := chi.URLParam(r, "planID")
		if planID == "" {
			// Derive the current plan and redirect.
			householdID, err := model.FindHouseholdByUser(db, userID)
			if err != nil || householdID == "" {
				http.Redirect(w, r, "/onboarding/1", http.StatusSeeOther)
				return
			}
			monday := currentWeekMonday()
			id, err := model.GetOrCreateMealPlan(db, householdID, monday, userID)
			if err != nil {
				http.Error(w, "plan error", http.StatusInternalServerError)
				return
			}
			http.Redirect(w, r, "/shoppinglist/"+id, http.StatusSeeOther)
			return
		}

		base, err := buildBaseVM(db, userID, "shopping")
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		items, err := model.GetShoppingList(db, planID, userID)
		if err != nil {
			http.Error(w, "shopping list error", http.StatusInternalServerError)
			return
		}

		// Group items by category.
		categoryOrder := []string{}
		categoryMap := make(map[string][]struct {
			ID       int64
			Quantity string
			Unit     string
			Name     string
			Bought   bool
		})

		for _, item := range items {
			if _, exists := categoryMap[item.Category]; !exists {
				categoryOrder = append(categoryOrder, item.Category)
			}
			categoryMap[item.Category] = append(categoryMap[item.Category], struct {
				ID       int64
				Quantity string
				Unit     string
				Name     string
				Bought   bool
			}{
				Quantity: strconv.FormatFloat(item.TotalQuantity, 'f', -1, 64),
				Unit:     item.Unit,
				Name:     item.IngredientName,
				Bought:   item.IsChecked,
			})
		}

		categories := make([]struct {
			Name  string
			Items []struct {
				ID       int64
				Quantity string
				Unit     string
				Name     string
				Bought   bool
			}
		}, 0, len(categoryOrder))

		for _, cat := range categoryOrder {
			categories = append(categories, struct {
				Name  string
				Items []struct {
					ID       int64
					Quantity string
					Unit     string
					Name     string
					Bought   bool
				}
			}{
				Name:  cat,
				Items: categoryMap[cat],
			})
		}

		// Build week range from the plan's start date.
		weekRange := ""
		history, _ := model.GetHistory(db, "", userID)
		for _, h := range history {
			if h.ID == planID {
				end := h.WeekStartDate.AddDate(0, 0, 6)
				weekRange = fmt.Sprintf("%s %d – %s %d",
					h.WeekStartDate.Format("Jan"), h.WeekStartDate.Day(),
					end.Format("Jan"), end.Day(),
				)
				break
			}
		}

		data := vm.ShoppingVM{
			BaseVM: base,
			Topbar: vm.TopbarVM{
				Title: "Shopping list",
				Sub:   weekRange,
			},
			WeekRange:  weekRange,
			Categories: categories,
		}

		if err := v.Render(w, "shopping.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}

// PostToggleItem toggles the checked state of a shopping list item.
func PostToggleItem(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		planID := chi.URLParam(r, "planID")
		itemID := chi.URLParam(r, "itemID")

		if err := r.ParseForm(); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		// Toggle: if the form sends "checked=1" it's being checked, otherwise unchecked.
		// Since we don't have current state from the form, read it from the query or just toggle.
		// The template posts to /shoppinglist/{planID}/item/{itemID}/toggle — we derive state
		// from the form value "checked" (1 = checked, 0 or absent = unchecked).
		isChecked := r.FormValue("checked") == "1"

		if err := model.ToggleItem(db, itemID, isChecked); err != nil {
			http.Error(w, "toggle error", http.StatusInternalServerError)
			return
		}

		http.Redirect(w, r, "/shoppinglist/"+planID, http.StatusSeeOther)
	}
}
