/** Tests for API endpoints. */

import request from "supertest";
import app from "../../src/index.js";

describe("Health Endpoint", () => {
  test("GET /health returns ok", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body.status).toBe("ok");
    expect(res.body.service).toBe("Express Example");
  });
});

describe("Calculator Endpoint", () => {
  test("POST /api/v1/calculate - add", async () => {
    const res = await request(app)
      .post("/api/v1/calculate")
      .send({ a: 10, b: 5, operation: "add" });
    expect(res.status).toBe(200);
    expect(res.body.result).toBe(15);
    expect(res.body.operation).toBe("add");
  });

  test("POST /api/v1/calculate - subtract", async () => {
    const res = await request(app)
      .post("/api/v1/calculate")
      .send({ a: 10, b: 5, operation: "subtract" });
    expect(res.status).toBe(200);
    expect(res.body.result).toBe(5);
  });

  test("POST /api/v1/calculate - multiply", async () => {
    const res = await request(app)
      .post("/api/v1/calculate")
      .send({ a: 10, b: 5, operation: "multiply" });
    expect(res.status).toBe(200);
    expect(res.body.result).toBe(50);
  });

  test("POST /api/v1/calculate - divide", async () => {
    const res = await request(app)
      .post("/api/v1/calculate")
      .send({ a: 10, b: 5, operation: "divide" });
    expect(res.status).toBe(200);
    expect(res.body.result).toBe(2);
  });

  test("POST /api/v1/calculate - divide by zero returns 400", async () => {
    const res = await request(app)
      .post("/api/v1/calculate")
      .send({ a: 10, b: 0, operation: "divide" });
    expect(res.status).toBe(400);
    expect(res.body.error).toContain("divide by zero");
  });

  test("POST /api/v1/calculate - invalid operation returns 400", async () => {
    const res = await request(app)
      .post("/api/v1/calculate")
      .send({ a: 10, b: 5, operation: "modulo" });
    expect(res.status).toBe(400);
    expect(res.body.error).toContain("Invalid operation");
  });

  test("POST /api/v1/calculate - invalid schema returns 400", async () => {
    const res = await request(app)
      .post("/api/v1/calculate")
      .send({ a: 10 });
    expect(res.status).toBe(400);
  });
});