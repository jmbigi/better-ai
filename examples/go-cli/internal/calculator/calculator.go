package calculator

import (
	"errors"
	"fmt"
)

var (
	ErrDivisionByZero   = errors.New("cannot divide by zero")
	ErrInvalidOperation = errors.New("invalid operation")
)

func Add(a, b float64) float64 {
	return a + b
}

func Subtract(a, b float64) float64 {
	return a - b
}

func Multiply(a, b float64) float64 {
	return a * b
}

func Divide(a, b float64) (float64, error) {
	if b == 0 {
		return 0, ErrDivisionByZero
	}
	return a / b, nil
}

func Calculate(a, b float64, operation string) (float64, error) {
	switch operation {
	case "add":
		return Add(a, b), nil
	case "subtract":
		return Subtract(a, b), nil
	case "multiply":
		return Multiply(a, b), nil
	case "divide":
		return Divide(a, b)
	default:
		return 0, fmt.Errorf("%w: %s", ErrInvalidOperation, operation)
	}
}