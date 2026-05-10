package config

import "os"

// Config holds all environment-driven configuration for the backend.
type Config struct {
	DBUser     string // FOODAURA_BACKEND_DB_USER, default "foodaura_backend"
	DBPassword string // FOODAURA_BACKEND_DB_PASSWORD
	DBHost     string // DB_HOST, default "localhost"
	DBPort     string // DB_PORT, default "3306"
	DBName     string // DB_NAME, default "foodaura"
	Port       string // PORT, default "8080"
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// Load reads configuration from environment variables.
func Load() Config {
	return Config{
		DBUser:     getenv("FOODAURA_BACKEND_DB_USER", "foodaura_backend"),
		DBPassword: os.Getenv("FOODAURA_BACKEND_DB_PASSWORD"),
		DBHost:     getenv("DB_HOST", "localhost"),
		DBPort:     getenv("DB_PORT", "3306"),
		DBName:     getenv("DB_NAME", "foodaura"),
		Port:       getenv("PORT", "8080"),
	}
}
