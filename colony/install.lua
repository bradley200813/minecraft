-- GENESIS COLONY INSTALLER
print("========================================")
print("  GENESIS COLONY - INSTALLER")
print("========================================")

fs.makeDir("/colony")
fs.makeDir("/colony/lib")
fs.makeDir("/colony/roles")
print("Created directories")

local function w(path, content)
    local f = fs.open(path, "w")
    if f then
        f.write(content)
        f.close()
        print("  + " .. path)
        return true
    end
    print("  ! " .. path)
    return false
end

-- STATE
w("/colony/lib/state.lua", [[
local S = {}
local file = "/.colony/state.json"
local data = {}

function S.load()
    if fs.exists(file) then
        local f = fs.open(file, "r")
        if f then
            local txt = f.readAll()
            f.close()
            data = textutils.unserializeJSON(txt) or {}
        end
    end
    return data
end

function S.save()
    if not fs.exists("/.colony") then
        fs.makeDir("/.colony")
    end
    local f = fs.open(file, "w")
    if f then
        f.write(textutils.serializeJSON(data))
        f.close()
    end
end

function S.get(k)
    if not k then return data end
    return data[k]
end

function S.set(k, val)
    data[k] = val
    S.save()
end

return S
]])

-- NAV
w("/colony/lib/nav.lua", [[
local N = {}
local pos = {x=0, y=0, z=0}
local facing = 0
local home = {x=0, y=0, z=0}
local fuelStation = nil  -- {x, y, z, side} where side is where the fuel container is
local storageStation = nil  -- {x, y, z, side} where side is where the chest is
local D = {{x=0,z=-1}, {x=1,z=0}, {x=0,z=1}, {x=-1,z=0}}

function N.init()
    if gps then
        local x, y, z = gps.locate(2)
        if x then
            pos = {x=x, y=y, z=z}
        end
    end
end

function N.getPosition()
    return {x=pos.x, y=pos.y, z=pos.z}
end

function N.getFacing()
    return facing
end

function N.setHome(p)
    if p then
        home = p
    else
        home = {x=pos.x, y=pos.y, z=pos.z}
    end
end

function N.getHome()
    return home
end

function N.forward()
    if turtle.forward() then
        pos.x = pos.x + D[facing+1].x
        pos.z = pos.z + D[facing+1].z
        return true
    end
    return false
end

function N.back()
    if turtle.back() then
        pos.x = pos.x - D[facing+1].x
        pos.z = pos.z - D[facing+1].z
        return true
    end
    return false
end

function N.up()
    if turtle.up() then
        pos.y = pos.y + 1
        return true
    end
    return false
end

function N.down()
    if turtle.down() then
        pos.y = pos.y - 1
        return true
    end
    return false
end

function N.turnLeft()
    turtle.turnLeft()
    facing = (facing - 1) % 4
end

function N.turnRight()
    turtle.turnRight()
    facing = (facing + 1) % 4
end

function N.face(d)
    while facing ~= d do
        N.turnRight()
    end
end

function N.digForward()
    while turtle.detect() do
        turtle.dig()
        sleep(0.3)
    end
    return N.forward()
end

function N.digUp()
    while turtle.detectUp() do
        turtle.digUp()
        sleep(0.3)
    end
    return N.up()
end

function N.digDown()
    turtle.digDown()
    return N.down()
end

function N.goTo(tx, ty, tz)
    while pos.y < ty do
        if not N.digUp() then break end
    end
    while pos.y > ty do
        if not N.digDown() then break end
    end
    while pos.x < tx do
        N.face(1)
        if not N.digForward() then break end
    end
    while pos.x > tx do
        N.face(3)
        if not N.digForward() then break end
    end
    while pos.z < tz do
        N.face(2)
        if not N.digForward() then break end
    end
    while pos.z > tz do
        N.face(0)
        if not N.digForward() then break end
    end
end

function N.goHome()
    N.goTo(home.x, home.y, home.z)
end

function N.setFuelStation(p, side)
    if p then
        fuelStation = {x=p.x, y=p.y, z=p.z, side=side or "front"}
    else
        fuelStation = {x=pos.x, y=pos.y, z=pos.z, side=side or "front"}
    end
end

function N.getFuelStation()
    return fuelStation
end

function N.goToFuelStation()
    if fuelStation then
        N.goTo(fuelStation.x, fuelStation.y, fuelStation.z)
        return true, fuelStation.side
    end
    return false, "No fuel station set"
end

function N.setStorageStation(p, side)
    if p then
        storageStation = {x=p.x, y=p.y, z=p.z, side=side or "front"}
    else
        storageStation = {x=pos.x, y=pos.y, z=pos.z, side=side or "front"}
    end
end

function N.getStorageStation()
    return storageStation
end

function N.goToStorageStation()
    if storageStation then
        N.goTo(storageStation.x, storageStation.y, storageStation.z)
        return true, storageStation.side
    end
    return false, "No storage station set"
end

return N
]])

