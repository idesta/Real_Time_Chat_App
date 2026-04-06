import dotenv from "dotenv";
import { Server } from "socket.io";
import http from "http";
import express from "express";

dotenv.config();
const ALLOWED_ORIGIN = process.env.CLIENT_URL || "http://localhost:5173";

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: [ALLOWED_ORIGIN],
    credentials: true,
  },
});

export function getReceiverSocketId(userId) {
  return userSocketMap[userId];
}

const userSocketMap = {}; // {userId: socketId}

io.on("connection", (socket) => {
  console.log("A user connected", socket.id);

  const userId = socket.handshake.query.userId;
  if (userId) userSocketMap[userId] = socket.id;

  // send events to all the connected clients
  io.emit("getOnlineUsers", Object.keys(userSocketMap));

  socket.on("disconnect", () => {
    console.log("A user disconnected", socket.id);
    delete userSocketMap[userId];
    io.emit("getOnlineUsers", Object.keys(userSocketMap));
  });
});

export { io, app, server };
