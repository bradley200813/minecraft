-- ============================================
-- COLONY INSTALLER
-- ============================================
-- Paste this into any turtle/computer to install the colony system
-- Usage: Run this file, it will create all necessary files

print("========================================")
print("  GENESIS COLONY INSTALLER")
print("========================================")
print("")

-- Create directories
local dirs = {
    "/colony",
    "/colony/lib", 
    "/colony/roles",
    "/colony/dashboard",
}

for _, dir in ipairs(dirs) do
    if not fs.exists(dir) then
        fs.makeDir(dir)
        print("Created: " .. dir)
    end
end

-- File contents (minified for space)
local files = {}

-- ============================================
-- CONFIG
-- ============================================
files["/colony/config.lua"] = [[
return {
    COLONY_NAME = "Genesis",
    PROTOCOL = "COLONY",
    MIN_FUEL = 100,
    LOW_FUEL = 500,
    RETURN_FUEL = 300,
    HEARTBEAT_INTERVAL = 5,
    HOME = {x=0, y=64, z=0},
}
]]

-- ============================================
-- LIB/STATE
-- ============================================
files["/colony/lib/state.lua"] = [[
local State = {}
local stateFile = "/.colony/state.json"
local data = {}

function State.load()
    if fs.exists(stateFile) then
        local f = fs.open(stateFile, "r")
        if f then
            local content = f.readAll()
            f.close()
            data = textutils.unserializeJSON(content) or {}
        end
    end
    return data
end

function State.save()
    local dir = fs.getDir(stateFile)
    if not fs.exists(dir) then fs.makeDir(dir) end
    local f = fs.open(stateFile, "w")
    if f then
        f.write(textutils.serializeJSON(data))
        f.close()
    end
end

function State.get(key)
    if not key then return data end
    local val = data
    for part in key:gmatch("[^.]+") do
        if type(val) ~= "table" then return nil end
        val = val[part]
    end
    return val
end

function State.set(key, value)
    local parts = {}
    for part in key:gmatch("[^.]+") do table.insert(parts, part) end
    local target = data
    for i = 1, #parts - 1 do
        if type(target[parts[i]]) ~= "table" then target[parts[i]] = {} end
        target = target[parts[i]]
    end
    target[parts[#parts]] = value
    State.save()
end

function State.getValue(key) return State.get(key) end

return State
]]

-- ============================================
-- LIB/NAV
-- ============================================
files["/colony/lib/nav.lua"] = [[
local Nav = {}
local pos = {x=0, y=0, z=0}
local facing = 0
local home = {x=0, y=0, z=0}
local DIRS = {{x=0,z=-1},{x=1,z=0},{x=0,z=1},{x=-1,z=0}}

function Nav.init()
    if gps then
        local x, y, z = gps.locate(2)
        if x then pos = {x=x, y=y, z=z} end
    end
end

function Nav.getPosition() return {x=pos.x, y=pos.y, z=pos.z} end
function Nav.getFacing() return facing end
function Nav.setHome(p) home = p or {x=pos.x, y=pos.y, z=pos.z} end
function Nav.getHome() return home end

function Nav.forward()
    if turtle.forward() then
        pos.x = pos.x + DIRS[facing+1].x
        pos.z = pos.z + DIRS[facing+1].z
        return true
    end
    return false
end

function Nav.back()
    if turtle.back() then
        pos.x = pos.x - DIRS[facing+1].x
        pos.z = pos.z - DIRS[facing+1].z
        return true
    end
    return false
end

function Nav.up()
    if turtle.up() then pos.y = pos.y + 1; return true end
    return false
end

function Nav.down()
    if turtle.down() then pos.y = pos.y - 1; return true end
    return false
end

function Nav.turnLeft()
    turtle.turnLeft()
    facing = (facing - 1) % 4
end

function Nav.turnRight()
    turtle.turnRight()
    facing = (facing + 1) % 4
end

function Nav.digForward()
    while turtle.detect() do
        turtle.dig()
        sleep(0.3)
    end
    return Nav.forward()
end

function Nav.digUp()
    while turtle.detectUp() do
        turtle.digUp()
        sleep(0.3)
    end
    return Nav.up()
end

function Nav.digDown()
    turtle.digDown()
    return Nav.down()
end

function Nav.goTo(tx, ty, tz)
    while pos.y < ty do if not Nav.digUp() then break end end
    while pos.y > ty do if not Nav.digDown() then break end end
    
    while pos.x < tx do Nav.face(1); if not Nav.digForward() then break end end
    while pos.x > tx do Nav.face(3); if not Nav.digForward() then break end end
    while pos.z < tz do Nav.face(2); if not Nav.digForward() then break end end
    while pos.z > tz do Nav.face(0); if not Nav.digForward() then break end end
end

function Nav.face(dir)
    while facing ~= dir do Nav.turnRight() end
end

function Nav.goHome()
    Nav.goTo(home.x, home.y, home.z)
end

return Nav
]]

-- ============================================
-- LIB/INV
-- ============================================
files["/colony/lib/inv.lua"] = [[
local Inv = {}

local FUEL_ITEMS = {
    ["minecraft:coal"] = 80,
    ["minecraft:charcoal"] = 80,
    ["minecraft:coal_block"] = 800,
    ["minecraft:lava_bucket"] = 1000,
}

local ORES = {
    "diamond", "emerald", "gold", "iron", "copper", 
    "redstone", "lapis", "coal", "ancient_debris"
}

local TRASH = {
    "cobblestone", "dirt", "gravel", "netherrack", 
    "cobbled_deepslate", "tuff", "granite", "diorite", "andesite"
}

function Inv.isFuel(name)
    return FUEL_ITEMS[name] ~= nil
end

function Inv.isOre(name)
    for _, ore in ipairs(ORES) do
        if name:find(ore) then return true end
    end
    return false
end

function Inv.isTrash(name)
    for _, trash in ipairs(TRASH) do
        if name:find(trash) then return true end
    end
    return false
end

function Inv.freeSlots()
    local count = 0
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then count = count + 1 end
    end
    return count
end

function Inv.isFull()
    return Inv.freeSlots() == 0
end

function Inv.refuel(minFuel)
    minFuel = minFuel or 1000
    while turtle.getFuelLevel() < minFuel do
        local found = false
        for i = 1, 16 do
            local item = turtle.getItemDetail(i)
            if item and Inv.isFuel(item.name) then
                turtle.select(i)
                if turtle.refuel(1) then found = true; break end
            end
        end
        if not found then break end
    end
    turtle.select(1)
    return turtle.getFuelLevel()
end

function Inv.dropTrash()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and Inv.isTrash(item.name) then
            turtle.select(i)
            turtle.drop()
        end
    end
    turtle.select(1)
end

function Inv.dumpToChest()
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            turtle.select(i)
            turtle.drop()
        end
    end
    turtle.select(1)
end

function Inv.summary()
    local items = {}
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item then
            items[item.name] = (items[item.name] or 0) + item.count
        end
    end
    return items
end

function Inv.countItem(name)
    local count = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and item.name:find(name) then
            count = count + item.count
        end
    end
    return count
end

function Inv.findItem(name)
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and item.name:find(name) then
            return i
        end
    end
    return nil
end

return Inv
]]

-- ============================================
-- LIB/COMMS
-- ============================================
files["/colony/lib/comms.lua"] = [[
local Comms = {}
local protocol = "COLONY"
local peers = {}
local handlers = {}

Comms.MSG = {
    PING = "ping",
    PONG = "pong",
    HELLO = "hello",
    HEARTBEAT = "heartbeat",
    TASK = "task",
    TASK_COMPLETE = "task_complete",
    HELP = "help",
    LOW_FUEL = "low_fuel",
    INVENTORY_FULL = "inventory_full",
    ASSIGN_ROLE = "assign_role",
}

function Comms.hasModem()
    for _, side in ipairs({"top","bottom","left","right","front","back"}) do
        if peripheral.getType(side) == "modem" then return true, side end
    end
    return false
end

function Comms.open()
    local has, side = Comms.hasModem()
    if has then
        rednet.open(side)
        return true
    end
    return false
end

function Comms.broadcast(msgType, data)
    rednet.broadcast({type=msgType, data=data, from=os.getComputerID()}, protocol)
end

function Comms.send(id, msgType, data)
    rednet.send(id, {type=msgType, data=data, from=os.getComputerID()}, protocol)
end

function Comms.receive(timeout)
    local id, msg = rednet.receive(protocol, timeout or 1)
    return id, msg
end

function Comms.announce(event, data)
    Comms.broadcast(Comms.MSG.HELLO, {
        event = event,
        label = os.getComputerLabel() or ("Turtle-"..os.getComputerID()),
        data = data,
    })
end

function Comms.setupDefaultHandlers()
    handlers[Comms.MSG.PING] = function(id, msg)
        Comms.send(id, Comms.MSG.PONG, {label = os.getComputerLabel()})
    end
end

function Comms.process(timeout)
    local id, msg = Comms.receive(timeout)
    if id and msg and msg.type and handlers[msg.type] then
        handlers[msg.type](id, msg)
        return true, id, msg
    end
    return false, id, msg
end

return Comms
]]

-- ============================================
-- LIB/REPORTER
-- ============================================
files["/colony/lib/reporter.lua"] = [[
local Reporter = {}
local Nav, Inv, State, Comms
local INTERVAL = 5

function Reporter.init(nav, inv, state, comms)
    Nav = nav; Inv = inv; State = state; Comms = comms
end

function Reporter.buildReport()
    return {
        id = os.getComputerID(),
        label = os.getComputerLabel() or ("Turtle-"..os.getComputerID()),
        role = State and State.get("role") or "unknown",
        generation = State and State.get("generation") or 0,
        position = Nav and Nav.getPosition() or {x=0,y=0,z=0},
        fuel = turtle.getFuelLevel(),
        fuelLimit = turtle.getFuelLimit(),
        state = State and State.get("currentState") or "idle",
    }
end

function Reporter.heartbeat()
    if Comms then
        Comms.broadcast("heartbeat", Reporter.buildReport())
    end
end

function Reporter.startReporting()
    while true do
        Reporter.heartbeat()
        sleep(INTERVAL)
    end
end

function Reporter.runParallel(mainFunc)
    parallel.waitForAll(mainFunc, Reporter.startReporting)
end

return Reporter
]]

-- ============================================
-- ROLES/MINER
-- ============================================
files["/colony/roles/miner.lua"] = [[
local Miner = {}
local Nav, Inv, State, Comms
local config = {
    branchLength = 20,
    branchSpacing = 3,
    returnOnFull = true,
    returnOnLowFuel = true,
    minFuel = 300,
}

Miner.PATTERNS = {
    BRANCH = "branch",
    TUNNEL = "tunnel",
    QUARRY = "quarry",
}

function Miner.init(nav, inv, state, comms)
    Nav = nav; Inv = inv; State = state; Comms = comms
end

function Miner.configure(opts)
    for k, v in pairs(opts) do config[k] = v end
end

function Miner.shouldReturn()
    if config.returnOnFull and Inv.isFull() then return true, "full" end
    if config.returnOnLowFuel and turtle.getFuelLevel() < config.minFuel then return true, "fuel" end
    return false
end

function Miner.checkOreVein()
    local found = false
    for _, dir in ipairs({"front","up","down"}) do
        local ok, data
        if dir == "front" then ok, data = turtle.inspect()
        elseif dir == "up" then ok, data = turtle.inspectUp()
        else ok, data = turtle.inspectDown() end
        
        if ok and Inv.isOre(data.name) then
            if dir == "front" then turtle.dig()
            elseif dir == "up" then turtle.digUp()
            else turtle.digDown() end
            found = true
        end
    end
    return found
end

function Miner.mineBranch(length)
    length = length or config.branchLength
    local mined = 0
    
    for i = 1, length do
        local shouldRet, reason = Miner.shouldReturn()
        if shouldRet then
            print("Returning: " .. reason)
            Nav.goHome()
            if reason == "full" then Inv.dumpToChest() end
            if reason == "fuel" then Inv.refuel(1000) end
            return mined, reason
        end
        
        if not Nav.digForward() then break end
        Nav.digUp()
        mined = mined + 2
        
        Miner.checkOreVein()
    end
    
    return mined
end

function Miner.run(pattern)
    pattern = pattern or Miner.PATTERNS.BRANCH
    print("[MINER] Starting: " .. pattern)
    
    local totalMined = 0
    
    if pattern == Miner.PATTERNS.BRANCH then
        local branches = 0
        while branches < 10 do
            local mined = Miner.mineBranch()
            totalMined = totalMined + mined
            
            -- Return to start of branch
            Nav.turnRight(); Nav.turnRight()
            for i = 1, config.branchLength do
                Nav.forward()
            end
            Nav.turnRight(); Nav.turnRight()
            
            -- Move to next branch position
            Nav.turnRight()
            for i = 1, config.branchSpacing do
                Nav.digForward()
            end
            Nav.turnLeft()
            
            branches = branches + 1
        end
    elseif pattern == Miner.PATTERNS.TUNNEL then
        totalMined = Miner.mineBranch(100)
    end
    
    Nav.goHome()
    return totalMined
end

return Miner
]]

-- ============================================
-- ROLES/CRAFTER
-- ============================================
files["/colony/roles/crafter.lua"] = [[
local Crafter = {}
local Nav, Inv, State, Comms

function Crafter.init(nav, inv, state, comms)
    Nav = nav; Inv = inv; State = state; Comms = comms
end

function Crafter.canCraftTurtle()
    local iron = Inv.countItem("iron_ingot")
    local redstone = Inv.countItem("redstone")
    local glass = Inv.countItem("glass_pane") + Inv.countItem("glass")
    local diamond = Inv.countItem("diamond")
    local wood = Inv.countItem("planks") + (Inv.countItem("log") * 4)
    
    return iron >= 7 and redstone >= 1 and glass >= 1 and diamond >= 3 and wood >= 8
end

function Crafter.birthTurtle()
    print("[CRAFTER] Birthing new turtle...")
    
    -- Place turtle from inventory
    local slot = Inv.findItem("turtle")
    if slot then
        turtle.select(slot)
        turtle.place()
        
        -- Turn on the new turtle
        peripheral.call("front", "turnOn")
        
        -- Wait and give it supplies
        sleep(2)
        
        return true
    end
    
    return false
end

return Crafter
]]

-- ============================================
-- BRAIN
-- ============================================
files["/colony/brain.lua"] = [[
local Brain = {}
local Nav, Inv, State, Comms, Miner, Crafter
local running = false

local PRIORITIES = {
    CRITICAL_FUEL = 100,
    INVENTORY_FULL = 90,
    CAN_BIRTH = 80,
    MINING = 50,
    IDLE = 10,
}

function Brain.init(nav, inv, state, comms, miner, crafter)
    Nav = nav; Inv = inv; State = state; Comms = comms
    Miner = miner; Crafter = crafter
end

function Brain.assess()
    local decisions = {}
    
    -- Check fuel
    local fuel = turtle.getFuelLevel()
    if fuel < 100 then
        table.insert(decisions, {priority = PRIORITIES.CRITICAL_FUEL, action = "refuel"})
    end
    
    -- Check inventory
    if Inv.isFull() then
        table.insert(decisions, {priority = PRIORITIES.INVENTORY_FULL, action = "dump"})
    end
    
    -- Can birth?
    if Crafter and Crafter.canCraftTurtle() then
        table.insert(decisions, {priority = PRIORITIES.CAN_BIRTH, action = "birth"})
    end
    
    -- Default: mine
    table.insert(decisions, {priority = PRIORITIES.MINING, action = "mine"})
    
    -- Sort by priority
    table.sort(decisions, function(a,b) return a.priority > b.priority end)
    
    return decisions[1]
end

function Brain.execute(decision)
    local action = decision.action
    State.set("currentState", action)
    
    if action == "refuel" then
        print("[BRAIN] Refueling...")
        Nav.goHome()
        Inv.refuel(1000)
        
    elseif action == "dump" then
        print("[BRAIN] Dumping inventory...")
        Nav.goHome()
        Inv.dropTrash()
        Inv.dumpToChest()
        
    elseif action == "birth" then
        print("[BRAIN] Birthing new turtle!")
        Nav.goHome()
        Crafter.birthTurtle()
        
    elseif action == "mine" then
        print("[BRAIN] Mining...")
        Miner.run(Miner.PATTERNS.BRANCH)
    end
    
    State.set("currentState", "idle")
end

function Brain.run()
    running = true
    print("[BRAIN] Starting autonomous mode")
    
    while running do
        local decision = Brain.assess()
        print("[BRAIN] Decision: " .. decision.action)
        Brain.execute(decision)
        sleep(1)
    end
end

function Brain.stop()
    running = false
end

return Brain
]]

-- ============================================
-- STARTUP
-- ============================================
files["/colony/startup.lua"] = [[
print("========================================")
print("  GENESIS COLONY - BOOTING")
print("========================================")

local stateFile = "/.colony/state.json"

local function loadLibs()
    package.path = package.path .. ";/colony/?.lua;/colony/lib/?.lua;/colony/roles/?.lua"
    local State = require("lib.state")
    local Inv = require("lib.inv")
    local Nav = require("lib.nav")
    local Comms = require("lib.comms")
    local Reporter = require("lib.reporter")
    local Miner = require("roles.miner")
    local Crafter = require("roles.crafter")
    local Brain = require("brain")
    return State, Inv, Nav, Comms, Reporter, Miner, Crafter, Brain
end

local function getIdentity()
    if fs.exists(stateFile) then
        local f = fs.open(stateFile, "r")
        if f then
            local data = textutils.unserializeJSON(f.readAll())
            f.close()
            if data then return data.role or "worker", data.generation or 0 end
        end
    end
    local label = os.getComputerLabel() or ""
    if label:find("Eve") then return "eve", 0 end
    return "newborn", -1
end

local role, gen = getIdentity()
print("Role: " .. role .. " | Gen: " .. gen)

local ok, err = pcall(function()
    local State, Inv, Nav, Comms, Reporter, Miner, Crafter, Brain = loadLibs()
    
    -- Initialize
    State.load()
    Nav.init()
    if Comms.hasModem() then
        Comms.open()
        Comms.setupDefaultHandlers()
    end
    
    Reporter.init(Nav, Inv, State, Comms)
    Miner.init(Nav, Inv, State, Comms)
    Crafter.init(Nav, Inv, State, Comms)
    Brain.init(Nav, Inv, State, Comms, Miner, Crafter)
    
    if role == "eve" then
        shell.run("/colony/eve.lua")
    else
        if role == "newborn" then
            State.set("role", "worker")
            State.set("generation", 1)
            os.setComputerLabel("Worker-" .. os.getComputerID())
        end
        
        Reporter.runParallel(function()
            Brain.run()
        end)
    end
end)

if not ok then
    print("ERROR: " .. tostring(err))
    print("Press any key to reboot...")
    os.pullEvent("key")
    os.reboot()
end
]]

-- ============================================
-- EVE
-- ============================================
files["/colony/eve.lua"] = [[
print("========================================")
print("  EVE - THE FIRST")
print("========================================")
print("")

package.path = package.path .. ";/colony/?.lua;/colony/lib/?.lua;/colony/roles/?.lua"

local State = require("lib.state")
local Inv = require("lib.inv")
local Nav = require("lib.nav")
local Comms = require("lib.comms")
local Reporter = require("lib.reporter")
local Miner = require("roles.miner")
local Crafter = require("roles.crafter")
local Brain = require("brain")

-- Initialize
State.load()
State.set("role", "eve")
State.set("generation", 0)
Nav.init()
Nav.setHome()

if Comms.hasModem() then
    Comms.open()
    Comms.announce("eve_online")
end

Reporter.init(Nav, Inv, State, Comms)
Miner.init(Nav, Inv, State, Comms)
Crafter.init(Nav, Inv, State, Comms)
Brain.init(Nav, Inv, State, Comms, Miner, Crafter)

local function menu()
    while true do
        print("")
        print("=== EVE MENU ===")
        print("1. Start Autonomous Mode")
        print("2. Mine (Branch Pattern)")
        print("3. Go Home")
        print("4. Refuel")
        print("5. Drop Trash")
        print("6. Status")
        print("0. Exit")
        print("")
        write("Choice: ")
        
        local choice = read()
        
        if choice == "1" then
            print("Starting Brain...")
            Reporter.runParallel(function() Brain.run() end)
        elseif choice == "2" then
            print("Mining...")
            Miner.run(Miner.PATTERNS.BRANCH)
        elseif choice == "3" then
            print("Going home...")
            Nav.goHome()
        elseif choice == "4" then
            print("Refueling...")
            Inv.refuel(1000)
            print("Fuel: " .. turtle.getFuelLevel())
        elseif choice == "5" then
            print("Dropping trash...")
            Inv.dropTrash()
        elseif choice == "6" then
            print("Fuel: " .. turtle.getFuelLevel())
            print("Position: " .. textutils.serialize(Nav.getPosition()))
            print("Free slots: " .. Inv.freeSlots())
        elseif choice == "0" then
            return
        end
    end
end

menu()
]]

-- Write all files
print("")
print("Installing files...")
print("")

local count = 0
for path, content in pairs(files) do
    local dir = fs.getDir(path)
    if not fs.exists(dir) then
        fs.makeDir(dir)
    end
    
    local f = fs.open(path, "w")
    if f then
        f.write(content)
        f.close()
        print("  + " .. path)
        count = count + 1
    else
        print("  ! FAILED: " .. path)
    end
end

print("")
print("========================================")
print("  INSTALLATION COMPLETE!")
print("========================================")
print("")
print("Installed " .. count .. " files")
print("")
print("NEXT STEPS:")
print("  1. Label this turtle: label set Eve-1")
print("  2. Fuel it: refuel all")
print("  3. Run: /colony/eve")
print("")
print("For new turtles, just copy /colony folder")
print("and run /colony/startup")
print("========================================")
