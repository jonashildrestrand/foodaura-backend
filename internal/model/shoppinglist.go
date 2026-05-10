package model

import (
	"database/sql"
	"fmt"
	"time"
)

// ShoppingItem represents a row from shopping_list_items.
type ShoppingItem struct {
	ID             string
	MealPlanID     string
	IngredientName string
	TotalQuantity  float64
	Unit           string
	Category       string
	IsChecked      bool
	CreatedAt      time.Time
}

// GetShoppingList calls sp_shoppinglist_get and returns all items for the plan.
func GetShoppingList(db *sql.DB, mealPlanID, requestingUserID string) ([]ShoppingItem, error) {
	rows, err := db.Query("CALL sp_shoppinglist_get(?, ?)", mealPlanID, requestingUserID)
	if err != nil {
		return nil, fmt.Errorf("model.GetShoppingList: %w", err)
	}
	defer rows.Close()

	var items []ShoppingItem
	for rows.Next() {
		var item ShoppingItem
		if err := rows.Scan(
			&item.ID, &item.MealPlanID, &item.IngredientName,
			&item.TotalQuantity, &item.Unit, &item.Category,
			&item.IsChecked, &item.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("model.GetShoppingList scan: %w", err)
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// ToggleItem calls sp_shoppinglist_toggle_item.
func ToggleItem(db *sql.DB, itemID string, isChecked bool) error {
	rows, err := db.Query("CALL sp_shoppinglist_toggle_item(?, ?)", itemID, isChecked)
	if err != nil {
		return fmt.Errorf("model.ToggleItem: %w", err)
	}
	return rows.Close()
}
