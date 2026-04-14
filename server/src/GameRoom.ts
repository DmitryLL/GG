import { Room, Client } from "colyseus";
import { Schema, MapSchema, ArraySchema, type } from "@colyseus/schema";
import {
  MAP_WIDTH,
  MAP_HEIGHT,
  MAX_STEP_PER_TICK,
  CHAT_MAX_LEN,
  PLAYER_HP_MAX,
  PLAYER_ATTACK_DAMAGE,
  PLAYER_ATTACK_RANGE,
  PLAYER_ATTACK_COOLDOWN_MS,
  MOB_HP_MAX,
  MOB_TOUCH_DAMAGE,
  MOB_TOUCH_RANGE,
  MOB_TOUCH_COOLDOWN_MS,
  MOB_WANDER_RADIUS,
  MOB_SPEED,
  MOB_RESPAWN_MS,
  MOB_SPAWNS,
  PLAYER_SPAWN,
  INVENTORY_SLOTS,
  ITEM_STACK_MAX,
  PICKUP_RANGE,
  DROP_LIFETIME_MS,
  XP_PER_MOB,
  PER_LEVEL_HP_BONUS,
  PER_LEVEL_DAMAGE_BONUS,
  xpForLevel,
  isWalkableAt,
  type MoveMessage,
  type ChatSend,
  type ChatBroadcast,
  type AttackMessage,
  type JoinOptions,
  type ItemId,
  type InventorySlot,
} from "@gg/shared";
import { verifyToken } from "./auth.js";
import { prisma } from "./db.js";

export class InvEntry extends Schema {
  @type("string") itemId: string = "";
  @type("number") qty: number = 0;
}

export class Player extends Schema {
  @type("number") x: number = PLAYER_SPAWN.x;
  @type("number") y: number = PLAYER_SPAWN.y;
  @type("number") hp: number = PLAYER_HP_MAX;
  @type("number") hpMax: number = PLAYER_HP_MAX;
  @type("number") level: number = 1;
  @type("number") xp: number = 0;
  @type("string") name: string = "";
  @type([InvEntry]) inventory = new ArraySchema<InvEntry>();
}

export class Mob extends Schema {
  @type("number") x: number = 0;
  @type("number") y: number = 0;
  @type("number") hp: number = MOB_HP_MAX;
  @type("string") state: string = "alive";
}

export class Drop extends Schema {
  @type("number") x: number = 0;
  @type("number") y: number = 0;
  @type("string") itemId: string = "";
  @type("number") qty: number = 1;
}

export class State extends Schema {
  @type({ map: Player }) players = new MapSchema<Player>();
  @type({ map: Mob }) mobs = new MapSchema<Mob>();
  @type({ map: Drop }) drops = new MapSchema<Drop>();
}

type AuthData = { userId: string; characterId: string };

const SIM_TICK_MS = 200;

function playerDamage(level: number): number {
  return PLAYER_ATTACK_DAMAGE + PER_LEVEL_DAMAGE_BONUS * (level - 1);
}
function playerMaxHp(level: number): number {
  return PLAYER_HP_MAX + PER_LEVEL_HP_BONUS * (level - 1);
}

export class GameRoom extends Room<State> {
  maxClients = 50;

  private lastPlayerAttack = new Map<string, number>();
  private lastMobTouch = new Map<string, number>();
  private mobRespawnAt = new Map<string, number>();
  private mobHome = new Map<string, { x: number; y: number }>();
  private mobTarget = new Map<string, { x: number; y: number }>();
  private dropExpireAt = new Map<string, number>();
  private nextDropId = 0;

