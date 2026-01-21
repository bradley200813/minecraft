-- ============================================
-- TEST REPORTER - Debug connectivity
-- ============================================
-- Run this on Eve to test if signals are being sent

print("========================================")
print("  CONNECTIVITY TEST")
print("========================================")
print("")

-- Check modem
local modemSide = nil
for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
    if peripheral.getType(side) == "modem" then
        modemSide = side
        break
    end
end

if modemSide then
    print("[OK] Modem found on: " .. modemSide)
    rednet.open(modemSide)
else
    print("[ERROR] No wireless modem found!")
    print("  -> Attach a wireless modem to the turtle")
    return
end

-- Check fuel
print("[INFO] Fuel: " .. turtle.getFuelLevel())

-- Check label
local label = os.getComputerLabel() or "NOT SET"
print("[INFO] Label: " .. label)
print("[INFO] ID: " .. os.getComputerID())

print("")
print("Sending test broadcasts...")
print("(Look for these on your bridge computer)")
print("")

-- Send test messages
for i = 1, 5 do
    local msg = {
        type = "heartbeat",
        data = {
            id = os.getComputerID(),
            label = os.getComputerLabel() or ("Turtle-" .. os.getComputerID()),
            role = "eve",
            position = {x = 0, y = 64, z = 0},
            fuel = turtle.getFuelLevel(),
            fuelLimit = turtle.getFuelLimit(),
            state = "testing",
            generation = 0,
        }
    }
    
    rednet.broadcast(msg, "COLONY")
    print("[SENT] Heartbeat #" .. i)
    sleep(2)
end

print("")
print("========================================")
print("Done! Check if bridge received messages.")
print("========================================")
