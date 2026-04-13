import * as Phaser from "phaser";
import { Client, Room, getStateCallbacks } from "colyseus.js";
import {
  MAP_WIDTH,
  MAP_HEIGHT,
  PLAYER_SPEED,
  ROOM_NAME,
  type MoveMessage,
  type JoinOptions,
} from "@gg/shared";
import { getStoredToken, mountAuthUI, mountLogoutButton } from "./auth";

const SERVER_URL = (() => {
  const env = (import.meta as any).env?.VITE_SERVER_WS_URL as string | undefined;
  if (env) return env;
  const proto = window.location.protocol === "https:" ? "wss" : "ws";
  return `${proto}://${window.location.host}`;
})();

const SPRITE_COUNT = 6;
const BASE = (import.meta as any).env?.BASE_URL ?? "/";
const spritesheetUrl = (i: number) => `${BASE}sprites/char_${i}.png`;

// Sprite layout: 3 walk frames × 4 directions. Row-major.
// Row 0: down, Row 1: left, Row 2: right, Row 3: up. Col 0: idle, 1/2: steps.
const DIR = { down: 0, left: 1, right: 2, up: 3 } as const;
type Direction = keyof typeof DIR;

function pickVariant(sessionId: string): number {
  let h = 0;
  for (const ch of sessionId) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return h % SPRITE_COUNT;
}

function dirFromDelta(dx: number, dy: number, prev: Direction): Direction {
  if (Math.abs(dx) < 0.01 && Math.abs(dy) < 0.01) return prev;
  if (Math.abs(dx) > Math.abs(dy)) return dx > 0 ? "right" : "left";
  return dy > 0 ? "down" : "up";
}

type PlayerSprite = {
  container: Phaser.GameObjects.Container;
  sprite: Phaser.GameObjects.Sprite;
  label: Phaser.GameObjects.Text;
  lastX: number;
  lastY: number;
  facing: Direction;
  variant: number;
};

class GameScene extends Phaser.Scene {
  constructor() { super("game"); }

  private room?: Room;
  private me?: PlayerSprite;
  private others = new Map<string, PlayerSprite>();
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
  private token!: string;
  private myFacing: Direction = "down";
  private myMoving = false;

  init(data: { token: string }) {
    this.token = data.token;
  }

  preload() {
    for (let i = 0; i < SPRITE_COUNT; i++) {
      this.load.spritesheet(`char_${i}`, spritesheetUrl(i), {
        frameWidth: 32,
        frameHeight: 32,
      });
    }
  }

  private ensureAnimations(variant: number) {
    const key = `char_${variant}`;
    const make = (name: string, row: number) => {
      const animKey = `${key}_${name}`;
      if (this.anims.exists(animKey)) return;
      const base = row * 3;
      this.anims.create({
        key: animKey,
        frames: this.anims.generateFrameNumbers(key, { frames: [base + 1, base, base + 2, base] }),
        frameRate: 8,
        repeat: -1,
      });
    };
    make("walk_down", DIR.down);
    make("walk_left", DIR.left);
    make("walk_right", DIR.right);
    make("walk_up", DIR.up);
  }

  private createPlayerSprite(variant: number, name: string, x: number, y: number): PlayerSprite {
    this.ensureAnimations(variant);
    const sprite = this.add.sprite(0, 0, `char_${variant}`, DIR.down * 3);
    sprite.setScale(1.5);
    const label = this.add.text(0, -30, name, {
      fontFamily: "system-ui, sans-serif",
      fontSize: "12px",
      color: "#ffffff",
      stroke: "#000000",
      strokeThickness: 3,
    });
    label.setOrigin(0.5, 1);
    const container = this.add.container(x, y, [sprite, label]);
    return { container, sprite, label, lastX: x, lastY: y, facing: "down", variant };
  }

  private setFrame(ps: PlayerSprite, dir: Direction, moving: boolean) {
    ps.facing = dir;
    const key = `char_${ps.variant}`;
    if (moving) {
      const animKey = `${key}_walk_${dir}`;
      const cur = ps.sprite.anims.currentAnim?.key;
      if (cur !== animKey) ps.sprite.anims.play(animKey);
    } else {
      ps.sprite.anims.stop();
      ps.sprite.setFrame(DIR[dir] * 3);
    }
  }

