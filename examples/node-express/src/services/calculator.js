/** Calculator service with basic arithmetic operations. */

export class CalculatorError extends Error {
  constructor(message) {
    super(message);
    this.name = "CalculatorError";
  }
}

export class DivisionByZeroError extends CalculatorError {
  constructor() {
    super("Cannot divide by zero");
    this.name = "DivisionByZeroError";
  }
}

export class InvalidOperationError extends CalculatorError {
  constructor(operation) {
    super(`Invalid operation: ${operation}. Supported: add, subtract, multiply, divide`);
    this.name = "InvalidOperationError";
  }
}

/**
 * Perform basic arithmetic operation.
 * @param {number} a - First operand
 * @param {number} b - Second operand
 * @param {string} operation - One of 'add', 'subtract', 'multiply', 'divide'
 * @returns {number} Result of the operation
 * @throws {DivisionByZeroError} If dividing by zero
 * @throws {InvalidOperationError} If operation is not supported
 */
export function calculate(a, b, operation) {
  if (typeof a !== "number" || typeof b !== "number") {
    throw new CalculatorError("Operands must be numbers");
  }

  switch (operation) {
    case "add":
      return a + b;
    case "subtract":
      return a - b;
    case "multiply":
      return a * b;
    case "divide":
      if (b === 0) {
        throw new DivisionByZeroError();
      }
      return a / b;
    default:
      throw new InvalidOperationError(operation);
  }
}