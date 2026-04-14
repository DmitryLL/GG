export const TILE_SIZE = 32;
export const MAP_COLS = 60;
export const MAP_ROWS = 45;
export const MAP_WIDTH = TILE_SIZE * MAP_COLS;    // 1920
export const MAP_HEIGHT = TILE_SIZE * MAP_ROWS;   // 1440

export const VIEW_WIDTH = 800;
export const VIEW_HEIGHT = 608;

export const MAX_STEP_PER_TICK = 16;
export const PLAYER_SPEED = 200;
export const WORLD_SEED = 1337;

export const ROOM_NAME = "game_room";

export const TILE = {
  GRASS: 0,
  SAND: 1,
  WATER: 2,
  TREE: 3,
  STONE: 4,
  PATH: 5,
} as const;
export type TileId = (typeof TILE)[keyof typeof TILE];

const BLOCKED = new Set<number>([TILE.WATER, TILE.TREE, TILE.STONE]);

export function isWalkableTile(id: number): boolean {
  return !BLOCKED.has(id);
}

function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function generateMap(): { tiles: number[]; mobSpawns: { x: number; y: number; type: string }[]; playerSpawn: { x: number; y: number } } {
  const rnd = mulberry32(WORLD_SEED);
  const tiles = new Array<number>(MAP_COLS * MAP_ROWS).fill(TILE.GRASS);
  const setTile = (c: number, r: number, id: number) => {
    if (c >= 0 && c < MAP_COLS && r >= 0 && r < MAP_ROWS) tiles[r * MAP_COLS + c] = id;
  };
  const getTile = (c: number, r: number): number => {
    if (c < 0 || c >= MAP_COLS || r < 0 || r >= MAP_ROWS) return TILE.TREE;
    return tiles[r * MAP_COLS + c]!;
  };

  // Border forest — 1 tile thick
  for (let c = 0; c < MAP_COLS; c++) {
    setTile(c, 0, TILE.TREE);
    setTile(c, MAP_ROWS - 1, TILE.TREE);
  }
  for (let r = 0; r < MAP_ROWS; r++) {
    setTile(0, r, TILE.TREE);
    setTile(MAP_COLS - 1, r, TILE.TREE);
  }

  // Water ponds
  const pondCount = 5;
  for (let i = 0; i < pondCount; i++) {
    const cx = 6 + Math.floor(rnd() * (MAP_COLS - 12));
    const cy = 6 + Math.floor(rnd() * (MAP_ROWS - 12));
    const radius = 2 + Math.floor(rnd() * 3);
    for (let dr = -radius - 1; dr <= radius + 1; dr++) {
      for (let dc = -radius - 1; dc <= radius + 1; dc++) {
        const d = Math.hypot(dc, dr);
        if (d <= radius) setTile(cx + dc, cy + dr, TILE.WATER);
        else if (d <= radius + 1 && getTile(cx + dc, cy + dr) === TILE.GRASS) setTile(cx + dc, cy + dr, TILE.SAND);
      }
    }
  }

  // Stone ruins
  const ruinCount = 4;
  for (let i = 0; i < ruinCount; i++) {
    const cx = 4 + Math.floor(rnd() * (MAP_COLS - 10));
    const cy = 4 + Math.floor(rnd() * (MAP_ROWS - 10));
    const w = 3 + Math.floor(rnd() * 3);
    const h = 3 + Math.floor(rnd() * 3);
    for (let dy = 0; dy < h; dy++) {
      for (let dx = 0; dx < w; dx++) {
        const edge = dy === 0 || dy === h - 1 || dx === 0 || dx === w - 1;
        const gapBottom = dy === h - 1 && dx === Math.floor(w / 2);
        if (edge && !gapBottom && getTile(cx + dx, cy + dy) !== TILE.WATER) {
          setTile(cx + dx, cy + dy, TILE.STONE);
        }
      }
    }
  }

  // Scatter trees (groves)
  for (let i = 0; i < 180; i++) {
    const c = 2 + Math.floor(rnd() * (MAP_COLS - 4));
    const r = 2 + Math.floor(rnd() * (MAP_ROWS - 4));
    if (getTile(c, r) === TILE.GRASS) setTile(c, r, TILE.TREE);
  }

  // Paths — a couple of meandering roads
  const pathCount = 3;
  for (let i = 0; i < pathCount; i++) {
    let c = 2 + Math.floor(rnd() * (MAP_COLS - 4));
    let r = 2 + Math.floor(rnd() * (MAP_ROWS - 4));
    const len = 30 + Math.floor(rnd() * 40);
    for (let s = 0; s < len; s++) {
      if (getTile(c, r) === TILE.GRASS || getTile(c, r) === TILE.TREE) setTile(c, r, TILE.PATH);
      const dir = Math.floor(rnd() * 4);
      if (dir === 0) c++;
      else if (dir === 1) c--;
      else if (dir === 2) r++;
      else r--;
      c = Math.max(1, Math.min(MAP_COLS - 2, c));
      r = Math.max(1, Math.min(MAP_ROWS - 2, r));
    }
  }

  // Clear spawn area — a safe plaza at map center
  const playerSpawn = { x: MAP_WIDTH / 2, y: MAP_HEIGHT / 2 };
  const scx = Math.floor(playerSpawn.x / TILE_SIZE);
  const scy = Math.floor(playerSpawn.y / TILE_SIZE);
  for (let dr = -2; dr <= 2; dr++) {
    for (let dc = -2; dc <= 2; dc++) {
      setTile(scx + dc, scy + dr, TILE.GRASS);
    }
  }

  // Mob spawns — scatter on grass tiles away from player spawn.
  // Closer to spawn: slimes; farther out: goblins.
  const mobSpawns: { x: number; y: number; type: string }[] = [];
  let attempts = 0;
  while (mobSpawns.length < 20 && attempts < 800) {
    attempts++;
    const c = 2 + Math.floor(rnd() * (MAP_COLS - 4));
    const r = 2 + Math.floor(rnd() * (MAP_ROWS - 4));
    if (getTile(c, r) !== TILE.GRASS && getTile(c, r) !== TILE.PATH) continue;
    const px = c * TILE_SIZE + TILE_SIZE / 2;
    const py = r * TILE_SIZE + TILE_SIZE / 2;
    const distToSpawn = Math.hypot(px - playerSpawn.x, py - playerSpawn.y);
    if (distToSpawn < 160) continue;
    if (mobSpawns.some((s) => Math.hypot(s.x - px, s.y - py) < 140)) continue;
    const type = distToSpawn > 500 ? "goblin" : "slime";
    mobSpawns.push({ x: px, y: py, type });
  }

  return { tiles, mobSpawns, playerSpawn };
}

