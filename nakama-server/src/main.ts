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
const MATCH_LABEL_PREFIX = "world_";    // label = "world_<zoneId>"
const DEFAULT_ZONE = "village";
const KNOWN_ZONES = ["village", "forest", "dungeon"]; // можно расширять
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
const OP_SKILL        = 20; // client → server { skill, mobId?, x?, y? }
const OP_SKILL_FX     = 21; // server → clients, visual effect for skill
const OP_SKILL_REJECT = 22; // server → caster, скилл отвергнут (сбросить локальный cd)
const OP_TILE_UPDATE  = 23; // admin edit: client→server {c,r,id}; server→clients broadcast
const OP_MAP_SAVE     = 24; // admin: client→server — запись tiles+mobs в Nakama Storage
const OP_MAP_FULL     = 25; // server→client at join: весь массив tiles, если карта редактировалась
const OP_MOB_ADD      = 26; // admin: client→server {type, x, y}
const OP_MOB_MOVE     = 27; // admin: client→server {mobId, x, y}
const OP_MOB_DEL      = 28; // admin: client→server {mobId}
const OP_TILE_RECT    = 29; // admin: {c1,r1,c2,r2,id} — заливка прямоугольника
const OP_MAP_HISTORY  = 30; // admin: client→server пусто; server→client {list:[{ts,size}]}
const OP_MAP_SNAPSHOT = 31; // admin: client→server пусто → создать версию
const OP_MAP_ROLLBACK = 32; // admin: client→server {ts} → восстановить
const OP_EDITOR_CURSOR = 33; // admin: client→server {x,y}; server→others {sid,name,x,y}
const OP_OBJ_ADD       = 34; // admin: client→server {kind, x, y, data}
const OP_OBJ_DEL       = 35; // admin: client→server {id}
const OP_OBJS          = 36; // server→client: {objects: MapObject[], full: bool} — snapshot/delta
const OP_OBJ_INTERACT  = 37; // client→server {id} — игрок кликнул на объект (сундук etc.)
const OP_ZONE_SWITCH   = 38; // server→client {zone, matchId, x, y} — клиент переподключается

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
    moveTarget: Vec2 | null;  // server-authoritative движение (текущий waypoint)
    movePath: Vec2[];         // очередь waypoints (A* путь); шагает по одному
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
    skillCd: { [skill: number]: number };  // ms timestamp when cooldown ends
    invulnUntil: number;
    atkSpeedBoostUntil: number;
    preciseShotReady: boolean;
    effects: PlayerEffect[];
    archerMods: { [skillId: string]: string };  // выбранные модификации скиллов лучника
}

const PLAYER_SPEED = 100; // px/sec — должна совпадать с Godot Player.SPEED

interface ActiveZone {
    id: string;
    kind: "arrow_rain";
    x: number; y: number; radius: number;
    nextTickAt: number;
    endAt: number;
    ownerSid: string;
}

interface MobDebuff {
    poisonStacks: number;
    poisonEndAt: number;
    slowEndAt: number;
    nextPoisonTickAt: number;
    poisonDmg: number;  // per-stack per-tick урон яда (считается от baseDmg в момент касtа)
}

interface PlayerEffect {
    id: string;
    kind: "buff" | "debuff";
    type: string;       // "heal" | "poison" | ...
    endAt: number;
    nextTickAt?: number;
    stacks?: number;
    damage?: number;    // per-tick damage (poison)
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
    debuff?: MobDebuff;
    stunUntil?: number;  // ms timestamp; пока t<stunUntil моб оглушён (не двигается, не атакует)
}

// Универсальная сущность карты: портал, сундук, спавн-зона, (позже NPC).
interface MapObject {
    id: string;
    kind: string;       // "portal" | "chest" | "spawn"
    x: number;
    y: number;
    data: any;          // portal: {tx, ty, label?}
                        // chest: {loot: InvEntry[], respawnMs, nextRespawnAt?, opened?}
                        // spawn: {mobType, radius, maxCount}
}

interface WorldState {
    players: { [sessionId: string]: MatchPlayer };
    mobs: { [mobId: string]: MatchMob };
    zones: ActiveZone[];
    tick: number;
    tiles: number[];                                // runtime-изменяемая копия карты (редактор, live-sync)
    objects: { [id: string]: MapObject };           // порталы, сундуки и т.п.
    portalCooldowns: { [sessionId: string]: number }; // антидребезг телепорта (server-ms)
    zoneId: string;                                 // "village" | "forest" | "dungeon"
}

