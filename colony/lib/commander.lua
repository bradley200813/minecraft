-- ============================================
-- COMMANDER.LUA - Remote Command Handler
-- ============================================
-- Handles commands received from the web dashboard

local Commander = {}

-- Dependencies (set via init)
local Nav, Inv, State, Comms, Miner, Crafter, Brain

-- Command handlers
local commandHandlers = {}

-- Flag to stop current task
local shouldStop = false

-- Initialize with dependencies
function Commander.init(nav, inv, state, comms, miner, crafter, brain)
    Nav = nav
    Inv = inv
    State = state
    Comms = comms
    Miner = miner
    Crafter = crafter
    Brain = brain
end

-- Register a command handler
function Commander.register(command, handler)
    commandHandlers[command] = handler
end

-- Check if should stop
function Commander.shouldStop()
    return shouldStop
end

-- Execute a command and return result
function Commander.execute(command, args)
    args = args or {}
    shouldStop = false
    
    local handler = commandHandlers[command]
    if handler then
        local success, result = pcall(handler, args)
        if success then
            return true, result or "OK"
        else
            return false, "Error: " .. tostring(result)
        end
    else
        return false, "Unknown command: " .. command
    end
end

-- Send command result back to bridge
function Commander.reportResult(commandId, success, message)
    if Comms then
        Comms.broadcast(Comms.MSG.COMMAND_RESULT, {
            commandId = commandId,
            success = success,
            message = message,
        })
    end
end

-- ==========================================
-- BASIC MOVEMENT COMMANDS
-- ==========================================

Commander.register("forward", function(args)
    local count = args.count or 1
    local success = true
    for i = 1, count do
        if shouldStop then return "Stopped" end
        if Nav then
            success = Nav.forward(args.dig) and success
        else
            success = turtle.forward() and success
        end
    end
    return success and "Moved forward " .. count or "Blocked"
end)

Commander.register("back", function(args)
    local count = args.count or 1
    local success = true
    for i = 1, count do
        if shouldStop then return "Stopped" end
        if Nav then
            success = Nav.back() and success
        else
            success = turtle.back() and success
        end
    end
    return success and "Moved back " .. count or "Blocked"
end)

Commander.register("up", function(args)
    local count = args.count or 1
    local success = true
    for i = 1, count do
        if shouldStop then return "Stopped" end
        if Nav then
            success = Nav.up(args.dig) and success
        else
            success = turtle.up() and success
        end
    end
    return success and "Moved up " .. count or "Blocked"
end)

Commander.register("down", function(args)
    local count = args.count or 1
    local success = true
    for i = 1, count do
        if shouldStop then return "Stopped" end
        if Nav then
            success = Nav.down(args.dig) and success
        else
            success = turtle.down() and success
        end
    end
    return success and "Moved down " .. count or "Blocked"
end)

Commander.register("turnLeft", function(args)
    if Nav then
        Nav.turnLeft()
    else
        turtle.turnLeft()
    end
    return "Turned left"
end)

Commander.register("turnRight", function(args)
    if Nav then
        Nav.turnRight()
    else
        turtle.turnRight()
    end
    return "Turned right"
end)

Commander.register("turnAround", function(args)
    if Nav then
        Nav.turnRight()
        Nav.turnRight()
    else
        turtle.turnRight()
        turtle.turnRight()
    end
    return "Turned around"
end)

-- ==========================================
-- DIGGING COMMANDS
-- ==========================================

Commander.register("dig", function(args)
    local success = turtle.dig()
    return success and "Block dug" or "Nothing to dig"
end)

Commander.register("digUp", function(args)
    local success = turtle.digUp()
    return success and "Block dug above" or "Nothing to dig"
end)

Commander.register("digDown", function(args)
    local success = turtle.digDown()
    return success and "Block dug below" or "Nothing to dig"
end)

Commander.register("digForward", function(args)
    -- Dig until clear (handles falling blocks)
    local count = 0
    while turtle.detect() do
        if shouldStop then return "Stopped after " .. count end
        turtle.dig()
        count = count + 1
        sleep(0.5)
    end
    return "Dug " .. count .. " blocks"
end)

-- ==========================================
-- PLACE COMMANDS
-- ==========================================

Commander.register("place", function(args)
    local success = turtle.place()
    return success and "Block placed" or "Cannot place"
end)

Commander.register("placeUp", function(args)
    local success = turtle.placeUp()
    return success and "Block placed above" or "Cannot place"
end)

Commander.register("placeDown", function(args)
    local success = turtle.placeDown()
    return success and "Block placed below" or "Cannot place"
end)