  onCreate() {
    this.setState(new State());

    for (let i = 0; i < MOB_SPAWNS.length; i++) {
      const id = `m${i}`;
      const spawn = MOB_SPAWNS[i]!;
      const mob = new Mob();
      mob.x = spawn.x;
      mob.y = spawn.y;
      mob.hp = MOB_HP_MAX;
      mob.state = "alive";
      this.state.mobs.set(id, mob);
      this.mobHome.set(id, { ...spawn });
    }

    this.onMessage<MoveMessage>("move", (client, msg) => {
      const player = this.state.players.get(client.sessionId);
      if (!player || player.hp <= 0) return;
      const dx = Math.max(-MAX_STEP_PER_TICK, Math.min(MAX_STEP_PER_TICK, msg.x - player.x));
      const dy = Math.max(-MAX_STEP_PER_TICK, Math.min(MAX_STEP_PER_TICK, msg.y - player.y));
      const nx = Math.max(0, Math.min(MAP_WIDTH - 1, player.x + dx));
      const ny = Math.max(0, Math.min(MAP_HEIGHT - 1, player.y + dy));
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

    this.onMessage<AttackMessage>("attack", (client, msg) => {
      const player = this.state.players.get(client.sessionId);
      if (!player || player.hp <= 0) return;
      const now = Date.now();
      const last = this.lastPlayerAttack.get(client.sessionId) ?? 0;
      if (now - last < PLAYER_ATTACK_COOLDOWN_MS) return;
      const mob = this.state.mobs.get(msg.mobId);
      if (!mob || mob.state !== "alive") return;
      const dist = Math.hypot(mob.x - player.x, mob.y - player.y);
      if (dist > PLAYER_ATTACK_RANGE) return;
      this.lastPlayerAttack.set(client.sessionId, now);
      mob.hp = Math.max(0, mob.hp - playerDamage(player.level));
      this.broadcast("hit", { mobId: msg.mobId, by: client.sessionId });
      if (mob.hp <= 0) {
        mob.state = "dead";
        this.mobRespawnAt.set(msg.mobId, now + MOB_RESPAWN_MS);
        this.dropJelly(mob.x, mob.y);
        this.grantXp(player, XP_PER_MOB);
      }
    });

    this.setSimulationInterval(() => this.tick(), SIM_TICK_MS);
  }

  private dropJelly(x: number, y: number) {
    const id = `d${this.nextDropId++}`;
    const drop = new Drop();
    drop.x = x;
    drop.y = y;
    drop.itemId = "slime_jelly";
    drop.qty = 1;
    this.state.drops.set(id, drop);
    this.dropExpireAt.set(id, Date.now() + DROP_LIFETIME_MS);
  }

  private grantXp(player: Player, amount: number) {
    player.xp += amount;
    while (player.xp >= xpForLevel(player.level)) {
      player.xp -= xpForLevel(player.level);
      player.level += 1;
      player.hpMax = playerMaxHp(player.level);
      player.hp = player.hpMax;
    }
  }

  private addToInventory(player: Player, itemId: ItemId, qty: number): boolean {
    for (const slot of player.inventory) {
      if (slot.itemId === itemId && slot.qty < ITEM_STACK_MAX) {
        const space = ITEM_STACK_MAX - slot.qty;
        const take = Math.min(space, qty);
        slot.qty += take;
        qty -= take;
        if (qty <= 0) return true;
      }
    }
    while (qty > 0 && player.inventory.length < INVENTORY_SLOTS) {
      const take = Math.min(ITEM_STACK_MAX, qty);
      const entry = new InvEntry();
      entry.itemId = itemId;
      entry.qty = take;
      player.inventory.push(entry);
      qty -= take;
    }
    return qty === 0;
  }

  private tick() {
    const now = Date.now();
    const dt = SIM_TICK_MS / 1000;

    this.state.mobs.forEach((mob, id) => {
      if (mob.state === "dead") {
        const t = this.mobRespawnAt.get(id);
        if (t && now >= t) {
          const home = this.mobHome.get(id)!;
          mob.x = home.x;
          mob.y = home.y;
          mob.hp = MOB_HP_MAX;
          mob.state = "alive";
          this.mobRespawnAt.delete(id);
          this.mobTarget.delete(id);
        }
        return;
      }

      let tgt = this.mobTarget.get(id);
      if (!tgt || Math.hypot(tgt.x - mob.x, tgt.y - mob.y) < 4) {
        const home = this.mobHome.get(id)!;
        const angle = Math.random() * Math.PI * 2;
        const r = Math.random() * MOB_WANDER_RADIUS;
        tgt = {
          x: Math.max(0, Math.min(MAP_WIDTH - 1, home.x + Math.cos(angle) * r)),
          y: Math.max(0, Math.min(MAP_HEIGHT - 1, home.y + Math.sin(angle) * r)),
        };
        this.mobTarget.set(id, tgt);
      }
      const mdx = tgt.x - mob.x;
      const mdy = tgt.y - mob.y;
      const mdist = Math.hypot(mdx, mdy);
      if (mdist > 0.1) {
        const step = Math.min(mdist, MOB_SPEED * dt);
        const nx = mob.x + (mdx / mdist) * step;
        const ny = mob.y + (mdy / mdist) * step;
        if (isWalkableAt(nx, mob.y)) mob.x = nx;
        else this.mobTarget.delete(id);
        if (isWalkableAt(mob.x, ny)) mob.y = ny;
        else this.mobTarget.delete(id);
      }

      this.state.players.forEach((player, sid) => {
        if (player.hp <= 0) return;
        const d = Math.hypot(player.x - mob.x, player.y - mob.y);
        if (d > MOB_TOUCH_RANGE) return;
        const last = this.lastMobTouch.get(`${id}:${sid}`) ?? 0;
        if (now - last < MOB_TOUCH_COOLDOWN_MS) return;
        this.lastMobTouch.set(`${id}:${sid}`, now);
        player.hp = Math.max(0, player.hp - MOB_TOUCH_DAMAGE);
        this.broadcast("playerHit", { sessionId: sid, by: id });
        if (player.hp <= 0) {
          player.x = PLAYER_SPAWN.x;
          player.y = PLAYER_SPAWN.y;
          player.hp = player.hpMax;
          this.broadcast("respawn", { sessionId: sid });
        }
      });
    });

    // Auto-pickup drops
    this.state.drops.forEach((drop, id) => {
      const expire = this.dropExpireAt.get(id);
      if (expire && now >= expire) {
        this.state.drops.delete(id);
        this.dropExpireAt.delete(id);
        return;
      }
      this.state.players.forEach((player) => {
        if (player.hp <= 0) return;
        const d = Math.hypot(player.x - drop.x, player.y - drop.y);
        if (d > PICKUP_RANGE) return;
        const ok = this.addToInventory(player, drop.itemId as ItemId, drop.qty);
        if (ok) {
          this.state.drops.delete(id);
          this.dropExpireAt.delete(id);
        }
      });
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
      player.x = PLAYER_SPAWN.x;
      player.y = PLAYER_SPAWN.y;
    }
    player.name = character.name;
    player.level = character.level;
    player.xp = character.xp;
    player.hpMax = playerMaxHp(player.level);
    player.hp = player.hpMax;
    const inv = Array.isArray(character.inventory) ? (character.inventory as InventorySlot[]) : [];
    for (const slot of inv) {
      if (!slot) continue;
      const entry = new InvEntry();
      entry.itemId = slot.itemId;
      entry.qty = slot.qty;
      player.inventory.push(entry);
    }
    this.state.players.set(client.sessionId, player);
    client.userData = auth;
    console.log(`${character.name} (L${player.level}) joined at ${player.x},${player.y}`);
  }

  async onLeave(client: Client) {
    const player = this.state.players.get(client.sessionId);
    const auth = client.userData as AuthData | undefined;
    if (player && auth) {
      const invJson = player.inventory.map((e) => ({ itemId: e.itemId, qty: e.qty }));
      await prisma.character.update({
        where: { id: auth.characterId },
        data: {
          x: Math.round(player.x),
          y: Math.round(player.y),
          level: player.level,
          xp: player.xp,
          inventory: invJson,
        },
      });
      console.log(`${player.name} saved L${player.level} xp${player.xp}`);
    }
    this.state.players.delete(client.sessionId);
    this.lastPlayerAttack.delete(client.sessionId);
  }
}
