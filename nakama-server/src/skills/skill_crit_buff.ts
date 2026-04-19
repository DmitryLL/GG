// Скилл 5: Баф крита — +75% шанс крита на 2 сек (self-buff, INSTANT).
// Модификации:
//   "party_crit"  (1п) — союзникам в радиусе 5 тайлов (160px) +20%
//                         к шансу крита на 2 сек.
//   "penetration" (2п) — +20% к итоговому урону как stop-gap до
//                         реализации брони у мобов.
// Визуал: applyPlayerEffect на каждом участнике, чтобы nameplate
// показывал таймер баффа.
registerSkill(5, {
    requiresBow: true,
    cooldownMs: 15000,
    manaCost: 30,
    handler: function (ctx: SkillContext): void {
        const { player, t, state, dispatcher } = ctx;
        const mod = player.archerMods ? player.archerMods["5"] : "";
        const BUFF_MS = 2000;
        const PARTY_RADIUS = 160;  // 5 тайлов × 32px

        // Базовый self-buff.
        player.critBuffUntil = t + BUFF_MS;
        player.critBonus = 0.75;
        applyPlayerEffect(player, {
            id: "crit_buff",
            kind: "buff",
            type: "crit_buff",
            endAt: t + BUFF_MS,
        });
        markMe(player);

        if (mod === "party_crit") {
            for (const sk of Object.keys(state.players)) {
                const ally = state.players[sk];
                if (ally.sessionId === player.sessionId) continue;
                if (!areAllies(player, ally)) continue;  // чужая фракция — мимо
                if (dist(ally.pos, player.pos) > PARTY_RADIUS) continue;
                ally.critBuffUntil = t + BUFF_MS;
                ally.critBonus = Math.max(ally.critBonus || 0, 0.20);
                applyPlayerEffect(ally, {
                    id: "crit_buff_party",
                    kind: "buff",
                    type: "crit_buff",
                    endAt: t + BUFF_MS,
                });
                markMe(ally);
            }
            dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
                kind: "party_crit_buff",
                sid: player.sessionId,
                x: player.pos.x, y: player.pos.y,
                radius: PARTY_RADIUS, duration: BUFF_MS,
            }));
        }
        if (mod === "penetration") {
            player.pierceBuffUntil = t + BUFF_MS;
            player.pierceBonus = 0.20;
            applyPlayerEffect(player, {
                id: "pierce",
                kind: "buff",
                type: "pierce",
                endAt: t + BUFF_MS,
            });
            markMe(player);
        }

        // Визуальная вспышка на кастере.
        dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
            kind: "crit_buff", sid: player.sessionId, duration: BUFF_MS,
        }));

        player.skillCd[5] = t + 15000;
    },
});
