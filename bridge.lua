-- ============================================
-- BRIDGE - Send turtle data to web dashboard
-- ============================================
-- Run on a CC COMPUTER (not turtle) with wireless modem

-- CHANGE THIS to your PC's IP address
local SERVER_URL = "http://localhost:3000/api/update"

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
print("(Ctrl+T to stop)")
print("========================================")
print("")

while true do
    local senderId, message = rednet.receive("COLONY", 1)
    
    if senderId and type(message) == "table" then
        local msgType = message.type or "unknown"
        local label = "?"
        
        if message.data and message.data.label then
            label = message.data.label
        end
        
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
                
                local resp = http.post(SERVER_URL, json, {
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
