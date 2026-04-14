import { Room, Client } from "colyseus";
import { Schema, MapSchema, type } from "@colyseus/schema";
import {
  MAP_WIDTH,
  MAP_HEIGHT,
  MAX_STEP_PER_TICK,
  CHAT_MAX_LEN,
  isWalkableAt,
  type MoveMessage,
  type ChatSend,
  type ChatBroadcast,
  type JoinOptions,
} from "@gg/shared";
import { verifyToken } from "./auth.js";
import { prisma } from "./db.js";

export class Player extends Schema {
  @type("number") x: number = 400;
  @type("number") y: number = 300;
  @type("string") name: string = "";
}

export class State extends Schema {
  @type({ map: Player }) players = new MapSchema<Player>();
}

type AuthData = { userId: string; characterId: string };

export class GameRoom extends Room<State> {
  maxClients = 50;

  onCreate() {
    this.setState(new State());

    this.onMessage<MoveMessage>("move", (client, msg) => {
      const player = this.state.players.get(client.sessionId);
      if (!player) return;
      const dx = Math.max(-MAX_STEP_PER_TICK, Math.min(MAX_STEP_PER_TICK, msg.x - player.x));
      const dy = Math.max(-MAX_STEP_PER_TICK, Math.min(MAX_STEP_PER_TICK, msg.y - player.y));
      const nx = Math.max(0, Math.min(MAP_WIDTH - 1, player.x + dx));
      const ny = Math.max(0, Math.min(MAP_HEIGHT - 1, player.y + dy));
      // Axis-separated collision: move along each axis only if destination tile is walkable.
      if (isWalkableAt(nx, player.y)) player.x = nx;
      if (isWalkableAt(player.x, ny)) player.y = ny;
    });

    this.onMessage<ChatSend>("chat", (client, msg) => {
      const player = this.state.players.get(client.sessionId);
      if (!player) return;
      const text = (msg?.text ?? "").toString().trim().slice(0, CHAT_MAX_LEN);
      if (!text) return;
      const payload: ChatBroadcast = {
        sessionId: client.sessionId,
        name: player.name,
        text,
        ts: Date.now(),
      };
      this.broadcast("chat", payload);
    });
  }

  async onAuth(_client: Client, options: JoinOptions): Promise<AuthData> {
    const token = options?.token;
    if (!token) throw new Error("Auth token required");
    const userId = verifyToken(token);
    if (!userId) throw new Error("Invalid token");
    const character = await prisma.character.findUnique({ where: { userId } });
    if (!character) throw new Error("Character not found");
    return { userId, characterId: character.id };
  }

  async onJoin(client: Client, _opts: unknown, auth: AuthData) {
    const character = await prisma.character.findUnique({ where: { id: auth.characterId } });
    if (!character) return;
    const player = new Player();
    player.x = character.x;
    player.y = character.y;
    if (!isWalkableAt(player.x, player.y)) {
      player.x = 400;
      player.y = 304;
    }
    player.name = character.name;
    this.state.players.set(client.sessionId, player);
    client.userData = auth;
    console.log(`${character.name} joined at ${player.x},${player.y}`);
  }

  async onLeave(client: Client) {
    const player = this.state.players.get(client.sessionId);
    const auth = client.userData as AuthData | undefined;
    if (player && auth) {
      await prisma.character.update({
        where: { id: auth.characterId },
        data: { x: Math.round(player.x), y: Math.round(player.y) },
      });
      console.log(`${player.name} saved at ${player.x},${player.y}`);
    }
    this.state.players.delete(client.sessionId);
  }
}
