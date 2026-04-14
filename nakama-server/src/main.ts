// Nakama runtime entry. Single file — every top-level `function` is hoisted
// into goja's global scope so Nakama can discover `InitModule` by name.

// ------------------------------------------------------------------ //
// World generation — mirrors godot/scripts/world_data.gd so the server
// can reason about walkability and place authoritative mob spawns.
// ------------------------------------------------------------------ //

const TILE_SIZE = 32;
const MAP_COLS = 60;
const MAP_ROWS = 45;
const MAP_WIDTH = TILE_SIZE * MAP_COLS;  // 1920
const MAP_HEIGHT = TILE_SIZE * MAP_ROWS; // 1440
const WORLD_SEED = 1337;

const TILE_GRASS = 0;
const TILE_SAND  = 1;
const TILE_WATER = 2;
const TILE_TREE  = 3;
const TILE_STONE = 4;
const TILE_PATH  = 5;
const BLOCKED = [TILE_WATER, TILE_TREE, TILE_STONE];

interface Vec2 { x: number; y: number; }
interface MobSpawn { x: number; y: number; type: string; }
interface GenResult {
    tiles: number[];
    mobSpawns: MobSpawn[];
    playerSpawn: Vec2;
}

function imul(a: number, b: number): number {
    a = a | 0;
    b = b | 0;
    const ah = (a >>> 16) & 0xffff;
    const al = a & 0xffff;
    const bh = (b >>> 16) & 0xffff;
    const bl = b & 0xffff;
    return (al * bl + (((ah * bl + al * bh) << 16) >>> 0)) | 0;
}

