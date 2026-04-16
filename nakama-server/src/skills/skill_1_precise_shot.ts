// Скилл 1: Меткий выстрел — одиночный x2 урон.
registerSkill(1, {
    requiresBow: true,
    cooldownMs: 5000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;
        const dmg = baseDmg * 2;

        // PvP: цель — другой игрок
        if (body.sid && body.sid !== player.sessionId) {
            const foe = state.players[String(body.sid)];
            if (!foe || foe.hp <= 0) return;
            if (dist(foe.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
            if (t < foe.invulnUntil) return;
            foe.hp -= dmg;
            if (foe.hp < 0) foe.hp = 0;
            markMe(foe);
            dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                fx: player.pos.x, fy: player.pos.y,
                tx: foe.pos.x, ty: foe.pos.y,
                crit: true,
            }));
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({
                sessionId: foe.sessionId, by: player.sessionId, dmg: dmg, crit: true,
            }));
            if (foe.hp <= 0) {
                foe.pos.x = WORLD.playerSpawn.x; foe.pos.y = WORLD.playerSpawn.y;
                foe.hp = foe.hpMax; foe.lastTouchedByMob = {};
                foe.dirtyPos = true; markMe(foe);
            }
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
        if (mob.hp <= 0) killMob(mob, player, t);
        player.skillCd[1] = t + 5000;
    },
});
