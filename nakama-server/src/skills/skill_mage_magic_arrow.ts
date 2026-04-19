// Mage skill 1: Магическая стрела — 150% от baseDmg.
// Мoды:
//   "armor_pierce" (1п) — игнор 30% маг. защиты (у мобов защиты пока нет,
//                          но если у цели есть armorDebuffUntil —
//                          добавляем +20% урона через дебафф).
//   "slow"         (2п) — slow 25% на 1 сек.
registerMageSkill(1, {
    requiresBow: false,
    cooldownMs: 4000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;
        let dmg = Math.max(1, Math.floor(baseDmg * 1.5));
        const mod = player.mageMods ? player.mageMods["1"] : "";
        const maxDist = attackRangeFor(player.equipment.weapon || "") + 40;

        // PvP
        if (body.sid && body.sid !== player.sessionId) {
            const foe = state.players[String(body.sid)];
            if (!foe || foe.hp <= 0) return;
            if (areAllies(player, foe)) return;  // по союзнику не бьём
            if (dist(foe.pos, player.pos) > maxDist) return;
            if (t < foe.invulnUntil) return;
            foe.hp -= dmg;
            if (foe.hp < 0) foe.hp = 0;
            foe.dirtyPos = true;
            markMe(foe);
            dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                fx: player.pos.x, fy: player.pos.y,
                tx: foe.pos.x, ty: foe.pos.y, ghost: true,
            }));
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({
                sessionId: foe.sessionId, by: player.sessionId, dmg: dmg, ghost: true,
            }));
            if (foe.hp <= 0) {
                foe.pos.x = WORLD.playerSpawn.x; foe.pos.y = WORLD.playerSpawn.y;
                foe.hp = foe.hpMax; foe.lastTouchedByMob = {};
                foe.dirtyPos = true; markMe(foe);
            }
            player.skillCd[1] = t + 4000;
            return;
        }

        // PvE
        const mob = state.mobs[String(body.mobId || "")];
        if (!mob || mob.state !== "alive") return;
        if (dist(mob.pos, player.pos) > maxDist) return;

        if (mod === "armor_pierce" && mob.armorDebuffUntil && t < mob.armorDebuffUntil) {
            dmg = Math.floor(dmg * 1.20);
        }

        mob.hp -= dmg;
        mob.dirty = true;
        dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
            fx: player.pos.x, fy: player.pos.y,
            tx: mob.pos.x, ty: mob.pos.y, ghost: true,
        }));
        dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({
            mobId: mob.id, dmg: dmg, ghost: true,
        }));

        if (mob.hp > 0 && mod === "slow") {
            if (!mob.debuff) {
                mob.debuff = { poisonStacks: 0, poisonEndAt: 0, slowEndAt: 0, nextPoisonTickAt: 0, poisonDmg: 0 };
            }
            mob.debuff.slowEndAt = Math.max(mob.debuff.slowEndAt, t + 1000);
            mob.dirty = true;
        }

        if (mob.hp <= 0) killMob(mob, player, t);
        player.skillCd[1] = t + 4000;
    },
});
