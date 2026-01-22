-- ============================================
-- SIMPLE COLONY TURTLE
-- ============================================
-- One file does it all: movement, mining, commands, reporting

local PROTOCOL = "COLONY"
local SERVER_URL = "https://738e20244ec5.ngrok.app"  -- Change this!

-- Position tracking
local pos = {x=0, y=0, z=0}
local facing = 0  -- 0=north, 1=east, 2=south, 3=west
local home = {x=0, y=0, z=0}

-- Direction vectors
local dirs = {
    [0] = {x=0, z=-1},  -- north
    [1] = {x=1, z=0},   -- east
    [2] = {x=0, z=1},   -- south
    [3] = {x=-1, z=0},  -- west
}

-- ============================================
-- MOVEMENT
-- ============================================

local function forward()
    if turtle.forward() then
        pos.x = pos.x + dirs[facing].x
        pos.z = pos.z + dirs[facing].z
        return true
    end
    return false
end

local function back()
    if turtle.back() then
        pos.x = pos.x - dirs[facing].x
        pos.z = pos.z - dirs[facing].z
        return true
    end
    return false
end

local function up()
    if turtle.up() then
        pos.y = pos.y + 1
        return true
    end
    return false
end

local function down()
    if turtle.down() then
        pos.y = pos.y - 1
        return true
    end
    return false
end

local function turnLeft()
    turtle.turnLeft()
    facing = (facing - 1) % 4
end

local function turnRight()
    turtle.turnRight()
    facing = (facing + 1) % 4
end

local function face(dir)
    while facing ~= dir do turnRight() end
end

-- Dig and move
local function digForward()
    while turtle.detect() do turtle.dig() sleep(0.3) end
    return forward()
end

local function digUp()
    while turtle.detectUp() do turtle.digUp() sleep(0.3) end
    return up()
end

local function digDown()
    turtle.digDown()
    return down()
end

-- Go to coordinates
local function goTo(tx, ty, tz)
    -- Y first (go up/down)
    while pos.y < ty do if not digUp() then break end end
    while pos.y > ty do if not digDown() then break end end
    -- X
    if pos.x < tx then face(1) end
    if pos.x > tx then face(3) end
    while pos.x ~= tx do if not digForward() then break end end
    -- Z
    if pos.z < tz then face(2) end
    if pos.z > tz then face(0) end
    while pos.z ~= tz do if not digForward() then break end end
end

local function goHome()
    goTo(home.x, home.y, home.z)
end

local function setHome()
    home = {x=pos.x, y=pos.y, z=pos.z}
end

-- ============================================
-- INVENTORY
-- ============================================

local TRASH = {"cobblestone", "dirt", "gravel", "netherrack", "granite", "diorite", "andesite", "tuff", "deepslate", "cobbled"}

local function isTrash(name)
    for _, t in ipairs(TRASH) do
        if name:find(t) then return true end
    end
    return false
end

local function freeSlots()
    local count = 0
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then count = count + 1 end
    end
    return count
end

local function isFull()
    return freeSlots() == 0
end

local function refuel(min)
    min = min or 1000
    for i = 1, 16 do
        if turtle.getFuelLevel() >= min then break end
        turtle.select(i)
        turtle.refuel()
    end
    turtle.select(1)
    return turtle.getFuelLevel()
end

local function dropTrash()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and isTrash(item.name) then
            turtle.select(i)
            turtle.drop()
        end
    end
    turtle.select(1)
end

local function dumpAll()
    for i = 1, 16 do
        turtle.select(i)
        turtle.drop()
    end
    turtle.select(1)
end

-- ============================================
-- MINING
-- ============================================

local shouldStop = false

local function quarry(size, maxDepth)
    size = size or 8
    maxDepth = maxDepth or 100
    local mined = 0
    local layer = 0
    local goingRight = true
    
    print("Quarry " .. size .. "x" .. size .. " starting...")
    
    while layer < maxDepth and not shouldStop do
        -- Mine this layer
        for row = 1, size do
            for col = 1, size do
                if shouldStop then return mined end
                
                -- Dig down at current spot
                if turtle.detectDown() then
                    turtle.digDown()
                    mined = mined + 1
                end
                
                -- Move to next column (not on last)
                if col < size then
                    while turtle.detect() do turtle.dig() mined = mined + 1 sleep(0.3) end
                    forward()
                end
                
                -- Fuel check
                if turtle.getFuelLevel() < 500 then refuel(2000) end
                if isFull() then dropTrash() end
            end
            
            -- Turn for next row
            if row < size then
                if goingRight then
                    turnRight()
                    while turtle.detect() do turtle.dig() mined = mined + 1 end
                    forward()
                    turnRight()
                else
                    turnLeft()
                    while turtle.detect() do turtle.dig() mined = mined + 1 end
                    forward()
                    turnLeft()
                end
                goingRight = not goingRight
            end
        end
        
        -- Go down one layer
        layer = layer + 1
        print("Layer " .. layer .. " done, " .. mined .. " blocks")
        
        if not down() then
            turtle.digDown()
            if not down() then
                print("Hit bedrock!")
                break
            end
        end
        
        -- Turn around
        turnRight()
        turnRight()
        goingRight = not goingRight
    end
    
    print("Quarry done: " .. mined .. " blocks")
    return mined
end

