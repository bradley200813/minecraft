# 🌐 Colony Web Bridge

See your real Minecraft turtles in your web browser!

## How It Works

```
┌─────────────────┐      Rednet       ┌─────────────────┐      HTTP       ┌─────────────────┐
│   🐢 Turtles    │ ───────────────▶ │  CC Computer    │ ─────────────▶ │   Node.js       │
│   (in game)     │                   │  (sender.lua)   │                 │   (server.js)   │
└─────────────────┘                   └─────────────────┘                 └────────┬────────┘
                                                                                   │
                                                                              WebSocket
                                                                                   │
                                                                                   ▼
                                                                          ┌─────────────────┐
                                                                          │   🌐 Browser    │
                                                                          │   (live.html)   │
                                                                          └─────────────────┘
```

## Quick Start

### Step 1: Start the Bridge Server (on your PC)

```bash
cd colony/dashboard/bridge
node server.js
```

You should see:
```
🐢 ═══════════════════════════════════════════
   GENESIS COLONY BRIDGE SERVER
═══════════════════════════════════════════════

   Dashboard:  http://localhost:3000
   WebSocket:  ws://localhost:3001
   API:        http://localhost:3000/api/update

   Waiting for turtles to connect...
```

### Step 2: Open the Dashboard

Open your browser and go to: **http://localhost:3000**

### Step 3: Setup In-Game Bridge (Minecraft)

1. **Enable HTTP** in CC:Tweaked config:
   
   Edit `config/computercraft-server.toml`:
   ```toml
   [[http.rules]]
   host = "*"
   action = "allow"
   ```

2. **Place a Computer** in Minecraft near your turtle base

3. **Attach a Wireless Modem** to the computer

4. **Copy sender.lua** to the computer:
   ```
   edit sender
   -- paste the code
   ```

5. **Run the sender**:
   ```
   sender
   ```

### Step 4: Start Your Turtles

Run your colony turtles with the Reporter library enabled. They'll automatically send updates!

## Configuration

### Bridge Server (server.js)

| Setting | Default | Description |
|---------|---------|-------------|
| PORT | 3000 | HTTP server port |
| WS_PORT | 3001 | WebSocket port |

### CC Sender (sender.lua)

Edit the CONFIG table at the top:

```lua
local CONFIG = {
    serverUrl = "http://localhost:3000/api/update",  -- Change if server is elsewhere
    heartbeatInterval = 5,
    protocol = "COLONY",
}
```

**If your Minecraft is on a different PC:**
1. Find your PC's IP address (run `ipconfig` on Windows)
2. Change `localhost` to your IP: `http://192.168.1.100:3000/api/update`

## Features

### Live Dashboard
- 🗺️ Real-time colony map with turtle positions
- 📊 Stats: turtles online, blocks mined, births, total fuel
- 📜 Live event feed
- 🐢 Individual turtle status cards

### Automatic Reconnection
- Browser reconnects if WebSocket disconnects
- CC sender queues messages if server is unavailable

### Low Resource Usage
- No database required
- Minimal CPU/memory usage
- Works on any modern browser

## Troubleshooting

### "HTTP API not available" in Minecraft

Enable HTTP in CC:Tweaked config:
1. Find `config/computercraft-server.toml` in your Minecraft folder
2. Add these lines:
   ```toml
   [[http.rules]]
   host = "*"
   action = "allow"
   ```
3. Restart Minecraft

### Browser shows "Connecting..."

1. Make sure Node.js server is running
2. Check the console for errors
3. Try refreshing the page

### Turtles not showing up

1. Ensure turtles have the Reporter library
2. Check that sender.lua is running
3. Verify wireless modems are attached
4. Check they're using the "COLONY" protocol

### Works locally but not from another PC

1. Use your actual IP instead of localhost
2. Allow ports 3000 and 3001 through firewall
3. Make sure both PCs are on same network

## API Reference

### POST /api/update

Send turtle updates:

```json
{
  "type": "heartbeat",
  "turtle": {
    "id": 1,
    "label": "Eve-1",
    "role": "eve",
    "position": {"x": 0, "y": 64, "z": 0},
    "fuel": 15000,
    "fuelLimit": 20000,
    "state": "idle",
    "generation": 0
  }
}
```

### GET /api/status

Get current colony state:

```json
{
  "name": "Genesis",
  "turtles": {...},
  "events": [...],
  "stats": {
    "totalBlocksMined": 1234,
    "totalTurtlesBorn": 5
  }
}
```

### WebSocket (port 3001)

Connect to receive real-time updates:

```javascript
const ws = new WebSocket('ws://localhost:3001');
ws.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  // msg.type: 'init', 'turtle', 'event', 'stats'
};
```

## Files

| File | Description |
|------|-------------|
| `server.js` | Node.js bridge server |
| `live.html` | Web dashboard UI |
| `sender.lua` | CC:Tweaked HTTP sender |
| `package.json` | Node.js package info |

Enjoy watching your colony grow! 🐢✨
