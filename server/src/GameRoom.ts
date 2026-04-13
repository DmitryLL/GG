import { Room, Client } from "colyseus";
import { Schema, MapSchema, type } from "@colyseus/schema";
import {
  MAP_WIDTH,
  MAP_HEIGHT,
  MAX_STEP_PER_TICK,
  type MoveMessage,
} from "@gg/shared";

export class Player extends Schema {
  @type("number") x: number = 400;
  @type("number") y: number = 300;
}

export class State extends Schema {
  @type({ map: Player }) players = new MapSchema<Player>();
}

export class GameRoom extends Room<State> {
  maxClients = 50;

  onCreate() {
    this.setState(new State());

    this.onMessage<MoveMessage>("move", (client, msg) => {
      const player = this.state.players.get(client.sessionId);
      if (!player) return;
      const dx = Math.max(-MAX_STEP_PER_TICK, Math.min(MAX_STEP_PER_TICK, msg.x - player.x));
      const dy = Math.max(-MAX_STEP_PER_TICK, Math.min(MAX_STEP_PER_TICK, msg.y - player.y));
      player.x = Math.max(0, Math.min(MAP_WIDTH, player.x + dx));
      player.y = Math.max(0, Math.min(MAP_HEIGHT, player.y + dy));
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
