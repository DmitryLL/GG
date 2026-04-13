# GG

2D top-down MMORPG — web first, mobile later.

## Stack

- **Client**: Vite + TypeScript + Phaser 4
- **Server**: Node.js + Colyseus (authoritative realtime)
- **Tunnel (dev)**: cloudflared

## Run locally

```bash
# terminal 1
cd server && npm install && npm run dev

# terminal 2
cd client && npm install && npm run dev
```

Open http://localhost:5173.

## Structure

- `client/` — browser game (Phaser)
- `server/` — realtime game server (Colyseus)
