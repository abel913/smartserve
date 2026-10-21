import { Hono } from "hono";
import type { HealthResponse } from "@smartserve/shared";

const app = new Hono();

app.get("/health", (c) => {
  const response: HealthResponse = {
    status: "ok",
    service: "smartserve-api",
    timestamp: new Date().toISOString(),
  };

  return c.json(response);
});

app.get("/", (c) => c.json({ service: "SmartServe API", health: "/health" }));

export default app;
