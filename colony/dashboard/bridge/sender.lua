-- ============================================
-- SENDER.LUA - HTTP Bridge for CC:Tweaked
-- ============================================
-- Run this on a CC Computer with HTTP access enabled
-- It receives colony updates via Rednet and sends to the web server
--
-- Requirements:
-- 1. Enable HTTP in CC:Tweaked config (computercraft-server.toml)
--    [[http.rules]]
--    host = "*"
--    action = "allow"
--
-- 2. Run the Node.js bridge server on your PC
-- 3. Run this program on a CC Computer with wireless modem

-- Configuration
local CONFIG = {
    -- Change this to your computer's IP if not localhost
    serverUrl = "http://localhost:3000/api/update",
    
    -- How often to send heartbeats (seconds)
    heartbeatInterval = 5,
    
    -- Rednet protocol
    protocol = "COLONY",
}

-- State
local turtles = {}
local sendQueue = {}

-- Find and open modem
local modemSide = nil
for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
    if peripheral.getType(side) == "modem" then
        modemSide = side
        break
    end
end

if not modemSide then
    print("ERROR: No modem found!")
    print("Attach a wireless modem and try again.")
    return
end

rednet.open(modemSide)
rednet.host(CONFIG.protocol, "Bridge")

print("========================================")
print("  COLONY WEB BRIDGE")
print("========================================")
print("")
print("Modem: " .. modemSide)
print("Protocol: " .. CONFIG.protocol)
print("Server: " .. CONFIG.serverUrl)
print("")

-- Check HTTP availability
if not http then
    print("ERROR: HTTP API not available!")
    print("")
    print("Enable HTTP in the CC:Tweaked config:")
    print("  computercraft-server.toml")
    print("")
    print("Add these lines:")
    print("  [[http.rules]]")
    print("  host = \"*\"")
    print("  action = \"allow\"")
    return
end

-- Test server connection
print("Testing connection to server...")
local testOk, testErr = pcall(function()
    local response = http.post(
        CONFIG.serverUrl,
        textutils.serializeJSON({type = "ping"}),
        {["Content-Type"] = "application/json"}
    )
    if response then
        response.close()
        return true
    end
    return false
end)

if testOk then
    print("Connected to bridge server!")
else
    print("WARNING: Could not reach server")
    print("Make sure Node.js server is running:")
    print("  cd colony/dashboard/bridge")
    print("  node server.js")
    print("")
    print("Continuing anyway...")
end

print("")
print("Listening for turtle updates...")
print("========================================")

-- Send data to web server
local function sendToServer(data)
    local ok, err = pcall(function()
        local json = textutils.serializeJSON(data)
        local response = http.post(
            CONFIG.serverUrl,
            json,
            {["Content-Type"] = "application/json"}
        )
        if response then
            response.close()
            return true
        end
    end)
    
    if not ok then
        -- Queue for retry
        table.insert(sendQueue, data)
        if #sendQueue > 100 then
            table.remove(sendQueue, 1)
        end
    end
    
    return ok
end

-- Process queued messages
local function processQueue()
    while true do
        if #sendQueue > 0 then
            local data = table.remove(sendQueue, 1)
            sendToServer(data)
        end
        sleep(1)
    end
end

-- Handle incoming rednet messages
local function handleRednet()
    while true do
        local senderId, message = rednet.receive(CONFIG.protocol, 1)
        
        if senderId and type(message) == "table" then
            local msgType = message.type
            
            if msgType == "heartbeat" or msgType == "status" then
                -- Update local cache
                turtles[senderId] = {
                    id = senderId,
                    label = message.data and message.data.label or ("Turtle-" .. senderId),
                    role = message.data and message.data.role or "worker",
                    position = message.data and message.data.position or {x=0, y=0, z=0},
                    fuel = message.data and message.data.fuel or 0,
                    fuelLimit = message.data and message.data.fuelLimit or 20000,
                    state = message.data and message.data.state or "idle",
                    generation = message.data and message.data.generation or 0,
                    lastSeen = os.epoch("utc"),
                }
                
                -- Send to web server
                sendToServer({
                    type = "heartbeat",
                    turtle = turtles[senderId],
                })
                
                print(string.format("[%s] %s - %s (Fuel: %d)",
                    os.date("%H:%M:%S"),
                    turtles[senderId].label,
                    turtles[senderId].state,
                    turtles[senderId].fuel
                ))
                
            elseif msgType == "hello" then
                local data = message.data or {}
                print(string.format("[%s] NEW: %s joined!",
                    os.date("%H:%M:%S"),
                    data.label or senderId
                ))
                
                sendToServer({
                    type = "event",
                    eventType = "birth",
                    message = (data.label or senderId) .. " joined the colony",
                    data = data,
                })
                
            elseif msgType == "task_complete" then
                local data = message.data or {}
                local label = turtles[senderId] and turtles[senderId].label or senderId
                
                sendToServer({
                    type = "event",
                    eventType = "mining",
                    message = label .. " completed task",
                    data = data,
                })
                
                if data.blocksMined then
                    sendToServer({
                        type = "stats",
                        stats = { totalBlocksMined = data.blocksMined },
                    })
                end
                
            elseif msgType == "low_fuel" or msgType == "inventory_full" or msgType == "help" then
                local label = turtles[senderId] and turtles[senderId].label or senderId
                
                sendToServer({
                    type = "event",
                    eventType = msgType == "low_fuel" and "fuel" or "error",
                    message = label .. ": " .. msgType,
                    data = message.data,
                })
            end
        end
    end
end

-- Respond to ping requests
local function handlePings()
    while true do
        local senderId, message = rednet.receive(CONFIG.protocol, 0.5)
        
        if senderId and type(message) == "table" and message.type == "ping" then
            rednet.send(senderId, {
                type = "pong",
                data = {
                    role = "bridge",
                    label = "Web Bridge",
                }
            }, CONFIG.protocol)
        end
    end
end

-- Display status
local function displayStatus()
    while true do
        sleep(30)
        
        local count = 0
        local now = os.epoch("utc")
        for id, t in pairs(turtles) do
            if (now - t.lastSeen) < 60000 then
                count = count + 1
            end
        end
        
        print(string.format("[%s] Active turtles: %d | Queue: %d",
            os.date("%H:%M:%S"),
            count,
            #sendQueue
        ))
    end
end

-- Main
parallel.waitForAll(handleRednet, handlePings, processQueue, displayStatus)
