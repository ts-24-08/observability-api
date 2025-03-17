import express from "express";
import { logger } from "../middleware/logger.js";

export const router = express.Router();

const users = [
  {
    id: 1,
    name: "John Doe",
  },
  {
    id: 2,
    name: "Jane Smith",
  },
];

router.get("/", (req, res) => {
  logger.info("Retrieved all users");
  res.status(200).json(users);
});

router.get("/:id", (req, res) => {
  const id = parseInt(req.params.id);
  const user = users.find((user) => user.id === id);
  if (user) {
    logger.info(`Retrieved user with id ${id}`);
    res.status(200).json(user);
  } else {
    logger.warn(`User with id ${id} not found`);
    res.status(404).json({ message: `User with id ${id} not found` });
  }
});

router.post("/", (req, res) => {
  if (!req.body.name) {
    logger.warn("Attempt to create a user without a name");
    return res.status(400).json({ error: "Name is required" });
  }
  const newUser = {
    id: users.length + 1,
    name: req.body.name,
  };
  users.push(newUser);
  logger.info(`Created new user: ${newUser.name}`);
  res.status(201).json(newUser);
});

router.patch("/:id", (req, res) => {
  const id = parseInt(req.params.id);
  const user = users.find((user) => user.id === id);
  if (!user) {
    logger.warn(`User with id ${id} not found`);
    return res.status(404).json({ message: `User with id ${id} not found` });
  }
  if (!req.body.name) {
    logger.warn("Attempt to update a user without a name");
    return res.status(400).json({ error: "Name is required" });
  }
  user.name = req.body.name;
  logger.info(`Updated user with id ${id}`);
  res.status(200).json(user);
});

router.delete("/:id", (req, res) => {
  const id = parseInt(req.params.id);
  const userIndex = users.findIndex((user) => user.id === id);
  if (userIndex === -1) {
    logger.warn(`User with id ${id} not found`);
    return res.status(404).json({ message: `User with id ${id} not found` });
  }
  const deletedUser = users.splice(userIndex, 1)[0];
  logger.info(`Deleted user with id ${id}`);
  res.status(200).json(deletedUser);
});
