// Скилл 2: Отравленная стрела.
// Удар = 80% от baseDmg, яд = 20% от baseDmg за каждый тик (7 тиков за 7с).
// На мобе stacks до 3 (суммируются при повторном касте), длительность обновляется.
registerSkill(2, {
    requiresBow: true,
    cooldownMs: 6000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;

        const hitDmg = Math.max(1, Math.floor(baseDmg * 0.8));
        const tickDmg = Math.max(1, Math.floor(baseDmg * 0.2));

        // PvP
        if (body.sid && body.sid !== player.sessionId) {
            const foe = state.players[String(body.sid)];
            if (!foe || foe.hp <= 0) return;
            if (dist(foe.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
            if (t < foe.invulnUntil) return;
            foe.hp -= hitDmg;
            if (foe.hp < 0) foe.hp = 0;
            foe.dirtyPos = true;
            markMe(foe);
            dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                fx: player.pos.x, fy: player.pos.y,
                tx: foe.pos.x, ty: foe.pos.y,
                poison: true,
            }));
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({
                sessionId: foe.sessionId, by: player.sessionId, dmg: hitDmg, poison: true,
            }));
            applyPlayerEffect(foe, {
                id: "poison",
                kind: "debuff",
                type: "poison",
                endAt: t + 7000,
                nextTickAt: t + 1000,
                stacks: 1,
                damage: tickDmg,
            });
            if (foe.hp <= 0) {
                foe.pos.x = WORLD.playerSpawn.x; foe.pos.y = WORLD.playerSpawn.y;
                foe.hp = foe.hpMax; foe.lastTouchedByMob = {};
                foe.dirtyPos = true; markMe(foe);
            }
            player.skillCd[2] = t + 6000;
            return;
        }

        const mob = state.mobs[String(body.mobId || "")];
        if (!mob || mob.state !== "alive") return;
        if (dist(mob.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
        mob.hp -= hitDmg;
        mob.dirty = true;
        if (!mob.debuff) {
            mob.debuff = { poisonStacks: 0, poisonEndAt: 0, slowEndAt: 0, nextPoisonTickAt: 0, poisonDmg: 0 };
        }
        mob.debuff.poisonStacks = Math.min(3, mob.debuff.poisonStacks + 1);
        mob.debuff.poisonEndAt = t + 7000;
        mob.debuff.slowEndAt = t + 7000;
        mob.debuff.nextPoisonTickAt = t + 1000;
        mob.debuff.poisonDmg = tickDmg;
        dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
            fx: player.pos.x, fy: player.pos.y,
            tx: mob.pos.x, ty: mob.pos.y,
            poison: true,
        }));
        dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({
            mobId: mob.id, dmg: hitDmg, poison: true,
        }));
        if (mob.hp <= 0) killMob(mob, player, t);
        player.skillCd[2] = t + 6000;
    },
});
