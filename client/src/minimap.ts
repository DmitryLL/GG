import {
  MAP_COLS,
  MAP_ROWS,
  MAP_TILES,
  TILE,
  TILE_SIZE,
  NPCS,
} from "@gg/shared";

const TILE_PX = 3; // each tile becomes a 3×3 square
const W = MAP_COLS * TILE_PX;
const H = MAP_ROWS * TILE_PX;
const SCALE = TILE_PX / TILE_SIZE;

const TILE_COLORS: Record<number, string> = {
  [TILE.GRASS]: "#4a7c4e",
  [TILE.SAND]:  "#dac494",
  [TILE.WATER]: "#3a6ea8",
  [TILE.TREE]:  "#2a5a32",
  [TILE.STONE]: "#8486a0",
  [TILE.PATH]:  "#a8926a",
};

export type MiniMobView = { x: number; y: number; alive: boolean };
export type MiniPlayerView = { x: number; y: number };

export function mountMinimap() {
  const host = document.getElementById("game-col")!;
  const wrapper = document.createElement("div");
  wrapper.id = "minimap";
  const canvas = document.createElement("canvas");
  canvas.width = W;
  canvas.height = H;
  wrapper.appendChild(canvas);
  host.appendChild(wrapper);

  const ctx = canvas.getContext("2d")!;

  // Pre-render terrain into an offscreen canvas so updates only redraw
  // entity dots on top.
  const terrain = document.createElement("canvas");
  terrain.width = W;
  terrain.height = H;
  const tctx = terrain.getContext("2d")!;
  for (let r = 0; r < MAP_ROWS; r++) {
    for (let c = 0; c < MAP_COLS; c++) {
      const id = MAP_TILES[r * MAP_COLS + c]!;
      tctx.fillStyle = TILE_COLORS[id] ?? "#000";
      tctx.fillRect(c * TILE_PX, r * TILE_PX, TILE_PX, TILE_PX);
    }
  }

  function dot(ctx: CanvasRenderingContext2D, x: number, y: number, size: number, color: string) {
    ctx.fillStyle = color;
    ctx.fillRect(Math.floor(x * SCALE - size / 2), Math.floor(y * SCALE - size / 2), size, size);
  }

  return {
    update(opts: {
      meX: number; meY: number;
      others: MiniPlayerView[];
      mobs: MiniMobView[];
    }) {
      ctx.drawImage(terrain, 0, 0);
      ctx.globalAlpha = 1;
      for (const npc of NPCS) dot(ctx, npc.x, npc.y, 4, "#fde047");
      for (const m of opts.mobs) {
        if (!m.alive) continue;
        dot(ctx, m.x, m.y, 3, "#ef4444");
      }
      for (const p of opts.others) dot(ctx, p.x, p.y, 3, "#ffffff");
      dot(ctx, opts.meX, opts.meY, 5, "#34d399");
    },
  };
}
