package model

import (
	"database/sql"
	"fmt"
	"time"
)

// Profile represents a row from nutritional_profiles.
type Profile struct {
	ID            string
	UserID        string
	BiologicalSex string
	Age           int
	WeightKg      float64
	HeightCm      float64
	ActivityLevel string
	Goal          string
	DietType      string
	UpdatedAt     time.Time
}

// Targets represents a row from nutritional_targets.
type Targets struct {
	Calories int
	ProteinG int
	CarbsG   int
	FatG     int
}

// UpsertProfile calls sp_profile_upsert.
func UpsertProfile(db *sql.DB, userID, biologicalSex string, age int, weightKg, heightCm float64, activityLevel, goal, dietType string) error {
	rows, err := db.Query(
		"CALL sp_profile_upsert(?, ?, ?, ?, ?, ?, ?, ?)",
		userID, biologicalSex, age, weightKg, heightCm, activityLevel, goal, dietType,
	)
	if err != nil {
		return fmt.Errorf("model.UpsertProfile: %w", err)
	}
	return rows.Close()
}

// GetProfile calls sp_profile_get and returns the user's nutritional profile.
// Returns nil, nil when the profile does not exist.
func GetProfile(db *sql.DB, userID string) (*Profile, error) {
	rows, err := db.Query("CALL sp_profile_get(?)", userID)
	if err != nil {
		return nil, fmt.Errorf("model.GetProfile: %w", err)
	}
	defer rows.Close()

	if rows.Next() {
		var p Profile
		if err := rows.Scan(
			&p.ID, &p.UserID, &p.BiologicalSex, &p.Age,
			&p.WeightKg, &p.HeightCm, &p.ActivityLevel,
			&p.Goal, &p.DietType, &p.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("model.GetProfile scan: %w", err)
		}
		return &p, rows.Err()
	}
	return nil, rows.Err()
}

// GetTargets calls sp_targets_get and returns the user's nutritional targets.
// Returns nil, nil when no targets exist.
func GetTargets(db *sql.DB, userID string) (*Targets, error) {
	rows, err := db.Query("CALL sp_targets_get(?)", userID)
	if err != nil {
		return nil, fmt.Errorf("model.GetTargets: %w", err)
	}
	defer rows.Close()

	if rows.Next() {
		var id, uid string
		var calcAt time.Time
		var t Targets
		if err := rows.Scan(&id, &uid, &t.Calories, &t.ProteinG, &t.CarbsG, &t.FatG, &calcAt); err != nil {
			return nil, fmt.Errorf("model.GetTargets scan: %w", err)
		}
		return &t, rows.Err()
	}
	return nil, rows.Err()
}

// AddIngredientDislike calls sp_preference_add_ingredient_dislike.
func AddIngredientDislike(db *sql.DB, userID, ingredientName string) error {
	rows, err := db.Query("CALL sp_preference_add_ingredient_dislike(?, ?)", userID, ingredientName)
	if err != nil {
		return fmt.Errorf("model.AddIngredientDislike: %w", err)
	}
	return rows.Close()
}

// SetRecipePreference calls sp_preference_set_recipe.
func SetRecipePreference(db *sql.DB, userID, recipeID, preference string) error {
	rows, err := db.Query("CALL sp_preference_set_recipe(?, ?, ?)", userID, recipeID, preference)
	if err != nil {
		return fmt.Errorf("model.SetRecipePreference: %w", err)
	}
	return rows.Close()
}
