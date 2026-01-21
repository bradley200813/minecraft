# Genesis Colony - Project Status

## Overview

A self-replicating turtle colony system for CC:Tweaked (Minecraft mod) with a real-time web dashboard.

**GitHub Repo:** https://github.com/bradley200813/minecraft

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  MINECRAFT SERVER (CC:Tweaked)                                   │
│                                                                  │
│   🐢 Eve Turtle ◀─Rednet─▶ 💻 Bridge Computer ◀─HTTP─┐         │
│   🐢 Worker Turtles ◀────────────▶     "COLONY" protocol │       │
│                                                           │       │
└───────────────────────────────────────────────────────────│───────┘
                                                            │
                                                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  YOUR PC (Outside Minecraft)                                     │
│                                                                  │
│   ngrok tunnel ◀─────────────────────────────────────────────┘   │
│        │                                                         │
│        ▼                                                         │
│   Node.js server.js (port 3000 HTTP, 3001 WebSocket)            │
│        │                                                         │
│        └──WebSocket (bidirectional)──▶ Browser Dashboard        │
│                                                                  │
│   🎮 Control Panel: Move, Dig, Mine, Go Home, etc.              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Command Flow (Dashboard → Turtle)

1. User clicks a button in web dashboard (e.g., "Forward")
2. Dashboard sends command via WebSocket to Node.js server
3. Server queues command in `/api/commands`
4. Bridge computer polls `/api/commands` every second
5. Bridge sends command to turtle via Rednet
6. Turtle's Commander module executes the command
7. Result flows back: Turtle → Bridge → Server → Dashboard

---

## Current Status: ✅ WORKING

### What Works
- [x] **Installer** - `install.lua` creates all files with embedded code
- [x] **Eve Menu** - Interactive menu for turtle control
- [x] **Mining** - Branch mining pattern with auto-return
- [x] **Navigation** - Position tracking, go-to, go-home
- [x] **Inventory** - Fuel management, trash disposal, item counting
- [x] **Rednet Communication** - Turtles broadcast on "COLONY" protocol
- [x] **Bridge Computer** - Receives Rednet, forwards to HTTP (bidirectional)
- [x] **Node.js Server** - Receives HTTP, broadcasts via WebSocket
- [x] **Web Dashboard** - Real-time turtle map and status (live.html)
- [x] **ngrok Tunnel** - Allows remote Minecraft servers to reach dashboard
- [x] **Remote Control** - Control turtles from web dashboard! 🎮

### What's Partially Working
- [ ] **GPS Integration** - Works if GPS towers exist, falls back to relative positioning
- [ ] **GitHub Downloads** - Branch sync issues (use Pastebin instead)

### What's Not Implemented Yet
- [ ] **Turtle Crafting** - Recipe and crafting logic exists but not fully tested
- [ ] **Turtle Birth** - Placing and programming new turtles
- [ ] **Self-Replication** - Full colony expansion loop
- [ ] **Resource Sharing** - Turtles helping each other
- [ ] **Ore Detection** - Smart mining based on ore location

---

## File Structure

```
/colony/
├── lib/
│   ├── state.lua      # Persistent state (JSON file)
│   ├── nav.lua        # Navigation & position tracking
│   ├── inv.lua        # Inventory management
│   ├── comms.lua      # Rednet communication
│   ├── reporter.lua   # Status broadcasting
│   └── commander.lua  # Remote command handler 🆕
├── roles/
│   ├── miner.lua      # Mining behaviors
│   └── crafter.lua    # Crafting & turtle birth
├── brain.lua          # AI decision engine
├── startup.lua        # Boot sequence
├── eve.lua            # Eve's interactive menu
├── test.lua           # Rednet connectivity test
├── bridge.lua         # Web bridge (runs on Computer, not Turtle)
├── install.lua        # All-in-one installer
└── dashboard/
    └── bridge/
        ├── server.js  # Node.js WebSocket server (with command API)
        ├── live.html  # Browser dashboard (with control panel)
        └── package.json
```

