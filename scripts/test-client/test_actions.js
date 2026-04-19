// Интеграционный тест: сервер рассылает OP_PLAYER_ACTION на каждое
// видимое действие игрока. Источник истины для анимаций — один поток
// эвентов, никаких точечных FX.
//
// Запуск:   node test_actions.js
//
// Схема:
//   botA входит в матч, ждёт OP_ME/OP_POSITIONS чтобы узнать свою позицию,
//   шлёт серию OP_ATTACK (по ближайшему мобу) и OP_SKILL.
//   botB входит в тот же матч и слушает OP_PLAYER_ACTION.
//   В конце сверяем: kind-ы совпадают, OP_ARROW без поля sid (доказано
//   что точечные sid убраны).

import WebSocket from 'ws';

const HOST = process.env.NK_HOST || 'nk.193-238-134-75.sslip.io';
const KEY = 'defaultkey';

const OP_MOVE_INTENT   = 2;
const OP_MOBS          = 3;
const OP_ATTACK        = 4;
const OP_ME            = 8;
const OP_ARROW         = 15;
const OP_SKILL         = 20;
const OP_POSITIONS     = 1;
const OP_PLAYER_ACTION = 47;

async function authDevice(id, name) {
    const r = await fetch(`https://${HOST}/v2/account/authenticate/device?create=true&username=${encodeURIComponent(name)}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic ' + Buffer.from(`${KEY}:`).toString('base64'),
        },
        body: JSON.stringify({ id }),
    });
    const j = await r.json();
    if (!j.token) throw new Error('Auth failed: ' + JSON.stringify(j));
    return j.token;
}

async function rpcGetMatch(token) {
    const r = await fetch(`https://${HOST}/v2/rpc/get_world_match?unwrap`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
        body: '{}',
    });
    return JSON.parse(await r.text()).match_id;
}

async function rpcCall(token, name, body) {
    const r = await fetch(`https://${HOST}/v2/rpc/${name}?unwrap`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
        body: JSON.stringify(body),
    });
    const t = await r.text();
    try { return JSON.parse(t); } catch { return t; }
}

// Создать персонажа-archer, если у бота нет. Без него matchJoin отдаст
// пустую экипировку → атаки в мили на 36px → далеко не до каждого моба
// + Град стрел требует лук и без него reject.
async function ensureCharacter(token, name) {
    const payload = { name: name.slice(0, 16), class: "archer", faction: "west" };
    await rpcCall(token, 'character_create', payload);
}

function connectWS(token) {
    const url = `wss://${HOST}/ws?token=${token}&format=json`;
    const ws = new WebSocket(url);
    return new Promise((resolve, reject) => {
        ws.once('open', () => resolve(ws));
        ws.once('error', reject);
    });
}

let cid = 0;
function send(ws, payload) {
    cid += 1;
    payload.cid = String(cid);
    ws.send(JSON.stringify(payload));
}
function b64(o) { return Buffer.from(JSON.stringify(o)).toString('base64'); }
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function spawnBot(tag) {
    // Уникальное имя на каждый запуск — иначе Nakama вернёт
    // "Username is already in use".
    const seed = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    const name = `acttest_${tag}_${seed}`;
    const id = ('at_' + tag + '_' + seed).padEnd(6, '_').slice(0, 32);
    const token = await authDevice(id, name);
    // Убедимся что у бота есть персонаж-лучник с wood_bow в экипировке.
    await ensureCharacter(token, name);
    const matchId = await rpcGetMatch(token);
    const ws = await connectWS(token);
    const bot = {
        ws, token, matchId, name,
        sid: '',
        pos: null,
        mobs: {},
        arrows: [],
        actions: [],
    };
    bot.opCounts = {};
    ws.on('message', (raw) => {
        const m = JSON.parse(raw.toString());
        if (m.match && m.match.self && m.match.self.session_id) {
            bot.sid = m.match.self.session_id;
        }
        if (m.match_presence_event) {
            for (const p of (m.match_presence_event.joins || [])) {
                if (p.session_id && !bot.sid) bot.sid = p.session_id;
            }
        }
        if (!m.match_data) return;
        const op = Number(m.match_data.op_code);
        bot.opCounts[op] = (bot.opCounts[op] || 0) + 1;
        let body = null;
        try { body = JSON.parse(Buffer.from(m.match_data.data, 'base64').toString()); } catch { return; }
        if (op === OP_PLAYER_ACTION) bot.actions.push(body);
        else if (op === OP_ARROW) bot.arrows.push(body);
        else if (op === OP_POSITIONS) {
            for (const p of (body.players || [])) {
                if (p.sid === bot.sid) bot.pos = { x: p.x, y: p.y };
            }
        }
        else if (op === OP_MOBS) {
            const full = !!body.full;
            if (full) bot.mobs = {};
            for (const m of (body.mobs || [])) {
                if (m.removed) { delete bot.mobs[m.id]; continue; }
                if (m.id) bot.mobs[m.id] = m;
            }
        }
    });
    send(ws, { match_join: { match_id: matchId } });
    await sleep(1200);  // дать серверу отдать OP_ME + OP_POSITIONS + OP_MOBS
    return bot;
}

function expect(ok, msg) {
    if (ok) { console.log(`  ✓ ${msg}`); return true; }
    console.log(`  ✗ FAIL: ${msg}`);
    process.exitCode = 1;
    return false;
}

