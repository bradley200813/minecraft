-- ============================================
-- SIMULATOR.LUA - Test Colony Scripts Locally
-- ============================================
-- Simulates the CC:Tweaked turtle API for testing
-- Run this with regular Lua (not in Minecraft)

print("========================================")
print("  COLONY SIMULATOR")
print("  Test your turtle scripts locally!")
print("========================================")
print("")

-- ==========================================
-- SIMULATED WORLD
-- ==========================================

local World = {
    blocks = {},      -- [x][y][z] = blockData
    turtles = {},     -- List of simulated turtles
    chests = {},      -- Chest inventories
    time = 0,
}

-- Block types
local BLOCKS = {
    AIR = nil,
    STONE = { name = "minecraft:stone" },
    COBBLESTONE = { name = "minecraft:cobblestone" },
    DIRT = { name = "minecraft:dirt" },
    IRON_ORE = { name = "minecraft:iron_ore" },
    DIAMOND_ORE = { name = "minecraft:diamond_ore" },
    COAL_ORE = { name = "minecraft:coal_ore" },
    REDSTONE_ORE = { name = "minecraft:redstone_ore" },
    CHEST = { name = "minecraft:chest" },
    BEDROCK = { name = "minecraft:bedrock" },
}

-- Generate world
function World.generate(sizeX, sizeY, sizeZ)
    sizeX = sizeX or 64
    sizeY = sizeY or 64
    sizeZ = sizeZ or 64
    
    print("[WORLD] Generating " .. sizeX .. "x" .. sizeY .. "x" .. sizeZ .. " world...")
    
    World.blocks = {}
    World.sizeX = sizeX
    World.sizeY = sizeY
    World.sizeZ = sizeZ
    
    for x = 0, sizeX - 1 do
        World.blocks[x] = {}
        for y = 0, sizeY - 1 do
            World.blocks[x][y] = {}
            for z = 0, sizeZ - 1 do
                -- Generate terrain
                if y == 0 then
                    World.blocks[x][y][z] = BLOCKS.BEDROCK
                elseif y < sizeY / 2 then
                    -- Underground
                    local rand = math.random(100)
                    if rand <= 1 then
                        World.blocks[x][y][z] = BLOCKS.DIAMOND_ORE
                    elseif rand <= 5 then
                        World.blocks[x][y][z] = BLOCKS.IRON_ORE
                    elseif rand <= 10 then
                        World.blocks[x][y][z] = BLOCKS.COAL_ORE
                    elseif rand <= 12 then
                        World.blocks[x][y][z] = BLOCKS.REDSTONE_ORE
                    else
                        World.blocks[x][y][z] = BLOCKS.STONE
                    end
                elseif y == math.floor(sizeY / 2) then
                    World.blocks[x][y][z] = BLOCKS.DIRT
                else
                    -- Air above ground
                    World.blocks[x][y][z] = nil
                end
            end
        end
    end
    
    print("[WORLD] Generated!")
end

function World.getBlock(x, y, z)
    if x < 0 or x >= World.sizeX then return BLOCKS.BEDROCK end
    if y < 0 or y >= World.sizeY then return BLOCKS.BEDROCK end
    if z < 0 or z >= World.sizeZ then return BLOCKS.BEDROCK end
    
    return World.blocks[x][y][z]
end

function World.setBlock(x, y, z, block)
    if x < 0 or x >= World.sizeX then return false end
    if y < 0 or y >= World.sizeY then return false end
    if z < 0 or z >= World.sizeZ then return false end
    
    World.blocks[x][y][z] = block
    return true
end

-- ==========================================
-- SIMULATED TURTLE
-- ==========================================

local SimTurtle = {}
SimTurtle.__index = SimTurtle

function SimTurtle.new(id, x, y, z, facing)
    local self = setmetatable({}, SimTurtle)
    
    self.id = id or 1
    self.label = "Turtle-" .. self.id
    self.x = x or 32
    self.y = y or 33  -- Start on surface
    self.z = z or 32
    self.facing = facing or 0  -- 0=N, 1=E, 2=S, 3=W
    
    self.fuel = 1000
    self.fuelLimit = 20000
    
    self.inventory = {}
    for i = 1, 16 do
        self.inventory[i] = nil
    end
    self.selectedSlot = 1
    
    self.stats = {
        blocksMined = 0,
        blocksMoved = 0,
        itemsCrafted = 0,
    }
    
    table.insert(World.turtles, self)
    
    return self
