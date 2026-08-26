/** Application configuration. */

export const config = {
  appName: "Express Example",
  version: "0.1.0",
  env: process.env.NODE_ENV || "development",
  port: parseInt(process.env.PORT || "3000", 10),
  cors: {
    origin: process.env.CORS_ORIGINS?.split(",") || ["http://localhost:3000", "http://localhost:8080"],
    credentials: true,
  },
  secretKey: process.env.SECRET_KEY || "dev-secret-change-in-production",
};