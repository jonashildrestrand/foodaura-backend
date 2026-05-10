package model

import (
	"database/sql"
	"fmt"
	"time"
)

// RecipeRow is one record from sp_recipe_find's first result set.
type RecipeRow struct {
	ID              string
	Title           string
	Cuisine         string
	CookTimeMinutes int
	ServingsBase    int
	Calories        int
	ProteinG        float64
}

// RecipeTag is one record from sp_recipe_find's second result set.
type RecipeTag struct {
	RecipeID string
	TagID    string
	Category string
	TagName  string
}

// RecipeDetail is the header row from sp_recipe_get's first result set.
type RecipeDetail struct {
	ID              string
	Title           string
	Description     string
	Cuisine         string
	CookTimeMinutes int
	ServingsBase    int
	Calories        int
	ProteinG        float64
	CarbsG          float64
	FatG            float64
	CreatedAt       time.Time
}

// Ingredient is one record from sp_recipe_get's second result set.
type Ingredient struct {
	ID       string
	RecipeID string
	Name     string
	Quantity float64
	Unit     string
	Category string
}

// RecipeStep is one record from sp_recipe_get's third result set.
type RecipeStep struct {
	ID          string
	StepNumber  int
	Instruction string
}

// ScaledIngredient is one record returned by sp_recipe_scale.
type ScaledIngredient struct {
	Name           string
	ScaledQuantity float64
	Unit           string
	Category       string
}

// Tag is one record returned by sp_tag_list.
type Tag struct {
	ID           string
	Name         string
	CategoryName string
}

// FindRecipes calls sp_recipe_find and returns two result sets.
func FindRecipes(db *sql.DB, userID, cuisine string, maxCookTime int, searchTerm, tagID string, limit, offset int) ([]RecipeRow, []RecipeTag, error) {
	var cuisineArg, searchArg, tagArg interface{}
	if cuisine != "" {
		cuisineArg = cuisine
	}
	var cookTimeArg interface{}
	if maxCookTime > 0 {
		cookTimeArg = maxCookTime
	}
	if searchTerm != "" {
		searchArg = searchTerm
	}
	if tagID != "" {
		tagArg = tagID
	}

	rows, err := db.Query(
		"CALL sp_recipe_find(?, ?, ?, ?, ?, ?, ?)",
		userID, cuisineArg, cookTimeArg, searchArg, tagArg, limit, offset,
	)
	if err != nil {
		return nil, nil, fmt.Errorf("model.FindRecipes: %w", err)
	}
	defer rows.Close()

	// First result set: recipe rows.
	var recipes []RecipeRow
	for rows.Next() {
		var r RecipeRow
		if err := rows.Scan(&r.ID, &r.Title, &r.Cuisine, &r.CookTimeMinutes, &r.ServingsBase, &r.Calories, &r.ProteinG); err != nil {
			return nil, nil, fmt.Errorf("model.FindRecipes recipe scan: %w", err)
		}
		recipes = append(recipes, r)
	}

	// Second result set: tags.
	var tags []RecipeTag
	if rows.NextResultSet() {
		for rows.Next() {
			var t RecipeTag
			if err := rows.Scan(&t.RecipeID, &t.TagID, &t.Category, &t.TagName); err != nil {
				return nil, nil, fmt.Errorf("model.FindRecipes tag scan: %w", err)
			}
			tags = append(tags, t)
		}
	}

	return recipes, tags, rows.Err()
}

// GetRecipe calls sp_recipe_get and returns the detail, ingredients, and steps.
func GetRecipe(db *sql.DB, recipeID string) (*RecipeDetail, []Ingredient, []RecipeStep, error) {
	rows, err := db.Query("CALL sp_recipe_get(?)", recipeID)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("model.GetRecipe: %w", err)
	}
	defer rows.Close()

	// First result set: recipe header.
	var d RecipeDetail
	if rows.Next() {
		if err := rows.Scan(
			&d.ID, &d.Title, &d.Description, &d.Cuisine,
			&d.CookTimeMinutes, &d.ServingsBase,
			&d.Calories, &d.ProteinG, &d.CarbsG, &d.FatG, &d.CreatedAt,
		); err != nil {
			return nil, nil, nil, fmt.Errorf("model.GetRecipe detail scan: %w", err)
		}
	}

	// Second result set: ingredients.
	var ingredients []Ingredient
	if rows.NextResultSet() {
		for rows.Next() {
			var ing Ingredient
			if err := rows.Scan(&ing.ID, &ing.RecipeID, &ing.Name, &ing.Quantity, &ing.Unit, &ing.Category); err != nil {
				return nil, nil, nil, fmt.Errorf("model.GetRecipe ingredient scan: %w", err)
			}
			ingredients = append(ingredients, ing)
		}
	}

	// Third result set: steps.
	var steps []RecipeStep
	if rows.NextResultSet() {
		for rows.Next() {
			var s RecipeStep
			if err := rows.Scan(&s.ID, &s.StepNumber, &s.Instruction); err != nil {
				return nil, nil, nil, fmt.Errorf("model.GetRecipe step scan: %w", err)
			}
			steps = append(steps, s)
		}
	}

	return &d, ingredients, steps, rows.Err()
}

// ScaleRecipe calls sp_recipe_scale and returns the scaled ingredients.
func ScaleRecipe(db *sql.DB, recipeID, mealSlotID string) ([]ScaledIngredient, error) {
	rows, err := db.Query("CALL sp_recipe_scale(?, ?)", recipeID, mealSlotID)
	if err != nil {
		return nil, fmt.Errorf("model.ScaleRecipe: %w", err)
	}
	defer rows.Close()

	var result []ScaledIngredient
	for rows.Next() {
		var s ScaledIngredient
		if err := rows.Scan(&s.Name, &s.ScaledQuantity, &s.Unit, &s.Category); err != nil {
			return nil, fmt.Errorf("model.ScaleRecipe scan: %w", err)
		}
		result = append(result, s)
	}
	return result, rows.Err()
}

// ListTags calls sp_tag_list and returns matching tags.
func ListTags(db *sql.DB, categoryID string) ([]Tag, error) {
	var arg interface{}
	if categoryID != "" {
		arg = categoryID
	}

	rows, err := db.Query("CALL sp_tag_list(?)", arg)
	if err != nil {
		return nil, fmt.Errorf("model.ListTags: %w", err)
	}
	defer rows.Close()

	var tags []Tag
	for rows.Next() {
		var t Tag
		if err := rows.Scan(&t.ID, &t.Name, &t.CategoryName); err != nil {
			return nil, fmt.Errorf("model.ListTags scan: %w", err)
		}
		tags = append(tags, t)
	}
	return tags, rows.Err()
}