end

-- Direction vectors
local DIR_VECTORS = {
    [0] = { x = 0, z = -1 },  -- North
    [1] = { x = 1, z = 0 },   -- East
    [2] = { x = 0, z = 1 },   -- South
    [3] = { x = -1, z = 0 },  -- West
}

function SimTurtle:getFrontPos()
    local vec = DIR_VECTORS[self.facing]
    return self.x + vec.x, self.y, self.z + vec.z
end

function SimTurtle:forward()
    if self.fuel <= 0 then
        return false, "Out of fuel"
    end
    
    local nx, ny, nz = self:getFrontPos()
    local block = World.getBlock(nx, ny, nz)
    
    if block then
        return false, "Movement obstructed"
    end
    
    self.x, self.y, self.z = nx, ny, nz
    self.fuel = self.fuel - 1
    self.stats.blocksMoved = self.stats.blocksMoved + 1
    return true
end

function SimTurtle:back()
    if self.fuel <= 0 then
        return false, "Out of fuel"
    end
    
    local vec = DIR_VECTORS[self.facing]
    local nx = self.x - vec.x
    local nz = self.z - vec.z
    local block = World.getBlock(nx, self.y, nz)
    
    if block then
        return false, "Movement obstructed"
    end
    
    self.x, self.z = nx, nz
    self.fuel = self.fuel - 1
    self.stats.blocksMoved = self.stats.blocksMoved + 1
    return true
end

function SimTurtle:up()
    if self.fuel <= 0 then
        return false, "Out of fuel"
    end
    
    local block = World.getBlock(self.x, self.y + 1, self.z)
    if block then
        return false, "Movement obstructed"
    end
    
    self.y = self.y + 1
    self.fuel = self.fuel - 1
    self.stats.blocksMoved = self.stats.blocksMoved + 1
    return true
end

function SimTurtle:down()
    if self.fuel <= 0 then
        return false, "Out of fuel"
    end
    
    local block = World.getBlock(self.x, self.y - 1, self.z)
    if block then
        return false, "Movement obstructed"
    end
    
    self.y = self.y - 1
    self.fuel = self.fuel - 1
    self.stats.blocksMoved = self.stats.blocksMoved + 1
    return true
end

function SimTurtle:turnLeft()
    self.facing = (self.facing - 1) % 4
    return true
end

function SimTurtle:turnRight()
    self.facing = (self.facing + 1) % 4
    return true
end

function SimTurtle:dig()
    local x, y, z = self:getFrontPos()
    local block = World.getBlock(x, y, z)
    
    if not block then
        return false, "Nothing to dig here"
    end
    
    if block.name == "minecraft:bedrock" then
        return false, "Unbreakable block detected"
    end
    
    -- Add to inventory
    self:addToInventory(block)
    World.setBlock(x, y, z, nil)
    self.stats.blocksMined = self.stats.blocksMined + 1
    
    return true
end

function SimTurtle:digUp()
    local block = World.getBlock(self.x, self.y + 1, self.z)
    
    if not block then
        return false, "Nothing to dig here"
    end
    
    if block.name == "minecraft:bedrock" then
        return false, "Unbreakable block detected"
    end
    
    self:addToInventory(block)
    World.setBlock(self.x, self.y + 1, self.z, nil)
    self.stats.blocksMined = self.stats.blocksMined + 1
    
    return true
end

function SimTurtle:digDown()
    local block = World.getBlock(self.x, self.y - 1, self.z)
    
    if not block then
        return false, "Nothing to dig here"
    end
    
    if block.name == "minecraft:bedrock" then
        return false, "Unbreakable block detected"
    end
    
    self:addToInventory(block)
    World.setBlock(self.x, self.y - 1, self.z, nil)
    self.stats.blocksMined = self.stats.blocksMined + 1
    
    return true
end

function SimTurtle:detect()
    local x, y, z = self:getFrontPos()
    return World.getBlock(x, y, z) ~= nil
