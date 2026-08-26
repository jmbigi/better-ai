/** Tests for calculator service. */

import { calculate, DivisionByZeroError, InvalidOperationError } from "../../src/services/calculator.js";

describe("Calculator Service", () => {
  describe("calculate()", () => {
    test("add", () => {
      expect(calculate(2, 3, "add")).toBe(5);
      expect(calculate(-1, 1, "add")).toBe(0);
      expect(calculate(0, 0, "add")).toBe(0);
    });

    test("subtract", () => {
      expect(calculate(5, 3, "subtract")).toBe(2);
      expect(calculate(0, 5, "subtract")).toBe(-5);
    });

    test("multiply", () => {
      expect(calculate(3, 4, "multiply")).toBe(12);
      expect(calculate(-2, 3, "multiply")).toBe(-6);
      expect(calculate(0, 100, "multiply")).toBe(0);
    });

    test("divide", () => {
      expect(calculate(10, 2, "divide")).toBe(5);
      expect(calculate(7, 2, "divide")).toBe(3.5);
      expect(calculate(-6, 2, "divide")).toBe(-3);
    });

    test("divide by zero throws DivisionByZeroError", () => {
      expect(() => calculate(5, 0, "divide")).toThrow(DivisionByZeroError);
    });

    test("invalid operation throws InvalidOperationError", () => {
      expect(() => calculate(1, 2, "modulo")).toThrow(InvalidOperationError);
    });
  });
});