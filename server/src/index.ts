import express from "express";
import { createServer } from "http";
import { Server } from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { ROOM_NAME } from "@gg/shared";
import { GameRoom } from "./GameRoom.js";
import { prisma } from "./db.js";
import { authRouter } from "./auth.js";

const port = Number(process.env.PORT) || 2567;

const app = express();
app.use(express.json());
app.get("/health", (_req, res) => res.json({ ok: true }));
app.use("/auth", authRouter);

const httpServer = createServer(app);

const gameServer = new Server({
  transport: new WebSocketTransport({ server: httpServer }),
});

gameServer.define(ROOM_NAME, GameRoom);

await prisma.$connect();
console.log("DB connected");

gameServer.listen(port);
console.log(`Listening on :${port}`);