function makeRand(seed: number): () => number {
    let state = seed >>> 0;
    return function () {
        state = (state + 0x6d2b79f5) >>> 0;
        let t = state;
        t = imul(t ^ (t >>> 15), t | 1);
        t = (t ^ (t + imul(t ^ (t >>> 7), t | 61))) >>> 0;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

function generateWorld(): GenResult {
    const rnd = makeRand(WORLD_SEED);
    const tiles = new Array<number>(MAP_COLS * MAP_ROWS).fill(TILE_GRASS);
    function setTile(c: number, r: number, id: number): void {
        if (c >= 0 && c < MAP_COLS && r >= 0 && r < MAP_ROWS) tiles[r * MAP_COLS + c] = id;
    }
    function getTile(c: number, r: number): number {
        if (c < 0 || c >= MAP_COLS || r < 0 || r >= MAP_ROWS) return TILE_TREE;
        return tiles[r * MAP_COLS + c];
    }

    // Border forest
    for (let c = 0; c < MAP_COLS; c++) { setTile(c, 0, TILE_TREE); setTile(c, MAP_ROWS - 1, TILE_TREE); }
    for (let r = 0; r < MAP_ROWS; r++) { setTile(0, r, TILE_TREE); setTile(MAP_COLS - 1, r, TILE_TREE); }

    // Water ponds
    for (let i = 0; i < 5; i++) {
        const cx = 6 + Math.floor(rnd() * (MAP_COLS - 12));
        const cy = 6 + Math.floor(rnd() * (MAP_ROWS - 12));
        const radius = 2 + Math.floor(rnd() * 3);
        for (let dr = -radius - 1; dr <= radius + 1; dr++) {
            for (let dc = -radius - 1; dc <= radius + 1; dc++) {
                const d = Math.sqrt(dc * dc + dr * dr);
                if (d <= radius) setTile(cx + dc, cy + dr, TILE_WATER);
                else if (d <= radius + 1 && getTile(cx + dc, cy + dr) === TILE_GRASS) setTile(cx + dc, cy + dr, TILE_SAND);
            }
        }
    }

    // Stone ruins
    for (let i = 0; i < 4; i++) {
        const cx = 4 + Math.floor(rnd() * (MAP_COLS - 10));
        const cy = 4 + Math.floor(rnd() * (MAP_ROWS - 10));
        const w = 3 + Math.floor(rnd() * 3);
        const h = 3 + Math.floor(rnd() * 3);
        for (let dy = 0; dy < h; dy++) {
            for (let dx = 0; dx < w; dx++) {
                const edge = dy === 0 || dy === h - 1 || dx === 0 || dx === w - 1;
                const gapBottom = dy === h - 1 && dx === Math.floor(w / 2);
                if (edge && !gapBottom && getTile(cx + dx, cy + dy) !== TILE_WATER) setTile(cx + dx, cy + dy, TILE_STONE);
            }
        }
    }

    // Scattered trees
    for (let i = 0; i < 180; i++) {
        const c = 2 + Math.floor(rnd() * (MAP_COLS - 4));
        const r = 2 + Math.floor(rnd() * (MAP_ROWS - 4));
        if (getTile(c, r) === TILE_GRASS) setTile(c, r, TILE_TREE);
    }

    // Meandering paths
    for (let i = 0; i < 3; i++) {
        let c = 2 + Math.floor(rnd() * (MAP_COLS - 4));
        let r = 2 + Math.floor(rnd() * (MAP_ROWS - 4));
        const length = 30 + Math.floor(rnd() * 40);
        for (let s = 0; s < length; s++) {
            const cur = getTile(c, r);
            if (cur === TILE_GRASS || cur === TILE_TREE) setTile(c, r, TILE_PATH);
            const dir = Math.floor(rnd() * 4);
            if (dir === 0) c++;
            else if (dir === 1) c--;
            else if (dir === 2) r++;
            else r--;
            c = Math.max(1, Math.min(MAP_COLS - 2, c));
            r = Math.max(1, Math.min(MAP_ROWS - 2, r));
        }
    }

    // Clear spawn area
    const playerSpawn: Vec2 = { x: MAP_WIDTH / 2, y: MAP_HEIGHT / 2 };
    const scx = Math.floor(playerSpawn.x / TILE_SIZE);
    const scy = Math.floor(playerSpawn.y / TILE_SIZE);
    for (let dr = -2; dr <= 2; dr++)
        for (let dc = -2; dc <= 2; dc++)
            setTile(scx + dc, scy + dr, TILE_GRASS);

    // Mob spawns
    const mobSpawns: MobSpawn[] = [];
    let attempts = 0;
    while (mobSpawns.length < 20 && attempts < 800) {
        attempts++;
        const c = 2 + Math.floor(rnd() * (MAP_COLS - 4));
        const r = 2 + Math.floor(rnd() * (MAP_ROWS - 4));
        const cur = getTile(c, r);
        if (cur !== TILE_GRASS && cur !== TILE_PATH) continue;
        const px = c * TILE_SIZE + TILE_SIZE / 2;
        const py = r * TILE_SIZE + TILE_SIZE / 2;
        const dx = px - playerSpawn.x;
        const dy = py - playerSpawn.y;
        const distToSpawn = Math.sqrt(dx * dx + dy * dy);
        if (distToSpawn < 160) continue;
        let tooClose = false;
        for (const s of mobSpawns) {
            const sdx = s.x - px;
            const sdy = s.y - py;
            if (Math.sqrt(sdx * sdx + sdy * sdy) < 140) { tooClose = true; break; }
        }
        if (tooClose) continue;
        mobSpawns.push({ x: px, y: py, type: distToSpawn > 500 ? "goblin" : "slime" });
    }

    return { tiles: tiles, mobSpawns: mobSpawns, playerSpawn: playerSpawn };
}

function isWalkableTile(id: number): boolean {
    for (const b of BLOCKED) if (b === id) return false;
    return true;
}

function isWalkableAt(tiles: number[], x: number, y: number): boolean {
    const col = Math.floor(x / TILE_SIZE);
    const row = Math.floor(y / TILE_SIZE);
    if (col < 0 || col >= MAP_COLS || row < 0 || row >= MAP_ROWS) return false;
    return isWalkableTile(tiles[row * MAP_COLS + col]);
}

const WORLD = generateWorld();

// ------------------------------------------------------------------ //
// Match state + config
// ------------------------------------------------------------------ //

const MATCH_MODULE = "world_match";
const MATCH_LABEL = "world";
const TICK_RATE = 10; // 10 Hz
const TICK_DT = 1 / TICK_RATE;

const OP_POSITIONS    = 1; // server → clients — player positions + hp
const OP_MOVE_INTENT  = 2; // client → server
const OP_MOBS         = 3; // server → clients — mob states
const OP_ATTACK       = 4; // client → server
const OP_HIT_FLASH    = 5; // server → clients — hit feedback
const OP_PLAYER_HIT   = 6; // server → clients — a player got hit

const PLAYER_HP_MAX = 100;
const PLAYER_ATTACK_DAMAGE = 10;
const PLAYER_ATTACK_RANGE = 48;
const PLAYER_ATTACK_COOLDOWN_MS = 450;

const MOB_TYPES: { [k: string]: { hpMax: number; touchDamage: number; speed: number; wanderRadius: number; touchRange: number; touchCooldownMs: number; respawnMs: number } } = {
    slime:  { hpMax: 30, touchDamage: 5,  speed: 40, wanderRadius: 80, touchRange: 26, touchCooldownMs: 900, respawnMs: 8000 },
    goblin: { hpMax: 60, touchDamage: 10, speed: 55, wanderRadius: 80, touchRange: 26, touchCooldownMs: 900, respawnMs: 8000 },
};

interface MatchPlayer {
    userId: string;
    sessionId: string;
    username: string;
    pos: Vec2;
    hp: number;
    dirty: boolean;
    lastAttackAt: number;
    lastTouchedByMob: { [mobId: string]: number };
}

interface MatchMob {
    id: string;
    type: string;
    home: Vec2;
    pos: Vec2;
    hp: number;
    hpMax: number;
    state: string; // "alive" | "dead"
    respawnAt: number;
    target: Vec2 | null;
    dirty: boolean;
}

interface WorldState {
    players: { [sessionId: string]: MatchPlayer };
    mobs: { [mobId: string]: MatchMob };
    tick: number;
}

function now(): number { return Date.now(); }

function spawnMob(id: string, spec: MobSpawn): MatchMob {
    const type = MOB_TYPES[spec.type] ? spec.type : "slime";
    const def = MOB_TYPES[type];
    return {
        id: id,
        type: type,
        home: { x: spec.x, y: spec.y },
        pos: { x: spec.x, y: spec.y },
        hp: def.hpMax,
        hpMax: def.hpMax,
        state: "alive",
        respawnAt: 0,
        target: null,
        dirty: true,
    };
}

// ------------------------------------------------------------------ //
// Match handlers
// ------------------------------------------------------------------ //

function matchInit(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _params: { [key: string]: string }): { state: WorldState; tickRate: number; label: string } {
    const mobs: { [id: string]: MatchMob } = {};
    for (let i = 0; i < WORLD.mobSpawns.length; i++) {
        const mobId = "m" + i;
        mobs[mobId] = spawnMob(mobId, WORLD.mobSpawns[i]);
    }
    const state: WorldState = { players: {}, mobs: mobs, tick: 0 };
    return { state: state, tickRate: TICK_RATE, label: MATCH_LABEL };
}

function matchJoinAttempt(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, _presence: nkruntime.Presence, _metadata: { [key: string]: any }): { state: WorldState; accept: boolean; rejectMessage?: string } {
    return { state: state, accept: true };
}

function matchJoin(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, presences: nkruntime.Presence[]): { state: WorldState } | null {
    for (let i = 0; i < presences.length; i++) {
        const p = presences[i];
        state.players[p.sessionId] = {
            userId: p.userId,
            sessionId: p.sessionId,
            username: p.username,
            pos: { x: WORLD.playerSpawn.x, y: WORLD.playerSpawn.y },
            hp: PLAYER_HP_MAX,
            dirty: true,
            lastAttackAt: 0,
            lastTouchedByMob: {},
        };
    }
    // Send full mob snapshot to newcomers.
    const mobsAll = snapshotMobs(state, true);
    if (mobsAll.length > 0) {
        dispatcher.broadcastMessage(OP_MOBS, JSON.stringify({ mobs: mobsAll, full: true }), presences);
    }
    return { state: state };
}

function matchLeave(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, presences: nkruntime.Presence[]): { state: WorldState } | null {
    for (let i = 0; i < presences.length; i++) {
        delete state.players[presences[i].sessionId];
    }
    return { state: state };
}

function snapshotMobs(state: WorldState, all: boolean): { id: string; t: string; x: number; y: number; hp: number; hpMax: number; st: string }[] {
    const out: { id: string; t: string; x: number; y: number; hp: number; hpMax: number; st: string }[] = [];
    const keys = Object.keys(state.mobs);
    for (let i = 0; i < keys.length; i++) {
        const m = state.mobs[keys[i]];
        if (!all && !m.dirty) continue;
        out.push({ id: m.id, t: m.type, x: m.pos.x, y: m.pos.y, hp: m.hp, hpMax: m.hpMax, st: m.state });
        m.dirty = false;
    }
    return out;
}

function matchLoop(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, tick: number, state: WorldState, messages: nkruntime.MatchMessage[]): { state: WorldState } | null {
    state.tick = tick;
    const t = now();

    // --- client → server messages ---
    for (let i = 0; i < messages.length; i++) {
        const msg = messages[i];
        const player = state.players[msg.sender.sessionId];
        if (!player) continue;

        if (msg.opCode === OP_MOVE_INTENT) {
            try {
                const body = JSON.parse(nk.binaryToString(msg.data)) as { x?: number; y?: number };
                const x = Number(body.x);
                const y = Number(body.y);
                if (!isFinite(x) || !isFinite(y)) continue;
                if (x < 0 || x > MAP_WIDTH || y < 0 || y > MAP_HEIGHT) continue;
                if (player.hp <= 0) continue;
                player.pos.x = x;
                player.pos.y = y;
                player.dirty = true;
            } catch (_e) {}
        } else if (msg.opCode === OP_ATTACK) {
            try {
                if (player.hp <= 0) continue;
                const body = JSON.parse(nk.binaryToString(msg.data)) as { mobId?: string };
                const mobId = String(body.mobId || "");
                const mob = state.mobs[mobId];
                if (!mob || mob.state !== "alive") continue;
                if (t - player.lastAttackAt < PLAYER_ATTACK_COOLDOWN_MS) continue;
                const dx = mob.pos.x - player.pos.x;
                const dy = mob.pos.y - player.pos.y;
                if (Math.sqrt(dx * dx + dy * dy) > PLAYER_ATTACK_RANGE) continue;
                player.lastAttackAt = t;
                mob.hp -= PLAYER_ATTACK_DAMAGE;
                mob.dirty = true;
                dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({ mobId: mobId }));
                if (mob.hp <= 0) {
                    mob.hp = 0;
                    mob.state = "dead";
                    mob.respawnAt = t + MOB_TYPES[mob.type].respawnMs;
                }
            } catch (_e) {}
        }
    }

    // --- mob AI + touch damage ---
    const mobKeys = Object.keys(state.mobs);
    for (let i = 0; i < mobKeys.length; i++) {
        const mob = state.mobs[mobKeys[i]];
        if (mob.state === "dead") {
            if (t >= mob.respawnAt) {
                mob.pos.x = mob.home.x;
                mob.pos.y = mob.home.y;
                mob.hp = mob.hpMax;
                mob.state = "alive";
                mob.target = null;
                mob.dirty = true;
            }
            continue;
        }

        const def = MOB_TYPES[mob.type];
        if (!mob.target || dist(mob.pos, mob.target) < 4) {
            const angle = Math.random() * Math.PI * 2;
            const r = Math.random() * def.wanderRadius;
            mob.target = {
                x: clamp(mob.home.x + Math.cos(angle) * r, 0, MAP_WIDTH - 1),
                y: clamp(mob.home.y + Math.sin(angle) * r, 0, MAP_HEIGHT - 1),
            };
        }
        const step = Math.min(dist(mob.pos, mob.target), def.speed * TICK_DT);
        if (step > 0.01) {
            const dx = mob.target.x - mob.pos.x;
            const dy = mob.target.y - mob.pos.y;
            const d = Math.sqrt(dx * dx + dy * dy) || 1;
            const nx = mob.pos.x + (dx / d) * step;
            const ny = mob.pos.y + (dy / d) * step;
            if (isWalkableAt(WORLD.tiles, nx, mob.pos.y)) mob.pos.x = nx;
            else mob.target = null;
            if (isWalkableAt(WORLD.tiles, mob.pos.x, ny)) mob.pos.y = ny;
            else mob.target = null;
            mob.dirty = true;
        }

        // Touch damage
        const playerKeys = Object.keys(state.players);
        for (let j = 0; j < playerKeys.length; j++) {
            const p = state.players[playerKeys[j]];
            if (p.hp <= 0) continue;
            const ddx = p.pos.x - mob.pos.x;
            const ddy = p.pos.y - mob.pos.y;
            const dd = Math.sqrt(ddx * ddx + ddy * ddy);
            if (dd > def.touchRange) continue;
            const last = p.lastTouchedByMob[mob.id] || 0;
            if (t - last < def.touchCooldownMs) continue;
            p.lastTouchedByMob[mob.id] = t;
            p.hp -= def.touchDamage;
            if (p.hp < 0) p.hp = 0;
            p.dirty = true;
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({ sessionId: p.sessionId, by: mob.id }));
            if (p.hp <= 0) {
                p.pos.x = WORLD.playerSpawn.x;
                p.pos.y = WORLD.playerSpawn.y;
                p.hp = PLAYER_HP_MAX;
                p.lastTouchedByMob = {};
            }
        }
    }

    // --- broadcast dirty players + mobs ---
    const pUpdates: { sid: string; uid: string; n: string; x: number; y: number; hp: number }[] = [];
    const pKeys = Object.keys(state.players);
    for (let i = 0; i < pKeys.length; i++) {
        const p = state.players[pKeys[i]];
        if (!p.dirty) continue;
        pUpdates.push({ sid: p.sessionId, uid: p.userId, n: p.username, x: p.pos.x, y: p.pos.y, hp: p.hp });
        p.dirty = false;
    }
    if (pUpdates.length > 0) {
        dispatcher.broadcastMessage(OP_POSITIONS, JSON.stringify({ players: pUpdates }));
    }

    const mUpdates = snapshotMobs(state, false);
    if (mUpdates.length > 0) {
        dispatcher.broadcastMessage(OP_MOBS, JSON.stringify({ mobs: mUpdates, full: false }));
    }

    return { state: state };
}