-- ==========================================
-- INVENTORY COMMANDS
-- ==========================================

Commander.register("refuel", function(args)
    local amount = args.amount or 1000
    if Inv then
        local fuel = Inv.refuel(amount)
        return "Fuel: " .. fuel
    else
        turtle.refuel()
        return "Fuel: " .. turtle.getFuelLevel()
    end
end)

Commander.register("select", function(args)
    local slot = args.slot or 1
    turtle.select(slot)
    return "Selected slot " .. slot
end)

Commander.register("drop", function(args)
    local count = args.count
    local success = turtle.drop(count)
    return success and "Items dropped" or "Nothing to drop"
end)

Commander.register("dropAll", function(args)
    local dropped = 0
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.drop() then
            dropped = dropped + 1
        end
    end
    turtle.select(1)
    return "Dropped from " .. dropped .. " slots"
end)

Commander.register("dropTrash", function(args)
    if Inv then
        Inv.dropTrash()
        return "Trash dropped"
    else
        return "Inv module not available"
    end
end)

Commander.register("suck", function(args)
    local count = args.count
    local success = turtle.suck(count)
    return success and "Items collected" or "Nothing to collect"
end)

Commander.register("suckUp", function(args)
    local count = args.count
    local success = turtle.suckUp(count)
    return success and "Items collected from above" or "Nothing to collect"
end)

Commander.register("suckDown", function(args)
    local count = args.count
    local success = turtle.suckDown(count)
    return success and "Items collected from below" or "Nothing to collect"
end)

Commander.register("dumpToChest", function(args)
    if Inv then
        Inv.dumpToChest()
        return "Dumped items to chest"
    else
        -- Try to dump manually
        for slot = 1, 16 do
            turtle.select(slot)
            turtle.drop()
        end
        turtle.select(1)
        return "Dumped items"
    end
end)

Commander.register("inventory", function(args)
    local items = {}
    local total = 0
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            items[item.name] = (items[item.name] or 0) + item.count
            total = total + item.count
        end
    end
    local result = "Items: " .. total .. " | "
    for name, count in pairs(items) do
        local short = name:match(":(.+)") or name
        result = result .. short .. ":" .. count .. " "
    end
    return result
end)

-- ==========================================
-- NAVIGATION COMMANDS
-- ==========================================

Commander.register("goHome", function(args)
    if Nav then
        State.set("currentState", "returning")
        Nav.goHome()
        State.set("currentState", "idle")
        return "Arrived home"
    else
        return "Nav module not available"
    end
end)

Commander.register("goTo", function(args)
    if Nav and args.x and args.y and args.z then
        State.set("currentState", "moving")
        Nav.goTo(args.x, args.y, args.z)
        State.set("currentState", "idle")
        return "Arrived at " .. args.x .. ", " .. args.y .. ", " .. args.z
    else
        return "Missing coordinates or Nav module"
    end
end)

Commander.register("setHome", function(args)
    if Nav then
        if args.x and args.y and args.z then
            Nav.setHome(args.x, args.y, args.z)
        else
            Nav.setHome()
        end
        local pos = Nav.getHome()
        return "Home set to " .. pos.x .. ", " .. pos.y .. ", " .. pos.z
    else
        return "Nav module not available"
    end
end)

Commander.register("locate", function(args)
    local x, y, z = gps.locate(2)
    if x then
        if Nav then
            Nav.setPosition(x, y, z)
        end
        return "GPS: " .. x .. ", " .. y .. ", " .. z
    else
        return "No GPS signal"
    end
end)

-- ==========================================
-- MINING COMMANDS
-- ==========================================

Commander.register("mine", function(args)
    if not Miner then return "Miner module not available" end
    
    local pattern = args.pattern or "branch"
    State.set("currentState", "mining")
    
    local result
    if pattern == "branch" then
        result = Miner.branchMine()
    elseif pattern == "tunnel" then
        result = Miner.tunnelMine()
    elseif pattern == "quarry" then
        result = Miner.quarryMine()
    elseif pattern == "strip" then
        result = Miner.stripMine()
    else
        result = Miner.run(pattern)
    end
    
    State.set("currentState", "idle")
    
    if type(result) == "table" then
        return "Mined " .. (result.blocksMined or 0) .. " blocks, " .. (result.oresMined or 0) .. " ores"
    else
        return "Mined " .. tostring(result) .. " blocks"
    end
end)