function currentTiles(state: WorldState): number[] {
    return state.tiles && state.tiles.length > 0 ? state.tiles : WORLD.tiles;
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

function killMob(mob: MatchMob, player: MatchPlayer, t: number): void {
    mob.hp = 0; mob.state = "dead";
    mob.respawnAt = t + MOB_TYPES[mob.type].respawnMs;
    mob.debuff = undefined;
    const def = MOB_TYPES[mob.type];
    grantXp(player, def.xp);
    player.gold += def.gold;
    markMe(player);
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
// Archer class: выбор модификаций скиллов.
// Источник истины — godot/data/skills_archer.json (клиент).
// На сервере держим канонический список для валидации.
// ================================================================== //

const ARCHER_MODS_COLLECTION = "gg_archer_mods";
const ARCHER_MODS_KEY = "archer";
const ARCHER_POINTS_BUDGET = 5;

// Синхронизировать с godot/data/skills_archer.json при изменении.
const ARCHER_MOD_COSTS: { [skillId: number]: { [modId: string]: number } } = {
    1: { "stun": 1, "fire": 2 },
    2: { "root": 1, "dispel": 2 },
    3: { "empowered_attack": 1, "sprint": 2 },
    4: { "slow": 1, "final_stun": 2 },
    5: { "party_crit": 1, "penetration": 2 },
};

interface StoredArcherMods {
    // ключ — skillId как строка (JSON совместимость), значение — modId
    selected: { [skillId: string]: string };
}

function loadArcherMods(nk: nkruntime.Nakama, userId: string): StoredArcherMods {
    try {
        const objs = nk.storageRead([{ collection: ARCHER_MODS_COLLECTION, key: ARCHER_MODS_KEY, userId: userId }]);
        if (objs.length === 0) return { selected: {} };
        const v = objs[0].value as StoredArcherMods;
        return { selected: (v && v.selected) ? v.selected : {} };
    } catch (_e) {
        return { selected: {} };
    }
}

function saveArcherMods(nk: nkruntime.Nakama, userId: string, selected: { [k: string]: string }): void {
    nk.storageWrite([{
        collection: ARCHER_MODS_COLLECTION,
        key: ARCHER_MODS_KEY,
        userId: userId,
        value: { selected } as unknown as { [k: string]: any },
        permissionRead: 1,
        permissionWrite: 0,
    }]);
}

// Валидация входящего выбора мод: неизвестные id отсеиваются, бюджет проверяется.
function sanitizeArcherMods(selected: { [k: string]: any }): { ok: boolean; cleaned: { [k: string]: string }; cost: number; reason?: string } {
    const cleaned: { [k: string]: string } = {};
    let cost = 0;
    for (const k of Object.keys(selected || {})) {
        const skillId = parseInt(k);
        if (isNaN(skillId)) continue;
        const mods = ARCHER_MOD_COSTS[skillId];
        if (!mods) continue;
        const modId = String(selected[k] || "");
        const c = mods[modId];
        if (c == null) continue;
        cleaned[String(skillId)] = modId;
        cost += c;
    }
    if (cost > ARCHER_POINTS_BUDGET) {
        return { ok: false, cleaned: {}, cost, reason: "budget_exceeded" };
    }
    return { ok: true, cleaned, cost };
}

// ================================================================== //
// Match handlers
// ================================================================== //

const MAP_STORAGE_COLLECTION = "gg_world";
const MAP_STORAGE_USER = "00000000-0000-0000-0000-000000000000"; // global

function zoneKey(zoneId: string): string {
    // Для village оставлен старый ключ "tiles" (backward-compat со старыми сохранениями).
    return zoneId === DEFAULT_ZONE ? "tiles" : ("tiles_" + zoneId);
}

function loadMapFromStorage(nk: nkruntime.Nakama, zoneId: string): number[] | null {
    try {
        const res = nk.storageRead([{
            collection: MAP_STORAGE_COLLECTION,
            key: zoneKey(zoneId),
            userId: MAP_STORAGE_USER,
        }]);
        if (res && res.length > 0 && res[0].value && Array.isArray((res[0].value as any).tiles)) {
            const arr = (res[0].value as any).tiles as number[];
            if (arr.length === MAP_COLS * MAP_ROWS) return arr.slice();
        }
    } catch (_e) {}
    return null;
}

function saveMapToStorage(nk: nkruntime.Nakama, zoneId: string, tiles: number[], mobs: { [id: string]: MatchMob }, objects: { [id: string]: MapObject }): void {
    const mobSpawns: MobSpawn[] = [];
    for (const k of Object.keys(mobs)) {
        const m = mobs[k];
        mobSpawns.push({ x: m.home.x, y: m.home.y, type: m.type });
    }
    const objList: MapObject[] = [];
    for (const k of Object.keys(objects)) objList.push(objects[k]);
    nk.storageWrite([{
        collection: MAP_STORAGE_COLLECTION,
        key: zoneKey(zoneId),
        userId: MAP_STORAGE_USER,
        value: { tiles: tiles, mobs: mobSpawns, objects: objList, savedAt: Date.now() },
        version: "",
        permissionRead: 2,
        permissionWrite: 1,
    }]);
}

// История версий: отдельные storage-записи с ключами "snap_<timestamp>".
// Ограничиваем число: после создания новой подрезаем до последних N.
const MAP_SNAPSHOT_LIMIT = 20;
const MAP_SNAPSHOT_PREFIX = "snap_";

function snapKey(zoneId: string, ts: number): string { return MAP_SNAPSHOT_PREFIX + zoneId + "_" + ts; }
function snapZonePrefix(zoneId: string): string { return MAP_SNAPSHOT_PREFIX + zoneId + "_"; }

function createMapSnapshot(nk: nkruntime.Nakama, zoneId: string, tiles: number[], mobs: { [id: string]: MatchMob }, objects: { [id: string]: MapObject }): number {
    const ts = Date.now();
    const mobSpawns: MobSpawn[] = [];
    for (const k of Object.keys(mobs)) {
        const m = mobs[k];
        mobSpawns.push({ x: m.home.x, y: m.home.y, type: m.type });
    }
    const objList: MapObject[] = [];
    for (const k of Object.keys(objects)) objList.push(objects[k]);
    nk.storageWrite([{
        collection: MAP_STORAGE_COLLECTION,
        key: snapKey(zoneId, ts),
        userId: MAP_STORAGE_USER,
        value: { tiles: tiles, mobs: mobSpawns, objects: objList, savedAt: ts, zone: zoneId },
        version: "",
        permissionRead: 2,
        permissionWrite: 1,
    }]);
    // Подрезать старые снапшоты этой зоны.
    try {
        const list = nk.storageList(MAP_STORAGE_USER, MAP_STORAGE_COLLECTION, 200);
        const prefix = snapZonePrefix(zoneId);
        const snaps = (list.objects || []).filter(o => o.key.indexOf(prefix) === 0);
        snaps.sort((a, b) => a.key < b.key ? 1 : -1); // новые первыми
        if (snaps.length > MAP_SNAPSHOT_LIMIT) {
            const toDel = snaps.slice(MAP_SNAPSHOT_LIMIT).map(o => ({
                collection: MAP_STORAGE_COLLECTION,
                key: o.key,
                userId: MAP_STORAGE_USER,
            }));
            nk.storageDelete(toDel);
        }
    } catch (_e) {}
    return ts;
}

function listMapSnapshots(nk: nkruntime.Nakama, zoneId: string): { ts: number; key: string }[] {
    try {
        const list = nk.storageList(MAP_STORAGE_USER, MAP_STORAGE_COLLECTION, 200);
        const prefix = snapZonePrefix(zoneId);
        const snaps = (list.objects || []).filter(o => o.key.indexOf(prefix) === 0);
        const out: { ts: number; key: string }[] = [];
        for (const o of snaps) {
            const ts = parseInt(o.key.substring(prefix.length), 10);
            if (isFinite(ts)) out.push({ ts: ts, key: o.key });
        }
        out.sort((a, b) => b.ts - a.ts);
        return out;
    } catch (_e) { return []; }
}

function loadMapSnapshot(nk: nkruntime.Nakama, zoneId: string, ts: number): { tiles: number[]; mobs: MobSpawn[]; objects: MapObject[] } | null {
    try {
        const res = nk.storageRead([{
            collection: MAP_STORAGE_COLLECTION,
            key: snapKey(zoneId, ts),
            userId: MAP_STORAGE_USER,
        }]);
        if (res && res.length > 0 && res[0].value) {
            const v = res[0].value as any;
            const tiles = Array.isArray(v.tiles) ? v.tiles as number[] : null;
            const mobs = Array.isArray(v.mobs) ? v.mobs as MobSpawn[] : [];
            const objects = Array.isArray(v.objects) ? v.objects as MapObject[] : [];
            if (tiles && tiles.length === MAP_COLS * MAP_ROWS) {
                return { tiles: tiles, mobs: mobs, objects: objects };
            }
        }
    } catch (_e) {}
    return null;
}

function loadMobsFromStorage(nk: nkruntime.Nakama, zoneId: string): MobSpawn[] | null {
    try {
        const res = nk.storageRead([{
            collection: MAP_STORAGE_COLLECTION,
            key: zoneKey(zoneId),
            userId: MAP_STORAGE_USER,
        }]);
        if (res && res.length > 0 && res[0].value && Array.isArray((res[0].value as any).mobs)) {
            return (res[0].value as any).mobs as MobSpawn[];
        }
    } catch (_e) {}
    return null;
}

// Одноразовая миграция: удаляем аккаунты старых админов (dmitryll/admin/prod/etc.)
// после смены whitelist на новых админов. Идемпотентно: флаг в storage.
function runAdminCleanupMigration(nk: nkruntime.Nakama, logger: nkruntime.Logger): void {
    const FLAG_COLLECTION = "_system";
    const FLAG_KEY = "admin_cleanup_v1";
    try {
        const existing = nk.storageRead([{
            collection: FLAG_COLLECTION, key: FLAG_KEY, userId: MAP_STORAGE_USER,
        }]);
        if (existing && existing.length > 0 && existing[0].value && (existing[0].value as any).done) return;
    } catch (_e) {}
    const oldAdmins = ["dmitryll", "admin", "prod", "Dmitryll", "Admin", "Prod", "DmitryLL"];
    try {
        const users = nk.usersGetUsername(oldAdmins);
        for (const u of users || []) {
            try {
                nk.accountDeleteId(u.userId, true);
                logger.info("Deleted old admin account: %s", u.username);
            } catch (_e) {}
        }
    } catch (_e) {}
    try {
        nk.storageWrite([{
            collection: FLAG_COLLECTION, key: FLAG_KEY, userId: MAP_STORAGE_USER,
            value: { done: true, ranAt: Date.now() }, version: "",
            permissionRead: 2, permissionWrite: 0,
        }]);
    } catch (_e) {}
}

function matchInit(_ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, params: { [key: string]: string }): { state: WorldState; tickRate: number; label: string } {
    runAdminCleanupMigration(nk, logger);
    let zoneId = String((params && params.zone) || DEFAULT_ZONE);
    if (KNOWN_ZONES.indexOf(zoneId) < 0) zoneId = DEFAULT_ZONE;
    // Village = исходная карта (WORLD). Остальные зоны стартуют пустыми (чистая трава).
    const isVillage = (zoneId === DEFAULT_ZONE);
    const defaultTiles = isVillage ? WORLD.tiles.slice() : new Array(MAP_COLS * MAP_ROWS).fill(0) as number[];
    const defaultMobs: MobSpawn[] = isVillage ? WORLD.mobSpawns : [];

    const savedMobs = loadMobsFromStorage(nk, zoneId);
    const mobSpawns = savedMobs ? savedMobs : defaultMobs;
    const mobs: { [id: string]: MatchMob } = {};
    for (let i = 0; i < mobSpawns.length; i++) {
        const mobId = "m" + i;
        mobs[mobId] = spawnMob(mobId, mobSpawns[i]);
    }
    const savedTiles = loadMapFromStorage(nk, zoneId);
    const tiles = savedTiles ? savedTiles : defaultTiles;
    const savedObjects = loadObjectsFromStorage(nk, zoneId);
    const objects: { [id: string]: MapObject } = {};
    if (savedObjects) {
        for (let i = 0; i < savedObjects.length; i++) {
            objects[savedObjects[i].id] = savedObjects[i];
        }
    }
    const state: WorldState = {
        players: {}, mobs: mobs, zones: [], tick: 0, tiles: tiles,
        objects: objects, portalCooldowns: {}, zoneId: zoneId,
    };
    return { state: state, tickRate: TICK_RATE, label: MATCH_LABEL_PREFIX + zoneId };
}

function loadObjectsFromStorage(nk: nkruntime.Nakama, zoneId: string): MapObject[] | null {
    try {
        const res = nk.storageRead([{
            collection: MAP_STORAGE_COLLECTION,
            key: zoneKey(zoneId),
            userId: MAP_STORAGE_USER,
        }]);
        if (res && res.length > 0 && res[0].value && Array.isArray((res[0].value as any).objects)) {
            return (res[0].value as any).objects as MapObject[];
        }
    } catch (_e) {}
    return null;
}

function matchJoinAttempt(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, _presence: nkruntime.Presence, _metadata: { [key: string]: any }): { state: WorldState; accept: boolean; rejectMessage?: string } {
    return { state: state, accept: true };
}

function matchJoin(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, presences: nkruntime.Presence[]): { state: WorldState } | null {
    for (let i = 0; i < presences.length; i++) {
        const p = presences[i];
        // Single session: если этот userId уже играет с другой сессии — кикнуть старую.
        for (const oldSid of Object.keys(state.players)) {
            const old = state.players[oldSid];
            if (old.userId === p.userId && old.sessionId !== p.sessionId) {
                // Сохранить прогресс старой сессии перед kick
                saveProgress(nk, old);
                dispatcher.matchKick([old.presence]);
                delete state.players[oldSid];
            }
        }
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
            skillCd: {},
            invulnUntil: 0,
            atkSpeedBoostUntil: 0,
            preciseShotReady: false,
            effects: [],
            moveTarget: null,
            movePath: [],
            archerMods: loadArcherMods(nk, p.userId).selected,
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
        // Если карта правилась в рантайме — сразу отдаём полный массив тайлов.
        if (state.tiles) {
            dispatcher.broadcastMessage(OP_MAP_FULL, JSON.stringify({ tiles: state.tiles }), [p]);
        }
        // Объекты карты (порталы, сундуки).
        const objList: MapObject[] = [];
        for (const ok of Object.keys(state.objects)) objList.push(state.objects[ok]);
        dispatcher.broadcastMessage(OP_OBJS, JSON.stringify({ objects: objList, full: true }), [p]);
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
        debuff: m.debuff || null,
        now: Date.now(),
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
        effects: p.effects || [],
        skillCd: p.skillCd || {},
        t: now(),
    };
    dispatcher.broadcastMessage(OP_ME, JSON.stringify(payload), presences);
}

function applyPlayerEffect(p: MatchPlayer, eff: PlayerEffect): void {
    if (!p.effects) p.effects = [];
    let existing: PlayerEffect | null = null;
    for (let i = 0; i < p.effects.length; i++) {
        if (p.effects[i].type === eff.type) { existing = p.effects[i]; break; }
    }
    if (existing) {
        existing.endAt = Math.max(existing.endAt, eff.endAt);
        if (eff.stacks) existing.stacks = Math.min(3, (existing.stacks || 0) + eff.stacks);
        if (eff.nextTickAt !== undefined) existing.nextTickAt = eff.nextTickAt;
        if (eff.damage !== undefined) existing.damage = eff.damage;
    } else {
        p.effects.push({
            id: eff.id,
            kind: eff.kind,
            type: eff.type,
            endAt: eff.endAt,
            nextTickAt: eff.nextTickAt,
            stacks: eff.stacks,
            damage: eff.damage,
        });
    }
    markMe(p);
}

function tickPlayerEffects(p: MatchPlayer, t: number): void {
    if (!p.effects || p.effects.length === 0) return;
    let changed = false;
    for (let i = p.effects.length - 1; i >= 0; i--) {
        const eff = p.effects[i];
        if (t >= eff.endAt) {
            p.effects.splice(i, 1);
            changed = true;
            continue;
        }
        if (eff.type === "poison" && eff.nextTickAt !== undefined && t >= eff.nextTickAt) {
            const dmg = (eff.damage || 3) * (eff.stacks || 1);
            p.hp = Math.max(0, p.hp - dmg);
            eff.nextTickAt = t + 1000;
            changed = true;
        }
    }
    if (changed) markMe(p);
}

const MAX_LEVEL = 20;

function grantXp(p: MatchPlayer, amount: number): void {
    if (p.level >= MAX_LEVEL) {
        p.xp = 0;  // на капе XP не копится
        markMe(p);
        return;
    }
    p.xp += amount;
    while (p.xp >= XP_FOR_LEVEL(p.level) && p.level < MAX_LEVEL) {
        p.xp -= XP_FOR_LEVEL(p.level);
        p.level += 1;
        p.hpMax = computeHpMax(p);
        p.hp = p.hpMax;
    }
    if (p.level >= MAX_LEVEL) p.xp = 0;
    markMe(p);
}


function matchLoop(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, tick: number, state: WorldState, messages: nkruntime.MatchMessage[]): { state: WorldState } | null {
    state.tick = tick;
    const t = now();

    // Автосохранение прогресса каждых 200 тиков (~10s при tickRate=20)
    // Защита от потери инвентаря/золота/уровня при крэше/рестарте сервера.
    if (tick % 200 === 0 && tick > 0) {
        const pk = Object.keys(state.players);
        for (let i = 0; i < pk.length; i++) saveProgress(nk, state.players[pk[i]]);
    }

    // --- client → server ---
    for (let i = 0; i < messages.length; i++) {
        const msg = messages[i];
        const player = state.players[msg.sender.sessionId];
        if (!player) continue;

        switch (msg.opCode) {
            case OP_MOVE_INTENT: {
                try {
                    if (player.hp <= 0) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { x?: number; y?: number; path?: { x: number; y: number }[] };
                    // Вариант 1: клиент прислал полный путь A* как массив waypoints.
                    if (Array.isArray(body.path) && body.path.length > 0) {
                        const path: Vec2[] = [];
                        // Защита от мусора: не более 200 точек, все в пределах карты.
                        for (let i = 0; i < body.path.length && i < 200; i++) {
                            const p = body.path[i];
                            const px = Number(p.x), py = Number(p.y);
                            if (!isFinite(px) || !isFinite(py)) continue;
                            if (px < 0 || px > MAP_WIDTH || py < 0 || py > MAP_HEIGHT) continue;
                            path.push({ x: px, y: py });
                        }
                        if (path.length > 0) {
                            player.movePath = path;
                            player.moveTarget = path.shift() || null;
                        }
                        break;
                    }
                    // Вариант 2: одиночная точка (совместимость).
                    const x = Number(body.x); const y = Number(body.y);
                    if (!isFinite(x) || !isFinite(y)) break;
                    if (x < 0 || x > MAP_WIDTH || y < 0 || y > MAP_HEIGHT) break;
                    player.moveTarget = { x, y };
                    player.movePath = [];
                } catch (_e) {}
                break;
            }
            case OP_ATTACK: {
                try {
                    if (player.hp <= 0) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { mobId?: string; sid?: string };
                    const atkCd = t < player.atkSpeedBoostUntil ? PLAYER_ATTACK_COOLDOWN_MS * 0.5 : PLAYER_ATTACK_COOLDOWN_MS;
                    if (t - player.lastAttackAt < atkCd) break;
                    const hasBow = (player.equipment.weapon || "").includes("bow");
                    const atkRange = hasBow ? PLAYER_ATTACK_RANGE : 36;

                    // PvP: атакуем другого игрока
                    if (body.sid && body.sid !== player.sessionId) {
                        const foe = state.players[body.sid];
                        if (!foe || foe.hp <= 0) break;
                        if (dist(foe.pos, player.pos) > atkRange) break;
                        if (t < foe.invulnUntil) break;
                        player.lastAttackAt = t;
                        const dmgP = computeDamage(player);
                        foe.hp -= dmgP;
                        if (foe.hp < 0) foe.hp = 0;
                        foe.dirtyPos = true;
                        markMe(foe);
                        dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                            fx: player.pos.x, fy: player.pos.y,
                            tx: foe.pos.x, ty: foe.pos.y,
                            melee: !hasBow,
                        }));
                        dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({ sessionId: foe.sessionId, by: player.sessionId, dmg: dmgP }));
                        if (foe.hp <= 0) {
                            foe.pos.x = WORLD.playerSpawn.x; foe.pos.y = WORLD.playerSpawn.y;
                            foe.hp = foe.hpMax;
                            foe.lastTouchedByMob = {};
                            foe.dirtyPos = true;
                            markMe(foe);
                        }
                        break;
                    }

                    const mobId = String(body.mobId || "");
                    const mob = state.mobs[mobId];
                    if (!mob || mob.state !== "alive") break;
                    if (dist(mob.pos, player.pos) > atkRange) break;
                    player.lastAttackAt = t;
                    const dmg = computeDamage(player);
                    mob.hp -= dmg;
                    mob.dirty = true;
                    dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                        fx: player.pos.x, fy: player.pos.y,
                        tx: mob.pos.x, ty: mob.pos.y,
                        melee: !hasBow,
                    }));
                    dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({ mobId: mobId, dmg: dmg }));
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
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { slot?: number; target?: string };
                    const idx = Number(body.slot);
                    if (!isFinite(idx) || idx < 0 || idx >= player.inventory.length) break;
                    const entry = player.inventory[idx];
                    const want = body.target ? String(body.target) : "";
                    let target: string | null = null;
                    if (want) {
                        // Клиент просит конкретный слот — проверяем совместимость.
                        const def = ITEMS[entry.itemId] as any;
                        const itemSlot = def ? String(def.slot || "") : "";
                        const ok = !!itemSlot && (
                            itemSlot === want ||
                            (itemSlot === "ring" && (want === "ring1" || want === "ring2"))
                        );
                        if (ok && EQUIP_SLOTS.indexOf(want) >= 0) target = want;
                    } else {
                        target = targetSlotFor(entry.itemId, player.equipment);
                    }
                    if (!target) break;
                    // Класс «Лучник»: в слот weapon только луки.
                    if (target === "weapon" && !entry.itemId.includes("bow")) break;
                    const prev = player.equipment[target];
                    player.equipment[target] = entry.itemId;
                    entry.qty -= 1;
                    if (entry.qty <= 0) player.inventory.splice(idx, 1);
                    if (prev) addToInventory(player, prev, 1);
                    player.hpMax = computeHpMax(player);
                    if (player.hp > player.hpMax) player.hp = player.hpMax;
                    player.dirtyPos = true;
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
                    player.dirtyPos = true;
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
                    if (def.heal) {
                        player.hp = Math.min(player.hpMax, player.hp + def.heal);
                        applyPlayerEffect(player, {
                            id: "heal_" + now(),
                            kind: "buff",
                            type: "heal",
                            endAt: now() + 2500,
                        });
                    }
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
            case OP_SKILL: {
                try {
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { skill?: number; mobId?: string; x?: number; y?: number };
                    const skill = Number(body.skill);
                    const spec = SKILLS[skill];
                    if (!spec) {
                        dispatcher.broadcastMessage(OP_SKILL_REJECT, JSON.stringify({ skill }), [player.presence]);
                        break;
                    }
                    const cdEnd = player.skillCd[skill] || 0;
                    if (t < cdEnd) {
                        dispatcher.broadcastMessage(OP_SKILL_REJECT, JSON.stringify({ skill, reason: "cooldown" }), [player.presence]);
                        break;
                    }
                    const hasBow = (player.equipment.weapon || "").includes("bow");
                    if (spec.requiresBow && !hasBow) {
                        dispatcher.broadcastMessage(OP_SKILL_REJECT, JSON.stringify({ skill, reason: "no_bow" }), [player.presence]);
                        break;
                    }
                    const baseDmg = computeDamage(player);
                    const cdBefore = player.skillCd[skill] || 0;
                    spec.handler({ player, body, t, state, dispatcher, baseDmg });
                    // Если handler не поставил cooldown — значит скилл не сработал
                    // (например, цель не в зоне, мобид невалидный)
                    if ((player.skillCd[skill] || 0) === cdBefore) {
                        dispatcher.broadcastMessage(OP_SKILL_REJECT, JSON.stringify({ skill, reason: "out_of_range" }), [player.presence]);
                    }
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
            case OP_TILE_UPDATE: {
                try {
                    if (!isAdminName(player.username)) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { c?: number; r?: number; id?: number };
                    const c = Number(body.c), r = Number(body.r), id = Number(body.id);
                    if (!isFinite(c) || !isFinite(r) || !isFinite(id)) break;
                    if (c < 0 || c >= MAP_COLS || r < 0 || r >= MAP_ROWS) break;
                    if (id < 0 || id > 5) break;
                    state.tiles[r * MAP_COLS + c] = id;
                    dispatcher.broadcastMessage(OP_TILE_UPDATE, JSON.stringify({ c, r, id }));
                } catch (_e) {}
                break;
            }
            case OP_MAP_SAVE: {
                try {
                    if (!isAdminName(player.username)) break;
                    saveMapToStorage(nk, state.zoneId, state.tiles, state.mobs, state.objects);
                } catch (_e) {}
                break;
            }
            case OP_MOB_ADD: {
                try {
                    if (!isAdminName(player.username)) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { type?: string; x?: number; y?: number };
                    const type = String(body.type || "slime");
                    if (!MOB_TYPES[type]) break;
                    const x = Number(body.x), y = Number(body.y);
                    if (!isFinite(x) || !isFinite(y)) break;
                    if (x < 0 || y < 0 || x > MAP_COLS * TILE_SIZE || y > MAP_ROWS * TILE_SIZE) break;
                    const newId = "m_" + state.tick + "_" + Math.floor(Math.random() * 1000);
                    state.mobs[newId] = spawnMob(newId, { x: x, y: y, type: type });
                    dispatcher.broadcastMessage(OP_MOBS, JSON.stringify({ mobs: [mobSnap(state.mobs[newId])], full: false }));
                } catch (_e) {}
                break;
            }
            case OP_MOB_MOVE: {
                try {
                    if (!isAdminName(player.username)) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { mobId?: string; x?: number; y?: number };
                    const mobId = String(body.mobId || "");
                    const mob = state.mobs[mobId];
                    if (!mob) break;
                    const x = Number(body.x), y = Number(body.y);
                    if (!isFinite(x) || !isFinite(y)) break;
                    if (x < 0 || y < 0 || x > MAP_COLS * TILE_SIZE || y > MAP_ROWS * TILE_SIZE) break;
                    mob.home.x = x; mob.home.y = y;
                    mob.pos.x = x; mob.pos.y = y;
                    mob.target = null;
                    mob.dirty = true;
                    dispatcher.broadcastMessage(OP_MOBS, JSON.stringify({ mobs: [mobSnap(mob)], full: false }));
                } catch (_e) {}
                break;
            }
            case OP_MOB_DEL: {
                try {
                    if (!isAdminName(player.username)) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { mobId?: string };
                    const mobId = String(body.mobId || "");
                    if (!state.mobs[mobId]) break;
                    delete state.mobs[mobId];
                    dispatcher.broadcastMessage(OP_MOBS, JSON.stringify({ mobs: [{ id: mobId, removed: true }], full: false }));
                } catch (_e) {}
                break;
            }
            case OP_TILE_RECT: {
                try {
                    if (!isAdminName(player.username)) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { c1?: number; r1?: number; c2?: number; r2?: number; id?: number };
                    let c1 = Number(body.c1), r1 = Number(body.r1), c2 = Number(body.c2), r2 = Number(body.r2);
                    const id = Number(body.id);
                    if (!isFinite(c1) || !isFinite(r1) || !isFinite(c2) || !isFinite(r2) || !isFinite(id)) break;
                    if (id < 0 || id > 5) break;
                    if (c1 > c2) { const t = c1; c1 = c2; c2 = t; }
                    if (r1 > r2) { const t = r1; r1 = r2; r2 = t; }
                    c1 = Math.max(0, Math.min(MAP_COLS - 1, c1));
                    c2 = Math.max(0, Math.min(MAP_COLS - 1, c2));
                    r1 = Math.max(0, Math.min(MAP_ROWS - 1, r1));
                    r2 = Math.max(0, Math.min(MAP_ROWS - 1, r2));
                    // Защита от огромных заливок — максимум 5000 клеток за раз.
                    const area = (c2 - c1 + 1) * (r2 - r1 + 1);
                    if (area > 5000) break;
                    for (let r = r1; r <= r2; r++) {
                        for (let c = c1; c <= c2; c++) {
                            state.tiles[r * MAP_COLS + c] = id;
                        }
                    }
                    dispatcher.broadcastMessage(OP_TILE_RECT, JSON.stringify({ c1, r1, c2, r2, id }));
                } catch (_e) {}
                break;
            }
            case OP_MAP_SNAPSHOT: {
                try {
                    if (!isAdminName(player.username)) break;
                    const ts = createMapSnapshot(nk, state.zoneId, state.tiles, state.mobs, state.objects);
                    dispatcher.broadcastMessage(OP_MAP_SNAPSHOT, JSON.stringify({ ts: ts }), [player.presence]);
                } catch (_e) {}
                break;
            }
            case OP_MAP_HISTORY: {
                try {
                    if (!isAdminName(player.username)) break;
                    const snaps = listMapSnapshots(nk, state.zoneId);
                    dispatcher.broadcastMessage(OP_MAP_HISTORY, JSON.stringify({ list: snaps }), [player.presence]);
                } catch (_e) {}
                break;
            }
            case OP_MAP_ROLLBACK: {
                try {
                    if (!isAdminName(player.username)) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { ts?: number };
                    const ts = Number(body.ts);
                    if (!isFinite(ts)) break;
                    const snap = loadMapSnapshot(nk, state.zoneId, ts);
                    if (!snap) break;
                    // Применить тайлы.
                    for (let i = 0; i < snap.tiles.length && i < state.tiles.length; i++) {
                        state.tiles[i] = snap.tiles[i];
                    }
                    // Перезалить мобов: удаляем всех, заспавнить из snapshot.
                    for (const mk of Object.keys(state.mobs)) delete state.mobs[mk];
                    for (let i = 0; i < snap.mobs.length; i++) {
                        const mid = "s_" + ts + "_" + i;
                        state.mobs[mid] = spawnMob(mid, snap.mobs[i]);
                    }
                    // Перезалить объекты карты.
                    for (const ok of Object.keys(state.objects)) delete state.objects[ok];
                    for (const o of snap.objects) state.objects[o.id] = o;
                    // Broadcast: полный набор тайлов + всех мобов + всех объектов.
                    dispatcher.broadcastMessage(OP_MAP_FULL, JSON.stringify({ tiles: state.tiles }));
                    dispatcher.broadcastMessage(OP_MOBS, JSON.stringify({ mobs: snapshotMobsAll(state), full: true }));
                    dispatcher.broadcastMessage(OP_OBJS, JSON.stringify({ objects: snap.objects, full: true }));
                } catch (_e) {}
                break;
            }
            case OP_OBJ_ADD: {
                try {
                    if (!isAdminName(player.username)) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { kind?: string; x?: number; y?: number; data?: any };
                    const kind = String(body.kind || "");
                    if (kind !== "portal" && kind !== "chest" && kind !== "spawn") break;
                    const x = Number(body.x), y = Number(body.y);
                    if (!isFinite(x) || !isFinite(y)) break;
                    if (x < 0 || y < 0 || x > MAP_COLS * TILE_SIZE || y > MAP_ROWS * TILE_SIZE) break;
                    const objId = kind.substring(0, 3) + "_" + state.tick + "_" + Math.floor(Math.random() * 1000);
                    const obj: MapObject = { id: objId, kind: kind, x: x, y: y, data: body.data || {} };
                    state.objects[objId] = obj;
                    dispatcher.broadcastMessage(OP_OBJS, JSON.stringify({ objects: [obj], full: false }));
                } catch (_e) {}
                break;
            }
            case OP_OBJ_DEL: {
                try {
                    if (!isAdminName(player.username)) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { id?: string };
                    const id = String(body.id || "");
                    if (!state.objects[id]) break;
                    delete state.objects[id];
                    dispatcher.broadcastMessage(OP_OBJS, JSON.stringify({ objects: [{ id: id, removed: true }], full: false }));
                } catch (_e) {}
                break;
            }
            case OP_OBJ_INTERACT: {
                try {
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { id?: string };
                    const id = String(body.id || "");
                    const obj = state.objects[id];
                    if (!obj) break;
                    // Игрок должен быть рядом.
                    if (dist(player.pos, { x: obj.x, y: obj.y }) > 60) break;
                    if (obj.kind === "chest") {
                        const data = obj.data || {};
                        if (data.opened && Number(data.nextRespawnAt || 0) > t) break;
                        // Перекинуть loot в инвентарь игрока.
                        const loot: InvEntry[] = Array.isArray(data.loot) ? data.loot as InvEntry[] : [];
                        for (const e of loot) addToInventory(player, e.itemId, e.qty);
                        data.opened = true;
                        data.nextRespawnAt = t + (Number(data.respawnMs) || 60000);
                        obj.data = data;
                        markMe(player);
                        dispatcher.broadcastMessage(OP_OBJS, JSON.stringify({ objects: [obj], full: false }));
                    }
                } catch (_e) {}
                break;
            }
            case OP_EDITOR_CURSOR: {
                try {
                    if (!isAdminName(player.username)) break;
                    const body = JSON.parse(nk.binaryToString(msg.data)) as { x?: number; y?: number };
                    const x = Number(body.x), y = Number(body.y);
                    if (!isFinite(x) || !isFinite(y)) break;
                    // Шлём всем остальным админам. Находим их список.
                    const targets: nkruntime.Presence[] = [];
                    for (const sk of Object.keys(state.players)) {
                        const sp = state.players[sk];
                        if (sp.sessionId === player.sessionId) continue;
                        if (!isAdminName(sp.username)) continue;
                        targets.push(sp.presence);
                    }
                    if (targets.length > 0) {
                        dispatcher.broadcastMessage(OP_EDITOR_CURSOR, JSON.stringify({
                            sid: player.sessionId, name: player.username, x: x, y: y,
                        }), targets);
                    }
                } catch (_e) {}
                break;
            }
        }
    }

    // --- active zones (arrow rain) ---
    for (let zi = state.zones.length - 1; zi >= 0; zi--) {
        const z = state.zones[zi];
        if (t >= z.endAt) { state.zones.splice(zi, 1); continue; }
        if (t < z.nextTickAt) continue;
        z.nextTickAt = t + 400;
        const owner = state.players[z.ownerSid];
        const ownerDmg = owner ? Math.floor(computeDamage(owner) * 0.45) : 3;
        for (const mk of Object.keys(state.mobs)) {
            const m = state.mobs[mk];
            if (m.state !== "alive") continue;
            if (Math.abs(m.pos.x - z.x) > z.radius || Math.abs(m.pos.y - z.y) > z.radius) continue;
            m.hp -= ownerDmg;
            m.dirty = true;
            dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({ mobId: m.id, dmg: ownerDmg }));
            if (m.hp <= 0 && owner) killMob(m, owner, t);
        }
        // PvP: бьём чужих игроков в зоне (исключая владельца)
        for (const sk of Object.keys(state.players)) {
            const tp = state.players[sk];
            if (tp.sessionId === z.ownerSid || tp.hp <= 0) continue;
            if (t < tp.invulnUntil) continue;
            if (Math.abs(tp.pos.x - z.x) > z.radius || Math.abs(tp.pos.y - z.y) > z.radius) continue;
            tp.hp -= ownerDmg;
            if (tp.hp < 0) tp.hp = 0;
            tp.dirtyPos = true;
            markMe(tp);
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({
                sessionId: tp.sessionId, by: z.ownerSid, dmg: ownerDmg,
            }));
            if (tp.hp <= 0) {
                tp.pos.x = WORLD.playerSpawn.x; tp.pos.y = WORLD.playerSpawn.y;
                tp.hp = tp.hpMax; tp.lastTouchedByMob = {};
                tp.dirtyPos = true; markMe(tp);
            }
        }
    }

    // --- player status effects (buffs/debuffs ticking) ---
    for (const sk of Object.keys(state.players)) {
        const pl = state.players[sk];
        if (pl.hp <= 0) continue;
        tickPlayerEffects(pl, t);
        if (pl.hp <= 0) {
            pl.pos.x = WORLD.playerSpawn.x; pl.pos.y = WORLD.playerSpawn.y;
            pl.hp = pl.hpMax; pl.lastTouchedByMob = {};
            pl.effects = [];
            pl.moveTarget = null; pl.movePath = [];
            pl.dirtyPos = true; markMe(pl);
        }
    }

    // --- server-authoritative player movement ---
    // Клиент шлёт moveTarget или путь A* (movePath). Сервер шагает от waypoint
    // к waypoint с PLAYER_SPEED. Axis-separated collision страхует от застревания.
    for (const sk of Object.keys(state.players)) {
        const pl = state.players[sk];
        if (pl.hp <= 0 || !pl.moveTarget) continue;
        let stepLeft = PLAYER_SPEED * TICK_DT;
        // Крутим цикл пока не израсходуем все шаги или не кончится путь —
        // чтобы на тике можно было перейти через несколько коротких waypoint-ов.
        while (stepLeft > 0 && pl.moveTarget) {
            const dx = pl.moveTarget.x - pl.pos.x;
            const dy = pl.moveTarget.y - pl.pos.y;
            const distTarget = Math.sqrt(dx * dx + dy * dy);
            if (distTarget <= stepLeft) {
                if (isWalkableAt(currentTiles(state), pl.moveTarget.x, pl.moveTarget.y)) {
                    pl.pos.x = pl.moveTarget.x;
                    pl.pos.y = pl.moveTarget.y;
                }
                stepLeft -= distTarget;
                // Следующий waypoint или конец.
                pl.moveTarget = pl.movePath.length > 0 ? (pl.movePath.shift() || null) : null;
                pl.dirtyPos = true;
            } else {
                const dirX = dx / distTarget;
                const dirY = dy / distTarget;
                const nx = pl.pos.x + dirX * stepLeft;
                if (isWalkableAt(currentTiles(state), nx, pl.pos.y)) pl.pos.x = nx;
                const ny = pl.pos.y + dirY * stepLeft;
                if (isWalkableAt(currentTiles(state), pl.pos.x, ny)) pl.pos.y = ny;
                pl.dirtyPos = true;
                stepLeft = 0;
            }
        }
    }

    // --- portals: player в радиусе 24px → телепорт к target, с cooldown 2s ---
    // Если portal.data.targetZone установлен — отправить игрока в другую зону (новый матч).
    for (const ok of Object.keys(state.objects)) {
        const obj = state.objects[ok];
        if (obj.kind !== "portal") continue;
        const data = obj.data || {};
        const tx = Number(data.tx), ty = Number(data.ty);
        if (!isFinite(tx) || !isFinite(ty)) continue;
        const targetZone: string = String(data.targetZone || "").trim();
        for (const sk of Object.keys(state.players)) {
            const pl = state.players[sk];
            if (pl.hp <= 0) continue;
            if ((state.portalCooldowns[sk] || 0) > t) continue;
            const dx = pl.pos.x - obj.x;
            const dy = pl.pos.y - obj.y;
            if (dx * dx + dy * dy > 24 * 24) continue;
            state.portalCooldowns[sk] = t + 2000;
            if (targetZone !== "" && targetZone !== state.zoneId && KNOWN_ZONES.indexOf(targetZone) >= 0) {
                // Межзонный переход: сохраняем новую позицию и шлём клиенту инструкцию переподключиться.
                pl.pos.x = tx; pl.pos.y = ty;
                try { saveProgress(nk, pl); } catch (_e) {}
                const targetLabel = MATCH_LABEL_PREFIX + targetZone;
                const existing = nk.matchList(1, true, targetLabel);
                const matchId = (existing.length > 0) ? existing[0].matchId : nk.matchCreate(MATCH_MODULE, { zone: targetZone });
                dispatcher.broadcastMessage(OP_ZONE_SWITCH, JSON.stringify({
                    zone: targetZone, matchId: matchId, x: tx, y: ty,
                }), [pl.presence]);
                // Отключение будет инициировано клиентом сразу после приёма сообщения.
            } else {
                // Обычный локальный телепорт внутри зоны.
                pl.pos.x = tx; pl.pos.y = ty;
                pl.moveTarget = null; pl.movePath = [];
                pl.dirtyPos = true;
                markMe(pl);
            }
        }
    }

    // --- chest respawn (opened → closed) ---
    for (const ok of Object.keys(state.objects)) {
        const obj = state.objects[ok];
        if (obj.kind !== "chest") continue;
        const data = obj.data || {};
        if (data.opened && Number(data.nextRespawnAt || 0) <= t) {
            data.opened = false;
            data.nextRespawnAt = 0;
            obj.data = data;
            dispatcher.broadcastMessage(OP_OBJS, JSON.stringify({ objects: [obj], full: false }));
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
        // Poison DoT
        if (mob.debuff && t < mob.debuff.poisonEndAt && t >= mob.debuff.nextPoisonTickAt) {
            const perTick = mob.debuff.poisonDmg || 3;
            const dot = Math.max(1, perTick * mob.debuff.poisonStacks);
            mob.hp -= dot;
            mob.dirty = true;
            mob.debuff.nextPoisonTickAt = t + 1000;
            dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({ mobId: mob.id, dmg: dot, poison: true }));
            if (mob.hp <= 0) {
                // Find any player to credit; fallback to first alive
                const pKeys2 = Object.keys(state.players);
                if (pKeys2.length > 0) killMob(mob, state.players[pKeys2[0]], t);
                else { mob.hp = 0; mob.state = "dead"; mob.respawnAt = t + def.respawnMs; }
                continue;
            }
        }
        if (mob.debuff && t >= mob.debuff.poisonEndAt) mob.debuff = undefined;
        // Stun: оглушённый моб не двигается и не бьёт. Poison DoT выше
        // продолжает тикать, чтобы лучник не терял DoT от стан-моды.
        if (mob.stunUntil && t < mob.stunUntil) {
            mob.dirty = true;
            continue;
        }
        const slowed = mob.debuff && t < mob.debuff.slowEndAt;
        const speed = slowed ? def.speed * 0.7 : def.speed;
        if (!mob.target || dist(mob.pos, mob.target) < 4) {
            const angle = Math.random() * Math.PI * 2;
            const r = Math.random() * def.wanderRadius;
            mob.target = {
                x: clamp(mob.home.x + Math.cos(angle) * r, 0, MAP_WIDTH - 1),
                y: clamp(mob.home.y + Math.sin(angle) * r, 0, MAP_HEIGHT - 1),
            };
        }
        const step = Math.min(dist(mob.pos, mob.target), speed * TICK_DT);
        if (step > 0.01) {
            const dx = mob.target.x - mob.pos.x; const dy = mob.target.y - mob.pos.y;
            const d = Math.sqrt(dx * dx + dy * dy) || 1;
            const nx = mob.pos.x + (dx / d) * step;
            const ny = mob.pos.y + (dy / d) * step;
            if (isWalkableAt(currentTiles(state), nx, mob.pos.y)) mob.pos.x = nx; else mob.target = null;
            if (isWalkableAt(currentTiles(state), mob.pos.x, ny)) mob.pos.y = ny; else mob.target = null;
            mob.dirty = true;
        }

        const playerKeys = Object.keys(state.players);
        for (let j = 0; j < playerKeys.length; j++) {
            const p = state.players[playerKeys[j]];
            if (p.hp <= 0) continue;
            if (t < p.invulnUntil) continue;
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
    const pUpdates: { sid: string; uid: string; n: string; x: number; y: number; hp: number; hpMax: number; lv: number; hb: boolean; effects: PlayerEffect[] }[] = [];
    const pKeys = Object.keys(state.players);
    for (let i = 0; i < pKeys.length; i++) {
        const p = state.players[pKeys[i]];
        if (!p.dirtyPos) continue;
        const hasBowBroadcast = (p.equipment.weapon || "").includes("bow");
        pUpdates.push({ sid: p.sessionId, uid: p.userId, n: p.username, x: p.pos.x, y: p.pos.y, hp: p.hp, hpMax: p.hpMax, lv: p.level, hb: hasBowBroadcast, effects: p.effects || [] });
        p.dirtyPos = false;
    }
    if (pUpdates.length > 0) {
        dispatcher.broadcastMessage(OP_POSITIONS, JSON.stringify({ players: pUpdates, t: Date.now() }));
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

function matchSignal(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, tick: number, state: WorldState, data: string): { state: WorldState; data?: string } | null {
    if (data === "snapshot") {
        const snapPlayers: any[] = [];
        const tNow = Date.now();
        for (const sk of Object.keys(state.players)) {
            const p = state.players[sk];
            snapPlayers.push({
                sid: p.sessionId, uid: p.userId, name: p.username,
                pos: p.pos, hp: p.hp, hpMax: p.hpMax, level: p.level,
                xp: p.xp, gold: p.gold,
                equipment: p.equipment, inventory: p.inventory,
                skillCd: p.skillCd, invulnUntil: p.invulnUntil,
                atkSpeedBoostUntil: p.atkSpeedBoostUntil,
                lastAttackAt: p.lastAttackAt,
                effects: p.effects || [],
            });
        }
        const snapMobs: any[] = [];
        for (const mk of Object.keys(state.mobs)) {
            const m = state.mobs[mk];
            snapMobs.push({
                id: m.id, type: m.type,
                pos: m.pos, home: m.home,
                hp: m.hp, hpMax: m.hpMax, state: m.state,
                respawnAt: m.respawnAt, debuff: m.debuff || null,
            });
        }
        return {
            state: state,
            data: JSON.stringify({ ts: tNow, tick: tick, players: snapPlayers, mobs: snapMobs, zones: state.zones }),
        };
    }
    if (data && data.indexOf("admin:") === 0) {
        const result = adminApply(state, data.substring("admin:".length));
        return { state: state, data: JSON.stringify(result) };
    }
    return { state: state };
}

function findPlayerByName(state: WorldState, name: string): MatchPlayer | null {
    const lower = name.toLowerCase();
    for (const sk of Object.keys(state.players)) {
        if (state.players[sk].username.toLowerCase() === lower) return state.players[sk];
    }
    return null;
}

function adminApply(state: WorldState, payload: string): { ok: boolean; error?: string; info?: string } {
    let body: any;
    try { body = JSON.parse(payload); } catch { return { ok: false, error: "bad json" }; }
    const op = String(body.op || "");
    const t = Date.now();
    switch (op) {
        case "give_gold": {
            const p = findPlayerByName(state, String(body.target || ""));
            if (!p) return { ok: false, error: "no player" };
            p.gold += Number(body.amount) || 0;
            markMe(p);
            return { ok: true, info: `${p.username} gold=${p.gold}` };
        }
        case "give_item": {
            const p = findPlayerByName(state, String(body.target || ""));
            if (!p) return { ok: false, error: "no player" };
            const itemId = String(body.itemId || "");
            const qty = Number(body.qty) || 1;
            if (!ITEMS[itemId]) return { ok: false, error: "no item" };
            addToInventory(p, itemId, qty);
            return { ok: true, info: `${p.username} +${qty} ${itemId}` };
        }
        case "set_level": {
            const p = findPlayerByName(state, String(body.target || ""));
            if (!p) return { ok: false, error: "no player" };
            p.level = Math.max(1, Math.min(MAX_LEVEL, Number(body.level) || 1));
            p.hpMax = computeHpMax(p);
            p.hp = p.hpMax;
            p.dirtyPos = true;
            markMe(p);
            return { ok: true, info: `${p.username} lv=${p.level}` };
        }
        case "set_hp": {
            const p = findPlayerByName(state, String(body.target || ""));
            if (!p) return { ok: false, error: "no player" };
            p.hp = Math.max(0, Math.min(p.hpMax, Number(body.hp) || p.hpMax));
            p.dirtyPos = true;
            markMe(p);
            return { ok: true, info: `${p.username} hp=${p.hp}` };
        }
        case "heal_all": {
            for (const sk of Object.keys(state.players)) {
                const p = state.players[sk];
                p.hp = p.hpMax;
                p.dirtyPos = true;
                markMe(p);
            }
            return { ok: true, info: "healed all" };
        }
        case "teleport": {
            const p = findPlayerByName(state, String(body.target || ""));
            if (!p) return { ok: false, error: "no player" };
            p.pos.x = Number(body.x) || p.pos.x;
            p.pos.y = Number(body.y) || p.pos.y;
            p.dirtyPos = true;
            return { ok: true, info: `${p.username} -> (${p.pos.x|0},${p.pos.y|0})` };
        }
        case "kill_mob": {
            const mid = String(body.mobId || "");
            const m = state.mobs[mid];
            if (!m) return { ok: false, error: "no mob" };
            m.hp = 0; m.state = "dead";
            m.respawnAt = t + MOB_TYPES[m.type].respawnMs;
            m.dirty = true;
            return { ok: true, info: `killed ${mid}` };
        }
        case "killall_mobs": {
            let n = 0;
            for (const mk of Object.keys(state.mobs)) {
                const m = state.mobs[mk];
                if (m.state === "alive") {
                    m.hp = 0; m.state = "dead";
                    m.respawnAt = t + MOB_TYPES[m.type].respawnMs;
                    m.dirty = true;
                    n++;
                }
            }
            return { ok: true, info: `killed ${n} mobs` };
        }
        case "respawn_mobs": {
            for (const mk of Object.keys(state.mobs)) {
                const m = state.mobs[mk];
                m.respawnAt = t;  // респавн на следующем тике
            }
            return { ok: true, info: "all mobs scheduled to respawn" };
        }
        default:
            return { ok: false, error: "unknown op " + op };
    }
}

function rpcGetWorldMatch(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    let zoneId = DEFAULT_ZONE;
    try {
        const p = JSON.parse(payload || "{}");
        if (p && typeof p.zone === "string" && KNOWN_ZONES.indexOf(p.zone) >= 0) {
            zoneId = p.zone;
        }
    } catch (_e) {}
    const label = MATCH_LABEL_PREFIX + zoneId;
    const existing = nk.matchList(1, true, label);
    if (existing.length > 0) return JSON.stringify({ match_id: existing[0].matchId, zone: zoneId });
    const matchId = nk.matchCreate(MATCH_MODULE, { zone: zoneId });
    return JSON.stringify({ match_id: matchId, zone: zoneId });
}

// Debug RPC — снимок состояния матча через matchSignal.
// Параметр payload может содержать {"filter": "mob"|"player"|"zone"}.
function rpcDebugState(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    let filter = "";
    try { filter = String((JSON.parse(payload || "{}") as any).filter || ""); } catch (_e) {}
    const matches = nk.matchList(1, true, MATCH_LABEL_PREFIX + DEFAULT_ZONE);
    if (matches.length === 0) return JSON.stringify({ error: "no active match" });
    const matchId = matches[0].matchId;
    const result = nk.matchSignal(matchId, "snapshot");
    if (!result) return JSON.stringify({ error: "no signal data" });
    let snap: any;
    try { snap = JSON.parse(result); } catch { return JSON.stringify({ error: "parse fail", raw: result }); }
    if (filter === "player") return JSON.stringify({ ts: snap.ts, players: snap.players });
    if (filter === "mob") return JSON.stringify({ ts: snap.ts, mobs: snap.mobs });
    if (filter === "zone") return JSON.stringify({ ts: snap.ts, zones: snap.zones });
    return JSON.stringify(snap);
}

// ===== Archer mods =====
// Клиентские RPC: получить/записать выбор мод скиллов лучника.

function rpcArcherModsGet(ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, _payload: string): string {
    if (!ctx.userId) throw new Error("auth required");
    const stored = loadArcherMods(nk, ctx.userId);
    const sanity = sanitizeArcherMods(stored.selected);
    return JSON.stringify({
        selected: sanity.cleaned,
        cost: sanity.cost,
        budget: ARCHER_POINTS_BUDGET,
    });
}

function rpcArcherModsSet(ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    if (!ctx.userId) throw new Error("auth required");
    let req: { selected?: { [k: string]: any } } = {};
    try { req = JSON.parse(payload || "{}"); } catch (_e) { throw new Error("bad_json"); }
    const sanity = sanitizeArcherMods(req.selected || {});
    if (!sanity.ok) {
        return JSON.stringify({ ok: false, reason: sanity.reason, budget: ARCHER_POINTS_BUDGET });
    }
    saveArcherMods(nk, ctx.userId, sanity.cleaned);
    return JSON.stringify({
        ok: true,
        selected: sanity.cleaned,
        cost: sanity.cost,
        budget: ARCHER_POINTS_BUDGET,
    });
}

// ===== ADMIN =====
// Whitelist админ-имён (lowercase). Нельзя редактировать через API — только в коде.
const ADMIN_USERNAMES = ["dimka4344", "v_tip"];
// Префиксы email'ов, с которых префикс превращается в один из ADMIN_USERNAMES
// через auth.gd:_username_from_email. Для справки, чтобы не забыть:
// dimka4344@gmail.com → "dimka4344"
// v.tip@mail.ru → "v_tip" (точка не-[a-z0-9] → "_")

function isAdminCtx(ctx: nkruntime.Context): boolean {
    const name = String(ctx.username || "").toLowerCase();
    return ADMIN_USERNAMES.indexOf(name) >= 0;
}

function isAdminName(username: string): boolean {
    return ADMIN_USERNAMES.indexOf(String(username || "").toLowerCase()) >= 0;
}

// rpcAdmin — единый endpoint для админ-команд. payload:
// { op: "kick"|"give_gold"|"give_item"|"set_level"|"set_hp"
//      |"kill_mob"|"spawn_mob"|"teleport"|"heal_all"|"killall_mobs",
//   target?: string, mobId?: string, type?: string,
//   itemId?: string, qty?: number, amount?: number, level?: number, hp?: number,
//   x?: number, y?: number }
function rpcAdmin(ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    if (!isAdminCtx(ctx)) return JSON.stringify({ ok: false, error: "not admin" });

    // Try parse for offline-capable ops
    let body: any = {};
    try { body = JSON.parse(payload); } catch (_e) {}
    const op = String(body.op || "");

    // set_password — линкуем email <username>@gg.local с паролем к юзеру
    if (op === "set_password") {
        try {
            const target = String(body.target || "");
            const password = String(body.password || "");
            if (!target || password.length < 1) return JSON.stringify({ ok: false, error: "target and password required" });
            const profiles = nk.usersGetUsername([target]);
            if (profiles.length === 0) return JSON.stringify({ ok: false, error: "no user " + target });
            const targetId = profiles[0].userId;
            const email = target.toLowerCase().replace(/[^a-z0-9_]/g, "_") + "@gg.local";
            nk.linkEmail(targetId, email, password);
            return JSON.stringify({ ok: true, info: `password set for ${target} (email: ${email})` });
        } catch (e: any) {
            return JSON.stringify({ ok: false, error: String(e) });
        }
    }

    // wipe_users — удалить storage прогресс всех юзеров кроме указанных в keep
    if (op === "wipe_users") {
        try {
            const keep: string[] = (body.keep || []).map((s: any) => String(s).toLowerCase());
            const list = nk.storageList(undefined, STORAGE_COLLECTION, 1000);
            let deleted = 0;
            for (const obj of list.objects || []) {
                const userInfo = nk.usersGetId([obj.userId]);
                const name = userInfo.length > 0 ? userInfo[0].username.toLowerCase() : "";
                if (keep.indexOf(name) >= 0) continue;
                try {
                    nk.storageDelete([{ collection: STORAGE_COLLECTION, key: STORAGE_KEY, userId: obj.userId }]);
                    deleted++;
                } catch (_e) {}
            }
            return JSON.stringify({ ok: true, info: `deleted ${deleted} users (kept ${keep.length})` });
        } catch (e: any) {
            return JSON.stringify({ ok: false, error: String(e) });
        }
    }

    // list_users — все игроки из Storage (offline + online)
    if (op === "list_users") {
        try {
            const list = nk.storageList(undefined, STORAGE_COLLECTION, 100);
            const users: any[] = [];
            for (const obj of list.objects || []) {
                const v = obj.value as any;
                users.push({
                    userId: obj.userId,
                    level: v.level || 1,
                    gold: v.gold || 0,
                    xp: v.xp || 0,
                });
            }
            // Подтянем username через usersGetId
            if (users.length > 0) {
                const ids = users.map(u => u.userId);
                const profiles = nk.usersGetId(ids);
                const idToName: { [id: string]: string } = {};
                for (const u of profiles) idToName[u.userId] = u.username;
                for (const u of users) u.name = idToName[u.userId] || "?";
            }
            return JSON.stringify({ ok: true, users });
        } catch (e: any) {
            return JSON.stringify({ ok: false, error: String(e) });
        }
    }

    // Try online first via matchSignal
    const matches = nk.matchList(1, true, MATCH_LABEL_PREFIX + DEFAULT_ZONE);
    let onlineResult: any = null;
    if (matches.length > 0) {
        const sig = nk.matchSignal(matches[0].matchId, "admin:" + payload);
        if (sig) {
            try { onlineResult = JSON.parse(sig); } catch (_e) { onlineResult = null; }
            if (onlineResult && onlineResult.ok) return JSON.stringify(onlineResult);
        }
    }

    // Offline fallback for give_gold / give_item — изменить Storage напрямую.
    if ((op === "give_gold" || op === "give_item") && body.target) {
        try {
            const profiles = nk.usersGetUsername([String(body.target)]);
            if (profiles.length === 0) return JSON.stringify({ ok: false, error: "no user " + body.target });
            const targetId = profiles[0].userId;
            const objs = nk.storageRead([{ collection: STORAGE_COLLECTION, key: STORAGE_KEY, userId: targetId }]);
            const v: any = (objs.length > 0 ? objs[0].value : { level: 1, xp: 0, gold: 0, inventory: [], equipment: {} });
            if (op === "give_gold") {
                v.gold = (Number(v.gold) || 0) + (Number(body.amount) || 0);
            } else {
                const itemId = String(body.itemId || "");
                const qty = Number(body.qty) || 1;
                if (!ITEMS[itemId]) return JSON.stringify({ ok: false, error: "no item " + itemId });
                const inv: any[] = v.inventory || [];
                let added = qty;
                if (itemId.indexOf("potion") >= 0 || itemId.indexOf("jelly") >= 0) {
                    for (const e of inv) {
                        if (e.itemId === itemId && e.qty < STACK_MAX) {
                            const space = STACK_MAX - e.qty;
                            const take = Math.min(space, added);
                            e.qty += take; added -= take;
                            if (added <= 0) break;
                        }
                    }
                }
                while (added > 0 && inv.length < INVENTORY_SLOTS) {
                    const take = Math.min(STACK_MAX, added);
                    inv.push({ itemId, qty: take });
                    added -= take;
                }
                v.inventory = inv;
            }
            nk.storageWrite([{
                collection: STORAGE_COLLECTION, key: STORAGE_KEY, userId: targetId,
                value: v, permissionRead: 1, permissionWrite: 0,
            }]);
            return JSON.stringify({ ok: true, info: `offline ${op} → ${body.target}: gold=${v.gold}, inv=${v.inventory.length}` });
        } catch (e: any) {
            return JSON.stringify({ ok: false, error: String(e) });
        }
    }

    if (onlineResult) return JSON.stringify(onlineResult);
    return JSON.stringify({ ok: false, error: "no match and op not offline-capable" });
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
    initializer.registerRpc("debug_state", rpcDebugState);
    initializer.registerRpc("admin", rpcAdmin);
    initializer.registerRpc("archer_mods_get", rpcArcherModsGet);
    initializer.registerRpc("archer_mods_set", rpcArcherModsSet);
    logger.info("GG runtime loaded. mobs=" + WORLD.mobSpawns.length + " npcs=" + NPCS.length);
}

!InitModule && InitModule;
