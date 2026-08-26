"""Calculator service with basic arithmetic operations."""


class CalculatorError(Exception):
    """Base exception for calculator errors."""

    def __init__(self, message: str):
        self.message = message
        super().__init__(message)


class DivisionByZeroError(CalculatorError):
    """Raised when attempting to divide by zero."""

    def __init__(self):
        super().__init__("Cannot divide by zero")


class InvalidOperationError(CalculatorError):
    """Raised when an invalid operation is requested."""

    def __init__(self, operation: str):
        super().__init__(f"Invalid operation: {operation}. Supported: add, subtract, multiply, divide")


def calculate(a: float, b: float, operation: str) -> float:
    """
    Perform basic arithmetic operation.

    Args:
        a: First operand
        b: Second operand
        operation: One of 'add', 'subtract', 'multiply', 'divide'

    Returns:
        Result of the operation

    Raises:
        DivisionByZeroError: If dividing by zero
        InvalidOperationError: If operation is not supported
    """
    if operation == "add":
        return a + b
    elif operation == "subtract":
        return a - b
    elif operation == "multiply":
        return a * b
    elif operation == "divide":
        if b == 0:
            raise DivisionByZeroError()
        return a / b
    else:
        raise InvalidOperationError(operation)