-- INV
w("/colony/lib/inv.lua", [[
local I = {}

-- Trash items to drop
I.TRASH = {"cobblestone", "dirt", "gravel", "netherrack", "granite", "diorite", "andesite", "tuff", "deepslate"}

-- Fuel values
I.FUEL_VALUES = {
    ["minecraft:coal"] = 80,
    ["minecraft:charcoal"] = 80,
    ["minecraft:coal_block"] = 800,
    ["minecraft:lava_bucket"] = 1000,
    ["minecraft:blaze_rod"] = 120,
}

function I.freeSlots()
    local c = 0
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            c = c + 1
        end
    end
    return c
end

function I.isFull()
    return I.freeSlots() == 0
end

function I.isTrash(name)
    for _, t in ipairs(I.TRASH) do
        if name:find(t) then return true end
    end
    return false
end

function I.refuel(min)
    min = min or 1000
    for i = 1, 16 do
        if turtle.getFuelLevel() >= min then break end
        turtle.select(i)
        turtle.refuel()
    end
    turtle.select(1)
    return turtle.getFuelLevel()
end

-- Refuel from lava using bucket
function I.refuelFromLava()
    -- Find empty bucket
    local bucketSlot = I.findItem("bucket")
    if not bucketSlot then
        return false, "No bucket"
    end
    
    -- Try to pick up lava from in front, above, or below
    turtle.select(bucketSlot)
    local gotLava = false
    
    -- Check if there's a tank/fluid container peripheral
    local tank = peripheral.find("tank") or peripheral.find("fluid_tank")
    if tank and tank.pullFluid then
        -- Try to pull lava from tank
        local pulled = tank.pullFluid("lava", 1000)
        if pulled and pulled > 0 then
            gotLava = true
        end
    end
    
    -- If no tank, try to scoop lava directly
    if not gotLava then
        if turtle.place() then  -- Try to scoop in front
            gotLava = true
        elseif turtle.placeUp() then
            gotLava = true
        elseif turtle.placeDown() then
            gotLava = true
        end
    end
    
    if gotLava then
        -- Now we have a lava bucket, refuel from it
        local slot = I.findItem("lava_bucket")
        if slot then
            turtle.select(slot)
            turtle.refuel()
            turtle.select(1)
            return true, turtle.getFuelLevel()
        end
    end
    
    turtle.select(1)
    return false, "No lava found"
end

-- Refuel from adjacent container (chest, tank, etc)
function I.refuelFromContainer(side)
    side = side or "front"
    local container = peripheral.wrap(side)
    if not container then return false, "No container" end
    
    -- Check if it's a fluid tank
    if container.tanks then
        local tanks = container.tanks()
        for _, tank in pairs(tanks) do
            if tank.name and tank.name:find("lava") then
                -- Has lava! Try to extract with bucket
                return I.refuelFromLava()
            end
        end
    end
    
    -- Check if it's an inventory (chest with coal/lava buckets)
    if container.list then
        local items = container.list()
        for slot, item in pairs(items) do
            if item.name:find("coal") or item.name:find("lava_bucket") or item.name:find("charcoal") then
                -- Pull fuel item
                local emptySlot = I.findEmptySlot()
                if emptySlot then
                    turtle.select(emptySlot)
                    if side == "front" then turtle.suck(64)
                    elseif side == "top" then turtle.suckUp(64)
                    elseif side == "bottom" then turtle.suckDown(64)
                    end
                    turtle.refuel()
                    turtle.select(1)
                    return true, turtle.getFuelLevel()
                end
            end
        end
    end
    
    return false, "No fuel in container"
end

function I.findEmptySlot()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            return i
        end
    end
    return nil
end

-- Refuel until max from a container (keeps pulling fuel items)
function I.refuelToMax(side)
    side = side or "front"
    local limit = turtle.getFuelLimit()
    local startFuel = turtle.getFuelLevel()
    local attempts = 0
    local maxAttempts = 100  -- Safety limit
    
    while turtle.getFuelLevel() < limit and attempts < maxAttempts do
        attempts = attempts + 1
        local emptySlot = I.findEmptySlot()
        if not emptySlot then
            -- Try to refuel what we have first
            for i = 1, 16 do
                turtle.select(i)
                turtle.refuel()
            end
            emptySlot = I.findEmptySlot()
            if not emptySlot then
                turtle.select(1)
                return turtle.getFuelLevel(), "Inventory full"
            end
        end
        
        turtle.select(emptySlot)
        local gotItem = false
        if side == "front" then gotItem = turtle.suck(64)
        elseif side == "top" then gotItem = turtle.suckUp(64)
        elseif side == "bottom" then gotItem = turtle.suckDown(64)
        end
        
        if gotItem then
            turtle.refuel()
        else
            -- No more fuel in container
            break
        end
    end
    
    -- Final refuel pass on any remaining items
    for i = 1, 16 do
        turtle.select(i)
        turtle.refuel()
    end
    turtle.select(1)
    
    local gained = turtle.getFuelLevel() - startFuel
    return turtle.getFuelLevel(), "Gained "..gained.." fuel"
end

-- Refuel to max using lava (keeps scooping until full)
function I.refuelToMaxLava()
    local limit = turtle.getFuelLimit()
    local startFuel = turtle.getFuelLevel()
    local attempts = 0
    local maxAttempts = 200  -- Safety limit (lava bucket = 1000 fuel, limit = 100000)
    
    while turtle.getFuelLevel() < limit and attempts < maxAttempts do
        attempts = attempts + 1
        local ok, result = I.refuelFromLava()
        if not ok then
            break
        end
        sleep(0.1)  -- Small delay for lava flow
    end
    
    local gained = turtle.getFuelLevel() - startFuel
    return turtle.getFuelLevel(), "Gained "..gained.." fuel from lava"
end

function I.dropTrash()
    for i = 1, 16 do
        local it = turtle.getItemDetail(i)
        if it and I.isTrash(it.name) then
            turtle.select(i)
            turtle.drop()
        end
    end
    turtle.select(1)
end

function I.dumpToChest()
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            turtle.select(i)
            turtle.drop()
        end
    end
    turtle.select(1)
end

function I.countItem(n)
    local c = 0
    for i = 1, 16 do
        local it = turtle.getItemDetail(i)
        if it and it.name:find(n) then
            c = c + it.count
        end
    end
    return c
end

function I.findItem(n)
    for i = 1, 16 do
        local it = turtle.getItemDetail(i)
        if it and it.name:find(n) then
            return i
        end
    end
    return nil
end

return I
]])

