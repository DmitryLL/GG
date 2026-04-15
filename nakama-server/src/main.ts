// Nakama runtime entry. Single file — every top-level `function` is hoisted
// into goja's global scope so Nakama can discover `InitModule` by name.

// ================================================================== //
// World generation — mirrors godot/scripts/world_data.gd so the server
// can reason about walkability and place authoritative mob spawns.
// ================================================================== //

const TILE_SIZE = BALANCE_DATA.world.tileSize;
const MAP_COLS = BALANCE_DATA.world.mapCols;
const MAP_ROWS = BALANCE_DATA.world.mapRows;
const MAP_WIDTH = TILE_SIZE * MAP_COLS;
const MAP_HEIGHT = TILE_SIZE * MAP_ROWS;
const WORLD_SEED = BALANCE_DATA.world.seed;

const TILE_GRASS = 0;
const TILE_SAND  = 1;
const TILE_WATER = 2;
const TILE_TREE  = 3;
const TILE_STONE = 4;
const TILE_PATH  = 5;
const BLOCKED = [TILE_WATER, TILE_TREE, TILE_STONE];

interface Vec2 { x: number; y: number; }
interface MobSpawn { x: number; y: number; type: string; }
interface GenResult { tiles: number[]; mobSpawns: MobSpawn[]; playerSpawn: Vec2; }

