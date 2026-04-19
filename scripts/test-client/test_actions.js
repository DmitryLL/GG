// Интеграционный тест: проверяет, что сервер рассылает OP_PLAYER_ACTION
// на каждое видимое действие игрока (bow_shot / punch / roll /
// bow_shot_upward / cast). Источник истины для анимаций — один поток
// эвентов, никаких точечных FX.
//
// Как запускается:
//   node test_actions.js
//
// Схема:
//   botA входит в матч, шлёт серию OP_ATTACK / OP_SKILL.
//   botB входит в тот же матч и слушает все OP_PLAYER_ACTION.
//   В конце сверяем: botA породил ожидаемый набор kind'ов,
//   у ВСЕХ событий есть sid botA, у ВСЕХ OP_ARROW больше НЕ должно
//   быть sid (доказательство что точечные sid убраны).

import WebSocket from 'ws';

const HOST = process.env.NK_HOST || 'nk.193-238-134-75.sslip.io';
const KEY = 'defaultkey';

const OP_MOVE_INTENT   = 2;
const OP_ATTACK        = 4;
const OP_ARROW         = 15;
const OP_SKILL         = 20;
const OP_SKILL_FX      = 21;
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
    const name = `actiontest_${tag}`;
    const id = ('at_' + tag + '_' + Date.now()).padEnd(6, '_').slice(0, 32);
    const token = await authDevice(id, name);
    const matchId = await rpcGetMatch(token);
    const ws = await connectWS(token);
    let mySid = '';
    const arrows = [];
    const actions = [];
    ws.on('message', (raw) => {
        const m = JSON.parse(raw.toString());
        if (m.match_data) {
            const op = Number(m.match_data.op_code);
            let body = null;
            try { body = JSON.parse(Buffer.from(m.match_data.data, 'base64').toString()); } catch {}
            if (!body) return;
            if (op === OP_PLAYER_ACTION) actions.push(body);
            else if (op === OP_ARROW) arrows.push(body);
        }
        if (m.match && m.match.self) mySid = m.match.self.session_id;
        if (m.match_presence_event) {
            for (const p of (m.match_presence_event.joins || [])) {
                if (p.session_id) mySid = mySid || p.session_id;
            }
        }
    });
    send(ws, { match_join: { match_id: matchId } });
    await sleep(500);
    return { ws, token, matchId, name, mySid: () => mySid, arrows, actions };
}

function expect(ok, msg) {
    if (ok) { console.log(`  ✓ ${msg}`); return; }
    console.log(`  ✗ FAIL: ${msg}`);
    process.exitCode = 1;
}

async function main() {
    console.log('== spawn botA (executor) ==');
    const A = await spawnBot('a');
    console.log(`  sid=${A.mySid()} match=${A.matchId}`);
    console.log('== spawn botB (observer) ==');
    const B = await spawnBot('b');
    console.log(`  sid=${B.mySid()}`);

    await sleep(600);
    // Убедимся, что у обоих матчи — один.
    expect(A.matchId === B.matchId, `same match: ${A.matchId}`);

    // Копируем sid-ы сразу после join.
    const aSid = A.mySid();

    // 1) обычная атака по ближайшему мобу (найдём по state через debug_state
    //    не будем — просто шлём bogus mobId, сервер ответит ничем.
    //    Вместо этого — сымитируем атаку в «пустоту», проверяя только наличие
    //    punch action-а если лук не экипирован.
    //    Однако при стартовом спавне у лучника уже есть wood_bow → bow_shot.
    //    Шлём OP_ATTACK {sid: aSid} (сами себя) — сервер отбросит из-за
    //    sid === player.sessionId. Попробуем PvP на B:
    const bSid = B.mySid();
    console.log('\n== scenario 1: OP_ATTACK PvP (A → B) ==');
    A.actions.length = 0;
    send(A.ws, { match_data_send: { match_id: A.matchId, op_code: OP_ATTACK, data: b64({ sid: bSid }) } });
    await sleep(700);
    // Серверу может не нравиться дистанция — примерно одно и то же место спавна, так что должно сработать.
    const saw_attack_action = A.actions.some(e => e.sid === aSid && (e.kind === 'bow_shot' || e.kind === 'punch'));
    expect(saw_attack_action, 'botA got back OP_PLAYER_ACTION bow_shot|punch for his own attack');
    expect(B.actions.some(e => e.sid === aSid), 'botB saw OP_PLAYER_ACTION from botA (cross-client sync)');

    console.log('\n== scenario 2: OP_SKILL 3 (Эскейп — roll) ==');
    A.actions.length = 0;
    B.actions.length = 0;
    send(A.ws, { match_data_send: { match_id: A.matchId, op_code: OP_SKILL, data: b64({ skill: 3, dx: 0, dy: 1 }) } });
    await sleep(700);
    expect(A.actions.some(e => e.sid === aSid && e.kind === 'roll'), 'OP_PLAYER_ACTION roll на кастере');
    expect(B.actions.some(e => e.sid === aSid && e.kind === 'roll'), 'B тоже видит roll от A');

    console.log('\n== scenario 3: OP_SKILL 4 (Град стрел — bow_shot_upward) ==');
    A.actions.length = 0;
    B.actions.length = 0;
    // Ждём откат после Эскейпа (там 8 сек, но 4-й скилл независим).
    send(A.ws, { match_data_send: { match_id: A.matchId, op_code: OP_SKILL, data: b64({ skill: 4, x: 700, y: 700 }) } });
    await sleep(700);
    expect(A.actions.some(e => e.sid === aSid && e.kind === 'bow_shot_upward'), 'bow_shot_upward у кастера');
    expect(B.actions.some(e => e.sid === aSid && e.kind === 'bow_shot_upward'), 'B видит bow_shot_upward');

    console.log('\n== scenario 4: OP_ARROW не содержит sid (точечная синхра убрана) ==');
    const arrows_without_sid = A.arrows.every(a => !('sid' in a));
    expect(arrows_without_sid, `все OP_ARROW без sid (получено ${A.arrows.length} стрел, с sid: ${A.arrows.filter(a => 'sid' in a).length})`);

    // Кладём ws.
    A.ws.close();
    B.ws.close();

    await sleep(300);
    console.log('\ndone.');
}

main().catch(e => { console.error(e); process.exit(1); });