function nearestMob(bot) {
    if (!bot.pos) return null;
    let best = null, bestD = Infinity;
    for (const id in bot.mobs) {
        const m = bot.mobs[id];
        // Серверный mobSnap кладёт state в поле `st`.
        if (m.st !== 'alive') continue;
        const dx = m.x - bot.pos.x, dy = m.y - bot.pos.y;
        const d = Math.sqrt(dx * dx + dy * dy);
        if (d < bestD) { bestD = d; best = { id, d }; }
    }
    return best;
}

async function main() {
    console.log('== spawn botA (executor) ==');
    const A = await spawnBot('a');
    console.log(`  sid=${A.sid}, pos=${JSON.stringify(A.pos)}, mobs=${Object.keys(A.mobs).length}`);

    console.log('== spawn botB (observer) ==');
    const B = await spawnBot('b');
    console.log(`  sid=${B.sid}`);

    if (!A.pos) {
        console.log('  ! botA did not receive OP_POSITIONS — server silent');
        A.ws.close(); B.ws.close();
        process.exit(1);
    }
    if (A.matchId !== B.matchId) {
        console.log('  ! different matches — test нерелевантен');
        A.ws.close(); B.ws.close();
        process.exit(1);
    }
    expect(true, `match=${A.matchId}`);

    // Двигаем A чуть в сторону, чтобы серверный state обновился и был в
    // подходящей позиции (спавн-точка может быть в клетке без мобов рядом).
    console.log('\n== move botA towards mob ==');
    const nm0 = nearestMob(A);
    if (!nm0) {
        console.log('  ! нет мобов в снимке — тест не может атаковать');
        A.ws.close(); B.ws.close();
        process.exit(1);
    }
    console.log(`  nearest mob ${nm0.id} at dist ${nm0.d.toFixed(1)} px`);
    const targetMob = A.mobs[nm0.id];
    // Идём к мобу в радиус атаки (~180px, чуть меньше чем 192)
    const dx = targetMob.x - A.pos.x, dy = targetMob.y - A.pos.y;
    const d = Math.sqrt(dx * dx + dy * dy);
    if (d > 150) {
        const k = (d - 150) / d;
        const mx = A.pos.x + dx * k;
        const my = A.pos.y + dy * k;
        send(A.ws, { match_data_send: { match_id: A.matchId, op_code: OP_MOVE_INTENT, data: b64({ x: mx, y: my }) } });
        await sleep(2500);  // даём добежать
    }

    console.log('\n== scenario 1: OP_ATTACK (A → mob) → bow_shot ==');
    A.actions.length = 0; B.actions.length = 0;
    A.arrows.length = 0; B.arrows.length = 0;
    const nm = nearestMob(A);
    console.log(`  cur pos=${JSON.stringify(A.pos)}, mob=${nm.id} dist=${nm.d.toFixed(1)}`);
    send(A.ws, { match_data_send: { match_id: A.matchId, op_code: OP_ATTACK, data: b64({ mobId: nm.id }) } });
    await sleep(900);
    expect(A.actions.some(e => e.sid === A.sid && e.kind === 'bow_shot'), 'A got OP_PLAYER_ACTION bow_shot');
    expect(B.actions.some(e => e.sid === A.sid && e.kind === 'bow_shot'), 'B got OP_PLAYER_ACTION bow_shot from A');

    console.log('\n== scenario 2: OP_SKILL 3 (Эскейп — roll) ==');
    A.actions.length = 0; B.actions.length = 0;
    send(A.ws, { match_data_send: { match_id: A.matchId, op_code: OP_SKILL, data: b64({ skill: 3, dx: 0, dy: 1 }) } });
    await sleep(900);
    expect(A.actions.some(e => e.sid === A.sid && e.kind === 'roll'), 'A got roll');
    expect(B.actions.some(e => e.sid === A.sid && e.kind === 'roll'), 'B got roll from A');

    console.log('\n== scenario 3: OP_SKILL 4 (Град стрел — bow_shot_upward) ==');
    A.actions.length = 0; B.actions.length = 0;
    // Кастуем в точку ~50px от своей позиции → гарантированно в радиусе атаки.
    const rx = A.pos.x + 40, ry = A.pos.y + 40;
    send(A.ws, { match_data_send: { match_id: A.matchId, op_code: OP_SKILL, data: b64({ skill: 4, x: rx, y: ry }) } });
    await sleep(900);
    expect(A.actions.some(e => e.sid === A.sid && e.kind === 'bow_shot_upward'), 'A got bow_shot_upward');
    expect(B.actions.some(e => e.sid === A.sid && e.kind === 'bow_shot_upward'), 'B got bow_shot_upward from A');

    console.log('\n== scenario 4: OP_ARROW без поля sid ==');
    const arrows_total = A.arrows.length + B.arrows.length;
    const arrows_with_sid = [...A.arrows, ...B.arrows].filter(a => 'sid' in a).length;
    expect(arrows_total > 0, `получены стрелы (A:${A.arrows.length}, B:${B.arrows.length})`);
    expect(arrows_with_sid === 0, `стрелы без sid (всего ${arrows_total}, с sid: ${arrows_with_sid})`);

    console.log('\n== debug: op counts ==');
    console.log('  A opCounts:', JSON.stringify(A.opCounts));
    console.log('  B opCounts:', JSON.stringify(B.opCounts));

    A.ws.close(); B.ws.close();
    await sleep(300);
    console.log('\ndone.');
}

main().catch(e => { console.error(e); process.exit(1); });