end

function SimTurtle:detectUp()
    return World.getBlock(self.x, self.y + 1, self.z) ~= nil
end

function SimTurtle:detectDown()
    return World.getBlock(self.x, self.y - 1, self.z) ~= nil
end

function SimTurtle:inspect()
    local x, y, z = self:getFrontPos()
    local block = World.getBlock(x, y, z)
    if block then
        return true, { name = block.name }
    end
    return false, "No block to inspect"
end

function SimTurtle:inspectUp()
    local block = World.getBlock(self.x, self.y + 1, self.z)
    if block then
        return true, { name = block.name }
    end
    return false, "No block to inspect"
end

function SimTurtle:inspectDown()
    local block = World.getBlock(self.x, self.y - 1, self.z)
    if block then
        return true, { name = block.name }
    end
    return false, "No block to inspect"
end

function SimTurtle:addToInventory(item)
    -- Convert block to drop
    local dropName = item.name
    if dropName == "minecraft:stone" then
        dropName = "minecraft:cobblestone"
    elseif dropName:find("_ore") then
        -- Silk touch simulation - keep ore
    end
    
    -- Find existing stack
    for slot = 1, 16 do
        if self.inventory[slot] and self.inventory[slot].name == dropName then
            if self.inventory[slot].count < 64 then
                self.inventory[slot].count = self.inventory[slot].count + 1
                return true
            end
        end
    end
    
    -- Find empty slot
    for slot = 1, 16 do
        if not self.inventory[slot] then
            self.inventory[slot] = { name = dropName, count = 1 }
            return true
        end
    end
    
    return false  -- Inventory full
end

function SimTurtle:select(slot)
    if slot < 1 or slot > 16 then
        error("Invalid slot")
    end
    self.selectedSlot = slot
    return true
end

function SimTurtle:getSelectedSlot()
    return self.selectedSlot
end

function SimTurtle:getItemCount(slot)
    slot = slot or self.selectedSlot
    if self.inventory[slot] then
        return self.inventory[slot].count
    end
    return 0
end

function SimTurtle:getItemSpace(slot)
    slot = slot or self.selectedSlot
    if self.inventory[slot] then
        return 64 - self.inventory[slot].count
    end
    return 64
end

function SimTurtle:getItemDetail(slot, detailed)
    slot = slot or self.selectedSlot
    return self.inventory[slot]
end

function SimTurtle:getFuelLevel()
    return self.fuel
end

function SimTurtle:getFuelLimit()
    return self.fuelLimit
end

function SimTurtle:refuel(count)
    count = count or 64
    local item = self.inventory[self.selectedSlot]
    if not item then
        return false, "No items to combust"
    end
    
    local fuelValues = {
        ["minecraft:coal"] = 80,
        ["minecraft:coal_ore"] = 80,
        ["minecraft:charcoal"] = 80,
        ["minecraft:coal_block"] = 800,
    }
    
    local value = fuelValues[item.name]
    if not value then
        return false, "Items are not combustible"
    end
    
    local toUse = math.min(count, item.count)
    self.fuel = math.min(self.fuelLimit, self.fuel + (value * toUse))
    item.count = item.count - toUse
    
    if item.count <= 0 then
        self.inventory[self.selectedSlot] = nil
    end
    
    return true
end

function SimTurtle:drop(count)
    local item = self.inventory[self.selectedSlot]
    if not item then
        return false, "No items to drop"
    end
    
    count = count or item.count
    item.count = item.count - count
    if item.count <= 0 then
        self.inventory[self.selectedSlot] = nil
    end
    
    return true
end

function SimTurtle:dropUp(count)
    return self:drop(count)
end

function SimTurtle:dropDown(count)
    return self:drop(count)
end

function SimTurtle:place()
    local item = self.inventory[self.selectedSlot]
    if not item then
        return false, "No items to place"
    end
    
    local x, y, z = self:getFrontPos()
    if World.getBlock(x, y, z) then
        return false, "Block already exists"
    end
    
    World.setBlock(x, y, z, { name = item.name })
    item.count = item.count - 1
    if item.count <= 0 then
        self.inventory[self.selectedSlot] = nil
    end
    
    return true
