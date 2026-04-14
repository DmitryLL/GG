import * as Phaser from "phaser";
import { Client, Room, getStateCallbacks } from "colyseus.js";
import {
  MAP_WIDTH,
  MAP_HEIGHT,
  MAP_COLS,
  MAP_ROWS,
  MAP_TILES,
  TILE_SIZE,
  VIEW_WIDTH,
  VIEW_HEIGHT,
  PLAYER_SPEED,
  PLAYER_HP_MAX,
  PLAYER_ATTACK_RANGE,
  PLAYER_SPAWN,
  MOB_HP_MAX,
  ROOM_NAME,
  isWalkableAt,
  type MoveMessage,
  type AttackMessage,
  type JoinOptions,
} from "@gg/shared";
import { getStoredToken, mountAuthUI, mountLogoutButton } from "./auth";
import { mountChat } from "./chat";
import { mountHud, type InvSlotView } from "./inventory";
import { xpForLevel, MOB_TYPES, type ItemId } from "@gg/shared";

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

type HpBar = {
  bg: Phaser.GameObjects.Rectangle;
  fill: Phaser.GameObjects.Rectangle;
};

type PlayerSprite = {
  container: Phaser.GameObjects.Container;
  sprite: Phaser.GameObjects.Sprite;
  label: Phaser.GameObjects.Text;
  hp: HpBar;
  xp?: HpBar;
  bubble?: Phaser.GameObjects.Text;
  bubbleTimer?: Phaser.Time.TimerEvent;
  lastX: number;
  lastY: number;
  facing: Direction;
  variant: number;
};

type MobSprite = {
  container: Phaser.GameObjects.Container;
  sprite: Phaser.GameObjects.Sprite;
  hp: HpBar;
};

type DropSprite = {
  container: Phaser.GameObjects.Container;
  sprite: Phaser.GameObjects.Sprite;
};

const HP_BAR_W = 28;
const HP_BAR_H = 4;

function makeHpBar(scene: Phaser.Scene, yOffset: number, fillColor: number): HpBar {
  const bg = scene.add.rectangle(0, yOffset, HP_BAR_W, HP_BAR_H, 0x000000, 0.7);
  bg.setStrokeStyle(1, 0x222222, 0.8);
  const fill = scene.add.rectangle(-HP_BAR_W / 2, yOffset, HP_BAR_W, HP_BAR_H, fillColor);
  fill.setOrigin(0, 0.5);
  return { bg, fill };
}

function setHp(hp: HpBar, ratio: number) {
  const clamped = Math.max(0, Math.min(1, ratio));
  hp.fill.width = HP_BAR_W * clamped;
  hp.fill.setVisible(clamped > 0);
}

class GameScene extends Phaser.Scene {
  constructor() { super("game"); }

  private room?: Room;
  private me?: PlayerSprite;
  private others = new Map<string, PlayerSprite>();
  private mobs = new Map<string, MobSprite>();
  private drops = new Map<string, DropSprite>();
  private hud?: ReturnType<typeof mountHud>;
  private keys!: {
    W: Phaser.Input.Keyboard.Key;
    A: Phaser.Input.Keyboard.Key;
    S: Phaser.Input.Keyboard.Key;
    D: Phaser.Input.Keyboard.Key;
  };
  private posX = PLAYER_SPAWN.x;
  private posY = PLAYER_SPAWN.y;
  private moveTarget: { x: number; y: number } | null = null;
  private marker?: Phaser.GameObjects.Arc;
  private myFacing: Direction = "down";
  private myMoving = false;

  private get token(): string {
    return authToken;
  }

  preload() {
    for (let i = 0; i < SPRITE_COUNT; i++) {
      this.load.spritesheet(`char_${i}`, spritesheetUrl(i), {
        frameWidth: 32,
        frameHeight: 32,
      });
    }
    this.load.spritesheet("tiles", `${BASE}sprites/tiles.png`, {
      frameWidth: TILE_SIZE,
      frameHeight: TILE_SIZE,
    });
    this.load.spritesheet("slime", `${BASE}sprites/slime.png`, {
      frameWidth: 32,
      frameHeight: 32,
    });
    this.load.spritesheet("goblin", `${BASE}sprites/goblin.png`, {
      frameWidth: 32,
      frameHeight: 32,
    });
    this.load.spritesheet("items", `${BASE}sprites/items.png`, {
      frameWidth: 16,
      frameHeight: 16,
    });
  }