local function tunnel(length)
    length = length or 50
    local mined = 0
    
    print("Tunnel " .. length .. " blocks...")
    
    for i = 1, length do
        if shouldStop then break end
        
        while turtle.detect() do turtle.dig() mined = mined + 1 sleep(0.3) end
        turtle.digUp()
        mined = mined + 1
        forward()
        
        if turtle.getFuelLevel() < 100 then refuel(500) end
        if isFull() then dropTrash() end
    end
    
    print("Tunnel done: " .. mined .. " blocks")
    return mined
end

-- ============================================
-- COMMUNICATION
-- ============================================

local modemSide = nil

local function openModem()
    for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
        if peripheral.getType(side) == "modem" then
            modemSide = side
            rednet.open(side)
            print("[OK] Modem on " .. side)
            return true
        end
    end
    print("[WARN] No modem!")
    return false
end

local function heartbeat()
    if not modemSide then return end
    
    rednet.broadcast({
        type = "heartbeat",
        data = {
            id = os.getComputerID(),
            label = os.getComputerLabel() or ("Turtle-" .. os.getComputerID()),
            position = pos,
            facing = facing,
            fuel = turtle.getFuelLevel(),
            fuelLimit = turtle.getFuelLimit(),
            freeSlots = freeSlots(),
            state = shouldStop and "stopped" or "ready",
        }
    }, PROTOCOL)
end

-- ============================================
-- COMMAND HANDLING
-- ============================================

local commands = {}

-- Movement
commands.forward = function(a) for i=1,(a.count or 1) do forward() end return "OK" end
commands.back = function(a) for i=1,(a.count or 1) do back() end return "OK" end
commands.up = function(a) for i=1,(a.count or 1) do up() end return "OK" end
commands.down = function(a) for i=1,(a.count or 1) do down() end return "OK" end
commands.turnLeft = function() turnLeft() return "OK" end
commands.turnRight = function() turnRight() return "OK" end
commands.dig = function() turtle.dig() return "OK" end
commands.digUp = function() turtle.digUp() return "OK" end
commands.digDown = function() turtle.digDown() return "OK" end

-- Navigation
commands.goTo = function(a) goTo(a.x, a.y, a.z) return "Arrived" end
commands.goHome = function() goHome() return "Home" end
commands.setHome = function() setHome() return "Home set" end

-- Inventory
commands.refuel = function(a) return "Fuel: " .. refuel(a.amount or 1000) end
commands.dropTrash = function() dropTrash() return "Done" end
commands.dumpAll = function() dumpAll() return "Done" end

-- Mining
commands.quarry = function(a) 
    shouldStop = false
    return "Mined: " .. quarry(a.size or 8, a.depth or 100) 
end
commands.tunnel = function(a) 
    shouldStop = false
    return "Mined: " .. tunnel(a.length or 50) 
end
commands.stop = function() shouldStop = true return "Stopped" end

-- Info
commands.status = function()
    return string.format("Fuel:%d Pos:%d,%d,%d Free:%d", 
        turtle.getFuelLevel(), pos.x, pos.y, pos.z, freeSlots())
end
commands.fuel = function() return "Fuel: " .. turtle.getFuelLevel() end
commands.position = function() return pos.x..","..pos.y..","..pos.z end

local function executeCommand(cmd, args)
    args = args or {}
    local handler = commands[cmd]
    if handler then
        local ok, result = pcall(handler, args)
        return ok, ok and result or tostring(result)
    end
    return false, "Unknown: " .. cmd
end

local function listenForCommands()
    while true do
        local id, msg = rednet.receive(PROTOCOL, 1)
        if id and type(msg) == "table" and msg.type == "command" then
            print("[CMD] " .. msg.command)
            local ok, result = executeCommand(msg.command, msg.args or {})
            print("  -> " .. result)
            
            -- Send result back
            rednet.broadcast({
                type = "command_result",
                commandId = msg.commandId,
                success = ok,
                message = result,
            }, PROTOCOL)
        end
    end
end

-- ============================================
-- MAIN
-- ============================================

local function main()
    print("========================================")
    print("  SIMPLE COLONY TURTLE")
    print("========================================")
    print("ID: " .. os.getComputerID())
    print("Label: " .. (os.getComputerLabel() or "NOT SET"))
    print("")
    
    openModem()
    setHome()
    refuel(1000)
    
    print("")
    print("Commands: forward, back, up, down, turnLeft,")
    print("  turnRight, dig, quarry, tunnel, goHome, etc.")
    print("")
    print("Listening for remote commands...")
    print("(Ctrl+T to exit)")
    print("")
    
    -- Send heartbeat immediately
    heartbeat()
    
    -- Run heartbeat + command listener
    parallel.waitForAny(
        function()
            while true do
                heartbeat()
                sleep(5)
            end
        end,
        listenForCommands
    )
end

-- Export for require() or run directly
if shell then
    main()
end

return {
    forward = forward, back = back, up = up, down = down,
    turnLeft = turnLeft, turnRight = turnRight,
    digForward = digForward, digUp = digUp, digDown = digDown,
    goTo = goTo, goHome = goHome, setHome = setHome,
    refuel = refuel, dropTrash = dropTrash, dumpAll = dumpAll,
    quarry = quarry, tunnel = tunnel,
    pos = pos, facing = facing, home = home,
}