-- COMMS
w("/colony/lib/comms.lua", [[
local C = {}
local proto = "COLONY"

function C.hasModem()
    for _, s in ipairs({"top","bottom","left","right","front","back"}) do
        if peripheral.getType(s) == "modem" then
            return true, s
        end
    end
    return false
end

function C.open()
    local h, s = C.hasModem()
    if h then
        rednet.open(s)
        return true
    end
    return false
end

function C.broadcast(t, d)
    rednet.broadcast({type=t, data=d, from=os.getComputerID()}, proto)
end

function C.send(id, t, d)
    rednet.send(id, {type=t, data=d, from=os.getComputerID()}, proto)
end

function C.receive(to)
    return rednet.receive(proto, to or 1)
end

function C.announce(e, d)
    C.broadcast("hello", {event=e, label=os.getComputerLabel() or "T-"..os.getComputerID(), data=d})
end

return C
]])

-- REPORTER
w("/colony/lib/reporter.lua", [[
local R = {}
local Nav, Inv, State, Comms

function R.init(n, i, s, c)
    Nav = n
    Inv = i
    State = s
    Comms = c
end

function R.buildReport()
    return {
        id = os.getComputerID(),
        label = os.getComputerLabel() or "T-"..os.getComputerID(),
        role = State and State.get("role") or "?",
        generation = State and State.get("generation") or 0,
        position = Nav and Nav.getPosition() or {x=0,y=0,z=0},
        fuel = turtle.getFuelLevel(),
        fuelLimit = turtle.getFuelLimit(),
        state = State and State.get("currentState") or "idle"
    }
end

function R.heartbeat()
    if Comms then
        Comms.broadcast("heartbeat", R.buildReport())
    end
end

function R.startReporting()
    while true do
        R.heartbeat()
        sleep(5)
    end
end

function R.runParallel(fn)
    parallel.waitForAll(fn, R.startReporting)
end

return R
]])

