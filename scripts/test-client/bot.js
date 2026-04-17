// Минимальный клиент-бот для тестов: коннектится к Nakama, входит в матч,
// шлёт указанные действия (move/attack/skill/equip), затем выводит итог.
//
// Использование:
//   node bot.js name=tester1 attack=m0          — атаковать моба m0
//   node bot.js name=tester1 skill=1 mob=m0     — кастонуть скилл 1 на m0
//   node bot.js name=tester1 skill=2 x=900 y=700  — Ливень в точке
//   node bot.js name=tester1 move=900,700        — двинуться в точку
//   node bot.js name=tester1 equip=wood_bow      — надеть лук (если есть в инвентаре)
//
// После каждого действия бот ждёт 2 сек и выходит.

import WebSocket from 'ws';

const HOST = process.env.NK_HOST || 'nk.193-238-134-75.sslip.io';
const KEY = 'defaultkey';

const args = {};
for (const a of process.argv.slice(2)) {
    const [k, v] = a.split('=');
    args[k] = v;
}
const NAME = args.name || ('bot_' + Math.random().toString(36).slice(2, 6));

const OP_MOVE_INTENT = 2;
const OP_ATTACK = 4;
const OP_EQUIP = 9;
const OP_SKILL = 20;

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

async function main() {
    const slug = ('test_' + NAME).toLowerCase().replace(/[^a-z0-9_]/g, '_');
    const token = await authDevice(slug.padEnd(6, '_'), NAME);
    console.log(`auth ok as ${NAME}`);

    const matchId = await rpcGetMatch(token);
    console.log(`match ${matchId}`);

    const ws = await connectWS(token);
    let mySid = '';

    ws.on('message', (raw) => {
        const m = JSON.parse(raw.toString());
        if (m.match_data) {
            const op = m.match_data.op_code;
            if (op === '8') {
                const me = JSON.parse(Buffer.from(m.match_data.data, 'base64').toString());
                console.log(`OP_ME hp=${me.hp}/${me.hpMax} lv=${me.level} eq=${JSON.stringify(me.eq)}`);
            }
        }
        if (m.match_presence_event) {
            for (const p of (m.match_presence_event.joins || [])) {
                if (p.user_id) mySid = p.session_id;
            }
        }
    });

    // Join match
    send(ws, { match_join: { match_id: matchId } });
    await sleep(800);

    // Run requested action
    if (args.move) {
        const [x, y] = args.move.split(',').map(Number);
        send(ws, { match_data_send: { match_id: matchId, op_code: OP_MOVE_INTENT, data: b64({ x, y }) } });
        console.log(`move → ${x},${y}`);
    }
    if (args.attack) {
        send(ws, { match_data_send: { match_id: matchId, op_code: OP_ATTACK, data: b64({ mobId: args.attack }) } });
        console.log(`attack ${args.attack}`);
    }
    if (args.skill) {
        const skillNum = Number(args.skill);
        const payload = { skill: skillNum };
        if (args.mob) payload.mobId = args.mob;
        if (args.sid) payload.sid = args.sid;
        if (args.x !== undefined) payload.x = Number(args.x);
        if (args.y !== undefined) payload.y = Number(args.y);
        if (args.dx !== undefined) payload.dx = Number(args.dx);
        if (args.dy !== undefined) payload.dy = Number(args.dy);
        send(ws, { match_data_send: { match_id: matchId, op_code: OP_SKILL, data: b64(payload) } });
        console.log(`skill ${skillNum} ${JSON.stringify(payload)}`);
    }
    if (args.equip !== undefined) {
        const slot = Number(args.equip);
        if (Number.isFinite(slot)) {
            send(ws, { match_data_send: { match_id: matchId, op_code: OP_EQUIP, data: b64({ slot }) } });
            console.log(`equip slot ${slot}`);
        }
    }

    await sleep(2000);
    ws.close();
    console.log('done');
}

function b64(o) { return Buffer.from(JSON.stringify(o)).toString('base64'); }
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

main().catch(e => { console.error(e); process.exit(1); });