const WORLD = generateMap();
export const MAP_TILES: readonly number[] = WORLD.tiles;
export const MOB_SPAWNS: readonly { x: number; y: number; type: string }[] = WORLD.mobSpawns;
export const PLAYER_SPAWN = WORLD.playerSpawn;

export function tileAt(col: number, row: number): number {
  if (col < 0 || col >= MAP_COLS || row < 0 || row >= MAP_ROWS) return TILE.TREE;
  return MAP_TILES[row * MAP_COLS + col]!;
}

export function isWalkableAt(x: number, y: number): boolean {
  const col = Math.floor(x / TILE_SIZE);
  const row = Math.floor(y / TILE_SIZE);
  return isWalkableTile(tileAt(col, row));
}

export const PLAYER_HP_MAX = 100;
export const PLAYER_ATTACK_DAMAGE = 10;
export const PLAYER_ATTACK_RANGE = 48;
export const PLAYER_ATTACK_COOLDOWN_MS = 450;

export const MOB_TOUCH_RANGE = 26;
export const MOB_TOUCH_COOLDOWN_MS = 900;
export const MOB_WANDER_RADIUS = 80;
export const MOB_RESPAWN_MS = 8000;

export const MOB_TYPES = {
  slime: {
    id: "slime",
    name: "Слайм",
    hpMax: 30,
    touchDamage: 5,
    speed: 40,
    xp: 12,
    gold: 1,
    scale: 1.3,
  },
  goblin: {
    id: "goblin",
    name: "Гоблин",
    hpMax: 60,
    touchDamage: 10,
    speed: 55,
    xp: 28,
    gold: 4,
    scale: 1.25,
  },
} as const;
export type MobTypeId = keyof typeof MOB_TYPES;

