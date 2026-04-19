// Mage skill 3: Прилив маны — +35% маны + замедление 40% на 2 сек себе.
// Системы маны на сервере пока нет, поэтому это заглушка: только КД и
// визуал (клиент показывает FX). Моды прописаны, но эффекта без
// ресурсной системы не дают.
//   "no_slow"     (1п) — TODO: убрать своё замедление когда появится moveSlowUntil.
//   "mana_hunger" (2п) — TODO: 25% маны за 5 сек с перerwaniem от урона.
registerMageSkill(3, {
    requiresBow: false,
    cooldownMs: 20000,
    handler: function (ctx: SkillContext): void {
        const { player, t, dispatcher } = ctx;
        dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
            kind: "mana_surge", sid: player.sessionId, duration: 2000,
        }));
        player.skillCd[3] = t + 20000;
    },
});
