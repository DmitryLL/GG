// Скилл 2: Деза — отбрасывание цели назад на 2 шага.
// Легаси: пока сохраняется старая механика (hit 80% + poison+slow) —
// чтобы не ломать баланс до полной переписки. Базовый knockback
// добавлен как дополнительный эффект.
// Модификации:
//   "root"   (1п) — после отбрасывания цель обездвижена 0.5 сек
//                   (переиспользует stunUntil на мобе).
//   "dispel" (2п) — снимает один положительный бафф. Заглушка:
//                   на мобах сейчас баффов нет, только визуал.
registerSkill(2, {
    requiresBow: true,
    cooldownMs: 6000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher, baseDmg } = ctx;

        const hitDmg = Math.max(1, Math.floor(baseDmg * 0.8));
        const tickDmg = Math.max(1, Math.floor(baseDmg * 0.2));
        const mod = player.archerMods ? player.archerMods["2"] : "";
        const KNOCK_PX = 64;  // 2 тайла по 32px
        const ROOT_MS = 500;

        // PvP
        if (body.sid && body.sid !== player.sessionId) {
            const foe = state.players[String(body.sid)];
            if (!foe || foe.hp <= 0) return;
            if (dist(foe.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
            if (t < foe.invulnUntil) return;
            foe.hp -= hitDmg;
            if (foe.hp < 0) foe.hp = 0;
            foe.dirtyPos = true;
            markMe(foe);
            dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
                fx: player.pos.x, fy: player.pos.y,
                tx: foe.pos.x, ty: foe.pos.y,
                poison: true,
            }));
            dispatcher.broadcastMessage(OP_PLAYER_HIT, JSON.stringify({
                sessionId: foe.sessionId, by: player.sessionId, dmg: hitDmg, poison: true,
            }));
            applyPlayerEffect(foe, {
                id: "poison",
                kind: "debuff",
                type: "poison",
                endAt: t + 7000,
                nextTickAt: t + 1000,
                stacks: 1,
                damage: tickDmg,
            });
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
        if (dist(mob.pos, player.pos) > PLAYER_ATTACK_RANGE + 40) return;
        mob.hp -= hitDmg;
        mob.dirty = true;
        if (!mob.debuff) {
            mob.debuff = { poisonStacks: 0, poisonEndAt: 0, slowEndAt: 0, nextPoisonTickAt: 0, poisonDmg: 0 };
        }
        mob.debuff.poisonStacks = Math.min(3, mob.debuff.poisonStacks + 1);
        mob.debuff.poisonEndAt = t + 7000;
        mob.debuff.slowEndAt = t + 7000;
        mob.debuff.nextPoisonTickAt = t + 1000;
        mob.debuff.poisonDmg = tickDmg;
        dispatcher.broadcastMessage(OP_ARROW, JSON.stringify({
            fx: player.pos.x, fy: player.pos.y,
            tx: mob.pos.x, ty: mob.pos.y,
            poison: true,
        }));
        dispatcher.broadcastMessage(OP_HIT_FLASH, JSON.stringify({
            mobId: mob.id, dmg: hitDmg, poison: true,
        }));

        // Knockback на 2 тайла от игрока через velocity: mob AI в
        // последующих тиках двигает моба постепенно, визуально отлетает,
        // а не телепортируется.
        if (mob.hp > 0) {
            const dirx = mob.pos.x - player.pos.x;
            const diry = mob.pos.y - player.pos.y;
            const dlen = Math.sqrt(dirx * dirx + diry * diry) || 1;
            const KNOCK_MS = 200;
            mob.knockbackVx = (dirx / dlen) * KNOCK_PX / (KNOCK_MS / 1000);
            mob.knockbackVy = (diry / dlen) * KNOCK_PX / (KNOCK_MS / 1000);
            mob.knockbackEndAt = t + KNOCK_MS;
            // Моб сбрасывает цель — после knockback подберёт новую точку AI.
            mob.target = null;
            mob.dirty = true;

            if (mod === "root") {
                mob.stunUntil = t + ROOT_MS;
                dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
                    kind: "root", mobId: mob.id, duration: ROOT_MS,
                }));
            }
            if (mod === "dispel") {
                // TODO: система баффов на мобах ещё не реализована. Клиент
                // получит вспышку, серверного эффекта нет.
                dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
                    kind: "dispel", mobId: mob.id,
                }));
            }
        }

        if (mob.hp <= 0) killMob(mob, player, t);
        player.skillCd[2] = t + 6000;
    },
});