---

## Installation Instructions

### On Turtle (Eve)

1. **Get installer via Pastebin:**
   - Upload `install.lua` to pastebin.com
   - In Minecraft: `pastebin get XXXXX install`
   - Run: `install`

2. **Setup Eve:**
   ```
   label set Eve-1
   refuel all
   /colony/eve
   ```

### On Bridge Computer (regular Computer with Wireless Modem)

1. Run same installer or just create bridge.lua
2. **IMPORTANT:** Edit the URL to your ngrok URL:
   ```lua
   local URL = "https://YOUR_NGROK_URL/api/update"
   ```
3. Run: `bridge`

### On Your PC (Dashboard)

1. **Start Node.js server:**
   ```powershell
   cd colony/dashboard/bridge
   npm install  # first time only
   node server.js
   ```

2. **Start ngrok tunnel:**
   ```powershell
   ngrok http 3000
   ```

3. **Open browser:** http://localhost:3000

---

## Key Technical Notes

### CC:Tweaked Compatibility
- Use `dofile()` instead of `require()` - CC:Tweaked doesn't support require
- Use proper spacing in code - compressed one-liners can cause parse errors
- Multiline strings `[[ ]]` work but be careful with special characters

### Communication Flow
1. Turtle calls `Reporter.heartbeat()` every 5 seconds
2. Broadcasts via Rednet on "COLONY" protocol
3. Bridge Computer receives and HTTP POSTs to Node.js
4. Node.js broadcasts via WebSocket to browser
5. Browser updates turtle map in real-time

### ngrok Setup
- Free tier gives random URLs that change on restart
- Update bridge.lua URL each time ngrok restarts
- Enable HTTP in `computercraft-server.toml`:
  ```toml
  [[http.rules]]
      host = "*.ngrok-free.app"
      action = "allow"
  ```

---

## Known Issues

1. **GitHub branch sync** - Local `master` and remote `main` got out of sync. Use Pastebin for installation instead.

2. **Nav.init() was missing** - Fixed in install.lua, but standalone files on GitHub may be outdated.

3. **Bridge URL hardcoded** - Must manually edit bridge.lua with ngrok URL on each session.

---

## Next Steps (Roadmap)

### Phase 1: Reliability ⬅️ CURRENT
- [x] Basic mining working
- [x] Dashboard connection working
- [ ] Test full mining cycle (mine → dump → refuel → repeat)
- [ ] Test on actual server

### Phase 2: Self-Replication
- [ ] Craft new turtles from mined resources
- [ ] Program new turtles via disk drive
- [ ] Copy colony code to child turtles
- [ ] Child turtle registration

### Phase 3: Colony Intelligence
- [ ] Task distribution
- [ ] Resource depot management
- [ ] Fuel station
- [ ] Ore processing

### Phase 4: Advanced Features
- [ ] GPS network auto-setup
- [ ] Chunk loading awareness
- [ ] Multiple mining patterns
- [ ] Dashboard controls (send commands to turtles)

---

## Quick Reference Commands

### In Minecraft

| Command | Description |
|---------|-------------|
| `install` | Run installer |
| `/colony/eve` | Start Eve menu |
| `/colony/test` | Test Rednet broadcasts |
| `bridge` | Start bridge on Computer |
| `label set Eve-1` | Name the turtle |
| `refuel all` | Fuel from inventory |

### On PC

| Command | Description |
|---------|-------------|
| `node server.js` | Start dashboard server |
| `ngrok http 3000` | Start tunnel |

---

## Session Notes

**Last Updated:** January 21, 2026

**Current ngrok URL:** `https://738e20244ec5.ngrok-free.app` (changes each session)

**Working:** Dashboard shows turtles when bridge forwards heartbeats correctly.

**Issue Resolved:** Fixed `Nav.init()` missing error by including it in embedded install.lua.