-- COMMANDER (Remote Control)
w("/colony/lib/commander.lua", [[
local Cmd = {}
local Nav, Inv, State, Comms, Miner, Crafter, Brain
local handlers = {}
local shouldStop = false

function Cmd.init(n, i, s, c, m, cr, b)
    Nav = n
    Inv = i
    State = s
    Comms = c
    Miner = m
    Crafter = cr
    Brain = b
end

function Cmd.register(name, fn)
    handlers[name] = fn
end

function Cmd.execute(cmd, args)
    args = args or {}
    shouldStop = false
    local h = handlers[cmd]
    if h then
        local ok, res = pcall(h, args)
        return ok, ok and (res or "OK") or tostring(res)
    end
    return false, "Unknown: " .. cmd
end

function Cmd.reportResult(id, ok, msg)
    if Comms then
        Comms.broadcast("command_result", {commandId=id, success=ok, message=msg})
    end
end

-- Movement
Cmd.register("forward", function(a) for i=1,(a.count or 1) do if Nav then Nav.forward(a.dig) else turtle.forward() end end return "Moved" end)
Cmd.register("back", function(a) for i=1,(a.count or 1) do if Nav then Nav.back() else turtle.back() end end return "Moved" end)
Cmd.register("up", function(a) for i=1,(a.count or 1) do if Nav then Nav.up(a.dig) else turtle.up() end end return "Moved" end)
Cmd.register("down", function(a) for i=1,(a.count or 1) do if Nav then Nav.down(a.dig) else turtle.down() end end return "Moved" end)
Cmd.register("turnLeft", function() if Nav then Nav.turnLeft() else turtle.turnLeft() end return "Turned" end)
Cmd.register("turnRight", function() if Nav then Nav.turnRight() else turtle.turnRight() end return "Turned" end)
Cmd.register("turnAround", function() turtle.turnRight() turtle.turnRight() return "Turned" end)

-- Digging & Placing
Cmd.register("dig", function() return turtle.dig() and "Dug" or "Nothing" end)
Cmd.register("digUp", function() return turtle.digUp() and "Dug" or "Nothing" end)
Cmd.register("digDown", function() return turtle.digDown() and "Dug" or "Nothing" end)
Cmd.register("place", function() return turtle.place() and "Placed" or "Failed" end)
Cmd.register("placeUp", function() return turtle.placeUp() and "Placed" or "Failed" end)
Cmd.register("placeDown", function() return turtle.placeDown() and "Placed" or "Failed" end)
Cmd.register("suck", function(a) return turtle.suck(a.count) and "Got items" or "Nothing" end)
Cmd.register("attack", function() return turtle.attack() and "Attacked" or "Nothing" end)
Cmd.register("inspect", function() local ok,d=turtle.inspect() return ok and d.name or "Empty" end)

-- Inventory
Cmd.register("refuel", function(a) if Inv then return "Fuel: "..Inv.refuel(a.amount or 1000) else turtle.refuel() return "Fuel: "..turtle.getFuelLevel() end end)
Cmd.register("refuelLava", function(a)
    if not Inv then return "No Inv module" end
    local ok, result = Inv.refuelFromLava()
    if ok then return "Fuel: "..result else return "Failed: "..result end
end)
Cmd.register("refuelContainer", function(a)
    if not Inv then return "No Inv module" end
    local side = a.side or "front"
    local ok, result = Inv.refuelFromContainer(side)
    if ok then return "Fuel: "..result else return "Failed: "..result end
end)
Cmd.register("dropTrash", function() if Inv then Inv.dropTrash() return "Dropped" end return "No Inv" end)
Cmd.register("dumpToChest", function() if Inv then Inv.dumpToChest() return "Dumped" end for s=1,16 do turtle.select(s) turtle.drop() end return "Dumped" end)
Cmd.register("dropAll", function() for s=1,16 do turtle.select(s) turtle.drop() end turtle.select(1) return "Dropped" end)
Cmd.register("fuel", function() return "Fuel: "..turtle.getFuelLevel().."/"..turtle.getFuelLimit() end)
Cmd.register("inventory", function()
    local t=0 for s=1,16 do t=t+turtle.getItemCount(s) end
    return "Items: "..t.." Free: "..(16-Inv.freeSlots())
end)

-- Navigation
Cmd.register("goHome", function() if Nav then State.set("currentState","returning") Nav.goHome() State.set("currentState","idle") return "Home" end return "No Nav" end)
Cmd.register("goTo", function(a) if Nav and a.x and a.y and a.z then Nav.goTo(a.x,a.y,a.z) return "Arrived" end return "Missing coords" end)
Cmd.register("setHome", function() if Nav then Nav.setHome() return "Home set" end return "No Nav" end)
Cmd.register("locate", function() local x,y,z=gps.locate(2) if x then return x..","..y..","..z end return "No GPS" end)
Cmd.register("position", function() if Nav then local p=Nav.getPosition() return p.x..","..p.y..","..p.z end return "No Nav" end)

-- Mining Tasks
Cmd.register("mine", function(a) if not Miner then return "No Miner" end State.set("currentState","mining") local r=Miner.run() State.set("currentState","idle") return "Mined "..tostring(r) end)
Cmd.register("quarry", function(a)
    local size = a.size or 8
    State.set("currentState","quarrying")
    local mined = 0
    for layer = 1, 50 do
        for row = 1, size do
            for col = 1, size-1 do
                turtle.dig()
                if not Nav.forward() then Nav.digForward() end
                mined = mined + 1
                if shouldStop then State.set("currentState","idle") return "Stopped at "..mined end
            end
            if row < size then
                if row % 2 == 1 then Nav.turnRight() else Nav.turnLeft() end
                turtle.dig()
                Nav.digForward()
                if row % 2 == 1 then Nav.turnRight() else Nav.turnLeft() end
                mined = mined + 1
            end
        end
        Nav.turnRight() Nav.turnRight()
        if not Nav.digDown() then break end
        turtle.digDown()
        mined = mined + 1
    end
    Nav.goHome()
    State.set("currentState","idle")
    return "Quarry done: "..mined
end)
Cmd.register("tunnel", function(a)
    local length = a.length or 50
    State.set("currentState","tunneling")
    local mined = 0
    for i = 1, length do
        turtle.dig() turtle.digUp()
        if not Nav.forward() then Nav.digForward() end
        mined = mined + 2
        if shouldStop then State.set("currentState","idle") return "Stopped at "..mined end
        if Inv.isFull() then Inv.dropTrash() end
        if turtle.getFuelLevel() < 100 then Inv.refuel(500) end
    end
    State.set("currentState","idle")
    return "Tunnel done: "..mined
end)
Cmd.register("branch", function(a) if not Miner then return "No Miner" end State.set("currentState","mining") local r=Miner.run() State.set("currentState","idle") return "Branch done: "..tostring(r) end)

-- Crafting & Replication
Cmd.register("craft", function(a) if not Crafter then return "No Crafter" end local ok,r=Crafter.craft(a.recipe or a.item,a.count or 1) return ok and "Crafted "..r or "Failed: "..tostring(r) end)
Cmd.register("canCraft", function(a) if not Crafter then return "No Crafter" end local ok,m=Crafter.canCraft(a.recipe) return ok and "Yes" or "Missing: "..textutils.serialize(m) end)
Cmd.register("replicate", function(a)
    if not Crafter then return "No Crafter" end
    -- Check if we have a turtle in inventory already
    if Crafter.hasTurtle and Crafter.hasTurtle() then
        local gen = (State.get("generation") or 0) + 1
        local ok, result = Crafter.birthTurtle(gen)
        return ok and "Replicated: "..result or "Failed: "..result
    end
    -- Check if we can craft one
    local canMake, missing = Crafter.canBirthTurtle()
    if not canMake then
        local list = ""
        for item, count in pairs(missing) do
            list = list .. item:match(":(.+)") .. ":" .. count .. " "
        end
        return "Need: " .. list
    end
    local gen = (State.get("generation") or 0) + 1
    local ok, result = Crafter.birthTurtle(gen)
    return ok and "Replicated: "..result or "Failed: "..result
end)
Cmd.register("canReplicate", function()
    if not Crafter then return "No Crafter" end
    if Crafter.hasTurtle and Crafter.hasTurtle() then
        return "Have turtle in inventory!"
    end
    local ok, missing = Crafter.canBirthTurtle()
    if ok then return "Ready to craft!" end
    local list = ""
    for item, count in pairs(missing) do
        list = list .. item:match(":(.+)") .. ":" .. count .. " "
    end
    return "Need: " .. list
end)
Cmd.register("hasTurtle", function()
    if not Inv then return "No Inv" end
    local slot = Inv.findItem("turtle")
    return slot and "Yes, slot "..slot or "No turtle in inventory"
end)

-- Control
Cmd.register("stop", function() shouldStop=true if State then State.set("currentState","idle") State.set("shouldStop",true) end return "Stopped" end)
Cmd.register("pause", function() shouldStop=true if State then State.set("currentState","paused") end return "Paused" end)
Cmd.register("resume", function() shouldStop=false if State then State.set("shouldStop",false) end return "Resumed" end)
Cmd.register("auto", function() if not Brain then return "No Brain" end shouldStop=false Brain.run() return "Auto done" end)
Cmd.register("status", function() return "ID:"..os.getComputerID().." Fuel:"..turtle.getFuelLevel().." State:"..(State and State.get("currentState") or "?") end)
Cmd.register("dance", function() for i=1,4 do turtle.turnLeft() sleep(0.2) end for i=1,4 do turtle.turnRight() sleep(0.2) end return "Dance!" end)

-- Fuel Station
Cmd.register("setFuelStation", function(a)
    if not Nav then return "No Nav" end
    local side = a.side or "front"
    Nav.setFuelStation(nil, side)
    return "Fuel station set ("..side..")"
end)
Cmd.register("goRefuel", function(a)
    if not Nav or not Inv then return "No Nav/Inv" end
    local ok, side = Nav.goToFuelStation()
    if not ok then return side end
    local fuel, msg = Inv.refuelToMax(side)
    Nav.goHome()
    return "Fuel: "..fuel.." - "..msg
end)
Cmd.register("goRefuelLava", function(a)
    if not Nav or not Inv then return "No Nav/Inv" end
    local ok, side = Nav.goToFuelStation()
    if not ok then return side end
    local fuel, msg = Inv.refuelToMaxLava()
    Nav.goHome()
    return "Fuel: "..fuel.." - "..msg
end)
Cmd.register("refuelMax", function(a)
    if not Inv then return "No Inv" end
    local side = a.side or "front"
    local fuel, msg = Inv.refuelToMax(side)
    return "Fuel: "..fuel.." - "..msg
end)
Cmd.register("refuelMaxLava", function(a)
    if not Inv then return "No Inv" end
    local fuel, msg = Inv.refuelToMaxLava()
    return "Fuel: "..fuel.." - "..msg
end)

-- Storage Station
Cmd.register("setStorageStation", function(a)
    if not Nav then return "No Nav" end
    local side = a.side or "front"
    Nav.setStorageStation(nil, side)
    return "Storage station set ("..side..")"
end)
Cmd.register("goDeposit", function(a)
    if not Nav or not Inv then return "No Nav/Inv" end
    local ok, side = Nav.goToStorageStation()
    if not ok then return side end
    Inv.dumpToChest()
    Nav.goHome()
    return "Deposited items"
end)

-- Custom code execution
Cmd.register("exec", function(a)
    local fn,e=load(a.code,"remote","t",{turtle=turtle,Nav=Nav,Inv=Inv,State=State,sleep=sleep,print=print})
    if not fn then return "Err: "..e end
    local ok,r=pcall(fn)
    return ok and tostring(r or "OK") or "Err: "..r
end)

function Cmd.handleMessage(sid, msg)
    if msg.type == "command" then
        print("[CMD] "..msg.command)
        local ok, res = Cmd.execute(msg.command, msg.args)
        print("  -> "..(ok and "OK" or "FAIL")..": "..res)
        if msg.commandId then Cmd.reportResult(msg.commandId, ok, res) end
        return true
    end
    return false
end

function Cmd.listen()
    while true do
        if Comms then
            local sid, msg = Comms.receive(1)
            if sid and msg then Cmd.handleMessage(sid, msg) end
        else sleep(1) end
    end
end

return Cmd
]])