  async create() {
    this.cameras.main.setBackgroundColor("#1e2a1e");
    this.add.grid(MAP_WIDTH / 2, MAP_HEIGHT / 2, MAP_WIDTH, MAP_HEIGHT, 40, 40, 0x223222, 1, 0x2e4a2e, 1);

    this.keys = this.input.keyboard!.addKeys("W,A,S,D") as typeof this.keys;
    this.marker = this.add.circle(0, 0, 6, 0xffff00, 0.7).setVisible(false);

    this.input.on("pointerdown", (p: Phaser.Input.Pointer) => {
      this.moveTarget = { x: p.worldX, y: p.worldY };
      this.marker!.setPosition(p.worldX, p.worldY).setVisible(true);
    });

    const client = new Client(SERVER_URL);
    const options: JoinOptions = { token: this.token };
    try {
      this.room = await client.joinOrCreate(ROOM_NAME, options);
    } catch (e: any) {
      console.error("Join failed", e);
      if (String(e?.message || "").toLowerCase().includes("token")) {
        localStorage.removeItem("gg_token");
        location.reload();
      }
      return;
    }

    const $ = getStateCallbacks(this.room);
    const mySessionId = this.room.sessionId;

    $(this.room.state).players.onAdd((player: any, sessionId: string) => {
      const isMe = sessionId === mySessionId;
      const variant = pickVariant(sessionId);
      const ps = this.createPlayerSprite(variant, player.name || "…", player.x, player.y);

      if (isMe) {
        this.me = ps;
        this.posX = player.x;
        this.posY = player.y;
      } else {
        this.others.set(sessionId, ps);
      }

      $(player).onChange(() => {
        if (isMe) return;
        const dx = player.x - ps.lastX;
        const dy = player.y - ps.lastY;
        const dir = dirFromDelta(dx, dy, ps.facing);
        const moving = Math.hypot(dx, dy) > 0.3;
        ps.container.x = player.x;
        ps.container.y = player.y;
        ps.lastX = player.x;
        ps.lastY = player.y;
        this.setFrame(ps, dir, moving);
        if (player.name && ps.label.text !== player.name) ps.label.setText(player.name);
      });
    });

    $(this.room.state).players.onRemove((_p: any, sessionId: string) => {
      this.others.get(sessionId)?.container.destroy();
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

    let moving = false;
    let stepX = 0, stepY = 0;

    if (dx || dy) {
      this.moveTarget = null;
      this.marker!.setVisible(false);
      const len = Math.hypot(dx, dy);
      stepX = (dx / len) * PLAYER_SPEED * dt;
      stepY = (dy / len) * PLAYER_SPEED * dt;
      moving = true;
    } else if (this.moveTarget) {
      const tx = this.moveTarget.x - this.posX;
      const ty = this.moveTarget.y - this.posY;
      const dist = Math.hypot(tx, ty);
      const step = PLAYER_SPEED * dt;
      if (dist <= step) {
        stepX = tx;
        stepY = ty;
        this.moveTarget = null;
        this.marker!.setVisible(false);
      } else {
        stepX = (tx / dist) * step;
        stepY = (ty / dist) * step;
      }
      moving = dist > 0.3;
    }

    if (moving || this.myMoving !== moving) {
      this.posX = Phaser.Math.Clamp(this.posX + stepX, 0, MAP_WIDTH);
      this.posY = Phaser.Math.Clamp(this.posY + stepY, 0, MAP_HEIGHT);
      this.me.container.x = this.posX;
      this.me.container.y = this.posY;
      this.me.lastX = this.posX;
      this.me.lastY = this.posY;
      if (moving) {
        this.myFacing = dirFromDelta(stepX, stepY, this.myFacing);
      }
      this.setFrame(this.me, this.myFacing, moving);
      this.myMoving = moving;

      if (moving) {
        const msg: MoveMessage = { x: this.posX, y: this.posY };
        this.room.send("move", msg);
      }
    }
  }
}

function startGame(token: string) {
  mountLogoutButton(() => location.reload());
  const game = new Phaser.Game({
    type: Phaser.AUTO,
    width: 800,
    height: 600,
    parent: "game",
    scene: GameScene,
    backgroundColor: "#000",
    pixelArt: true,
  });
  game.scene.start("game", { token });
}

const existing = getStoredToken();
if (existing) {
  document.getElementById("auth-overlay")?.remove();
  startGame(existing);
} else {
  mountAuthUI((token) => startGame(token));
}
