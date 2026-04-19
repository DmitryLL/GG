// Скилл 3: Эскейп — телепорт вперёд на 3 шага + 0.5s неуязвимости + 3s atk speed x2.
// Модификации:
//   "empowered_attack" (1п) — следующая базовая атака +100% урона (окно 5 сек).
//   "sprint"           (2п) — на 2 сек скорость +25% (visual feedback через поле sprintUntil).
registerSkill(3, {
    requiresBow: false,
    cooldownMs: 8000,
    handler: function (ctx: SkillContext): void {
        const { player, body, t, state, dispatcher } = ctx;
        const mod = player.archerMods ? player.archerMods["3"] : "";
        // Направление: сначала dx/dy от клиента (взгляд), иначе вниз
        let dx = Number(body.dx) || 0;
        let dy = Number(body.dy) || 0;
        const len = Math.sqrt(dx * dx + dy * dy);
        if (len < 0.01) { dx = 0; dy = 1; }
        else { dx /= len; dy /= len; }
        // Сохраняем конечную цель ходьбы ДО телепорта: если игрок шёл куда-то,
        // должен продолжить идти туда же после Dodge.
        const finalDest: Vec2 | null = (player.movePath && player.movePath.length > 0)
            ? player.movePath[player.movePath.length - 1]
            : player.moveTarget;
        // Raycast по линии с шагом 6px: останавливаемся перед первой непроходимой
        // клеткой, чтобы нельзя было «перескочить» через стену или попасть в неё.
        const tiles = currentTiles(state);
        const maxDist = 80;
        const step = 6;
        let reach = 0;
        for (let s = step; s <= maxDist; s += step) {
            const tx = player.pos.x + dx * s;
            const ty = player.pos.y + dy * s;
            if (!isWalkableAt(tiles, tx, ty)) break;
            reach = s;
        }
        const nx = player.pos.x + dx * reach;
        const ny = player.pos.y + dy * reach;
        player.pos.x = Math.max(TILE_SIZE, Math.min(MAP_WIDTH - TILE_SIZE, nx));
        player.pos.y = Math.max(TILE_SIZE, Math.min(MAP_HEIGHT - TILE_SIZE, ny));
        player.dirtyPos = true;
        // Сбрасываем промежуточные waypoints и ведём игрока напрямую к финалу.
        player.movePath = [];
        if (finalDest) {
            const ddx = finalDest.x - player.pos.x;
            const ddy = finalDest.y - player.pos.y;
            // Если уже дошли (≤ 8px от финала) — просто стоим.
            player.moveTarget = (ddx * ddx + ddy * ddy < 64) ? null : { x: finalDest.x, y: finalDest.y };
        } else {
            player.moveTarget = null;
        }
        player.invulnUntil = t + 500;
        player.atkSpeedBoostUntil = t + 3000;
        // Обработка мод.
        if (mod === "empowered_attack") {
            player.empoweredAttackUntil = t + 5000;
        }
        if (mod === "sprint") {
            player.sprintUntil = t + 2000;
        }
        dispatcher.broadcastMessage(OP_SKILL_FX, JSON.stringify({
            kind: "dodge", sid: player.sessionId,
            fx: player.pos.x, fy: player.pos.y,
            empowered: mod === "empowered_attack",
            sprint: mod === "sprint",
        }));
        player.skillCd[3] = t + 8000;
    },
});