Commander.register("quarry", function(args)
    if not Miner then return "Miner module not available" end
    
    local size = args.size or 8
    Miner.configure({ quarrySize = size })
    
    State.set("currentState", "quarrying")
    local result = Miner.quarryMine()
    State.set("currentState", "idle")
    
    if type(result) == "table" then
        return "Quarry complete: " .. (result.blocksMined or 0) .. " blocks"
    else
        return "Quarry complete"
    end
end)

Commander.register("tunnel", function(args)
    if not Miner then return "Miner module not available" end
    
    local length = args.length or 50
    Miner.configure({ tunnelLength = length })
    
    State.set("currentState", "tunneling")
    local result = Miner.tunnelMine()
    State.set("currentState", "idle")
    
    if type(result) == "table" then
        return "Tunnel complete: " .. (result.blocksMined or 0) .. " blocks"
    else
        return "Tunnel complete"
    end
end)

Commander.register("branch", function(args)
    if not Miner then return "Miner module not available" end
    
    if args.length then
        Miner.configure({ branchLength = args.length })
    end
    if args.spacing then
        Miner.configure({ branchSpacing = args.spacing })
    end
    
    State.set("currentState", "branch_mining")
    local result = Miner.branchMine()
    State.set("currentState", "idle")
    
    if type(result) == "table" then
        return "Branch mining complete: " .. (result.blocksMined or 0) .. " blocks"
    else
        return "Branch mining complete"
    end
end)

-- ==========================================
-- CRAFTING COMMANDS
-- ==========================================

Commander.register("craft", function(args)
    if not Crafter then return "Crafter module not available" end
    
    local recipe = args.recipe or args.item
    if not recipe then
        return "Specify recipe name"
    end
    
    local count = args.count or 1
    local success, result = Crafter.craft(recipe, count)
    
    if success then
        return "Crafted " .. result .. "x " .. recipe
    else
        return "Failed: " .. tostring(result)
    end
end)

Commander.register("canCraft", function(args)
    if not Crafter then return "Crafter module not available" end
    
    local recipe = args.recipe or args.item
    if not recipe then
        return "Specify recipe name"
    end
    
    local canDo, missing = Crafter.canCraft(recipe)
    if canDo then
        return "Can craft " .. recipe
    else
        local missingStr = ""
        for mat, count in pairs(missing) do
            missingStr = missingStr .. mat .. ":" .. count .. " "
        end
        return "Missing: " .. missingStr
    end
end)

-- ==========================================
-- REPLICATION COMMANDS
-- ==========================================

Commander.register("replicate", function(args)
    if not Crafter then return "Crafter module not available" end
    
    State.set("currentState", "replicating")
    
    -- Check if we can birth a turtle
    local canBirth, missing = Crafter.canBirthTurtle()
    if not canBirth then
        State.set("currentState", "idle")
        local missingStr = ""
        for mat, count in pairs(missing) do
            missingStr = missingStr .. mat .. ":" .. count .. " "
        end
        return "Cannot replicate. Missing: " .. missingStr
    end
    
    -- Get current generation
    local gen = State.get("generation") or 0
    
    -- Do the birth!
    local success, result = Crafter.birthTurtle(gen + 1)
    State.set("currentState", "idle")
    
    if success then
        return "Successfully created new turtle! Generation " .. (gen + 1)
    else
        return "Replication failed: " .. tostring(result)
    end
end)

Commander.register("canReplicate", function(args)
    if not Crafter then return "Crafter module not available" end
    
    local canBirth, missing = Crafter.canBirthTurtle()
    if canBirth then
        return "Ready to replicate!"
    else
        local missingStr = ""
        for mat, count in pairs(missing) do
            missingStr = missingStr .. mat .. ":" .. count .. " "
        end
        return "Cannot replicate. Need: " .. missingStr
    end
end)

-- ==========================================
-- ATTACK COMMANDS
-- ==========================================

Commander.register("attack", function(args)
    local success = turtle.attack()
    return success and "Attacked!" or "Nothing to attack"
end)

Commander.register("attackUp", function(args)
    local success = turtle.attackUp()
    return success and "Attacked above!" or "Nothing to attack"
end)

Commander.register("attackDown", function(args)
    local success = turtle.attackDown()
    return success and "Attacked below!" or "Nothing to attack"
end)

-- ==========================================
-- INSPECTION COMMANDS
-- ==========================================

Commander.register("inspect", function(args)
    local success, data = turtle.inspect()
    if success then
        return "Block: " .. data.name
    else
        return "No block"
    end
end)

Commander.register("inspectUp", function(args)
    local success, data = turtle.inspectUp()
    if success then
        return "Block above: " .. data.name
    else
        return "No block above"
    end
end)

