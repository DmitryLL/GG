// Скилл 1: РДД-удар — одиночный x2 урон.
// Модификации (см. godot/data/skills_archer.json):
//   "stun" (1п) — после попадания враг оглушён на 1 сек.
//   "fire" (2п) — поджог: пока не реализован.
registerSkill(1, {
    requiresBow: true,
    cooldownMs: 5000,
    manaCost: 20,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;
        const dmg = baseDmg * 2;
        const mod = player.archerMods ? player.archerMods["1"] : "";
        const STUN_MS = 1000;

        // PvP: цель — другой игрок
        if (body.sid && body.sid !== player.sessionId) {
            const foe = state.players[String(body.sid)];
            if (!foe || foe.hp <= 0) return;
            if (areAllies(player, foe)) return;  // по союзнику не бьём
            if (dist(foe.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
            if (t < foe.invulnUntil) return;
            const finalDmg = applyPlayerArmor(foe, dmg, "phys");
            foe.hp -= finalDmg;
            if (foe.hp < 0) foe.hp = 0;
            foe.dirtyPos = true;
            markMe(foe);
            dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                fx: player.pos.x, fy: player.pos.y,
                tx: foe.pos.x, ty: foe.pos.y,
                crit: true,
            }));
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({
                sessionId: foe.sessionId, by: player.sessionId, dmg: finalDmg, crit: true,
            }));
            if (foe.hp <= 0) {
                foe.pos.x = WORLD.playerSpawn.x; foe.pos.y = WORLD.playerSpawn.y;
                foe.hp = foe.hpMax; foe.lastTouchedByMob = {};
                foe.dirtyPos = true; markMe(foe);
            }
            // Стан мода пока применяется только к мобам (PvP-стан игроков —
            // отдельная механика с прерыванием движения/каста).
            player.skillCd[1] = t + 5000;
            return;
        }

        // PvE: цель — моб
        const mob = state.mobs[String(body.mobId || "")];
        if (!mob || mob.state !== "alive") return;
        if (dist(mob.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
        mob.hp -= dmg;
        mob.dirty = true;
        dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
            fx: player.pos.x, fy: player.pos.y,
            tx: mob.pos.x, ty: mob.pos.y,
            crit: true,
        }));
        dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({
            mobId: mob.id, dmg: dmg, crit: true,
        }));
        if (mob.hp > 0 && mod === "stun") {
            mob.stunUntil = t + STUN_MS;
            dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
                kind: "stun", mobId: mob.id, duration: STUN_MS,
            }));
        }
        if (mob.hp > 0 && mod === "fire") {
            // Стрела попадает на dmg (x2) + поджигает: 20% от базового
            // физического урона игрока за тик × 3 тика.
            mob.fireDmg = Math.max(1, Math.floor(computePhysDmg(player) * 0.2));
            mob.fireEndAt = t + 3500;
            mob.nextFireTickAt = t + 1000;
            dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
                kind: "fire", mobId: mob.id, duration: 3500,
            }));
        }
        if (mob.hp <= 0) killMob(mob, player, t);
        player.skillCd[1] = t + 5000;
    },
});
