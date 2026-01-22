# Simple Colony

A simplified turtle control system for CC:Tweaked.

## Files

- `turtle.lua` - All-in-one turtle script (movement, mining, commands)
- `bridge.lua` - Relay computer script (forwards messages to web)
- `server.js` - Node.js web dashboard
- `install.lua` - One-command installer

## Quick Start

### 1. Start the server

```bash
cd colony/simple
node server.js
```

### 2. Set up ngrok (for external access)

```bash
ngrok http 3000
```

Copy the ngrok URL.

### 3. Install on turtle

On a **Mining Turtle** in Minecraft:

```
wget run https://raw.githubusercontent.com/bradley200813/minecraft/main/colony/simple/install.lua
label set MyTurtle
reboot
```

### 4. Install on bridge computer

On a **Computer** with wireless modem:

```
wget run https://raw.githubusercontent.com/bradley200813/minecraft/main/colony/simple/install.lua
edit /colony/bridge.lua
```

Change `SERVER_URL` to your ngrok URL, then:

```
reboot
```

### 5. Open dashboard

Go to `http://localhost:3000` in your browser.

## Commands

| Command | Description |
|---------|-------------|
| `forward`, `back`, `up`, `down` | Move |
| `turnLeft`, `turnRight` | Turn |
| `dig`, `digUp`, `digDown` | Dig |
| `quarry {size: 8}` | Mine a square down |
| `tunnel {length: 50}` | Dig a tunnel |
| `stop` | Stop current task |
| `refuel` | Refuel from inventory |
| `dropTrash` | Drop cobblestone, dirt, etc |
| `goHome` | Return to home position |
| `setHome` | Set current pos as home |
| `status` | Get turtle status |

## Architecture

```
[Turtle] --rednet--> [Bridge Computer] --http--> [Node Server] --ws--> [Browser]
```

That's it. No complicated modules, no state machines, just simple code.
