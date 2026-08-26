package calculator

import (
	"testing"
)

func TestAdd(t *testing.T) {
	tests := []struct {
		name     string
		a, b     float64
		expected float64
	}{
		{"positive", 2, 3, 5},
		{"negative", -1, 1, 0},
		{"zero", 0, 0, 0},
		{"decimals", 1.5, 2.5, 4.0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Add(tt.a, tt.b)
			if result != tt.expected {
				t.Errorf("Add(%g, %g) = %g, want %g", tt.a, tt.b, result, tt.expected)
			}
		})
	}
}

func TestSubtract(t *testing.T) {
	tests := []struct {
		name     string
		a, b     float64
		expected float64
	}{
		{"positive", 5, 3, 2},
		{"negative result", 0, 5, -5},
		{"zero", 0, 0, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Subtract(tt.a, tt.b)
			if result != tt.expected {
				t.Errorf("Subtract(%g, %g) = %g, want %g", tt.a, tt.b, result, tt.expected)
			}
		})
	}
}

func TestMultiply(t *testing.T) {
	tests := []struct {
		name     string
		a, b     float64
		expected float64
	}{
		{"positive", 3, 4, 12},
		{"negative", -2, 3, -6},
		{"zero", 0, 100, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Multiply(tt.a, tt.b)
			if result != tt.expected {
				t.Errorf("Multiply(%g, %g) = %g, want %g", tt.a, tt.b, result, tt.expected)
			}
		})
	}
}

func TestDivide(t *testing.T) {
	tests := []struct {
		name     string
		a, b     float64
		expected float64
	}{
		{"positive", 10, 2, 5},
		{"decimal", 7, 2, 3.5},
		{"negative", -6, 2, -3},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := Divide(tt.a, tt.b)
			if err != nil {
				t.Errorf("Divide(%g, %g) unexpected error: %v", tt.a, tt.b, err)
			}
			if result != tt.expected {
				t.Errorf("Divide(%g, %g) = %g, want %g", tt.a, tt.b, result, tt.expected)
			}
		})
	}
}

func TestDivideByZero(t *testing.T) {
	_, err := Divide(5, 0)
	if err == nil {
		t.Error("Divide by zero should return error")
	}
	if !errors.Is(err, ErrDivisionByZero) {
		t.Errorf("Expected ErrDivisionByZero, got %v", err)
	}
}

func TestCalculate(t *testing.T) {
	tests := []struct {
		name          string
		a, b          float64
		operation     string
		expected      float64
		expectError   bool
	}{
		{"add", 2, 3, "add", 5, false},
		{"subtract", 5, 3, "subtract", 2, false},
		{"multiply", 3, 4, "multiply", 12, false},
		{"divide", 10, 2, "divide", 5, false},
		{"invalid operation", 1, 2, "modulo", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := Calculate(tt.a, tt.b, tt.operation)
			if tt.expectError {
				if err == nil {
					t.Error("Expected error for invalid operation")
				}
				return
			}
			if err != nil {
				t.Errorf("Unexpected error: %v", err)
			}
			if result != tt.expected {
				t.Errorf("Calculate(%g, %g, %s) = %g, want %g", tt.a, tt.b, tt.operation, result, tt.expected)
			}
		})
	}
}