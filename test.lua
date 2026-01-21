-- ============================================
-- TEST - Connectivity Test
-- ============================================

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
    print("  -> Right-click a wireless modem onto turtle")
    return
end

print("[INFO] Label: " .. (os.getComputerLabel() or "NOT SET"))
print("[INFO] ID: " .. os.getComputerID())
print("[INFO] Fuel: " .. turtle.getFuelLevel())

print("")
print("Sending 5 test broadcasts on COLONY protocol...")
print("")

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
print("Done! Check your bridge computer.")
print("========================================")
