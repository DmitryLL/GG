// Mage skill 2: Землетрясение — AoE 2×2, до 5 врагов, slow 10% базовый.
// Моды:
//   "armor_debuff" (1п) — armorDebuffUntil = t + 5000 на целях.
//   "freeze_legs"  (2п) — stunUntil = t + 2000 (stop moves).
registerMageSkill(2, {
    requiresBow: false,
    cooldownMs: 8000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;
        const zx = Number(body.x); const zy = Number(body.y);
        if (!isFinite(zx) || !isFinite(zy)) return;
        const castDist = Math.sqrt((zx - player.pos.x) ** 2 + (zy - player.pos.y) ** 2);
        if (castDist > PLAYER_ATTACK_RANGE + 40) return;

        const mod = player.mageMods ? player.mageMods["2"] : "";
        const HALF = 32;  // 2×2 тайла по 32px → radius 32
        const mobsInZone: MatchMob[] = [];
        for (const mk of Object.keys(state.mobs)) {
            const m = state.mobs[mk];
            if (m.state !== "alive") continue;
            if (Math.abs(m.pos.x - zx) > HALF || Math.abs(m.pos.y - zy) > HALF) continue;
            mobsInZone.push(m);
        }
        const targets = mobsInZone.slice(0, 5);
        const tickDmg = Math.max(1, Math.floor(baseDmg * 0.15));
        for (const m of targets) {
            m.hp -= tickDmg;
            if (!m.debuff) {
                m.debuff = { poisonStacks: 0, poisonEndAt: 0, slowEndAt: 0, nextPoisonTickAt: 0, poisonDmg: 0 };
            }
            m.debuff.slowEndAt = Math.max(m.debuff.slowEndAt, t + 3000);
            m.dirty = true;
            dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({ mobId: m.id, dmg: tickDmg }));
            if (m.hp <= 0) killMob(m, player, t);
        }

        if (mod === "armor_debuff") {
            for (const m of targets) {
                if (m.hp <= 0) continue;
                m.armorDebuffUntil = Math.max(m.armorDebuffUntil || 0, t + 5000);
                m.dirty = true;
            }
        }
        if (mod === "freeze_legs") {
            for (const m of targets) {
                if (m.hp <= 0) continue;
                m.stunUntil = Math.max(m.stunUntil || 0, t + 2000);
                dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
                    kind: "stun", mobId: m.id, duration: 2000,
                }));
            }
        }

        dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
            kind: "earthquake", x: zx, y: zy, r: HALF,
            fx: player.pos.x, fy: player.pos.y,
            duration: 3000, t: t,
        }));
        player.skillCd[2] = t + 8000;
    },
});