// Back-compat for code paths still referencing slime defaults.
export const MOB_HP_MAX = MOB_TYPES.slime.hpMax;
export const MOB_TOUCH_DAMAGE = MOB_TYPES.slime.touchDamage;
export const MOB_SPEED = MOB_TYPES.slime.speed;

export const INVENTORY_SLOTS = 6;
export const ITEM_STACK_MAX = 99;
export const PICKUP_RANGE = 40;
export const DROP_LIFETIME_MS = 60000;

export type ItemKind = "material" | "weapon" | "armor" | "consumable";
export type ItemDef = {
  id: string;
  name: string;
  icon: number;
  kind: ItemKind;
  damage?: number;
  hp?: number;
  heal?: number;
  price?: number;       // merchant buy price (player pays)
  sellPrice?: number;   // merchant sell price (player receives)
};

export const ITEMS = {
  slime_jelly: { id: "slime_jelly", name: "Слизь",       icon: 0, kind: "material",  sellPrice: 2 },
  wood_sword:  { id: "wood_sword",  name: "Деревянный меч", icon: 1, kind: "weapon",   damage: 4,  sellPrice: 5 },
  iron_sword:  { id: "iron_sword",  name: "Железный меч",   icon: 2, kind: "weapon",   damage: 10, sellPrice: 18 },
  cloth_armor: { id: "cloth_armor", name: "Тканая броня",   icon: 3, kind: "armor",    hp: 20,     sellPrice: 8 },
  iron_armor:  { id: "iron_armor",  name: "Железная броня", icon: 4, kind: "armor",    hp: 45,     sellPrice: 22 },
} satisfies Record<string, ItemDef>;
export type ItemId = keyof typeof ITEMS;

export function isEquippable(itemId: ItemId): boolean {
  const kind = ITEMS[itemId].kind;
  return kind === "weapon" || kind === "armor";
}

export type InventorySlot = { itemId: ItemId; qty: number } | null;

export function xpForLevel(level: number): number {
  return 50 * level;
}
export const PER_LEVEL_HP_BONUS = 10;
export const PER_LEVEL_DAMAGE_BONUS = 2;

// Drop table per mob type: roll item with weight; rolls may miss.
export const DROP_TABLES: Record<MobTypeId, { itemId: ItemId; weight: number }[]> = {
  slime: [
    { itemId: "slime_jelly", weight: 80 },
    { itemId: "wood_sword",  weight: 4  },
    { itemId: "cloth_armor", weight: 3  },
  ],
  goblin: [
    { itemId: "slime_jelly", weight: 30 },
    { itemId: "wood_sword",  weight: 15 },
    { itemId: "iron_sword",  weight: 8  },
    { itemId: "cloth_armor", weight: 10 },
    { itemId: "iron_armor",  weight: 5  },
  ],
};

export type MoveMessage = { x: number; y: number };
export type AttackMessage = { mobId: string };
export type EquipMessage = { slot: number };       // equip from inventory slot index
export type UnequipMessage = { slot: "weapon" | "armor" };
export type ChatSend = { text: string };
export type ChatBroadcast = { sessionId: string; name: string; text: string; ts: number };

export const CHAT_MAX_LEN = 140;

export type ClientMessages = {
  move: MoveMessage;
  chat: ChatSend;
};

export type JoinOptions = {
  token?: string;
};

export type AuthRequest = { email: string; password: string };
export type AuthResponse = { token: string; userId: string };
export type AuthError = { error: string };

export type PlayerView = {
  x: number;
  y: number;
};
