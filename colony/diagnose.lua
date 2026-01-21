-- ============================================
-- NETWORK DIAGNOSTICS
-- ============================================
-- Run this on your computer to diagnose connection issues

print("========================================")
print("  COLONY NETWORK DIAGNOSTICS")
print("========================================")
print("")

-- Step 1: Check for modem
print("[1] Checking for modem...")
local modemSide = nil
local modemType = nil

for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
    local pType = peripheral.getType(side)
    if pType == "modem" then
        modemSide = side
        local modem = peripheral.wrap(side)
        modemType = modem.isWireless() and "wireless" or "wired"
        break
    end
end

if not modemSide then
    print("   [FAIL] No modem found!")
    print("")
    print("   FIX: Attach a WIRELESS modem to this computer")
    print("        Right-click a wireless modem onto the computer")
    return
else
    print("   [OK] Found " .. modemType .. " modem on " .. modemSide)
    if modemType == "wired" then
        print("")
        print("   [WARN] You have a WIRED modem!")
        print("          Wired modems only work through cables.")
        print("          Use a WIRELESS modem for turtle communication.")
    end
end

-- Step 2: Open modem
print("")
print("[2] Opening modem...")
rednet.open(modemSide)
print("   [OK] Modem opened")

-- Step 3: Check our ID
print("")
print("[3] This computer's ID: " .. os.getComputerID())

-- Step 4: Listen for any rednet traffic
print("")
print("[4] Listening for ANY rednet messages (10 seconds)...")
print("    Waiting...")

local heard = false
local startTime = os.epoch("utc")

while (os.epoch("utc") - startTime) < 10000 do
    local senderId, message, protocol = rednet.receive(nil, 1)
    if senderId then
        heard = true
        print("")
        print("   [RECEIVED] From ID " .. senderId)
        print("   Protocol: " .. tostring(protocol))
        print("   Message type: " .. type(message))
        if type(message) == "table" then
            print("   Message.type: " .. tostring(message.type))
        end
    end
end

if not heard then
    print("   [FAIL] No messages received!")
    print("")
    print("   POSSIBLE CAUSES:")
    print("   - Turtles don't have wireless modems")
    print("   - Turtles aren't running colony scripts")
    print("   - Turtles are too far away (range ~64 blocks)")
    print("   - Turtles haven't sent a heartbeat yet")
end

-- Step 5: Try pinging
print("")
print("[5] Broadcasting PING on COLONY protocol...")
rednet.broadcast({type = "ping", from = os.getComputerID()}, "COLONY")
print("   Waiting for responses (5 seconds)...")

local responses = 0
startTime = os.epoch("utc")

while (os.epoch("utc") - startTime) < 5000 do
    local senderId, message, protocol = rednet.receive("COLONY", 1)
    if senderId then
        responses = responses + 1
        local label = "Unknown"
        if type(message) == "table" and message.data then
            label = message.data.label or message.data.name or senderId
        end
        print("   [PONG] ID " .. senderId .. " - " .. tostring(label))
    end
end

if responses == 0 then
    print("   [FAIL] No responses to ping")
else
    print("   [OK] " .. responses .. " turtle(s) responded!")
end

-- Step 6: Check if turtles are running
print("")
print("[6] Listening specifically for COLONY protocol (10s)...")

local colonyMsgs = 0
startTime = os.epoch("utc")

while (os.epoch("utc") - startTime) < 10000 do
    local senderId, message, protocol = rednet.receive("COLONY", 1)
    if senderId then
        colonyMsgs = colonyMsgs + 1
        local msgType = type(message) == "table" and message.type or "unknown"
        print("   [MSG] ID " .. senderId .. " - " .. msgType)
    end
end

print("   Received " .. colonyMsgs .. " COLONY messages")

-- Summary
print("")
print("========================================")
print("  DIAGNOSIS SUMMARY")
print("========================================")

if not modemSide then
    print("PROBLEM: No modem attached")
    print("FIX: Attach a wireless modem")
elseif modemType == "wired" then
    print("PROBLEM: Using wired modem")
    print("FIX: Use a WIRELESS modem instead")
elseif responses == 0 and colonyMsgs == 0 then
    print("PROBLEM: No turtles responding")
    print("")
    print("CHECK YOUR TURTLES:")
    print("  1. Do they have wireless modems? (right-click to attach)")
    print("  2. Is the modem activated? (right-click modem, should glow)")
    print("  3. Are they running /colony/startup or /colony/eve?")
    print("  4. Are they within range? (~64 blocks)")
    print("")
    print("RUN THIS ON EACH TURTLE to test:")
    print("  lua")
    print("  rednet.open('top')  -- or whatever side")
    print("  rednet.broadcast('test', 'COLONY')")
else
    print("SUCCESS: Communication working!")
    print("Turtles found: " .. math.max(responses, colonyMsgs))
end

print("")
print("========================================")