Commander.register("inspectDown", function(args)
    local success, data = turtle.inspectDown()
    if success then
        return "Block below: " .. data.name
    else
        return "No block below"
    end
end)

-- ==========================================
-- TASK CONTROL COMMANDS
-- ==========================================

Commander.register("stop", function(args)
    shouldStop = true
    if State then
        State.set("currentState", "idle")
        State.set("shouldStop", true)
    end
    return "Stop requested"
end)

Commander.register("pause", function(args)
    shouldStop = true
    if State then
        State.set("currentState", "paused")
    end
    return "Paused"
end)

Commander.register("resume", function(args)
    shouldStop = false
    if State then
        State.set("shouldStop", false)
    end
    return "Resumed"
end)

Commander.register("auto", function(args)
    if not Brain then return "Brain module not available" end
    
    shouldStop = false
    State.set("currentState", "autonomous")
    Brain.run()
    State.set("currentState", "idle")
    return "Autonomous mode ended"
end)

-- ==========================================
-- STATUS COMMANDS
-- ==========================================

Commander.register("status", function(args)
    local status = {
        id = os.getComputerID(),
        label = os.getComputerLabel() or "unknown",
        fuel = turtle.getFuelLevel(),
        fuelLimit = turtle.getFuelLimit(),
    }
    
    if Nav then
        status.position = Nav.getPosition()
        status.facing = Nav.getFacingName()
        status.home = Nav.getHome()
    end
    
    if Inv then
        status.freeSlots = Inv.freeSlots()
    end
    
    if State then
        status.state = State.get("currentState") or "idle"
        status.role = State.get("role") or "worker"
        status.generation = State.get("generation") or 0
    end
    
    return textutils.serialize(status)
end)

Commander.register("fuel", function(args)
    return "Fuel: " .. turtle.getFuelLevel() .. "/" .. turtle.getFuelLimit()
end)

Commander.register("position", function(args)
    if Nav then
        local pos = Nav.getPosition()
        return "Position: " .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. " facing " .. Nav.getFacingName()
    else
        return "Nav module not available"
    end
end)

-- ==========================================
-- PERIPHERAL COMMANDS
-- ==========================================

Commander.register("equip", function(args)
    local side = args.side or "left"
    if side == "left" then
        turtle.equipLeft()
        return "Equipped left"
    else
        turtle.equipRight()
        return "Equipped right"
    end
end)

-- ==========================================
-- CUSTOM/SCRIPT COMMANDS
-- ==========================================

Commander.register("exec", function(args)
    local code = args.code
    if not code then
        return "No code provided"
    end
    
    local fn, err = load(code, "remote", "t", {
        turtle = turtle,
        Nav = Nav,
        Inv = Inv,
        State = State,
        Comms = Comms,
        Miner = Miner,
        Crafter = Crafter,
        sleep = sleep,
        print = print,
    })
    
    if not fn then
        return "Syntax error: " .. tostring(err)
    end
    
    local success, result = pcall(fn)
    if success then
        return tostring(result or "OK")
    else
        return "Runtime error: " .. tostring(result)
    end
end)

Commander.register("dance", function(args)
    -- Fun command!
    for i = 1, 4 do
        turtle.turnLeft()
        sleep(0.3)
    end
    for i = 1, 4 do
        turtle.turnRight()
        sleep(0.3)
    end
    return "💃 Dance complete!"
end)

-- ==========================================
-- COMMAND LISTENER
-- ==========================================

-- Process incoming command messages
function Commander.handleMessage(senderId, msg)
    if msg.type == "command" then
        local command = msg.command
        local args = msg.args or {}
        local commandId = msg.commandId
        
        print("[CMD] Received: " .. command)
        
        local success, result = Commander.execute(command, args)
        
        print("  -> " .. (success and "OK" or "FAIL") .. ": " .. tostring(result))
        
        -- Report result back
        if commandId then
            Commander.reportResult(commandId, success, result)
        end
        
        return true
    end
    return false
end

-- Run command listener as parallel task
-- Use this with parallel.waitForAny or parallel.waitForAll
function Commander.listen()
    while true do
        if Comms then
            local senderId, msg = Comms.receive(1)
            if senderId and msg then
                Commander.handleMessage(senderId, msg)
            end
        else
            sleep(1)
        end
    end
end

-- Run main function with command listener in parallel
function Commander.runWithListener(mainFunc)
    parallel.waitForAny(
        mainFunc,
        Commander.listen
    )
end

return Commander
