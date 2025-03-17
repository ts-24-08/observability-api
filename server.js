import app from "./app.js";
import { config } from "./config/config.js";

const server = app.listen(config.port, () => {
  console.info(`Server running on port ${config.port}`);
});

process.on("SIGTERM", () => {
  console.info("SIGTERM signal received.");
  server.close(() => {
    console.log("Http server closed.");
    process.exit(0);
  });
});
