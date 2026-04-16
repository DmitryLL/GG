// Быстрый дамп состояния матча через debug_state RPC.
// Использование:
//   node state.js                — полный снимок
//   node state.js mob             — только мобы
//   node state.js player          — только игроки
//   node state.js mob 12          — конкретный mob по индексу
//   node state.js mob slime       — все мобы типа
//   node state.js zone            — активные зоны (Ливень и т.п.)

const HOST = process.env.NK_HOST || 'nk.193-238-134-75.sslip.io';
const KEY = 'defaultkey';

async function getToken() {
    const r = await fetch(`https://${HOST}/v2/account/authenticate/device?create=true`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic ' + Buffer.from(`${KEY}:`).toString('base64'),
        },
        body: JSON.stringify({ id: 'debug-cli-' + (process.env.USER || 'anon') }),
    });
    const j = await r.json();
    if (!j.token) throw new Error('Auth failed: ' + JSON.stringify(j));
    return j.token;
}

async function callRpc(token, name, payload) {
    const r = await fetch(
        `https://${HOST}/v2/rpc/${name}?http_key=&unwrap`,
        {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + token,
            },
            body: JSON.stringify(payload),
        },
    );
    const text = await r.text();
    try { return JSON.parse(text); } catch { return text; }
}

(async () => {
    const filter = process.argv[2] || '';
    const subFilter = process.argv[3] || '';
    const token = await getToken();
    const payload = filter ? { filter } : {};
    const data = await callRpc(token, 'debug_state', payload);
    if (typeof data === 'string') { console.log(data); return; }

    if (subFilter && filter === 'mob') {
        let mobs = data.mobs || [];
        if (/^\d+$/.test(subFilter)) {
            const idx = parseInt(subFilter, 10);
            mobs = mobs[idx] ? [mobs[idx]] : [];
        } else {
            mobs = mobs.filter(m => m.type === subFilter);
        }
        console.log(JSON.stringify({ count: mobs.length, mobs }, null, 2));
        return;
    }

    // Краткий дамп: позиции и hp
    if (!filter) {
        console.log(`tick ${data.tick} ts ${data.ts}`);
        console.log(`players ${data.players?.length || 0}, mobs ${data.mobs?.length || 0}, zones ${data.zones?.length || 0}`);
        for (const p of (data.players || [])) {
            const cd = Object.entries(p.skillCd || {}).map(([k, v]) => `${k}:${Math.max(0, v - data.ts)}ms`).join(' ');
            console.log(`  P ${p.name} pos=(${p.pos.x.toFixed(0)},${p.pos.y.toFixed(0)}) hp=${p.hp}/${p.hpMax} lv${p.level} cd[${cd}]`);
        }
        for (const m of (data.mobs || [])) {
            const debuff = m.debuff ? ` poison×${m.debuff.poisonStacks}` : '';
            console.log(`  M ${m.id} ${m.type} pos=(${m.pos.x.toFixed(0)},${m.pos.y.toFixed(0)}) hp=${m.hp}/${m.hpMax} ${m.state}${debuff}`);
        }
        for (const z of (data.zones || [])) {
            console.log(`  Z ${z.kind} (${z.x.toFixed(0)},${z.y.toFixed(0)}) r=${z.radius} ends_in=${z.endAt - data.ts}ms`);
        }
        return;
    }
    console.log(JSON.stringify(data, null, 2));
})().catch(e => { console.error(e); process.exit(1); });
