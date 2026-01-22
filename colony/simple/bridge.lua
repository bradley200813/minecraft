-- ============================================
-- SIMPLE COLONY BRIDGE
-- ============================================
-- Run on a COMPUTER (not turtle) with wireless modem
-- Relays turtle messages to web dashboard

local PROTOCOL = "COLONY"
local SERVER_URL = "https://738e20244ec5.ngrok.app"  -- Change this!

print("========================================")
print("  SIMPLE COLONY BRIDGE")
print("========================================")

-- Find modem
local modemSide = nil
for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
    if peripheral.getType(side) == "modem" then
        modemSide = side
        break
    end
end

if not modemSide then
    print("[ERROR] No modem!")
    return
end

print("[OK] Modem on: " .. modemSide)
rednet.open(modemSide)

if not http then
    print("[WARN] HTTP disabled - local only")
end

print("[OK] Server: " .. SERVER_URL)
print("")
print("Listening for turtles...")
print("(Ctrl+T to stop)")
print("========================================")
print("")

-- Poll for commands from web
local function pollCommands()
    if not http then return end
    
    pcall(function()
        local resp = http.get(SERVER_URL .. "/api/commands")
        if resp then
            local data = textutils.unserializeJSON(resp.readAll())
            resp.close()
            
            if data and data.commands then
                for _, cmd in ipairs(data.commands) do
                    print("[CMD] " .. cmd.command .. " -> " .. (cmd.targetId or "all"))
                    
                    local msg = {
                        type = "command",
                        command = cmd.command,
                        args = cmd.args or {},
                        commandId = cmd.id,
                    }
                    
                    if cmd.targetId and cmd.targetId ~= "all" then
                        rednet.send(tonumber(cmd.targetId), msg, PROTOCOL)
                    else
                        rednet.broadcast(msg, PROTOCOL)
                    end
                end
            end
        end
    end)
end

-- Send data to web
local function sendToWeb(data)
    if not http then return end
    
    pcall(function()
        local json = textutils.serializeJSON(data)
        local resp = http.post(SERVER_URL .. "/api/update", json, {
            ["Content-Type"] = "application/json"
        })
        if resp then resp.close() end
    end)
end

-- Main loop
local lastPoll = 0

while true do
    -- Listen for turtle messages
    local id, msg = rednet.receive(PROTOCOL, 0.5)
    
    if id and type(msg) == "table" then
        local label = "?"
        if msg.data and msg.data.label then
            label = msg.data.label
        end
        
        print(os.date("%H:%M:%S") .. " [" .. msg.type .. "] " .. label)
        
        -- Forward to web
        sendToWeb({
            type = msg.type,
            turtle = msg.data or msg,
        })
    end
    
    -- Poll for commands every second
    local now = os.epoch("utc")
    if now - lastPoll >= 1000 then
        pollCommands()
        lastPoll = now
    end
end
