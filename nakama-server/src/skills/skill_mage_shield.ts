// Mage skill 5: Щит стихий — 15% блока 3 сек.
// Упрощённая первая версия: включаем полную неуязвимость на 3 секунды
// (позже заменим на частичный абсорб 15% когда добавится shieldAbsorb).
// Моды:
//   "reactive_slow" (1п) — TODO: при первом ударе по щиту замедлить
//                          атакующего на 35% 2 сек.
//   "shield_burst"  (2п) — TODO: после 3 ударов по щиту — AoE взрыв 80%.
registerMageSkill(5, {
    requiresBow: false,
    cooldownMs: 15000,
    handler: function (ctx: SkillContext): void {
        const { player, t, dispatcher } = ctx;
        player.invulnUntil = Math.max(player.invulnUntil, t + 3000);
        dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
            kind: "shield_up", sid: player.sessionId, duration: 3000,
        }));
        player.skillCd[5] = t + 15000;
    },
});
