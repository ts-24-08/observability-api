import winston from "winston";
import morgan from "morgan";
import { config } from "../config/config.js";

export const logger = winston.createLogger({
  level: config.logLevel,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()],
});

export const requestLogger = morgan("combined", {
  stream: {
    write: (message) => logger.info(message.trim()),
  },
});
