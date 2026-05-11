package model

import (
	"database/sql"
	"fmt"
)

type Goal struct {
	Value string
	Label string
	Icon  string
}

type DietType struct {
	Value string
	Label string
}

func GetGoals(db *sql.DB) ([]Goal, error) {
	rows, err := db.Query("CALL sp_goals_list()")
	if err != nil {
		return nil, fmt.Errorf("model.GetGoals: %w", err)
	}
	defer rows.Close()
	var goals []Goal
	for rows.Next() {
		var g Goal
		if err := rows.Scan(&g.Value, &g.Label, &g.Icon); err != nil {
			return nil, fmt.Errorf("model.GetGoals scan: %w", err)
		}
		goals = append(goals, g)
	}
	for rows.NextResultSet() {}
	return goals, rows.Err()
}

func GetDietTypes(db *sql.DB) ([]DietType, error) {
	rows, err := db.Query("CALL sp_diet_types_list()")
	if err != nil {
		return nil, fmt.Errorf("model.GetDietTypes: %w", err)
	}
	defer rows.Close()
	var types []DietType
	for rows.Next() {
		var d DietType
		if err := rows.Scan(&d.Value, &d.Label); err != nil {
			return nil, fmt.Errorf("model.GetDietTypes scan: %w", err)
		}
		types = append(types, d)
	}
	for rows.NextResultSet() {}
	return types, rows.Err()
}
