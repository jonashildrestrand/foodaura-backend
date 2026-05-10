package model

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

// MealPlan represents a row from the meal_plans table.
type MealPlan struct {
	ID            string
	HouseholdID   string
	WeekStartDate time.Time
	CreatedAt     time.Time
}

// MealSlot represents a slot row from sp_mealplan_get.
type MealSlot struct {
	ID                    string
	DayOfWeek             int
	MealType              string
	RecipeID              string
	RecipeTitle           string
	RecipeCalories        int
	RecipeProteinG        float64
	RecipeCarbsG          float64
	RecipeFatG            float64
	RecipeCookTimeMinutes int
}

// SlotParticipant represents a participant row from sp_mealplan_get.
type SlotParticipant struct {
	MealSlotID  string
	UserID      string
	DisplayName string
	Email       string
}

// GetOrCreateMealPlan calls sp_mealplan_get_or_create and returns the meal_plan_id.
func GetOrCreateMealPlan(db *sql.DB, householdID string, weekStartDate time.Time, requestingUserID string) (string, error) {
	rows, err := db.Query(
		"CALL sp_mealplan_get_or_create(?, ?, ?)",
		householdID, weekStartDate.Format("2006-01-02"), requestingUserID,
	)
	if err != nil {
		return "", fmt.Errorf("model.GetOrCreateMealPlan: %w", err)
	}
	defer rows.Close()

	var mealPlanID string
	if rows.Next() {
		if err := rows.Scan(&mealPlanID); err != nil {
			return "", fmt.Errorf("model.GetOrCreateMealPlan scan: %w", err)
		}
	}
	return mealPlanID, rows.Err()
}

// GetMealPlan calls sp_mealplan_get and returns the plan, slots, and participants.
func GetMealPlan(db *sql.DB, mealPlanID, requestingUserID string) (*MealPlan, []MealSlot, []SlotParticipant, error) {
	rows, err := db.Query("CALL sp_mealplan_get(?, ?)", mealPlanID, requestingUserID)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("model.GetMealPlan: %w", err)
	}
	defer rows.Close()

	// First result set: meal plan header.
	var plan MealPlan
	if rows.Next() {
		if err := rows.Scan(&plan.ID, &plan.HouseholdID, &plan.WeekStartDate, &plan.CreatedAt); err != nil {
			return nil, nil, nil, fmt.Errorf("model.GetMealPlan plan scan: %w", err)
		}
	}

	// Second result set: slots.
	var slots []MealSlot
	if rows.NextResultSet() {
		for rows.Next() {
			var s MealSlot
			var recipeID sql.NullString
			var recipeTitle sql.NullString
			var recipeCalories sql.NullInt64
			var recipeProteinG sql.NullFloat64
			var recipeCarbsG sql.NullFloat64
			var recipeFatG sql.NullFloat64
			var recipeCookTime sql.NullInt64
			if err := rows.Scan(
				&s.ID, &s.DayOfWeek, &s.MealType,
				&recipeID, &recipeTitle, &recipeCalories,
				&recipeProteinG, &recipeCarbsG, &recipeFatG, &recipeCookTime,
			); err != nil {
				return nil, nil, nil, fmt.Errorf("model.GetMealPlan slot scan: %w", err)
			}
			if recipeID.Valid {
				s.RecipeID = recipeID.String
			}
			if recipeTitle.Valid {
				s.RecipeTitle = recipeTitle.String
			}
			if recipeCalories.Valid {
				s.RecipeCalories = int(recipeCalories.Int64)
			}
			if recipeProteinG.Valid {
				s.RecipeProteinG = recipeProteinG.Float64
			}
			if recipeCarbsG.Valid {
				s.RecipeCarbsG = recipeCarbsG.Float64
			}
			if recipeFatG.Valid {
				s.RecipeFatG = recipeFatG.Float64
			}
			if recipeCookTime.Valid {
				s.RecipeCookTimeMinutes = int(recipeCookTime.Int64)
			}
			slots = append(slots, s)
		}
	}

	// Third result set: participants.
	var participants []SlotParticipant
	if rows.NextResultSet() {
		for rows.Next() {
			var p SlotParticipant
			if err := rows.Scan(&p.MealSlotID, &p.UserID, &p.DisplayName, &p.Email); err != nil {
				return nil, nil, nil, fmt.Errorf("model.GetMealPlan participant scan: %w", err)
			}
			participants = append(participants, p)
		}
	}

	return &plan, slots, participants, rows.Err()
}

// AssignRecipe calls sp_mealplan_assign_recipe.
// participantUserIDs is marshaled to JSON and passed to the stored procedure.
func AssignRecipe(db *sql.DB, mealSlotID, recipeID string, participantUserIDs []string) error {
	if participantUserIDs == nil {
		participantUserIDs = []string{}
	}
	jsonIDs, err := json.Marshal(participantUserIDs)
	if err != nil {
		return fmt.Errorf("model.AssignRecipe marshal: %w", err)
	}

	rows, err := db.Query(
		"CALL sp_mealplan_assign_recipe(?, ?, ?)",
		mealSlotID, recipeID, string(jsonIDs),
	)
	if err != nil {
		return fmt.Errorf("model.AssignRecipe: %w", err)
	}
	return rows.Close()
}

// ClearSlot calls sp_mealplan_clear_slot.
func ClearSlot(db *sql.DB, mealSlotID string) error {
	rows, err := db.Query("CALL sp_mealplan_clear_slot(?)", mealSlotID)
	if err != nil {
		return fmt.Errorf("model.ClearSlot: %w", err)
	}
	return rows.Close()
}

// HistoryEntry is a reduced view of a meal plan for history listing.
type HistoryEntry struct {
	ID            string
	WeekStartDate time.Time
}

// GetHistory calls sp_mealplan_get_history and returns a slice of history entries.
func GetHistory(db *sql.DB, householdID, requestingUserID string) ([]HistoryEntry, error) {
	rows, err := db.Query("CALL sp_mealplan_get_history(?, ?)", householdID, requestingUserID)
	if err != nil {
		return nil, fmt.Errorf("model.GetHistory: %w", err)
	}
	defer rows.Close()

	var result []HistoryEntry
	for rows.Next() {
		var e HistoryEntry
		if err := rows.Scan(&e.ID, &e.WeekStartDate); err != nil {
			return nil, fmt.Errorf("model.GetHistory scan: %w", err)
		}
		result = append(result, e)
	}
	return result, rows.Err()
}
