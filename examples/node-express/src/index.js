/** Express application entry point. */

import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import dotenv from "dotenv";

import { config } from "./config/index.js";
import calculatorRoutes from "./routes/calculator.js";
import { errorHandler } from "./middleware/error.js";

dotenv.config();

const app = express();

// Security middleware
app.use(helmet());
app.use(cors(config.cors));

// Logging
app.use(morgan(config.env === "development" ? "dev" : "combined"));

// Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use("/api/v1/calculate", calculatorRoutes);

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: config.appName });
});

// Error handling (must be last)
app.use(errorHandler);

const PORT = config.port;

app.listen(PORT, () => {
  console.log(`${config.appName} running on port ${PORT} in ${config.env} mode`);
});

export default app;