end

function SimTurtle:transferTo(slot, count)
    local source = self.inventory[self.selectedSlot]
    if not source then
        return false
    end
    
    count = count or source.count
    local target = self.inventory[slot]
    
    if target then
        if target.name ~= source.name then
            return false
        end
        local space = 64 - target.count
        local toMove = math.min(count, source.count, space)
        target.count = target.count + toMove
        source.count = source.count - toMove
    else
        local toMove = math.min(count, source.count)
        self.inventory[slot] = { name = source.name, count = toMove }
        source.count = source.count - toMove
    end
    
    if source.count <= 0 then
        self.inventory[self.selectedSlot] = nil
    end
    
    return true
end

function SimTurtle:suck(count)
    -- Simulate picking up item
    return false, "No items to suck"
end

function SimTurtle:attack()
    return false, "Nothing to attack"
end

function SimTurtle:attackUp()
    return false, "Nothing to attack"
end

function SimTurtle:attackDown()
    return false, "Nothing to attack"
end

function SimTurtle:craft(count)
    -- Simplified crafting check
    return false, "Crafting not fully simulated"
end

function SimTurtle:equipLeft()
    return true
end

function SimTurtle:equipRight()
    return true
end

function SimTurtle:compareTo(slot)
    local a = self.inventory[self.selectedSlot]
    local b = self.inventory[slot]
    if not a and not b then return true end
    if not a or not b then return false end
    return a.name == b.name
end

function SimTurtle:getPosition()
    return self.x, self.y, self.z
end

function SimTurtle:status()
    local dirs = { [0] = "N", [1] = "E", [2] = "S", [3] = "W" }
    print(string.format("Pos: (%d, %d, %d) Facing: %s", 
        self.x, self.y, self.z, dirs[self.facing]))
    print(string.format("Fuel: %d/%d", self.fuel, self.fuelLimit))
    print(string.format("Stats: Mined=%d Moved=%d",
        self.stats.blocksMined, self.stats.blocksMoved))
    
    print("Inventory:")
    for slot = 1, 16 do
        if self.inventory[slot] then
            print(string.format("  [%d] %s x%d", 
                slot, self.inventory[slot].name, self.inventory[slot].count))
        end
    end
end

-- ==========================================
-- GLOBAL TURTLE API (mimics CC:Tweaked)
-- ==========================================

local currentTurtle = nil

function setCurrentTurtle(t)
    currentTurtle = t
end

-- Create global turtle table
turtle = {}

function turtle.forward() return currentTurtle:forward() end
function turtle.back() return currentTurtle:back() end
function turtle.up() return currentTurtle:up() end
function turtle.down() return currentTurtle:down() end
function turtle.turnLeft() return currentTurtle:turnLeft() end
function turtle.turnRight() return currentTurtle:turnRight() end
function turtle.dig() return currentTurtle:dig() end
function turtle.digUp() return currentTurtle:digUp() end
function turtle.digDown() return currentTurtle:digDown() end
function turtle.detect() return currentTurtle:detect() end
function turtle.detectUp() return currentTurtle:detectUp() end
function turtle.detectDown() return currentTurtle:detectDown() end
function turtle.inspect() return currentTurtle:inspect() end
function turtle.inspectUp() return currentTurtle:inspectUp() end
function turtle.inspectDown() return currentTurtle:inspectDown() end
function turtle.select(s) return currentTurtle:select(s) end
function turtle.getSelectedSlot() return currentTurtle:getSelectedSlot() end
function turtle.getItemCount(s) return currentTurtle:getItemCount(s) end
function turtle.getItemSpace(s) return currentTurtle:getItemSpace(s) end
function turtle.getItemDetail(s, d) return currentTurtle:getItemDetail(s, d) end
function turtle.getFuelLevel() return currentTurtle:getFuelLevel() end
function turtle.getFuelLimit() return currentTurtle:getFuelLimit() end
function turtle.refuel(c) return currentTurtle:refuel(c) end
function turtle.drop(c) return currentTurtle:drop(c) end
function turtle.dropUp(c) return currentTurtle:dropUp(c) end
function turtle.dropDown(c) return currentTurtle:dropDown(c) end
function turtle.place() return currentTurtle:place() end
function turtle.placeUp() return currentTurtle:placeUp() end
function turtle.placeDown() return currentTurtle:placeDown() end
function turtle.suck(c) return currentTurtle:suck(c) end
function turtle.suckUp(c) return currentTurtle:suckUp(c) end
function turtle.suckDown(c) return currentTurtle:suckDown(c) end
function turtle.attack() return currentTurtle:attack() end
function turtle.attackUp() return currentTurtle:attackUp() end
function turtle.attackDown() return currentTurtle:attackDown() end
function turtle.transferTo(s, c) return currentTurtle:transferTo(s, c) end
function turtle.craft(c) return currentTurtle:craft(c) end
function turtle.equipLeft() return currentTurtle:equipLeft() end
function turtle.equipRight() return currentTurtle:equipRight() end
function turtle.compareTo(s) return currentTurtle:compareTo(s) end