-- MINER
w("/colony/roles/miner.lua", [[
local M = {}
local Nav, Inv, State, Comms
local branchLength = 20
local minFuel = 300

function M.init(n, i, s, c)
    Nav = n
    Inv = i
    State = s
    Comms = c
end

function M.shouldReturn()
    if Inv.isFull() then return true, "full" end
    if turtle.getFuelLevel() < minFuel then return true, "fuel" end
    return false
end

function M.mineBranch(len)
    len = len or branchLength
    local mined = 0
    for i = 1, len do
        local r, why = M.shouldReturn()
        if r then
            Nav.goHome()
            if why == "full" then
                Inv.dumpToChest()
            else
                Inv.refuel(1000)
            end
            return mined
        end
        if not Nav.digForward() then break end
        Nav.digUp()
        mined = mined + 2
    end
    return mined
end

function M.run()
    print("[MINER] Starting...")
    local total = 0
    for b = 1, 5 do
        total = total + M.mineBranch()
        Nav.turnRight()
        Nav.turnRight()
        for i = 1, branchLength do
            Nav.forward()
        end
        Nav.turnRight()
        for i = 1, 3 do
            Nav.digForward()
        end
        Nav.turnRight()
    end
    Nav.goHome()
    return total
end

return M
]])

-- CRAFTER
w("/colony/roles/crafter.lua", [[
local C = {}
local Nav, Inv, State, Comms

function C.init(n, i, s, c)
    Nav = n
    Inv = i
    State = s
    Comms = c
end

-- Materials needed for a mining turtle
C.TURTLE_RECIPE = {
    ["minecraft:iron_ingot"] = 7,
    ["minecraft:chest"] = 1,
    ["minecraft:cobblestone"] = 7,
    ["minecraft:redstone"] = 1,
    ["minecraft:glass_pane"] = 1,
    ["minecraft:diamond_pickaxe"] = 1,
}

-- Check if we can craft a turtle
function C.canBirthTurtle()
    local missing = {}
    for item, need in pairs(C.TURTLE_RECIPE) do
        local have = Inv.countItem(item:match(":(.+)"))
        if have < need then
            missing[item] = need - have
        end
    end
    if next(missing) then
        return false, missing
    end
    return true, nil
end

-- Check if we already have a turtle in inventory
function C.hasTurtle()
    return Inv.findItem("turtle") ~= nil
end

-- Place and program a new turtle
function C.birthTurtle(generation)
    generation = generation or 1
    
    -- First check if we have a turtle
    local slot = Inv.findItem("turtle")
    if not slot then
        return false, "No turtle in inventory"
    end
    
    -- Find disk drive nearby
    local drive = peripheral.find("drive")
    
    -- Place the turtle in front
    turtle.select(slot)
    if not turtle.place() then
        return false, "Cannot place turtle"
    end
    
    -- Get the turtle peripheral
    local baby = peripheral.wrap("front")
    if not baby then
        return false, "Cannot access placed turtle"
    end
    
    -- If we have a disk drive with a disk, copy code
    if drive and drive.getDiskLabel then
        print("[BIRTH] Disk drive found, copying code...")
        -- The disk should have startup that downloads from pastebin
    end
    
    -- Set label
    local newLabel = "Worker-" .. os.epoch("utc") % 10000
    baby.setLabel(newLabel)
    
    -- Turn it on
    baby.turnOn()
    
    -- Announce birth
    if Comms then
        Comms.broadcast("birth", {
            parent = os.getComputerID(),
            child = newLabel,
            generation = generation,
        })
    end
    
    print("[BIRTH] Created: " .. newLabel .. " (Gen " .. generation .. ")")
    return true, newLabel
end

-- Simple craft function (for items we have recipes for)
function C.craft(recipe, count)
    -- This requires a crafting turtle
    if not turtle.craft then
        return false, "Not a crafting turtle"
    end
    return false, "Crafting not implemented"
end

function C.canCraft(recipe)
    return false, {["crafting"] = "not implemented"}
end

return C
]])

