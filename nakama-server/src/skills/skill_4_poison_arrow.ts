// Скилл 4: Отравленная стрела — DoT (3 урона/тик × stacks) + slow 30% на 7s.
registerSkill(4, {
    requiresBow: true,
    cooldownMs: 6000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;
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
