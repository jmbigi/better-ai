/** Error handling middleware. */

import { DivisionByZeroError, InvalidOperationError, CalculatorError } from "../services/calculator.js";

/** Global error handler. */
export function errorHandler(err, req, res, next) {
  console.error("Error:", err);

  // Known errors
  if (err instanceof DivisionByZeroError) {
    return res.status(400).json({ error: err.message });
  }
  if (err instanceof InvalidOperationError) {
    return res.status(400).json({ error: err.message });
  }
  if (err instanceof CalculatorError) {
    return res.status(500).json({ error: "Calculation error: " + err.message });
  }

  // Validation errors (express-validator, etc.)
  if (err.name === "ValidationError") {
    return res.status(400).json({ error: err.message });
  }

  // Default: internal server error
  return res.status(500).json({ error: "Internal server error" });
}