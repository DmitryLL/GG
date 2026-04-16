// Скилл 2: Ливень стрел — AoE-зона радиусом 80px на 3.5s.
// Каждые 400ms тикает, нанося ~45% от computeDamage всем мобам в зоне.
registerSkill(2, function (ctx: SkillContext): void {
    const { player, body, t, state, dispatcher } = ctx;
    const zx = Number(body.x); const zy = Number(body.y);
    if (!isFinite(zx) || !isFinite(zy)) return;
    state.zones.push({
        id: "z" + t + Math.random().toString(36).slice(2, 6),
        kind: "arrow_rain",
        x: zx, y: zy, radius: 80,
        nextTickAt: t + 400,
        endAt: t + 3500,
        ownerSid: player.sessionId,
    });
    dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
        kind: "rain_start", x: zx, y: zy, r: 80,
        fx: player.pos.x, fy: player.pos.y,
        duration: 3500,
    }));
    player.skillCd[2] = t + 12000;
});