-- BRAIN
w("/colony/brain.lua", [[
local B = {}
local Nav, Inv, State, Comms, Miner, Crafter
local running = false

function B.init(n, i, s, c, m, cr)
    Nav = n
    Inv = i
    State = s
    Comms = c
    Miner = m
    Crafter = cr
end

function B.assess()
    if turtle.getFuelLevel() < 100 then
        return {a = "refuel"}
    end
    if Inv.isFull() then
        return {a = "dump"}
    end
    return {a = "mine"}
end

function B.execute(dec)
    State.set("currentState", dec.a)
    if dec.a == "refuel" then
        Nav.goHome()
        Inv.refuel(1000)
    elseif dec.a == "dump" then
        Nav.goHome()
        Inv.dropTrash()
        Inv.dumpToChest()
    elseif dec.a == "mine" then
        Miner.run()
    end
    State.set("currentState", "idle")
end

function B.run()
    running = true
    while running do
        local d = B.assess()
        print("[BRAIN] " .. d.a)
        B.execute(d)
        sleep(1)
    end
end

function B.stop()
    running = false
end

return B
]])

-- STARTUP
w("/colony/startup.lua", [[
print("=== GENESIS COLONY ===")

local function ld(p)
    if fs.exists(p .. ".lua") then
        return dofile(p .. ".lua")
    elseif fs.exists(p) then
        return dofile(p)
    else
        error("Missing: " .. p)
    end
end

local State = ld("/colony/lib/state")
local Nav = ld("/colony/lib/nav")
local Inv = ld("/colony/lib/inv")
local Comms = ld("/colony/lib/comms")
local Reporter = ld("/colony/lib/reporter")
local Commander = ld("/colony/lib/commander")
local Miner = ld("/colony/roles/miner")
local Crafter = ld("/colony/roles/crafter")
local Brain = ld("/colony/brain")

local l = os.getComputerLabel() or ""
local role = "worker"
if l:find("Eve") then role = "eve" end

print("Role: " .. role)
State.load()
Nav.init()

if Comms.hasModem() then
    Comms.open()
    print("[OK] Modem")
end

Reporter.init(Nav, Inv, State, Comms)
Miner.init(Nav, Inv, State, Comms)
Crafter.init(Nav, Inv, State, Comms)
Commander.init(Nav, Inv, State, Comms, Miner, Crafter, Brain)
Brain.init(Nav, Inv, State, Comms, Miner, Crafter)

if role == "eve" then
    dofile("/colony/eve.lua")
else
    State.set("role", "worker")
    Nav.setHome()
    parallel.waitForAny(
        function() Reporter.runParallel(function() Brain.run() end) end,
        function() Commander.listen() end
    )
end
]])