function loadTiledWorld(): GenResult {
    // Tiled gid'ы 1-based, наш firstgid=1 → tile_id = gid - 1.
    const tilesRaw = (WORLD_MAP_DATA.layers as any[]).find((l) => l.name === "Tiles");
    const tiles = (tilesRaw.data as number[]).map((g) => Math.max(0, g - 1));

    const mobsLayer = (WORLD_MAP_DATA.layers as any[]).find((l) => l.name === "Mobs");
    const mobSpawns: MobSpawn[] = ((mobsLayer && mobsLayer.objects) || []).map((o: any) => ({
        x: o.x + (o.width || TILE_SIZE) / 2,
        y: o.y + (o.height || TILE_SIZE) / 2,
        type: String(o.type || "slime"),
    }));

    const npcLayer = (WORLD_MAP_DATA.layers as any[]).find((l) => l.name === "NPCs");
    let playerSpawn: Vec2 = { x: MAP_WIDTH / 2, y: MAP_HEIGHT / 2 };
    if (npcLayer && npcLayer.objects) {
        for (const o of npcLayer.objects as any[]) {
            if (o.type === "spawn" || o.name === "player_spawn") {
                playerSpawn = {
                    x: o.x + (o.width || TILE_SIZE) / 2,
                    y: o.y + (o.height || TILE_SIZE) / 2,
                };
                break;
            }
        }
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

const WORLD = loadTiledWorld();

// ================================================================== //
// Items, drop tables, mobs, NPCs
// ================================================================== //

// Все игровые данные приходят из data/*.json через scripts/gen-data.js.
// Здесь только удобные алиасы и старые имена, чтобы не править остальной код.
type ItemKind = "material" | "weapon" | "armor" | "consumable";
interface ItemDef extends ItemDefData { id: string; kind: ItemKind; }
const ITEMS: { [id: string]: ItemDef } = (() => {
    const out: { [id: string]: ItemDef } = {};
    for (const id of Object.keys(ITEMS_DATA)) {
        out[id] = { id: id, ...ITEMS_DATA[id], kind: ITEMS_DATA[id].kind as ItemKind };
    }
    return out;
})();

const INVENTORY_SLOTS = BALANCE_DATA.inventory.slots;
const STACK_MAX = BALANCE_DATA.inventory.stackMax;

const MOB_TYPES = MOBS_DATA;
const DROP_TABLES: { [mob: string]: DropEntryData[] } = (() => {
    const out: { [mob: string]: DropEntryData[] } = {};
    for (const k of Object.keys(DROPS_DATA)) out[k] = DROPS_DATA[k].table;
    return out;
})();
const DROP_MISS_WEIGHT: { [mob: string]: number } = (() => {
    const out: { [mob: string]: number } = {};
    for (const k of Object.keys(DROPS_DATA)) out[k] = DROPS_DATA[k].missWeight;
    return out;
})();

const NPCS = NPCS_DATA;
const NPC_INTERACT_RANGE = BALANCE_DATA.npc.interactRange;

// ================================================================== //
// Player / match state
// ================================================================== //

const MATCH_MODULE = "world_match";
const MATCH_LABEL = "world";
const TICK_RATE = 10;
const TICK_DT = 1 / TICK_RATE;

const OP_POSITIONS    = 1; // server → clients — positions + hp + xp + gold
const OP_MOVE_INTENT  = 2; // client → server
const OP_MOBS         = 3;
const OP_ATTACK       = 4;
const OP_HIT_FLASH    = 5;
const OP_PLAYER_HIT   = 6;
const OP_DROPS        = 7; // drops state
const OP_ME           = 8; // full local view (inventory + equipment) direct to recipient
const OP_EQUIP        = 9; // client → server
const OP_UNEQUIP      = 10;
const OP_USE          = 11;
const OP_BUY          = 12;
const OP_SELL         = 13;
const OP_NPCS         = 14; // one-shot on join — static NPC list
const OP_ARROW        = 15; // server → clients, visualise a bow shot
const OP_CHAT_SEND    = 16; // client → server, chat line
const OP_CHAT_RELAY   = 17; // server → clients, broadcast chat line
const OP_LOOT_TAKE    = 18; // client → server { mobId, index } — забрать конкретный предмет с трупа
const OP_LOOT_TAKE_ALL = 19; // client → server { mobId } — забрать всё что влезет

const PLAYER_HP_BASE = BALANCE_DATA.player.hpBase;
const PLAYER_ATTACK_DAMAGE = BALANCE_DATA.player.attackDamage;
const PLAYER_ATTACK_RANGE = BALANCE_DATA.player.attackRange;
const PLAYER_ATTACK_COOLDOWN_MS = BALANCE_DATA.player.attackCooldownMs;
const PER_LEVEL_HP_BONUS = BALANCE_DATA.player.perLevelHpBonus;
const PER_LEVEL_DAMAGE_BONUS = BALANCE_DATA.player.perLevelDamageBonus;
const XP_BASE = BALANCE_DATA.xp.base;
const XP_FOR_LEVEL = (L: number): number => XP_BASE * L;
const PICKUP_RANGE = BALANCE_DATA.drops.pickupRange;
const DROP_LIFETIME_MS = BALANCE_DATA.drops.lifetimeMs;

interface InvEntry { itemId: string; qty: number; }

interface MatchPlayer {
    userId: string;
    sessionId: string;
    username: string;
    presence: nkruntime.Presence;
    pos: Vec2;
    hp: number;
    hpMax: number;
    level: number;
    xp: number;
    gold: number;
    inventory: InvEntry[];
    equipment: { [slot: string]: string };
    dirtyPos: boolean;
    dirtyMe: boolean;
    lastAttackAt: number;
    lastTouchedByMob: { [mobId: string]: number };
}

const EQUIP_SLOTS = ["head", "body", "weapon", "boots", "belt", "ring1", "ring2", "cloak", "amulet"];

function targetSlotFor(itemId: string, equipment: { [slot: string]: string }): string | null {
    const def = ITEMS[itemId];
    if (!def || !(def as any).slot) return null;
    const slot = String((def as any).slot);
    if (slot === "ring") {
        if (!equipment.ring1) return "ring1";
        if (!equipment.ring2) return "ring2";
        return "ring1"; // оба заняты — заменяем первое
    }
    return slot;
}

interface MatchMob {
    id: string;
    type: string;
    home: Vec2;
    pos: Vec2;
    hp: number;
    hpMax: number;
    state: string;
    respawnAt: number;
    target: Vec2 | null;
    loot: InvEntry[];
    dirty: boolean;
}

interface WorldState {
    players: { [sessionId: string]: MatchPlayer };
    mobs: { [mobId: string]: MatchMob };
    tick: number;
}

function now(): number { return Date.now(); }
function dist(a: Vec2, b: Vec2): number { const dx = a.x - b.x; const dy = a.y - b.y; return Math.sqrt(dx * dx + dy * dy); }
function clamp(v: number, lo: number, hi: number): number { return v < lo ? lo : v > hi ? hi : v; }

function playerBaseHp(level: number): number { return PLAYER_HP_BASE + PER_LEVEL_HP_BONUS * (level - 1); }
function playerBaseDamage(level: number): number { return PLAYER_ATTACK_DAMAGE + PER_LEVEL_DAMAGE_BONUS * (level - 1); }

function computeHpMax(p: MatchPlayer): number {
    let total = playerBaseHp(p.level);
    for (const slot of EQUIP_SLOTS) {
        const id = p.equipment[slot];
        if (!id) continue;
        const def = ITEMS[id];
        if (def && def.hp) total += def.hp;
    }
    return total;
}
function computeDamage(p: MatchPlayer): number {
    let total = playerBaseDamage(p.level);
    for (const slot of EQUIP_SLOTS) {
        const id = p.equipment[slot];
        if (!id) continue;
        const def = ITEMS[id];
        if (def && def.damage) total += def.damage;
    }
    return total;
}
function markMe(p: MatchPlayer): void { p.dirtyMe = true; }

function addToInventory(p: MatchPlayer, itemId: string, qty: number): boolean {
    const def = ITEMS[itemId];
    if (!def) return false;
    const stackable = def.kind === "material" || def.kind === "consumable";
    if (stackable) {
        for (const slot of p.inventory) {
            if (slot.itemId === itemId && slot.qty < STACK_MAX) {
                const space = STACK_MAX - slot.qty;
                const take = Math.min(space, qty);
                slot.qty += take;
                qty -= take;
                if (qty <= 0) { markMe(p); return true; }
            }
        }
    }
    while (qty > 0 && p.inventory.length < INVENTORY_SLOTS) {
        const take = stackable ? Math.min(STACK_MAX, qty) : 1;
        p.inventory.push({ itemId: itemId, qty: take });
        qty -= take;
    }
    markMe(p);
    return qty === 0;
}

function spawnMob(id: string, spec: MobSpawn): MatchMob {
    const type = MOB_TYPES[spec.type] ? spec.type : "slime";
    const def = MOB_TYPES[type];
    return {
        id: id, type: type,
        home: { x: spec.x, y: spec.y },
        pos: { x: spec.x, y: spec.y },
        hp: def.hpMax, hpMax: def.hpMax,
        state: "alive", respawnAt: 0, target: null, loot: rollMobLoot(type), dirty: true,
    };
}

function rollMobLoot(mobType: string): InvEntry[] {
    // 90% шанс что у моба вообще есть лут. Если есть — 1..3 ролла.
    if (Math.random() >= 0.9) return [];
    const loot: InvEntry[] = [];
    const rollCount = 1 + Math.floor(Math.random() * 3);
    for (let n = 0; n < rollCount; n++) {
        const drop = rollDrop(mobType);
        if (!drop) continue;
        const di = ITEMS[drop];
        const stackable = di && (di.kind === "material" || di.kind === "consumable");
        let merged = false;
        if (stackable) {
            for (const e of loot) {
                if (e.itemId === drop) { e.qty += 1; merged = true; break; }
            }
        }
        if (!merged) loot.push({ itemId: drop, qty: 1 });
    }
    return loot;
}

function rollDrop(mobType: string): string | null {
    const table = DROP_TABLES[mobType];
    if (!table) return null;
    const missWeight = DROP_MISS_WEIGHT[mobType] || 0;
    let total = missWeight;
    for (const e of table) total += e.weight;
    let r = Math.random() * total;
    for (const e of table) {
        if (r < e.weight) return e.itemId;
        r -= e.weight;
    }
    return null;
}

// ---------- persistence via Nakama storage ----------
const STORAGE_COLLECTION = "gg";
const STORAGE_KEY = "progress";

interface StoredProgress {
    level: number;
    xp: number;
    gold: number;
    inventory: InvEntry[];
    equipment?: { [slot: string]: string };
    // legacy
    eqWeapon?: string;
    eqArmor?: string;
}

function loadProgress(nk: nkruntime.Nakama, userId: string): StoredProgress | null {
    try {
        const objs = nk.storageRead([{ collection: STORAGE_COLLECTION, key: STORAGE_KEY, userId: userId }]);
        if (objs.length === 0) return null;
        return objs[0].value as StoredProgress;
    } catch (_e) {
        return null;
    }
}

function saveProgress(nk: nkruntime.Nakama, p: MatchPlayer): void {
    try {
        const payload: StoredProgress = {
            level: p.level, xp: p.xp, gold: p.gold,
            inventory: p.inventory, equipment: p.equipment,
        };
        nk.storageWrite([{
            collection: STORAGE_COLLECTION,
            key: STORAGE_KEY,
            userId: p.userId,
            value: payload as unknown as { [k: string]: any },
            permissionRead: 1,
            permissionWrite: 0,
        }]);
    } catch (_e) { /* swallow */ }
}

// ================================================================== //
// Match handlers
// ================================================================== //

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

function matchJoin(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, presences: nkruntime.Presence[]): { state: WorldState } | null {
    for (let i = 0; i < presences.length; i++) {
        const p = presences[i];
        const saved = loadProgress(nk, p.userId);
        const equipment: { [slot: string]: string } = {};
        for (const s of EQUIP_SLOTS) equipment[s] = "";
        if (saved && saved.equipment) {
            for (const s of EQUIP_SLOTS) {
                if (saved.equipment[s]) equipment[s] = saved.equipment[s];
            }
        } else if (saved) {
            // миграция со старого формата (eqWeapon / eqArmor → weapon/body)
            if (saved.eqWeapon) equipment.weapon = saved.eqWeapon;
            if (saved.eqArmor) equipment.body = saved.eqArmor;
        }
        const player: MatchPlayer = {
            userId: p.userId, sessionId: p.sessionId, username: p.username,
            presence: p,
            pos: { x: WORLD.playerSpawn.x, y: WORLD.playerSpawn.y },
            hp: 0, hpMax: 0,
            level: saved ? saved.level : 1,
            xp: saved ? saved.xp : 0,
            gold: saved ? saved.gold : 0,
            inventory: saved ? saved.inventory : [],
            equipment: equipment,
            dirtyPos: true, dirtyMe: true,
            lastAttackAt: 0,
            lastTouchedByMob: {},
        };
        player.hpMax = computeHpMax(player);
        player.hp = player.hpMax;
        state.players[p.sessionId] = player;

        // Send one-shot snapshots to the newcomer.
        const prices: { [id: string]: { buy: number | null; sell: number | null } } = {};
        for (const id of Object.keys(ITEMS)) {
            const def = ITEMS[id];
            prices[id] = { buy: def.price || null, sell: def.sellPrice || null };
        }
        dispatcher.broadcastMessage(OP_NPCS, JSON.stringify({ npcs: NPCS, prices: prices }), [p]);
        const mobsAll = snapshotMobsAll(state);
        dispatcher.broadcastMessage(OP_MOBS, JSON.stringify({ mobs: mobsAll, full: true }), [p]);
    }
    return { state: state };
}

function matchLeave(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, presences: nkruntime.Presence[]): { state: WorldState } | null {
    for (let i = 0; i < presences.length; i++) {
        const p = state.players[presences[i].sessionId];
        if (p) saveProgress(nk, p);
        delete state.players[presences[i].sessionId];
    }
    return { state: state };
}

function mobSnap(m: MatchMob) {
    return {
        id: m.id, t: m.type,
        x: m.pos.x, y: m.pos.y,
        hp: m.hp, hpMax: m.hpMax,
        st: m.state,
        loot: m.loot,
    };
}

function snapshotMobsAll(state: WorldState) {
    const out: ReturnType<typeof mobSnap>[] = [];
    const keys = Object.keys(state.mobs);
    for (let i = 0; i < keys.length; i++) {
        const m = state.mobs[keys[i]];
        out.push(mobSnap(m));
        m.dirty = false;
    }
    return out;
}

function snapshotMobsDirty(state: WorldState) {
    const out: ReturnType<typeof mobSnap>[] = [];
    const keys = Object.keys(state.mobs);
    for (let i = 0; i < keys.length; i++) {
        const m = state.mobs[keys[i]];
        if (!m.dirty) continue;
        out.push(mobSnap(m));
        m.dirty = false;
    }
    return out;
}

function broadcastMeTo(dispatcher: nkruntime.MatchDispatcher, p: MatchPlayer, presences: nkruntime.Presence[]): void {
    const payload = {
        hp: p.hp, hpMax: p.hpMax,
        level: p.level, xp: p.xp, xpNeed: XP_FOR_LEVEL(p.level),
        gold: p.gold,
        damage: computeDamage(p),
        inv: p.inventory,
        eq: p.equipment,
    };
    dispatcher.broadcastMessage(OP_ME, JSON.stringify(payload), presences);
}

function grantXp(p: MatchPlayer, amount: number): void {
    p.xp += amount;
    while (p.xp >= XP_FOR_LEVEL(p.level)) {
        p.xp -= XP_FOR_LEVEL(p.level);
        p.level += 1;
        p.hpMax = computeHpMax(p);
        p.hp = p.hpMax;
    }
    markMe(p);
}


function matchLoop(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, tick: number, state: WorldState, messages: nkruntime.MatchMessage[]): { state: WorldState } | null {
    state.tick = tick;
    const t = now();

    // --- client → server ---
    for (let i = 0; i < messages.length; i++) {
        const msg = messages[i];
        const player = state.players[msg.sender.sessionId];
        if (!player) continue;

        switch (msg.opCode) {
            case OP_MOVE_INTENT: {
                try {
                    if (player.hp <= 0) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { x?: number; y?: number };
                    const x = Number(body.x); const y = Number(body.y);
                    if (!isFinite(x) || !isFinite(y)) break;
                    if (x < 0 || x > MAP_WIDTH || y < 0 || y > MAP_HEIGHT) break;
                    player.pos.x = x; player.pos.y = y;
                    player.dirtyPos = true;
                } catch (_e) {}
                break;
            }
            case OP_ATTACK: {
                try {
                    if (player.hp <= 0) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { mobId?: string };
                    const mobId = String(body.mobId || "");
                    const mob = state.mobs[mobId];
                    if (!mob || mob.state !== "alive") break;
                    if (t - player.lastAttackAt < PLAYER_ATTACK_COOLDOWN_MS) break;
                    if (dist(mob.pos, player.pos) > PLAYER_ATTACK_RANGE) break;
                    player.lastAttackAt = t;
                    mob.hp -= computeDamage(player);
                    mob.dirty = true;
                    dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                        fx: player.pos.x, fy: player.pos.y,
                        tx: mob.pos.x, ty: mob.pos.y,
                    }));
                    dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({ mobId: mobId }));
                    if (mob.hp <= 0) {
                        mob.hp = 0; mob.state = "dead";
                        mob.respawnAt = t + MOB_TYPES[mob.type].respawnMs;
                        const def = MOB_TYPES[mob.type];
                        grantXp(player, def.xp);
                        player.gold += def.gold;
                        // Лут был пред-ролльнут на спавне (см. rollMobLoot).
                        // На трупе остаётся то, что уже лежит в mob.loot.
                    }
                } catch (_e) {}
                break;
            }
            case OP_EQUIP: {
                try {
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { slot?: number };
                    const idx = Number(body.slot);
                    if (!isFinite(idx) || idx < 0 || idx >= player.inventory.length) break;
                    const entry = player.inventory[idx];
                    const target = targetSlotFor(entry.itemId, player.equipment);
                    if (!target) break;
                    const prev = player.equipment[target];
                    player.equipment[target] = entry.itemId;
                    entry.qty -= 1;
                    if (entry.qty <= 0) player.inventory.splice(idx, 1);
                    if (prev) addToInventory(player, prev, 1);
                    player.hpMax = computeHpMax(player);
                    if (player.hp > player.hpMax) player.hp = player.hpMax;
                    markMe(player);
                } catch (_e) {}
                break;
            }
            case OP_UNEQUIP: {
                try {
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { slot?: string };
                    const slot = String(body.slot || "");
                    if (EQUIP_SLOTS.indexOf(slot) < 0) break;
                    const id = player.equipment[slot];
                    if (!id) break;
                    if (!addToInventory(player, id, 1)) break;
                    player.equipment[slot] = "";
                    player.hpMax = computeHpMax(player);
                    if (player.hp > player.hpMax) player.hp = player.hpMax;
                    markMe(player);
                } catch (_e) {}
                break;
            }
            case OP_USE: {
                try {
                    if (player.hp <= 0) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { slot?: number };
                    const idx = Number(body.slot);
                    if (!isFinite(idx) || idx < 0 || idx >= player.inventory.length) break;
                    const entry = player.inventory[idx];
                    const def = ITEMS[entry.itemId];
                    if (!def || def.kind !== "consumable") break;
                    if (def.heal) player.hp = Math.min(player.hpMax, player.hp + def.heal);
                    entry.qty -= 1;
                    if (entry.qty <= 0) player.inventory.splice(idx, 1);
                    markMe(player);
                } catch (_e) {}
                break;
            }
            case OP_BUY: {
                try {
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { npcId?: string; itemId?: string };
                    const npc = NPCS.find(n => n.id === body.npcId);
                    if (!npc) break;
                    if (dist(player.pos, { x: npc.x, y: npc.y }) > NPC_INTERACT_RANGE) break;
                    const itemId = String(body.itemId || "");
                    if (npc.stock.indexOf(itemId) < 0) break;
                    const def = ITEMS[itemId];
                    if (!def || !def.price) break;
                    if (player.gold < def.price) break;
                    if (!addToInventory(player, itemId, 1)) break;
                    player.gold -= def.price;
                    markMe(player);
                } catch (_e) {}
                break;
            }
            case OP_LOOT_TAKE: {
                try {
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { mobId?: string; index?: number };
                    const mob = state.mobs[String(body.mobId || "")];
                    if (!mob || mob.state !== "dead") break;
                    if (dist(player.pos, mob.pos) > PICKUP_RANGE) break;
                    const idx = Number(body.index);
                    if (!isFinite(idx) || idx < 0 || idx >= mob.loot.length) break;
                    const entry = mob.loot[idx];
                    if (!addToInventory(player, entry.itemId, entry.qty)) break;
                    mob.loot.splice(idx, 1);
                    mob.dirty = true;
                } catch (_e) {}
                break;
            }
            case OP_LOOT_TAKE_ALL: {
                try {
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { mobId?: string };
                    const mob = state.mobs[String(body.mobId || "")];
                    if (!mob || mob.state !== "dead") break;
                    if (dist(player.pos, mob.pos) > PICKUP_RANGE) break;
                    for (let li = mob.loot.length - 1; li >= 0; li--) {
                        const entry = mob.loot[li];
                        if (addToInventory(player, entry.itemId, entry.qty)) {
                            mob.loot.splice(li, 1);
                            mob.dirty = true;
                        }
                    }
                } catch (_e) {}
                break;
            }
            case OP_CHAT_SEND: {
                try {
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { text?: string };
                    const text = String(body.text || "").slice(0, 140).trim();
                    if (text.length === 0) break;
                    dispatcher.broadcastMessage(OP_CHAT_RELAY, JSON.stringify({
                        sid: player.sessionId,
                        uid: player.userId,
                        n: player.username,
                        t: text,
                        ts: t,
                    }));
                } catch (_e) {}
                break;
            }
            case OP_SELL: {
                try {
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { slot?: number };
                    const idx = Number(body.slot);
                    if (!isFinite(idx) || idx < 0 || idx >= player.inventory.length) break;
                    let near = false;
                    for (const npc of NPCS) {
                        if (dist(player.pos, { x: npc.x, y: npc.y }) <= NPC_INTERACT_RANGE) { near = true; break; }
                    }
                    if (!near) break;
                    const entry = player.inventory[idx];
                    const def = ITEMS[entry.itemId];
                    if (!def || !def.sellPrice) break;
                    player.gold += def.sellPrice;
                    entry.qty -= 1;
                    if (entry.qty <= 0) player.inventory.splice(idx, 1);
                    markMe(player);
                } catch (_e) {}
                break;
            }
        }
    }

    // --- mob AI + touch damage ---
    const mobKeys = Object.keys(state.mobs);
    for (let i = 0; i < mobKeys.length; i++) {
        const mob = state.mobs[mobKeys[i]];
        if (mob.state === "dead") {
            if (t >= mob.respawnAt) {
                mob.pos.x = mob.home.x; mob.pos.y = mob.home.y;
                mob.hp = mob.hpMax; mob.state = "alive";
                mob.target = null; mob.loot = rollMobLoot(mob.type); mob.dirty = true;
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
            const dx = mob.target.x - mob.pos.x; const dy = mob.target.y - mob.pos.y;
            const d = Math.sqrt(dx * dx + dy * dy) || 1;
            const nx = mob.pos.x + (dx / d) * step;
            const ny = mob.pos.y + (dy / d) * step;
            if (isWalkableAt(WORLD.tiles, nx, mob.pos.y)) mob.pos.x = nx; else mob.target = null;
            if (isWalkableAt(WORLD.tiles, mob.pos.x, ny)) mob.pos.y = ny; else mob.target = null;
            mob.dirty = true;
        }

        const playerKeys = Object.keys(state.players);
        for (let j = 0; j < playerKeys.length; j++) {
            const p = state.players[playerKeys[j]];
            if (p.hp <= 0) continue;
            if (dist(p.pos, mob.pos) > def.touchRange) continue;
            const last = p.lastTouchedByMob[mob.id] || 0;
            if (t - last < def.touchCooldownMs) continue;
            p.lastTouchedByMob[mob.id] = t;
            p.hp -= def.touchDamage;
            if (p.hp < 0) p.hp = 0;
            p.dirtyPos = true; markMe(p);
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({ sessionId: p.sessionId, by: mob.id }));
            if (p.hp <= 0) {
                p.pos.x = WORLD.playerSpawn.x; p.pos.y = WORLD.playerSpawn.y;
                p.hp = p.hpMax;
                p.lastTouchedByMob = {};
            }
        }
    }

    // --- broadcasts ---
    const pUpdates: { sid: string; uid: string; n: string; x: number; y: number; hp: number; lv: number }[] = [];
    const pKeys = Object.keys(state.players);
    for (let i = 0; i < pKeys.length; i++) {
        const p = state.players[pKeys[i]];
        if (!p.dirtyPos) continue;
        pUpdates.push({ sid: p.sessionId, uid: p.userId, n: p.username, x: p.pos.x, y: p.pos.y, hp: p.hp, lv: p.level });
        p.dirtyPos = false;
    }
    if (pUpdates.length > 0) {
        dispatcher.broadcastMessage(OP_POSITIONS, JSON.stringify({ players: pUpdates }));
    }

    // direct "me" updates
    for (let i = 0; i < pKeys.length; i++) {
        const p = state.players[pKeys[i]];
        if (!p.dirtyMe) continue;
        broadcastMeTo(dispatcher, p, [p.presence]);
        p.dirtyMe = false;
    }

    const mUpdates = snapshotMobsDirty(state);
    if (mUpdates.length > 0) {
        dispatcher.broadcastMessage(OP_MOBS, JSON.stringify({ mobs: mUpdates, full: false }));
    }

    return { state: state };
}

function matchTerminate(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, _graceSeconds: number): { state: WorldState } | null {
    // Persist all players before shutting down.
    const keys = Object.keys(state.players);
    for (let i = 0; i < keys.length; i++) saveProgress(nk, state.players[keys[i]]);
    return { state: state };
}

function matchSignal(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, _data: string): { state: WorldState; data?: string } | null {
    return { state: state };
}

function rpcGetWorldMatch(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, _payload: string): string {
    const existing = nk.matchList(1, true, MATCH_LABEL);
    if (existing.length > 0) return JSON.stringify({ match_id: existing[0].matchId });
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
    logger.info("GG runtime loaded. mobs=" + WORLD.mobSpawns.length + " npcs=" + NPCS.length);
}

!InitModule && InitModule;
