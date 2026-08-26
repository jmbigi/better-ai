"""Tests for calculator service."""

import pytest

from src.services.calculator import (
    calculate,
    DivisionByZeroError,
    InvalidOperationError,
)


class TestCalculator:
    """Tests for calculate function."""

    def test_add(self):
        assert calculate(2, 3, "add") == 5
        assert calculate(-1, 1, "add") == 0
        assert calculate(0, 0, "add") == 0

    def test_subtract(self):
        assert calculate(5, 3, "subtract") == 2
        assert calculate(0, 5, "subtract") == -5
        assert calculate(-2, -3, "subtract") == 1

    def test_multiply(self):
        assert calculate(3, 4, "multiply") == 12
        assert calculate(-2, 3, "multiply") == -6
        assert calculate(0, 100, "multiply") == 0

    def test_divide(self):
        assert calculate(10, 2, "divide") == 5
        assert calculate(7, 2, "divide") == 3.5
        assert calculate(-6, 2, "divide") == -3

    def test_divide_by_zero_raises_error(self):
        with pytest.raises(DivisionByZeroError):
            calculate(5, 0, "divide")

    def test_invalid_operation_raises_error(self):
        with pytest.raises(InvalidOperationError):
            calculate(1, 2, "modulo")

    def test_case_sensitivity(self):
        with pytest.raises(InvalidOperationError):
            calculate(1, 2, "ADD")  # Should be lowercase