-- EVE
w("/colony/eve.lua", [[
print("=== EVE ===")

local function ld(p)
    if fs.exists(p .. ".lua") then
        return dofile(p .. ".lua")
    else
        return dofile(p)
    end
end

local State = ld("/colony/lib/state")
local Nav = ld("/colony/lib/nav")
local Inv = ld("/colony/lib/inv")
local Comms = ld("/colony/lib/comms")
local Reporter = ld("/colony/lib/reporter")
local Commander = ld("/colony/lib/commander")
local Miner = ld("/colony/roles/miner")
local Crafter = ld("/colony/roles/crafter")
local Brain = ld("/colony/brain")

State.load()
State.set("role", "eve")
State.set("generation", 0)
Nav.init()
Nav.setHome()

if Comms.hasModem() then
    Comms.open()
    Comms.announce("eve_online")
    print("[OK] Modem")
end

Reporter.init(Nav, Inv, State, Comms)
Miner.init(Nav, Inv, State, Comms)
Crafter.init(Nav, Inv, State, Comms)
Commander.init(Nav, Inv, State, Comms, Miner, Crafter, Brain)
Brain.init(Nav, Inv, State, Comms, Miner, Crafter)

while true do
    print("")
    print("=== MENU ===")
    print("1.Auto 2.Mine 3.Home 4.Fuel 5.Status 6.Test 7.Remote 0.Exit")
    write("> ")
    local c = read()
    
    if c == "1" then
        parallel.waitForAny(
            function() Reporter.runParallel(function() Brain.run() end) end,
            function() Commander.listen() end
        )
    elseif c == "2" then
        print("Mined: " .. Miner.run())
    elseif c == "3" then
        Nav.goHome()
        print("Home!")
    elseif c == "4" then
        print("Fuel: " .. Inv.refuel(1000))
    elseif c == "5" then
        print("ID: " .. os.getComputerID())
        print("Fuel: " .. turtle.getFuelLevel())
    elseif c == "6" then
        for i = 1, 3 do
            Reporter.heartbeat()
            print("Sent " .. i)
            sleep(1)
        end
    elseif c == "7" then
        print("Remote Control Mode (Ctrl+T to exit)")
        parallel.waitForAny(
            function() while true do Reporter.heartbeat() sleep(5) end end,
            function() Commander.listen() end
        )
    elseif c == "0" then
        return
    end
end
]])

