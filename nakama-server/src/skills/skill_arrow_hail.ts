// Скилл 4: Град стрел — AoE-зона радиусом 80px на 3.5s.
// Модификации:
//   "slow"       (1п) — 5 случайных врагов в зоне замедляются на 20% (переиспользует slowEndAt).
//   "final_stun" (2п) — последний тик станит до 5 случайных целей на 0.5 сек.
registerSkill(4, {
    requiresBow: true,
    cooldownMs: 12000,
    manaCost: 40,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher } = ctx;
        const zx = Number(body.x); const zy = Number(body.y);
        if (!isFinite(zx) || !isFinite(zy)) return;
        const mod = player.archerMods ? player.archerMods["4"] : "";
        // Дальность каста: в пределах PLAYER_ATTACK_RANGE + 40 (лаг)
        const castDist = Math.sqrt((zx - player.pos.x) ** 2 + (zy - player.pos.y) ** 2);
        if (castDist > PLAYER_ATTACK_RANGE + 40) return;
        state.zones.push({
            id: "z" + t + Math.random().toString(36).slice(2, 6),
            kind: "arrow_rain",
            x: zx, y: zy, radius: 80,
            nextTickAt: t + 400,
            endAt: t + 3500,
            ownerSid: player.sessionId,
            mod: mod,
        });
        dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
            kind: "rain_start", x: zx, y: zy, r: 80,
            fx: player.pos.x, fy: player.pos.y,
            duration: 3500,
            t: t,  // server-time старта, чтобы клиент привязал длительность к серверу
        }));
        player.skillCd[4] = t + 12000;
    },
});
