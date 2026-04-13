import { Server } from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { createServer } from "http";
import { ROOM_NAME } from "@gg/shared";
import { GameRoom } from "./GameRoom.js";

const port = Number(process.env.PORT) || 2567;
const httpServer = createServer();

const gameServer = new Server({
  transport: new WebSocketTransport({ server: httpServer }),
});

gameServer.define(ROOM_NAME, GameRoom);

gameServer.listen(port);
console.log(`Listening on ws://localhost:${port}`);