-- ==========================================
-- OTHER CC:TWEAKED API STUBS
-- ==========================================

os = os or {}
local realOs = os

os.getComputerID = function() return currentTurtle and currentTurtle.id or 1 end
os.getComputerLabel = function() return currentTurtle and currentTurtle.label or nil end
os.setComputerLabel = function(l) if currentTurtle then currentTurtle.label = l end end
os.epoch = function(t) return realOs.time() * 1000 end
os.pullEvent = function(f) 
    io.write("Waiting for event (" .. (f or "any") .. ")... press Enter: ")
    io.read()
    return f or "key", "enter"
end
os.reboot = function() print("[SIM] Reboot requested") end

fs = {
    exists = function(p) return false end,
    makeDir = function(p) end,
    open = function(p, m) return nil end,
    delete = function(p) end,
    copy = function(s, d) end,
}

textutils = {
    serialize = function(t) 
        -- Simple serializer
        local function ser(v, indent)
            indent = indent or ""
            if type(v) == "table" then
                local s = "{\n"
                for k, val in pairs(v) do
                    s = s .. indent .. "  [" .. ser(k) .. "] = " .. ser(val, indent .. "  ") .. ",\n"
                end
                return s .. indent .. "}"
            elseif type(v) == "string" then
                return '"' .. v .. '"'
            else
                return tostring(v)
            end
        end
        return ser(t)
    end,
    serializeJSON = function(t)
        -- Very basic JSON
        local json = require("dkjson") or nil
        if json then return json.encode(t) end
        return textutils.serialize(t)
    end,
    unserializeJSON = function(s)
        local json = require("dkjson") or nil
        if json then return json.decode(s) end
        return nil
    end,
}

gps = {
    locate = function(timeout)
        if currentTurtle then
            return currentTurtle.x, currentTurtle.y, currentTurtle.z
        end
        return nil
    end
}

rednet = {
    open = function(side) print("[SIM] Rednet opened on " .. side) end,
    close = function(side) end,
    host = function(protocol, hostname) end,
    unhost = function(protocol) end,
    send = function(id, msg, protocol) return true end,
    broadcast = function(msg, protocol) return true end,
    receive = function(protocol, timeout) return nil end,
    lookup = function(protocol, hostname) return nil end,
}

peripheral = {
    getType = function(side)
        if side == "left" or side == "right" then
            return "modem"
        end
        return nil
    end,
    wrap = function(side) return nil end,
}

shell = {
    run = function(program) 
        print("[SIM] Would run: " .. program)
    end,
}

sleep = function(s)
    -- In real Lua, we could use os.execute("sleep " .. s)
    -- For testing, just print
    -- realOs.execute("timeout /t " .. math.ceil(s) .. " > nul")
end

-- ==========================================
-- SIMULATION RUNNER
-- ==========================================

local Sim = {}

