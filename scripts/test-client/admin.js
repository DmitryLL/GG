// Админская CLI. Авторизуется как admin-пользователь, дёргает RPC `admin`.
//
// Авторизация: ник из админ-whitelist на сервере (см. ADMIN_USERNAMES в main.ts).
// По умолчанию используем "admin" (есть в whitelist), переопределить через --as=DmitryLL
//
// Команды:
//   node admin.js state                                  — снимок матча (как state.js)
//   node admin.js give gold=100 to=DmitryLL              — дать золото
//   node admin.js give item=golden_bow to=DmitryLL [qty=1] — дать предмет
//   node admin.js setlevel 50 to=DmitryLL                — установить уровень
//   node admin.js heal to=DmitryLL                       — полностью вылечить
//   node admin.js heal_all                               — вылечить всех
//   node admin.js teleport to=DmitryLL x=900 y=720       — телепортнуть игрока
//   node admin.js killmob m12                            — убить моба
//   node admin.js killall                                — убить всех мобов
//   node admin.js respawn                                — мгновенно респавнить мобов
//
// Опционально: --as=Username

const HOST = process.env.NK_HOST || 'nk.193-238-134-75.sslip.io';
const KEY = 'defaultkey';

function parseArgs() {
    const args = { _positional: [] };
    let asName = 'admin';
    for (const raw of process.argv.slice(2)) {
        if (raw.startsWith('--as=')) {
            asName = raw.substring(5);
            continue;
        }
        const eq = raw.indexOf('=');
        if (eq > 0) {
            args[raw.substring(0, eq)] = raw.substring(eq + 1);
        } else {
            args._positional.push(raw);
        }
    }
    args._asName = asName;
    return args;
}

async function authAs(name) {
    const id = ('admin_' + name).toLowerCase().replace(/[^a-z0-9_]/g, '_').padEnd(6, '_');
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

async function callRpc(token, name, payload) {
    const r = await fetch(`https://${HOST}/v2/rpc/${name}?unwrap`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
        body: JSON.stringify(payload),
    });
    const text = await r.text();
    try { return JSON.parse(text); } catch { return text; }
}

async function admin(token, op, fields) {
    return await callRpc(token, 'admin', { op, ...fields });
}

(async () => {
    const args = parseArgs();
    const cmd = args._positional[0];
    if (!cmd) { printHelp(); return; }

    const token = await authAs(args._asName);

    switch (cmd) {
        case 'state': {
            const snap = await callRpc(token, 'debug_state', {});
            console.log(JSON.stringify(snap, null, 2));
            break;
        }
        case 'list':
        case 'users': {
            const r = await admin(token, 'list_users', {});
            if (r && r.users) {
                console.log(`${r.users.length} users:`);
                for (const u of r.users) {
                    console.log(`  ${u.name.padEnd(20)} lv${u.level}  gold=${u.gold}  xp=${u.xp}`);
                }
            } else {
                console.log(r);
            }
            break;
        }
        case 'give': {
            if (args.gold) {
                console.log(await admin(token, 'give_gold', { target: args.to, amount: Number(args.gold) }));
            } else if (args.item) {
                console.log(await admin(token, 'give_item', { target: args.to, itemId: args.item, qty: Number(args.qty) || 1 }));
            } else {
                console.log('give что? добавь gold=N или item=ID');
            }
            break;
        }
        case 'setlevel': {
            const lvl = Number(args._positional[1]);
            console.log(await admin(token, 'set_level', { target: args.to, level: lvl }));
            break;
        }
        case 'sethp': {
            const hp = Number(args._positional[1]);
            console.log(await admin(token, 'set_hp', { target: args.to, hp }));
            break;
        }
        case 'heal': {
            console.log(await admin(token, 'set_hp', { target: args.to, hp: 9999 }));
            break;
        }
        case 'heal_all': {
            console.log(await admin(token, 'heal_all', {}));
            break;
        }
        case 'teleport': {
            console.log(await admin(token, 'teleport', { target: args.to, x: Number(args.x), y: Number(args.y) }));
            break;
        }
        case 'killmob': {
            const mid = args._positional[1];
            console.log(await admin(token, 'kill_mob', { mobId: mid }));
            break;
        }
        case 'killall': {
            console.log(await admin(token, 'killall_mobs', {}));
            break;
        }
        case 'respawn': {
            console.log(await admin(token, 'respawn_mobs', {}));
            break;
        }
        default:
            printHelp();
    }
})().catch(e => { console.error(e); process.exit(1); });

function printHelp() {
    console.log(`Использование: node admin.js <команда> [args] [--as=Username]

Команды:
  state                                    — снимок матча (онлайн)
  list                                     — все юзеры из Storage (онлайн+оффлайн)
  give gold=N to=NAME                      — выдать золото
  give item=ITEM_ID to=NAME [qty=N]        — выдать предмет
  setlevel N to=NAME                       — установить уровень
  sethp N to=NAME                          — установить HP
  heal to=NAME                             — полное лечение
  heal_all                                 — вылечить всех
  teleport to=NAME x=N y=N                 — телепортация
  killmob mobId                            — убить моба
  killall                                  — убить всех мобов
  respawn                                  — респавн всех мобов

По умолчанию авторизуется как admin (в whitelist на сервере).
Переопределить: --as=DmitryLL`);
}
