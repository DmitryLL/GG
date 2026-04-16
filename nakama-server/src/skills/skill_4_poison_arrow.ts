// Скилл 4: Отравленная стрела — DoT (3 урона/тик × stacks) + slow 30% на 7s.
registerSkill(4, {
    requiresBow: true,
    cooldownMs: 6000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;

        // PvP: прямой урон (без debuff пока)
        if (body.sid && body.sid !== player.sessionId) {
            const foe = state.players[String(body.sid)];
            if (!foe || foe.hp <= 0) return;
            if (dist(foe.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
            if (t < foe.invulnUntil) return;
            foe.hp -= baseDmg;
            if (foe.hp < 0) foe.hp = 0;
            markMe(foe);
            dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                fx: player.pos.x, fy: player.pos.y,
                tx: foe.pos.x, ty: foe.pos.y,
                poison: true,
            }));
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({
                sessionId: foe.sessionId, by: player.sessionId, dmg: baseDmg, poison: true,
            }));
            if (foe.hp <= 0) {
                foe.pos.x = WORLD.playerSpawn.x; foe.pos.y = WORLD.playerSpawn.y;
                foe.hp = foe.hpMax; foe.lastTouchedByMob = {};
                foe.dirtyPos = true; markMe(foe);
            }
            player.skillCd[4] = t + 6000;
            return;
        }

        const mob = state.mobs[String(body.mobId || "")];
        if (!mob || mob.state !== "alive") return;
        if (dist(mob.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
        mob.hp -= baseDmg;
        mob.dirty = true;
        if (!mob.debuff) {
            mob.debuff = { poisonStacks: 0, poisonEndAt: 0, slowEndAt: 0, nextPoisonTickAt: 0 };
        }
        mob.debuff.poisonStacks = Math.min(3, mob.debuff.poisonStacks + 1);
        mob.debuff.poisonEndAt = t + 7000;
        mob.debuff.slowEndAt = t + 7000;
        mob.debuff.nextPoisonTickAt = t + 1000;
        dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
            fx: player.pos.x, fy: player.pos.y,
            tx: mob.pos.x, ty: mob.pos.y,
            poison: true,
        }));
        dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({
            mobId: mob.id, dmg: baseDmg, poison: true,
        }));
        if (mob.hp <= 0) killMob(mob, player, t);
        player.skillCd[4] = t + 6000;
    },
});
