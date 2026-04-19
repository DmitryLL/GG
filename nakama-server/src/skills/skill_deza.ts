// Деза — отбрасывание цели на 2 шага + базовый удар.
// Модификации:
//   "root"   (1п) — после отбрасывания цель обездвижена 0.5 сек (stunUntil).
//   "dispel" (2п) — снимает положительный бафф. Заглушка: на мобах баффов нет.
registerSkill(2, {
    requiresBow: true,
    cooldownMs: 6000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;

        const hitDmg = Math.max(1, Math.floor(baseDmg * 0.8));
        const mod = player.archerMods ? player.archerMods["2"] : "";
        const KNOCK_PX = 64;  // 2 тайла по 32px
        const ROOT_MS = 500;
        const KNOCK_MS = 200;

        // PvP
        if (body.sid && body.sid !== player.sessionId) {
            const foe = state.players[String(body.sid)];
            if (!foe || foe.hp <= 0) return;
            if (areAllies(player, foe)) return;  // по союзнику не бьём
            if (dist(foe.pos, player.pos) > attackRangeFor(player.equipment.weapon || "") + 40) return;
            if (t < foe.invulnUntil) return;
            foe.hp -= hitDmg;
            if (foe.hp < 0) foe.hp = 0;
            foe.dirtyPos = true;
            markMe(foe);
            dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                fx: player.pos.x, fy: player.pos.y,
                tx: foe.pos.x, ty: foe.pos.y,
            }));
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({
                sessionId: foe.sessionId, by: player.sessionId, dmg: hitDmg,
            }));
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
        if (dist(mob.pos, player.pos) > attackRangeFor(player.equipment.weapon || "") + 40) return;
        mob.hp -= hitDmg;
        mob.dirty = true;
        dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
            fx: player.pos.x, fy: player.pos.y,
            tx: mob.pos.x, ty: mob.pos.y,
        }));
        dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({
            mobId: mob.id, dmg: hitDmg,
        }));

        // Knockback velocity: AI двигает моба постепенно, он «скользит» назад.
        if (mob.hp > 0) {
            const dirx = mob.pos.x - player.pos.x;
            const diry = mob.pos.y - player.pos.y;
            const dlen = Math.sqrt(dirx * dirx + diry * diry) || 1;
            mob.knockbackVx = (dirx / dlen) * KNOCK_PX / (KNOCK_MS / 1000);
            mob.knockbackVy = (diry / dlen) * KNOCK_PX / (KNOCK_MS / 1000);
            mob.knockbackEndAt = t + KNOCK_MS;
            mob.target = null;
            mob.dirty = true;

            if (mod === "root") {
                mob.stunUntil = t + ROOT_MS;
                dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
                    kind: "root", mobId: mob.id, duration: ROOT_MS,
                }));
            }
            // Всегда шлём FX с актуальным mod'ом — для отладки и вспышки на клиенте.
            const beforeCount = (mob.buffs || []).length;
            let removedType: string | null = null;
            if (mod === "dispel") {
                // Index-based удаление: reference-equality (b !== removed)
                // в Goja-runtime Nakama иногда не удаляет элемент, хотя в
                // V8/Node работает. Поэтому работаем через индексы.
                const buffs = mob.buffs || [];
                const activeIdx: number[] = [];
                for (let i = 0; i < buffs.length; i++) {
                    if (buffs[i].endAt > t) activeIdx.push(i);
                }
                if (activeIdx.length > 0) {
                    const pick = activeIdx[Math.floor(Math.random() * activeIdx.length)];
                    removedType = buffs[pick].type;
                    const next: MobBuff[] = [];
                    for (let i = 0; i < buffs.length; i++) {
                        if (i !== pick) next.push(buffs[i]);
                    }
                    mob.buffs = next;
                    mob.dirty = true;
                }
            }
            dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
                kind: "dispel", mobId: mob.id,
                mod: mod,
                before: beforeCount,
                after: (mob.buffs || []).length,
                removed: removedType,
            }));
        }

        if (mob.hp <= 0) killMob(mob, player, t);
        player.skillCd[2] = t + 6000;
    },
});
