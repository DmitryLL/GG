import { Room, Client } from "colyseus";
import { Schema, MapSchema, type } from "@colyseus/schema";

export class Player extends Schema {
  @type("number") x: number = 400;
  @type("number") y: number = 300;
}

export class State extends Schema {
  @type({ map: Player }) players = new MapSchema<Player>();
}

type MoveMsg = { x: number; y: number };

const MAP_W = 800;
const MAP_H = 600;
const MAX_STEP = 16;

export class GameRoom extends Room<State> {
  maxClients = 50;

  onCreate() {
    this.setState(new State());

    this.onMessage<MoveMsg>("move", (client, msg) => {
      const player = this.state.players.get(client.sessionId);
      if (!player) return;
      const dx = Math.max(-MAX_STEP, Math.min(MAX_STEP, msg.x - player.x));
      const dy = Math.max(-MAX_STEP, Math.min(MAX_STEP, msg.y - player.y));
      player.x = Math.max(0, Math.min(MAP_W, player.x + dx));
      player.y = Math.max(0, Math.min(MAP_H, player.y + dy));
    });
  }

  onJoin(client: Client) {
    this.state.players.set(client.sessionId, new Player());
    console.log(client.sessionId, "joined");
  }

  onLeave(client: Client) {
    this.state.players.delete(client.sessionId);
    console.log(client.sessionId, "left");
  }
}
