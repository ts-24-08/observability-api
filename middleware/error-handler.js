// ----- middleware/error-handler.js -----
import { logger } from "./logger.js";

// Not found handler
export const notFoundHandler = (req, res, next) => {
  res.status(404).json({ error: "Not Found" });
};

// General error handler
export const errorHandler = (err, req, res, next) => {
  logger.error(err.stack);
  res.status(err.status || 500).json({
    error: {
      message: err.message,
      status: err.status || 500,
    },
  });
};
