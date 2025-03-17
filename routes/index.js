import express from "express";
import { router as userRouter } from "./users.js";

export const router = express.Router();

router.get("/", (req, res) => {
  res.status(200).json({ message: "Welcome to the Observability API" });
});

router.use("/users", userRouter);