function dist(a: Vec2, b: Vec2): number {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return Math.sqrt(dx * dx + dy * dy);
}

function clamp(v: number, lo: number, hi: number): number {
    return v < lo ? lo : v > hi ? hi : v;
}

function matchTerminate(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, _graceSeconds: number): { state: WorldState } | null {
    return { state: state };
}

function matchSignal(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, _data: string): { state: WorldState; data?: string } | null {
    return { state: state };
}

// ------------------------------------------------------------------ //
// RPC: find or create the world match
// ------------------------------------------------------------------ //

function rpcGetWorldMatch(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, _payload: string): string {
    const existing = nk.matchList(1, true, MATCH_LABEL);
    if (existing.length > 0) {
        return JSON.stringify({ match_id: existing[0].matchId });
    }
    const matchId = nk.matchCreate(MATCH_MODULE, {});
    return JSON.stringify({ match_id: matchId });
}

function InitModule(_ctx: nkruntime.Context, logger: nkruntime.Logger, _nk: nkruntime.Nakama, initializer: nkruntime.Initializer): void {
    initializer.registerMatch(MATCH_MODULE, {
        matchInit: matchInit,
        matchJoinAttempt: matchJoinAttempt,
        matchJoin: matchJoin,
        matchLeave: matchLeave,
        matchLoop: matchLoop,
        matchTerminate: matchTerminate,
        matchSignal: matchSignal,
    });
    initializer.registerRpc("get_world_match", rpcGetWorldMatch);
    logger.info("GG runtime loaded. mobs=" + WORLD.mobSpawns.length);
}

// Satisfy noUnusedLocals.
!InitModule && InitModule;
