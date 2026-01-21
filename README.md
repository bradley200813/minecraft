# 🐢 Genesis Colony - Self-Replicating Turtle System

A sophisticated CC:Tweaked turtle colony that mines, crafts, and **creates more turtles**.

## Quick Start

### 1. Prepare Eve (The First Turtle)

Craft a **Crafty Mining Turtle**:
- Mining Turtle + Crafting Table
- Or: Turtle + Diamond Pickaxe + Crafting Table

Equip a **Wireless Modem** (optional but recommended for colony communication).

### 2. Load the Colony Software

Copy the entire `colony` folder to your turtle. You can:
- Use a floppy disk
- Use the `pastebin` command
- Use `wget` to download

### 3. Start Eve

```lua
cd colony
lua eve.lua
```

Or set as startup:
```lua
copy colony/startup.lua startup.lua
reboot
```

### 4. Initial Resources

Give Eve starting resources:
- 64+ Coal (for fuel)
- Some iron, diamonds if you have them

## Project Structure

```
colony/
├── eve.lua              # First turtle bootstrap program
├── startup.lua          # Auto-run for all turtles
├── brain.lua            # AI decision engine
├── config.lua           # Colony configuration
├── simulator.lua        # Test without Minecraft
│
├── lib/
│   ├── state.lua        # Save/load persistence
│   ├── inv.lua          # Inventory management
│   ├── nav.lua          # Navigation & GPS
│   └── comms.lua        # Rednet communication
│
└── roles/
    ├── miner.lua        # Mining behaviors
    └── crafter.lua      # Crafting & turtle birth
```

## How It Works

### The Birth Cycle

1. **Eve** starts with basic resources
2. Eve **mines** to gather materials:
   - 7 Iron Ingots
   - 3 Diamonds
   - 1 Redstone
   - Stone, Glass, Planks, etc.
3. Eve **crafts** prerequisites:
   - Sticks, Chest, Glass Panes
   - Computer, Diamond Pickaxe
4. Eve **crafts a new turtle**
5. Eve **places** and **activates** the child
6. Child turtle **boots up**, joins the colony
7. Both continue mining and birthing...

### The Brain

Each turtle has a decision engine that weighs priorities:

| Situation | Priority | Action |
|-----------|----------|--------|
| Out of fuel | 100 | Find and consume fuel |
| Inventory full | 90 | Return home, deposit |
| Can birth turtle | 80 | Create new turtle! |
| Colony needs resources | 50 | Deliver items |
| Nothing to do | 20 | Mine for resources |

### Communication

Turtles communicate via Rednet:
- **HELLO** - Announce presence
- **HEARTBEAT** - Regular status update
- **NEED** - Request resources
- **HAVE** - Offer resources
- **TASK** - Assign work

## Testing with Simulator

You can test the colony logic without Minecraft:

```bash
cd colony
lua simulator.lua
```

Commands in simulator:
- `gen` - Generate world
- `spawn` - Create turtle
- `mine 20` - Mine 20 blocks
- `status` - Show turtle status
- `test` - Run test sequence

## Configuration

Edit `config.lua` to customize:

```lua
Config.MINING = {
    DEFAULT_PATTERN = "branch",  -- branch, tunnel, quarry, strip
    BRANCH_LENGTH = 20,
    OPTIMAL_Y_LEVEL = -59,       -- Diamond level
}

Config.BIRTH = {
    MAX_CHILDREN_PER_PARENT = 3,
}
```

## Requirements

- **CC:Tweaked** mod for Minecraft
- **Crafty Mining Turtle** (turtle with pickaxe + crafting table)
- **Wireless Modem** (optional, for colony communication)

## Tips

1. **Fuel First** - Always ensure Eve has plenty of fuel before starting
2. **Safe Location** - Start in a safe, enclosed area
3. **Chest Nearby** - Place a chest at the starting position for storage
4. **Patience** - The first turtle birth takes a while to gather materials

## The Dream

Start with **one turtle**.  
End with **an empire**.

```
Day 1:   🐢
Day 2:   🐢🐢
Day 3:   🐢🐢🐢🐢
Day 7:   🐢🐢🐢🐢🐢🐢🐢🐢🐢🐢🐢🐢🐢🐢🐢🐢
...
```

## License

Free to use, modify, and share. May your turtles multiply!
