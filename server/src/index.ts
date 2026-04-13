import { Server } from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { createServer } from "http";
import { GameRoom } from "./GameRoom.js";

const port = Number(process.env.PORT) || 2567;
const httpServer = createServer();

const gameServer = new Server({
  transport: new WebSocketTransport({ server: httpServer }),
});

gameServer.define("game_room", GameRoom);

gameServer.listen(port);
console.log(`Listening on ws://localhost:${port}`);
