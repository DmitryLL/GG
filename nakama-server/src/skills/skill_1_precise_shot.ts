// Скилл 1: Меткий выстрел — одиночный x2 урон.
// Чёрная стрела с красным glow, КРИТ метка, cd 5s.
registerSkill(1, function (ctx: SkillContext): void {
    const { player, body, t, state, dispatcher, baseDmg } = ctx;
    const mob = state.mobs[String(body.mobId || "")];
    if (!mob || mob.state !== "alive") return;
    if (dist(mob.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
    const dmg = baseDmg * 2;
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
});