function Sim.run()
    print("")
    print("=== SIMULATION CONTROLS ===")
    print("Commands:")
    print("  gen      - Generate new world")
    print("  spawn    - Spawn turtle")
    print("  status   - Turtle status")
    print("  forward  - Move forward")
    print("  back     - Move backward")
    print("  up       - Move up")
    print("  down     - Move down")
    print("  left     - Turn left")
    print("  right    - Turn right")
    print("  dig      - Dig forward")
    print("  mine N   - Mine forward N blocks")
    print("  inv      - Show inventory")
    print("  fuel     - Show fuel")
    print("  test     - Run test sequence")
    print("  quit     - Exit")
    print("")
    
    while true do
        io.write("> ")
        local input = io.read()
        local cmd = input:match("^(%S+)")
        local arg = input:match("^%S+%s+(.+)")
        
        if cmd == "gen" then
            World.generate(64, 64, 64)
            
        elseif cmd == "spawn" then
            local t = SimTurtle.new(1, 32, 33, 32, 0)
            setCurrentTurtle(t)
            -- Give some starting items
            t.inventory[1] = { name = "minecraft:coal", count = 32 }
            print("Turtle spawned at (32, 33, 32)")
            
        elseif cmd == "status" then
            if currentTurtle then
                currentTurtle:status()
            else
                print("No turtle spawned")
            end
            
        elseif cmd == "forward" then
            local ok, err = turtle.forward()
            print(ok and "Moved forward" or ("Failed: " .. err))
            
        elseif cmd == "back" then
            local ok, err = turtle.back()
            print(ok and "Moved back" or ("Failed: " .. err))
            
        elseif cmd == "up" then
            local ok, err = turtle.up()
            print(ok and "Moved up" or ("Failed: " .. err))
            
        elseif cmd == "down" then
            local ok, err = turtle.down()
            print(ok and "Moved down" or ("Failed: " .. err))
            
        elseif cmd == "left" then
            turtle.turnLeft()
            print("Turned left")
            
        elseif cmd == "right" then
            turtle.turnRight()
            print("Turned right")
            
        elseif cmd == "dig" then
            local ok, err = turtle.dig()
            print(ok and "Dug block" or ("Failed: " .. err))
            
        elseif cmd == "mine" then
            local n = tonumber(arg) or 10
            print("Mining " .. n .. " blocks...")
            for i = 1, n do
                turtle.dig()
                local ok = turtle.forward()
                if not ok then
                    print("Stopped at block " .. i)
                    break
                end
            end
            print("Done. Mined " .. currentTurtle.stats.blocksMined .. " blocks total")
            
        elseif cmd == "inv" then
            if currentTurtle then
                for slot = 1, 16 do
                    local item = currentTurtle.inventory[slot]
                    if item then
                        print(string.format("[%2d] %s x%d", slot, item.name, item.count))
                    end
                end
            end
            
        elseif cmd == "fuel" then
            print("Fuel: " .. turtle.getFuelLevel() .. "/" .. turtle.getFuelLimit())
            
        elseif cmd == "test" then
            print("Running test sequence...")
            
            -- Test mining
            print("1. Mining test")
            for i = 1, 5 do
                turtle.dig()
                turtle.forward()
            end
            print("   Mined 5 blocks forward")
            
            -- Test turning
            print("2. Turning test")
            turtle.turnRight()
            for i = 1, 5 do
                turtle.dig()
                turtle.forward()
            end
            print("   Mined 5 blocks right")
            
            -- Test vertical
            print("3. Vertical test")
            for i = 1, 3 do
                turtle.digDown()
                turtle.down()
            end
            print("   Dug down 3 blocks")
            
            print("")
            print("Test complete!")
            currentTurtle:status()
            
        elseif cmd == "quit" or cmd == "exit" then
            print("Goodbye!")
            break
            
        else
            print("Unknown command: " .. (cmd or ""))
        end
    end
end

-- ==========================================
-- MAIN
-- ==========================================

-- Generate world
World.generate(64, 64, 64)

-- Spawn initial turtle
local eve = SimTurtle.new(1, 32, 33, 32, 0)
setCurrentTurtle(eve)

-- Give Eve some starting resources
eve.inventory[1] = { name = "minecraft:coal", count = 64 }
eve.inventory[2] = { name = "minecraft:iron_ingot", count = 7 }
eve.inventory[3] = { name = "minecraft:diamond", count = 3 }
eve.fuel = 5000

print("Eve spawned at (32, 33, 32) with starting resources")
print("")

-- Run simulation
Sim.run()
