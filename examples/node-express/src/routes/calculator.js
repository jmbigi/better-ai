/** Calculator API routes. */

import express from "express";
import { calculate, DivisionByZeroError, InvalidOperationError } from "../services/calculator.js";

const router = express.Router();

/**
 * @swagger
 * /calculate:
 *   post:
 *     summary: Perform a calculation
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [a, b, operation]
 *             properties:
 *               a: { type: number }
 *               b: { type: number }
 *               operation: { type: string, enum: [add, subtract, multiply, divide] }
 *     responses:
 *       200:
 *         description: Calculation result
 *       400:
 *         description: Invalid operation or division by zero
 */
router.post("/", (req, res, next) => {
  try {
    const { a, b, operation } = req.body;

    // Validation
    if (typeof a !== "number" || typeof b !== "number" || typeof operation !== "string") {
      return res.status(400).json({ error: "Invalid request: a, b must be numbers, operation must be string" });
    }

    const result = calculate(a, b, operation);

    res.json({
      result,
      operation,
      a,
      b,
    });
  } catch (error) {
    next(error);
  }
});

export default router;