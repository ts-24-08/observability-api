import express from "express";
import helmet from "helmet";
import cors from "cors";
import { router as mainRouter } from "./routes/index.js";
import { requestLogger, logger } from "./middleware/logger.js";
import {
  requestCounter,
  responseTimeHistogram,
  getMetrics,
} from "./middleware/metrics.js";
import { notFoundHandler, errorHandler } from "./middleware/error-handler.js";

const app = express();

app.use(helmet());
app.use(cors());

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(requestLogger);
app.use(requestCounter);
app.use(responseTimeHistogram);

app.use("/", mainRouter);

app.get("/health", (req, res) => {
  res.status(200).json({ status: "UP" });
});

app.get("/metrics", getMetrics);

app.get("/error/test", (req, res, next) => {
  logger.info("Error test route called");
  if (Math.random() > 0.5) {
    next(new Error("Simulated error for testing"));
    return;
  }
  setTimeout(() => {
    res.json({ message: "Delayed response for testing timing metrics" });
  }, Math.floor(Math.random() * 1000));
});

// Error handling middleware
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
