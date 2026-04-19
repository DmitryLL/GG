#!/usr/bin/env node
// Читает data/*.json, генерит src/data.gen.ts с типизированными константами.
// Запускается перед tsc.

const fs = require("fs");
const path = require("path");

const DATA_DIR = path.join(__dirname, "..", "..", "data");
const OUT = path.join(__dirname, "..", "src", "data.gen.ts");

function loadJson(file) {
    const full = path.join(DATA_DIR, file);
    const raw = fs.readFileSync(full, "utf8");
    const parsed = JSON.parse(raw);
    // Удаляем все ключи, начинающиеся с _ (комментарии в JSON).
    return stripUnderscoreKeys(parsed);
}

function stripUnderscoreKeys(value) {
    if (Array.isArray(value)) return value.map(stripUnderscoreKeys);
    if (value && typeof value === "object") {
        const out = {};
        for (const k of Object.keys(value)) {
            if (k.startsWith("_")) continue;
            out[k] = stripUnderscoreKeys(value[k]);
        }
        return out;
    }
    return value;
}

const items = loadJson("items.json");
const mobs = loadJson("mobs.json");
const drops = loadJson("drops.json");
const npcs = loadJson("npcs.json");
const balance = loadJson("balance.json");
const worldMap = loadJson(path.join("maps", "world.tmj"));

const json = (v) => JSON.stringify(v, null, 4);

const banner = `// AUTO-GENERATED FROM data/*.json by scripts/gen-data.js — DO NOT EDIT.\n`;

const out =
    banner +
    `interface ItemDefData { kind: string; slot?: string; damage?: number; physDmg?: number; magDmg?: number; hp?: number; heal?: number; price?: number; sellPrice?: number; }\n` +
    `interface MobTypeDataX { hpMax: number; touchDamage: number; speed: number; wanderRadius: number; touchRange: number; touchCooldownMs: number; respawnMs: number; xp: number; gold: number; }\n` +
    `interface DropEntryData { itemId: string; weight: number; }\n` +
    `interface DropTableData { missWeight: number; table: DropEntryData[]; }\n` +
    `interface NpcData { id: string; name: string; x: number; y: number; stock: string[]; }\n` +
    `interface PlayerBalanceData { hpBase: number; perLevelHpBonus: number; perLevelDamageBonus: number; attackDamage: number; attackRange: number; attackCooldownMs: number; }\n` +
    `interface WorldBalanceData { tileSize: number; mapCols: number; mapRows: number; seed: number; }\n` +
    `interface DropsBalanceData { pickupRange: number; lifetimeMs: number; }\n` +
    `interface InventoryBalanceData { slots: number; stackMax: number; }\n` +
    `interface XpBalanceData { base: number; }\n` +
    `interface NpcBalanceData { interactRange: number; }\n` +
    `interface BalanceData { player: PlayerBalanceData; world: WorldBalanceData; drops: DropsBalanceData; inventory: InventoryBalanceData; xp: XpBalanceData; npc: NpcBalanceData; }\n\n` +
    `const ITEMS_DATA: { [id: string]: ItemDefData } = ${json(items)};\n\n` +
    `const MOBS_DATA: { [id: string]: MobTypeDataX } = ${json(mobs)};\n\n` +
    `const DROPS_DATA: { [mobType: string]: DropTableData } = ${json(drops)};\n\n` +
    `const NPCS_DATA: NpcData[] = ${json(npcs)};\n\n` +
    `const BALANCE_DATA: BalanceData = ${json(balance)};\n\n` +
    `const WORLD_MAP_DATA: any = ${json(worldMap)};\n`;

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, out);
console.log(`wrote ${OUT} (${(out.length / 1024).toFixed(1)} kb)`);