  private renderMap() {
    for (let r = 0; r < MAP_ROWS; r++) {
      for (let c = 0; c < MAP_COLS; c++) {
        const id = MAP_TILES[r * MAP_COLS + c]!;
        const img = this.add.image(c * TILE_SIZE, r * TILE_SIZE, "tiles", id);
        img.setOrigin(0, 0);
      }
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
    const hp = makeHpBar(this, -34, 0x4ade80);
    const xp = makeHpBar(this, -29, 0xfbbf24);
    xp.bg.setAlpha(0.5);
    const container = this.add.container(x, y, [sprite, label, hp.bg, hp.fill, xp.bg, xp.fill]);
    return { container, sprite, label, hp, xp, lastX: x, lastY: y, facing: "down", variant };
  }

  private createMobSprite(kind: string, x: number, y: number): MobSprite {
    const def = (MOB_TYPES as any)[kind] ?? MOB_TYPES.slime;
    const key = kind === "goblin" ? "goblin" : "slime";
    const animKey = `${key}_idle`;
    if (!this.anims.exists(animKey)) {
      this.anims.create({
        key: animKey,
        frames: this.anims.generateFrameNumbers(key, { frames: [0, 0, 0, 1] }),
        frameRate: key === "goblin" ? 4 : 3,
        repeat: -1,
      });
    }
    const sprite = this.add.sprite(0, 0, key, 0);
    sprite.setScale(def.scale);
    sprite.play(animKey);
    const hp = makeHpBar(this, -22, 0xef4444);
    const container = this.add.container(x, y, [sprite, hp.bg, hp.fill]);
    return { container, sprite, hp };
  }

  private flashSprite(sprite: Phaser.GameObjects.Sprite) {
    sprite.setTint(0xffffff);
    this.time.delayedCall(90, () => sprite.clearTint());
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
    this.cameras.main.setBackgroundColor("#000");
    this.cameras.main.setBounds(0, 0, MAP_WIDTH, MAP_HEIGHT);
    this.renderMap();

    this.keys = this.input.keyboard!.addKeys("W,A,S,D") as typeof this.keys;
    this.marker = this.add.circle(0, 0, 6, 0xffff00, 0.7).setVisible(false);

    this.input.on("pointerdown", (p: Phaser.Input.Pointer) => {
      const mobHit = this.findMobAt(p.worldX, p.worldY);
      if (mobHit && this.me) {
        const dist = Math.hypot(mobHit.ms.container.x - this.me.container.x, mobHit.ms.container.y - this.me.container.y);
        if (dist <= PLAYER_ATTACK_RANGE) {
          const msg: AttackMessage = { mobId: mobHit.id };
          this.room?.send("attack", msg);
          return;
        }
        this.moveTarget = { x: mobHit.ms.container.x, y: mobHit.ms.container.y };
        this.marker!.setPosition(mobHit.ms.container.x, mobHit.ms.container.y).setVisible(true);
        return;
      }
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
        this.cameras.main.startFollow(ps.container, true, 0.15, 0.15);
      } else {
        this.others.set(sessionId, ps);
      }

      const updateStats = () => {
        setHp(ps.hp, player.hp / (player.hpMax || PLAYER_HP_MAX));
        if (ps.xp) setHp(ps.xp, player.xp / Math.max(1, xpForLevel(player.level)));
        const displayName = `${player.name} L${player.level}`;
        if (ps.label.text !== displayName) ps.label.setText(displayName);
      };
      updateStats();
      if (isMe) this.updateLocalInventory(player);

      $(player).onChange(() => {
        updateStats();
        if (isMe) this.updateLocalInventory(player);
        if (isMe) {
          // Server-driven teleport (e.g., respawn) needs to sync local prediction.
          const dist = Math.hypot(player.x - this.posX, player.y - this.posY);
          if (dist > 64) {
            this.posX = player.x;
            this.posY = player.y;
            ps.container.x = player.x;
            ps.container.y = player.y;
            this.moveTarget = null;
            this.marker!.setVisible(false);
          }
          return;
        }
        const dx = player.x - ps.lastX;
        const dy = player.y - ps.lastY;
        const dir = dirFromDelta(dx, dy, ps.facing);
        const moving = Math.hypot(dx, dy) > 0.3;
        ps.container.x = player.x;
        ps.container.y = player.y;
        ps.lastX = player.x;
        ps.lastY = player.y;
        this.setFrame(ps, dir, moving);
      });
    });

    $(this.room.state).players.onRemove((_p: any, sessionId: string) => {
      this.others.get(sessionId)?.container.destroy();
      this.others.delete(sessionId);
    });

    $(this.room.state).mobs.onAdd((mob: any, mobId: string) => {
      const ms = this.createMobSprite(mob.kind, mob.x, mob.y);
      this.mobs.set(mobId, ms);
      setHp(ms.hp, mob.hp / (mob.hpMax || MOB_HP_MAX));
      ms.container.setVisible(mob.state === "alive");

      $(mob).onChange(() => {
        ms.container.x = mob.x;
        ms.container.y = mob.y;
        setHp(ms.hp, mob.hp / (mob.hpMax || MOB_HP_MAX));
        ms.container.setVisible(mob.state === "alive");
      });
    });

    $(this.room.state).mobs.onRemove((_m: any, mobId: string) => {
      this.mobs.get(mobId)?.container.destroy();
      this.mobs.delete(mobId);
    });

    $(this.room.state).drops.onAdd((drop: any, dropId: string) => {
      const sprite = this.add.sprite(0, 0, "items", 0);
      sprite.setScale(1);
      const container = this.add.container(drop.x, drop.y, [sprite]);
      this.tweens.add({
        targets: container,
        y: { from: drop.y - 4, to: drop.y + 2 },
        duration: 900,
        yoyo: true,
        repeat: -1,
        ease: "sine.inout",
      });
      this.drops.set(dropId, { container, sprite });
      $(drop).onChange(() => {
        container.x = drop.x;
        container.y = drop.y;
      });
    });

    $(this.room.state).drops.onRemove((_d: any, dropId: string) => {
      this.drops.get(dropId)?.container.destroy();
      this.drops.delete(dropId);
    });

    this.room.onMessage("hit", (data: { mobId: string }) => {
      const ms = this.mobs.get(data.mobId);
      if (ms) this.flashSprite(ms.sprite);
    });

    this.room.onMessage("playerHit", (data: { sessionId: string }) => {
      const ps = data.sessionId === mySessionId ? this.me : this.others.get(data.sessionId);
      if (ps) this.flashSprite(ps.sprite);
    });

    this.hud = mountHud(this.room);

    mountChat(this.room, (msg) => {
      const ps = msg.sessionId === mySessionId
        ? this.me
        : this.others.get(msg.sessionId);
      if (ps) this.showBubble(ps, msg.text);
    });
  }

