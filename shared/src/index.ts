export const TILE_SIZE = 32;
export const MAP_COLS = 25;
export const MAP_ROWS = 19;
export const MAP_WIDTH = TILE_SIZE * MAP_COLS;   // 800
export const MAP_HEIGHT = TILE_SIZE * MAP_ROWS;  // 608

export const MAX_STEP_PER_TICK = 16;
export const PLAYER_SPEED = 200;

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

// Static map — 25 cols × 19 rows.
// Legend:  .=grass  ,=path  s=sand  ~=water  T=tree  #=stone
const MAP_ASCII: string[] = [
  "TTTTTTTTTTTTTTTTTTTTTTTTT",
  "T.......................T",
  "T..........,,,,.........T",
  "T.........,,..,,........T",
  "T........,,....,,.......T",
  "T.......,,......,,T.....T",
  "T......,,.......,,......T",
  "T.T...,,.........,,.....T",
  "T....,,.###.......,,....T",
  "T...,,..#.#........,,..TT",
  "T...,,..###.........,,.TT",
  "T...,,...............,,.T",
  "T....,,...........T...,,T",
  "TT....,,........sss.....T",
  "TT.....,,......ss~~s....T",
  "T.......,,....ss~~~~s...T",
  "T........,,...s~~~~~s..TT",
  "T.........,,..sss~ss...TT",
  "TTTTTTTTTTTTTTTTTTTTTTTTT",
];

const CHAR_TO_TILE: Record<string, number> = {
  ".": TILE.GRASS,
  ",": TILE.PATH,
  s: TILE.SAND,
  "~": TILE.WATER,
  T: TILE.TREE,
  "#": TILE.STONE,
};

export const MAP_TILES: number[] = (() => {
  const out: number[] = [];
  for (let r = 0; r < MAP_ROWS; r++) {
    const row = MAP_ASCII[r] ?? "";
    for (let c = 0; c < MAP_COLS; c++) {
      const ch = row[c] ?? ".";
      out.push(CHAR_TO_TILE[ch] ?? TILE.GRASS);
    }
  }
  return out;
})();

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

export const MOB_HP_MAX = 30;
export const MOB_TOUCH_DAMAGE = 5;
export const MOB_TOUCH_RANGE = 26;
export const MOB_TOUCH_COOLDOWN_MS = 900;
export const MOB_WANDER_RADIUS = 80;
export const MOB_SPEED = 40;
export const MOB_RESPAWN_MS = 8000;

export const MOB_SPAWNS = [
  { x: 250, y: 250 },
  { x: 550, y: 150 },
  { x: 150, y: 450 },
  { x: 650, y: 420 },
];

export type MoveMessage = { x: number; y: number };
export type AttackMessage = { mobId: string };
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
