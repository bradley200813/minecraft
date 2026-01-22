-- ============================================
-- COMMS.LUA - Colony Communication Protocol
-- ============================================
-- Rednet-based communication between turtles

local Comms = {}

-- Protocol identifier
local PROTOCOL = "COLONY"
local CHANNEL = 100

-- Message types
Comms.MSG = {
    -- Discovery
    PING = "ping",
    PONG = "pong",
    HELLO = "hello",
    GOODBYE = "goodbye",
    
    -- Colony management
    REGISTER = "register",
    HEARTBEAT = "heartbeat",
    STATUS = "status",
    ASSIGN_ROLE = "assign_role",
    
    -- Tasks
    TASK = "task",
    TASK_COMPLETE = "task_complete",
    TASK_FAILED = "task_failed",
    
    -- Resources
    NEED = "need",
    HAVE = "have",
    DEPOSIT = "deposit",
    WITHDRAW = "withdraw",
    
    -- Emergencies
    HELP = "help",
    LOW_FUEL = "low_fuel",
    STUCK = "stuck",
    INVENTORY_FULL = "inventory_full",
    
    -- Queries
    WHERE_IS = "where_is",
    WHO_HAS = "who_has",
    COLONY_STATUS = "colony_status",
    
    -- Remote control (from dashboard)
    COMMAND = "command",
    COMMAND_RESULT = "command_result",
}

-- State
local modemSide = nil
local myId = nil
local isOpen = false
local messageQueue = {}
local handlers = {}
local knownPeers = {}

-- Find and open modem
function Comms.open()
    myId = os.getComputerID()
    
    -- Find modem
    local sides = {"left", "right", "top", "bottom", "front", "back"}
    for _, side in ipairs(sides) do
        local ptype = peripheral.getType(side)
        if ptype == "modem" then
            modemSide = side
            print("[COMMS] Found modem on " .. side)
            break
        end
    end
    
    if not modemSide then
        print("[COMMS] ERROR: No modem found on any side!")
        print("[COMMS] Make sure turtle has a wireless modem equipped")
        isOpen = false
        return false
    end
    
    -- Open rednet
    local ok, err = pcall(rednet.open, modemSide)
    if not ok then
        print("[COMMS] ERROR opening rednet: " .. tostring(err))
        isOpen = false
        return false
    end
    
    isOpen = true
    
    -- Host on protocol
    pcall(function()
        rednet.host(PROTOCOL, os.getComputerLabel() or ("Turtle-" .. myId))
    end)
    
    print("[COMMS] Opened on " .. modemSide .. " (ID: " .. myId .. ")")
    return true
end

-- Check if comms are open
function Comms.isOpen()
    return isOpen
end

-- Close communications
function Comms.close()
    if isOpen then
        rednet.unhost(PROTOCOL)
        rednet.close(modemSide)
        isOpen = false
    end
end

-- Build a message
local function buildMessage(msgType, data)
    return {
        type = msgType,
        sender = myId,
        timestamp = os.epoch("utc"),
        data = data or {},
    }
end

-- Send to specific turtle
function Comms.send(targetId, msgType, data)
    if not isOpen then
        return false
    end
    
    local msg = buildMessage(msgType, data)
    return rednet.send(targetId, msg, PROTOCOL)
end

-- Broadcast to all colony members
function Comms.broadcast(msgType, data)
    if not isOpen then
        return false
    end
    
    local msg = buildMessage(msgType, data)
    rednet.broadcast(msg, PROTOCOL)
    return true
end

-- Receive a message (with timeout)
function Comms.receive(timeout)
    if not isOpen then
        return nil
    end
    
    local senderId, msg = rednet.receive(PROTOCOL, timeout)
    if senderId then
        -- Track peer
        knownPeers[senderId] = {
            lastSeen = os.epoch("utc"),
            data = msg.data,
        }
        return senderId, msg
    end
    return nil
end

-- Non-blocking check for messages
function Comms.poll()
    return Comms.receive(0)
end

-- Register message handler
function Comms.on(msgType, handler)
    if not handlers[msgType] then
        handlers[msgType] = {}
    end
    table.insert(handlers[msgType], handler)
end