  private updateLocalInventory(player: any) {
    if (!this.hud) return;
    const slots: InvSlotView[] = [];
    for (const e of player.inventory) {
      slots.push({ itemId: e.itemId as ItemId, qty: e.qty });
    }
    this.hud.update({
      gold: player.gold ?? 0,
      weapon: player.eqWeapon ?? "",
      armor: player.eqArmor ?? "",
      slots,
    });
  }

  private findMobAt(x: number, y: number): { id: string; ms: MobSprite } | null {
    let bestId = "";
    let bestMs: MobSprite | null = null;
    let bestDist = Infinity;
    this.mobs.forEach((ms, id) => {
      if (!ms.container.visible) return;
      const d = Math.hypot(ms.container.x - x, ms.container.y - y);
      if (d < 24 && d < bestDist) {
        bestId = id;
        bestMs = ms;
        bestDist = d;
      }
    });
    return bestMs ? { id: bestId, ms: bestMs } : null;
  }

  private showBubble(ps: PlayerSprite, text: string) {
    ps.bubbleTimer?.remove();
    ps.bubble?.destroy();
    const bubble = this.add.text(0, -46, text, {
      fontFamily: "system-ui, sans-serif",
      fontSize: "12px",
      color: "#ffffff",
      backgroundColor: "rgba(0,0,0,0.7)",
      padding: { x: 6, y: 3 },
      wordWrap: { width: 180, useAdvancedWrap: true },
      align: "center",
    });
    bubble.setOrigin(0.5, 1);
    ps.container.add(bubble);
    ps.bubble = bubble;
    ps.bubbleTimer = this.time.delayedCall(4000, () => {
      bubble.destroy();
      if (ps.bubble === bubble) ps.bubble = undefined;
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
      const nx = Phaser.Math.Clamp(this.posX + stepX, 0, MAP_WIDTH - 1);
      const ny = Phaser.Math.Clamp(this.posY + stepY, 0, MAP_HEIGHT - 1);
      if (isWalkableAt(nx, this.posY)) this.posX = nx;
      if (isWalkableAt(this.posX, ny)) this.posY = ny;
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

let authToken = "";

function startGame(token: string) {
  authToken = token;
  mountLogoutButton(() => location.reload());
  new Phaser.Game({
    type: Phaser.AUTO,
    width: VIEW_WIDTH,
    height: VIEW_HEIGHT,
    parent: "game",
    scene: GameScene,
    backgroundColor: "#000",
    pixelArt: true,
  });
}

const existing = getStoredToken();
if (existing) {
  document.getElementById("auth-overlay")?.remove();
  startGame(existing);
} else {
  mountAuthUI((token) => startGame(token));
}
