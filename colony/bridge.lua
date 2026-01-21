-- ============================================
-- BRIDGE - Send turtle data to web dashboard
-- ============================================
-- Run on a CC COMPUTER (not turtle) with wireless modem

-- CHANGE THIS to your PC's IP address
local SERVER_URL = "https://738e20244ec5.ngrok-free.app"

print("========================================")
print("  COLONY WEB BRIDGE")
print("========================================")
print("")

-- Find modem
local modemSide = nil
for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
    if peripheral.getType(side) == "modem" then
        modemSide = side
        break
    end
end

if not modemSide then
    print("[ERROR] No modem found!")
    print("Attach a wireless modem and try again.")
    return
end

print("[OK] Modem on: " .. modemSide)
rednet.open(modemSide)

-- Check HTTP
if not http then
    print("[ERROR] HTTP not enabled on server!")
    print("")
    print("Ask admin to edit config/computercraft-server.toml:")
    print('  [[http.rules]]')
    print('  host = "*"')
    print('  action = "allow"')
    print("")
    print("Will still show local Rednet messages...")
end

print("[INFO] Server URL: " .. SERVER_URL)
print("")
print("Listening for turtle broadcasts...")
print("Polling for commands...")
print("(Ctrl+T to stop)")
print("========================================")
print("")

-- Track known turtles for command routing
local knownTurtles = {}

-- Poll for commands from web dashboard
local function pollCommands()
    if not http then return end
    
    local ok, err = pcall(function()
        local resp = http.get(SERVER_URL .. "/api/commands", {
            ["Content-Type"] = "application/json"
        })
        
        if resp then
            local body = resp.readAll()
            resp.close()
            
            local data = textutils.unserializeJSON(body)
            if data and data.commands then
                for _, cmd in ipairs(data.commands) do
                    print(string.format("[CMD] %s -> #%s", 
                        cmd.command, 
                        tostring(cmd.targetId)
                    ))
                    
                    -- Send command to turtle via Rednet
                    local targetId = tonumber(cmd.targetId)
                    if targetId then
                        rednet.send(targetId, {
                            type = "command",
                            command = cmd.command,
                            args = cmd.args or {},
                            commandId = cmd.id,
                        }, "COLONY")
                        print("  -> Sent to turtle #" .. targetId)
                    else
                        -- Broadcast to all
                        rednet.broadcast({
                            type = "command",
                            command = cmd.command,
                            args = cmd.args or {},
                            commandId = cmd.id,
                        }, "COLONY")
                        print("  -> Broadcast to all")
                    end
                end
            end
        end
    end)
    
    if not ok then
        -- Silent fail - server might be down
    end
end

-- Report command result back to server
local function reportCommandResult(commandId, success, message)
    if not http then return end
    
    pcall(function()
        local json = textutils.serializeJSON({
            commandId = commandId,
            success = success,
            message = message,
        })
        
        local resp = http.post(SERVER_URL .. "/api/command-result", json, {
            ["Content-Type"] = "application/json"
        })
        
        if resp then resp.close() end
    end)
end

-- Main loop: handle both incoming turtle messages and command polling
local lastPoll = 0
local POLL_INTERVAL = 1  -- Poll every 1 second

while true do
    -- Check for turtle broadcasts (non-blocking with short timeout)
    local senderId, message = rednet.receive("COLONY", 0.5)
    
    if senderId and type(message) == "table" then
        local msgType = message.type or "unknown"
        local label = "?"
        
        if message.data and message.data.label then
            label = message.data.label
        end
        
        -- Track known turtles
        knownTurtles[senderId] = {
            label = label,
            lastSeen = os.epoch("utc"),
        }
        
        -- Handle command responses from turtles
        if msgType == "command_result" then
            print(string.format("[RESULT] #%d: %s", 
                senderId,
                message.success and "OK" or "FAIL"
            ))
            reportCommandResult(message.commandId, message.success, message.message)
        else
            -- Forward status updates to web
            print(string.format("[%s] #%d %s: %s", 
                os.date("%H:%M:%S"),
                senderId,
                label,
                msgType
            ))
            
            if http then
                local ok = pcall(function()
                    local json = textutils.serializeJSON({
                        type = msgType,
                        turtle = message.data or message,
                    })
                    
                    local resp = http.post(SERVER_URL .. "/api/update", json, {
                        ["Content-Type"] = "application/json"
                    })
                    
                    if resp then
                        resp.close()
                        print("  -> Sent to web")
                    end
                end)
                
                if not ok then
                    print("  -> HTTP failed")
                end
            end
        end
    end
    
    -- Poll for commands periodically
    local now = os.epoch("utc")
    if now - lastPoll >= POLL_INTERVAL * 1000 then
        pollCommands()
        lastPoll = now
    end
end