-- Process incoming messages (call in main loop)
function Comms.process(timeout)
    timeout = timeout or 0.1
    
    local senderId, msg = Comms.receive(timeout)
    if senderId and msg then
        -- Call registered handlers
        local typeHandlers = handlers[msg.type]
        if typeHandlers then
            for _, handler in ipairs(typeHandlers) do
                handler(senderId, msg.data, msg)
            end
        end
        
        -- Also call wildcard handlers
        local wildcardHandlers = handlers["*"]
        if wildcardHandlers then
            for _, handler in ipairs(wildcardHandlers) do
                handler(senderId, msg.data, msg)
            end
        end
        
        return true, senderId, msg
    end
    return false
end

-- ==========================================
-- HIGH-LEVEL COLONY FUNCTIONS
-- ==========================================

-- Announce presence to colony
function Comms.announce(role, position)
    return Comms.broadcast(Comms.MSG.HELLO, {
        role = role,
        position = position,
        fuel = turtle.getFuelLevel(),
        label = os.getComputerLabel(),
    })
end

-- Send heartbeat
function Comms.heartbeat(status)
    return Comms.broadcast(Comms.MSG.HEARTBEAT, {
        role = status.role,
        position = status.position,
        fuel = turtle.getFuelLevel(),
        task = status.currentTask,
        inventory = status.inventorySummary,
    })
end

-- Discover other turtles
function Comms.discover(timeout)
    timeout = timeout or 2
    
    Comms.broadcast(Comms.MSG.PING, {})
    
    local found = {}
    local startTime = os.epoch("utc")
    
    while (os.epoch("utc") - startTime) < (timeout * 1000) do
        local senderId, msg = Comms.receive(0.5)
        if senderId and msg.type == Comms.MSG.PONG then
            found[senderId] = msg.data
        end
    end
    
    return found
end

-- Request help
function Comms.requestHelp(issue, details)
    return Comms.broadcast(Comms.MSG.HELP, {
        issue = issue,
        details = details,
        position = details.position,
        fuel = turtle.getFuelLevel(),
    })
end

-- Report resource need
function Comms.needResource(resource, amount)
    return Comms.broadcast(Comms.MSG.NEED, {
        resource = resource,
        amount = amount,
    })
end

-- Report resource availability
function Comms.haveResource(resource, amount, location)
    return Comms.broadcast(Comms.MSG.HAVE, {
        resource = resource,
        amount = amount,
        location = location,
    })
end

-- Send task to another turtle
function Comms.assignTask(targetId, task)
    return Comms.send(targetId, Comms.MSG.TASK, task)
end

-- Report task completion
function Comms.reportTaskComplete(taskId, result)
    return Comms.broadcast(Comms.MSG.TASK_COMPLETE, {
        taskId = taskId,
        result = result,
    })
end

-- Get known peers
function Comms.getPeers()
    return knownPeers
end

-- Get count of known peers
function Comms.getPeerCount()
    local count = 0
    for _ in pairs(knownPeers) do
        count = count + 1
    end
    return count
end

-- Check if modem is available
function Comms.hasModem()
    if modemSide ~= nil then
        return true, modemSide
    end
    -- Check all sides for modem
    local sides = {"left", "right", "top", "bottom", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "modem" then
            return true, side
        end
    end
    return false
end

-- Get my ID
function Comms.getId()
    return myId or os.getComputerID()
end

-- Lookup by hostname
function Comms.lookup(hostname)
    return rednet.lookup(PROTOCOL, hostname)
end

-- Lookup all colony members
function Comms.lookupAll()
    local ids = {rednet.lookup(PROTOCOL)}
    return ids
end

-- Setup default handlers
function Comms.setupDefaultHandlers()
    -- Respond to pings
    Comms.on(Comms.MSG.PING, function(senderId, data)
        Comms.send(senderId, Comms.MSG.PONG, {
            role = data.role or "unknown",
            label = os.getComputerLabel(),
        })
    end)
    
    -- Log hellos
    Comms.on(Comms.MSG.HELLO, function(senderId, data)
        print("[COMMS] " .. (data.label or senderId) .. " joined the colony")
    end)
    
    -- Log goodbyes
    Comms.on(Comms.MSG.GOODBYE, function(senderId, data)
        print("[COMMS] " .. senderId .. " left the colony")
        knownPeers[senderId] = nil
    end)
end

return Comms