-- TEST
w("/colony/test.lua", [[
print("=== TEST ===")

local m = nil
for _, s in ipairs({"top","bottom","left","right","front","back"}) do
    if peripheral.getType(s) == "modem" then
        m = s
        break
    end
end

if m then
    print("[OK] Modem: " .. m)
    rednet.open(m)
else
    print("[ERROR] No modem!")
    return
end

print("ID: " .. os.getComputerID())
print("Label: " .. (os.getComputerLabel() or "NOT SET"))
print("Sending 5 broadcasts...")

for i = 1, 5 do
    rednet.broadcast({
        type = "heartbeat",
        data = {
            id = os.getComputerID(),
            label = os.getComputerLabel() or "Test",
            role = "eve",
            position = {x=0, y=64, z=0},
            fuel = turtle.getFuelLevel(),
            fuelLimit = turtle.getFuelLimit(),
            state = "testing",
            generation = 0
        }
    }, "COLONY")
    print("Sent " .. i)
    sleep(2)
end
print("Done!")
]])

-- BRIDGE
w("/colony/bridge.lua", [[
local URL = "http://localhost:3000"

print("=== COLONY BRIDGE ===")
print("URL: " .. URL)

local m = nil
for _, s in ipairs({"top","bottom","left","right","front","back"}) do
    if peripheral.getType(s) == "modem" then
        m = s
        break
    end
end

if not m then
    print("[ERROR] No modem!")
    return
end

print("[OK] Modem: " .. m)
rednet.open(m)

if not http then
    print("[ERROR] HTTP disabled!")
    return
end

print("[OK] HTTP enabled")
print("Listening + polling commands...")

local lastPoll = 0

local function pollCommands()
    pcall(function()
        local r = http.get(URL .. "/api/commands")
        if r then
            local data = textutils.unserializeJSON(r.readAll())
            r.close()
            if data and data.commands then
                for _, cmd in ipairs(data.commands) do
                    print("[CMD] " .. cmd.command .. " -> #" .. tostring(cmd.targetId))
                    local tid = tonumber(cmd.targetId)
                    if tid then
                        rednet.send(tid, {type="command", command=cmd.command, args=cmd.args or {}, commandId=cmd.id}, "COLONY")
                    else
                        rednet.broadcast({type="command", command=cmd.command, args=cmd.args or {}, commandId=cmd.id}, "COLONY")
                    end
                end
            end
        end
    end)
end

local function reportResult(cid, ok, msg)
    pcall(function()
        local json = textutils.serializeJSON({commandId=cid, success=ok, message=msg})
        local r = http.post(URL .. "/api/command-result", json, {["Content-Type"]="application/json"})
        if r then r.close() end
    end)
end

while true do
    local id, msg = rednet.receive("COLONY", 0.5)
    if id and type(msg) == "table" then
        if msg.type == "command_result" then
            print("[RESULT] #" .. id .. ": " .. (msg.success and "OK" or "FAIL"))
            reportResult(msg.commandId, msg.success, msg.message)
        else
            local lbl = "?"
            if msg.data and msg.data.label then lbl = msg.data.label end
            print(os.date("%H:%M:%S") .. " " .. lbl)
            pcall(function()
                local json = textutils.serializeJSON({type=msg.type, turtle=msg.data})
                local r = http.post(URL .. "/api/update", json, {["Content-Type"]="application/json"})
                if r then r.close() print("  -> web") end
            end)
        end
    end
    
    local now = os.epoch("utc")
    if now - lastPoll >= 1000 then
        pollCommands()
        lastPoll = now
    end
end
]])

print("")
print("========================================")
print("  DONE! All files created.")
print("========================================")
print("")
print("Next steps:")
print("  label set Eve-1")
print("  refuel all")
print("  /colony/eve")
