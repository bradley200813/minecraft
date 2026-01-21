# 🖥️ Colony Dashboard

A beautiful real-time web interface to monitor your self-replicating turtle colony!

## Components

### 1. Dashboard Server (`server.lua`)
Run this on a CC:Tweaked **Computer** (not a turtle) with a wireless modem.

```
/colony/dashboard/server
```

**Features:**
- Receives status updates from all turtles via Rednet
- Generates real-time HTML dashboard
- Tracks colony statistics
- Event logging

### 2. Monitor Display (`monitor.lua`)
For in-game visualization using CC:Tweaked monitors.

```
/colony/dashboard/monitor
```

**Setup:**
1. Place a Computer next to your base
2. Attach a wireless modem
3. Attach monitors (any size, bigger = better)
4. Run the program

**Features:**
- Live turtle positions on map
- Fuel bars and status indicators
- Event log
- Works on any size monitor

### 3. Standalone HTML (`index.html`)
A web interface that can be opened in any browser.

**Features:**
- Beautiful dark theme with glow effects
- Animated turtle markers on colony map
- Real-time event log
- Responsive design for mobile

**Note:** The HTML file includes simulated demo data. To connect it to your actual colony, you'd need to:
1. Set up a WebSocket server
2. Bridge CC:Tweaked HTTP to WebSocket

### 4. Reporter Library (`lib/reporter.lua`)
Add to your turtles to send status updates to the dashboard.

**Usage:**
```lua
local Reporter = require("lib.reporter")
Reporter.init(Nav, Inv, State, Comms)

-- Send periodic heartbeat
Reporter.heartbeat()

-- Report events
Reporter.taskComplete("mining", {blocksMined = 50})
Reporter.lowFuel()
Reporter.inventoryFull()
Reporter.needHelp("stuck", {position = {x=10, y=64, z=20}})

-- Run as parallel task
Reporter.runParallel(function()
    -- Your main turtle code here
end)
```

## Setup Guide

### Basic Setup (In-Game Monitor)

1. **Place a Computer** near your turtle base
2. **Attach a Wireless Modem** (any side)
3. **Attach Monitors** (optional, for visual display)
4. **Copy colony files** to the computer:
   ```
   mkdir /colony/dashboard
   -- Copy server.lua and monitor.lua
   ```
5. **Run the dashboard:**
   ```
   /colony/dashboard/server
   ```

### Advanced Setup (Web Dashboard)

For real web access, you'll need to:

1. Use CC:Tweaked's HTTP API to serve content
2. Set up port forwarding or a tunnel (ngrok, etc.)
3. Connect the HTML client via WebSocket

**Example with HTTP Server:**
```lua
-- In your CC computer
http.listen(8080, function(request)
    local html = generateHTML()
    request.setStatusCode(200)
    request.setResponseHeader("Content-Type", "text/html")
    request.write(html)
end)
```

## Dashboard Views

### Colony Map
- 🐢 Green dots = Active workers
- 👑 Gold star = Eve (the first turtle)
- Dots pulse when turtles are actively working

### Turtle Cards
- **Border Color:**
  - Green = Online and idle
  - Yellow = Busy (mining/crafting)
  - Red = Offline (no heartbeat for 30s)
- **Fuel Bar:** Color-coded (red < 25%, yellow < 50%, green ≥ 50%)

### Event Log
- 🐣 Birth events (new turtles)
- ⛏️ Mining activities
- 🔧 Crafting events
- ⚠️ Warnings (low fuel, inventory full)
- ❌ Errors (stuck, help needed)

## Message Protocol

Turtles communicate via Rednet on the `COLONY` protocol:

| Message Type | Description |
|-------------|-------------|
| `heartbeat` | Regular status update (every 5s) |
| `hello` | Turtle joins colony |
| `goodbye` | Turtle disconnects |
| `task_complete` | Finished a task |
| `low_fuel` | Fuel below threshold |
| `inventory_full` | No inventory space |
| `help` | Turtle needs assistance |

## Customization

Edit the CSS in `index.html` to customize:
- Colors: Modify CSS variables in `:root`
- Layout: Adjust grid templates
- Animations: Add/remove keyframes

## Troubleshooting

**"No modem found"**
- Ensure a wireless modem is attached to the computer

**"No turtles showing"**
- Check turtles have wireless modems
- Verify turtles are using the Reporter library
- Ensure both use `COLONY` protocol

**Map positions wrong**
- Initialize GPS on your turtles
- Call `Nav.calibrate()` on each turtle

## Screenshots

```
╔══════════════════════════════════════╗
║     🐢 GENESIS COLONY 🐢             ║
╠══════════════════════════════════════╣
║  TURTLES: 5   │  MINED: 2,847        ║
║  BORN: 5      │  FUEL: 45,230        ║
╠══════════════════════════════════════╣
║  ● Eve-1       [EVE]     (0,64,0)    ║
║  ● Worker-2    [MINER]   (45,52,-12) ║
║  ● Worker-3    [MINER]   (-30,58,8)  ║
║  ○ Worker-4    [CRAFT]   (0,64,5)    ║
║  ● Worker-5    [MINER]   (22,48,-35) ║
╚══════════════════════════════════════╝
```

Enjoy watching your colony grow! 🐢✨
