-- ============================================
-- SIMPLE BRIDGE - Minimal HTTP sender
-- ============================================
-- Run this on a CC COMPUTER (not turtle) with:
--   1. Wireless modem attached
--   2. HTTP enabled on server
--
-- This listens for turtle broadcasts and sends to web

-- CHANGE THIS to your PC's IP if not localhost
local SERVER_URL = "http://localhost:3000/api/update"

print("========================================")
print("  COLONY BRIDGE - SIMPLE")
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
    print("[ERROR] No modem found!")
    print("Attach a wireless modem and try again.")
    return
end

print("[OK] Modem on: " .. modemSide)
rednet.open(modemSide)

-- Check HTTP
if not http then
    print("[ERROR] HTTP not enabled!")
    print("")
    print("Ask server admin to edit:")
    print("  config/computercraft-server.toml")
    print("")
    print("Add:")
    print("  [[http.rules]]")
    print("  host = \"*\"")
    print("  action = \"allow\"")
    return
end

print("[OK] HTTP available")

-- Test connection
print("")
print("Testing connection to: " .. SERVER_URL)

local testOk = pcall(function()
    local resp = http.post(SERVER_URL, 
        textutils.serializeJSON({type="ping"}),
        {["Content-Type"] = "application/json"}
    )
    if resp then resp.close() end
end)

if testOk then
    print("[OK] Server reachable!")
else
    print("[WARN] Cannot reach server")
    print("Make sure Node.js server is running:")
    print("  node server.js")
end

print("")
print("Listening for turtle broadcasts...")
print("(Press Ctrl+T to stop)")
print("========================================")

-- Main loop
while true do
    local senderId, message = rednet.receive("COLONY", 1)
    
    if senderId and type(message) == "table" then
        print(string.format("[%s] From #%d: %s", 
            os.date("%H:%M:%S"),
            senderId,
            message.type or "unknown"
        ))
        
        -- Forward to web server
        local ok = pcall(function()
            local json = textutils.serializeJSON({
                type = message.type or "heartbeat",
                turtle = message.data or message,
            })
            
            local resp = http.post(SERVER_URL, json, {
                ["Content-Type"] = "application/json"
            })
            
            if resp then
                resp.close()
                print("  -> Sent to web!")
            end
        end)
        
        if not ok then
            print("  -> Failed to send")
        end
    end
end
