import * as Phaser from "phaser";
import { Client, Room, getStateCallbacks } from "colyseus.js";
import {
  MAP_WIDTH,
  MAP_HEIGHT,
  PLAYER_SPEED,
  ROOM_NAME,
  type MoveMessage,
} from "@gg/shared";

const SERVER_URL = (() => {
  const env = (import.meta as any).env?.VITE_SERVER_WS_URL as string | undefined;
  if (env) return env;
  const proto = window.location.protocol === "https:" ? "wss" : "ws";
  return `${proto}://${window.location.host}/ws`;
})();

class GameScene extends Phaser.Scene {
  private room?: Room;
  private me?: Phaser.GameObjects.Rectangle;
  private others = new Map<string, Phaser.GameObjects.Rectangle>();
  private keys!: {
    W: Phaser.Input.Keyboard.Key;
    A: Phaser.Input.Keyboard.Key;
    S: Phaser.Input.Keyboard.Key;
    D: Phaser.Input.Keyboard.Key;
  };
  private posX = 400;
  private posY = 300;
  private moveTarget: { x: number; y: number } | null = null;
  private marker?: Phaser.GameObjects.Arc;

  async create() {
    this.cameras.main.setBackgroundColor("#1e2a1e");
    this.add.grid(400, 300, 800, 600, 40, 40, 0x000000, 0, 0x2a3a2a);
    this.keys = this.input.keyboard!.addKeys("W,A,S,D") as typeof this.keys;

    this.marker = this.add.circle(0, 0, 6, 0xffff00, 0.7).setVisible(false);

    this.input.on("pointerdown", (p: Phaser.Input.Pointer) => {
      this.moveTarget = { x: p.worldX, y: p.worldY };
      this.marker!.setPosition(p.worldX, p.worldY).setVisible(true);
    });

    const client = new Client(SERVER_URL);
    try {
      this.room = await client.joinOrCreate(ROOM_NAME);
      console.log("joined room, session:", this.room.sessionId);
    } catch (e) {
      console.error("Join failed", e);
      return;
    }

    const $ = getStateCallbacks(this.room);
    const mySessionId = this.room.sessionId;

    $(this.room.state).players.onAdd((player: any, sessionId: string) => {
      const isMe = sessionId === mySessionId;
      console.log("player joined:", sessionId, "isMe:", isMe, "at", player.x, player.y);
      const rect = this.add.rectangle(
        player.x, player.y, 24, 24,
        isMe ? 0x55ff55 : 0xff5555
      );
      rect.setStrokeStyle(2, 0xffffff);
      if (isMe) {
        this.me = rect;
        this.posX = player.x;
        this.posY = player.y;
      } else {
        this.others.set(sessionId, rect);
      }
      $(player).onChange(() => {
        if (isMe) return;
        rect.x = player.x;
        rect.y = player.y;
      });
    });

    $(this.room.state).players.onRemove((_p: any, sessionId: string) => {
      this.others.get(sessionId)?.destroy();
      this.others.delete(sessionId);
    });
  }

  update(_t: number, delta: number) {
    if (!this.me || !this.room) return;
    const dt = delta / 1000;

    let dx = 0, dy = 0;
    if (this.keys.A.isDown) dx -= 1;
    if (this.keys.D.isDown) dx += 1;
    if (this.keys.W.isDown) dy -= 1;
    if (this.keys.S.isDown) dy += 1;

    if (dx || dy) {
      this.moveTarget = null;
      this.marker!.setVisible(false);
      const len = Math.hypot(dx, dy);
      this.posX += (dx / len) * PLAYER_SPEED * dt;
      this.posY += (dy / len) * PLAYER_SPEED * dt;
    } else if (this.moveTarget) {
      const tx = this.moveTarget.x - this.posX;
      const ty = this.moveTarget.y - this.posY;
      const dist = Math.hypot(tx, ty);
      const step = PLAYER_SPEED * dt;
      if (dist <= step) {
        this.posX = this.moveTarget.x;
        this.posY = this.moveTarget.y;
        this.moveTarget = null;
        this.marker!.setVisible(false);
      } else {
        this.posX += (tx / dist) * step;
        this.posY += (ty / dist) * step;
      }
    } else {
      return;
    }

    this.posX = Phaser.Math.Clamp(this.posX, 0, MAP_WIDTH);
    this.posY = Phaser.Math.Clamp(this.posY, 0, MAP_HEIGHT);
    this.me.x = this.posX;
    this.me.y = this.posY;
    const msg: MoveMessage = { x: this.posX, y: this.posY };
    this.room.send("move", msg);
  }
}

new Phaser.Game({
  type: Phaser.AUTO,
  width: 800,
  height: 600,
  parent: "game",
  scene: GameScene,
  backgroundColor: "#000",
});
