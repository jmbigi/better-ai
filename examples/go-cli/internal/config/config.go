package config

import (
	"os"
	"strconv"
)

type Config struct {
	Format string
	Debug  bool
}

func Load() *Config {
	return &Config{
		Format: getEnv("CALCULATOR_FORMAT", "text"),
		Debug:  getEnvBool("CALCULATOR_DEBUG", false),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		parsed, err := strconv.ParseBool(value)
		if err == nil {
			return parsed
		}
	}
	return defaultValue
}