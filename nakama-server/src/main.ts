// Nakama runtime entry. All top-level function declarations so goja can
// resolve them as global symbols (its script mode doesn't expose
// const-bound arrow functions to host lookups the same way).

const MATCH_MODULE = "world_match";
const MATCH_LABEL = "world";
const TICK_RATE = 10;

const OP_POSITIONS = 1;
const OP_MOVE_INTENT = 2;

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

function matchInit(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _params: { [key: string]: string }): { state: WorldState; tickRate: number; label: string } {
    const state: WorldState = { players: {} };
    return { state: state, tickRate: TICK_RATE, label: MATCH_LABEL };
}

function matchJoinAttempt(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, _presence: nkruntime.Presence, _metadata: { [key: string]: any }): { state: WorldState; accept: boolean; rejectMessage?: string } {
    return { state: state, accept: true };
}

function matchJoin(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, presences: nkruntime.Presence[]): { state: WorldState } | null {
    for (let i = 0; i < presences.length; i++) {
        const p = presences[i];
        state.players[p.sessionId] = {
            userId: p.userId,
            sessionId: p.sessionId,
            username: p.username,
            pos: { x: PLAYER_SPAWN_X, y: PLAYER_SPAWN_Y },
            dirty: true,
        };
    }
    return { state: state };
}

function matchLeave(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, presences: nkruntime.Presence[]): { state: WorldState } | null {
    for (let i = 0; i < presences.length; i++) {
        delete state.players[presences[i].sessionId];
    }
    return { state: state };
}

function matchLoop(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, messages: nkruntime.MatchMessage[]): { state: WorldState } | null {
    for (let i = 0; i < messages.length; i++) {
        const msg = messages[i];
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
    return { state: state };
}

function matchTerminate(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, _graceSeconds: number): { state: WorldState } | null {
    return { state: state };
}

function matchSignal(_ctx: nkruntime.Context, _logger: nkruntime.Logger, _nk: nkruntime.Nakama, _dispatcher: nkruntime.MatchDispatcher, _tick: number, state: WorldState, _data: string): { state: WorldState; data?: string } | null {
    return { state: state };
}

function rpcGetWorldMatch(_ctx: nkruntime.Context, _logger: nkruntime.Logger, nk: nkruntime.Nakama, _payload: string): string {
    const existing = nk.matchList(1, true, MATCH_LABEL);
    if (existing.length > 0) {
        return JSON.stringify({ match_id: existing[0].matchId });
    }
    const matchId = nk.matchCreate(MATCH_MODULE, {});
    return JSON.stringify({ match_id: matchId });
}

function InitModule(_ctx: nkruntime.Context, logger: nkruntime.Logger, _nk: nkruntime.Nakama, initializer: nkruntime.Initializer): void {
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

// Satisfy noUnusedLocals — Nakama discovers InitModule via goja global scope.
!InitModule && InitModule;
