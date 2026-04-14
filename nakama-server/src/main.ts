// Nakama runtime entry. Registers the persistent world match and an RPC
// clients call to discover (or lazily create) its id. Top-level declarations
// only — Nakama's goja loader wants InitModule as a global function.

const MATCH_MODULE = "world_match";
const MATCH_LABEL = "world";
const TICK_RATE = 10;

const OP_POSITIONS = 1; // server → clients
const OP_MOVE_INTENT = 2; // client → server

const PLAYER_SPAWN_X = 960;
const PLAYER_SPAWN_Y = 720;
const MAP_WIDTH = 1920;
const MAP_HEIGHT = 1440;

interface Vec2 { x: number; y: number; }

interface MatchPlayer {
    userId: string;
    sessionId: string;
    username: string;
    pos: Vec2;
    dirty: boolean;
}

interface WorldState {
    players: { [sessionId: string]: MatchPlayer };
}

// --- match handlers -----------------------------------------------

const matchInit: nkruntime.MatchInitFunction<WorldState> = function (_ctx, _logger, _nk, _params) {
    const state: WorldState = { players: {} };
    return { state, tickRate: TICK_RATE, label: MATCH_LABEL };
};

const matchJoinAttempt: nkruntime.MatchJoinAttemptFunction<WorldState> = function (
    _ctx, _logger, _nk, _dispatcher, _tick, state, _presence, _metadata,
) {
    return { state, accept: true };
};

const matchJoin: nkruntime.MatchJoinFunction<WorldState> = function (
    _ctx, _logger, _nk, _dispatcher, _tick, state, presences,
) {
    for (const p of presences) {
        state.players[p.sessionId] = {
            userId: p.userId,
            sessionId: p.sessionId,
            username: p.username,
            pos: { x: PLAYER_SPAWN_X, y: PLAYER_SPAWN_Y },
            dirty: true,
        };
    }
    return { state };
};

const matchLeave: nkruntime.MatchLeaveFunction<WorldState> = function (
    _ctx, _logger, _nk, _dispatcher, _tick, state, presences,
) {
    for (const p of presences) {
        delete state.players[p.sessionId];
    }
    return { state };
};

const matchLoop: nkruntime.MatchLoopFunction<WorldState> = function (
    _ctx, _logger, nk, dispatcher, _tick, state, messages,
) {
    for (const msg of messages) {
        if (msg.opCode !== OP_MOVE_INTENT) continue;
        const player = state.players[msg.sender.sessionId];
        if (!player) continue;
        try {
            const raw = nk.binaryToString(msg.data);
            const body = JSON.parse(raw) as { x?: number; y?: number };
            const x = Number(body.x);
            const y = Number(body.y);
            if (!isFinite(x) || !isFinite(y)) continue;
            if (x < 0 || x > MAP_WIDTH || y < 0 || y > MAP_HEIGHT) continue;
            player.pos.x = x;
            player.pos.y = y;
            player.dirty = true;
        } catch (_e) { /* malformed */ }
    }

    const updates: { sid: string; uid: string; n: string; x: number; y: number }[] = [];
    const keys = Object.keys(state.players);
    for (let i = 0; i < keys.length; i++) {
        const p = state.players[keys[i]];
        if (!p || !p.dirty) continue;
        updates.push({ sid: p.sessionId, uid: p.userId, n: p.username, x: p.pos.x, y: p.pos.y });
        p.dirty = false;
    }
    if (updates.length > 0) {
        dispatcher.broadcastMessage(OP_POSITIONS, JSON.stringify({ players: updates }));
    }
    return { state };
};

const matchTerminate: nkruntime.MatchTerminateFunction<WorldState> = function (
    _ctx, _logger, _nk, _dispatcher, _tick, state, _graceSeconds,
) {
    return { state };
};

const matchSignal: nkruntime.MatchSignalFunction<WorldState> = function (
    _ctx, _logger, _nk, _dispatcher, _tick, state, _data,
) {
    return { state };
};

// --- RPC: find or create the world match --------------------------

const rpcGetWorldMatch: nkruntime.RpcFunction = function (_ctx, _logger, nk, _payload) {
    const existing = nk.matchList(1, true, MATCH_LABEL);
    if (existing.length > 0) {
        return JSON.stringify({ match_id: existing[0].matchId });
    }
    const matchId = nk.matchCreate(MATCH_MODULE, {});
    return JSON.stringify({ match_id: matchId });
};

// --- init ---------------------------------------------------------

function InitModule(
    _ctx: nkruntime.Context,
    logger: nkruntime.Logger,
    _nk: nkruntime.Nakama,
    initializer: nkruntime.Initializer,
): void {
    initializer.registerMatch(MATCH_MODULE, {
        matchInit: matchInit,
        matchJoinAttempt: matchJoinAttempt,
        matchJoin: matchJoin,
        matchLeave: matchLeave,
        matchLoop: matchLoop,
        matchTerminate: matchTerminate,
        matchSignal: matchSignal,
    });
    initializer.registerRpc("get_world_match", rpcGetWorldMatch);
    logger.info("GG runtime loaded.");
}

// Silence unused-symbol warnings — Nakama discovers InitModule via goja.
!InitModule;
