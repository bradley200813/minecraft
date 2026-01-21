-- ============================================
-- EVE - The First Turtle
-- ============================================

print("========================================")
print("  EVE - THE FIRST")
print("========================================")
print("")

-- Load modules
local function load(path)
    if fs.exists(path) then
        return dofile(path)
    elseif fs.exists(path .. ".lua") then
        return dofile(path .. ".lua")
    else
        error("File not found: " .. path)
    end
end

local State = load("/colony/lib/state")
local Nav = load("/colony/lib/nav")
local Inv = load("/colony/lib/inv")
local Comms = load("/colony/lib/comms")
local Reporter = load("/colony/lib/reporter")
local Commander = load("/colony/lib/commander")
local Miner = load("/colony/roles/miner")
local Crafter = load("/colony/roles/crafter")
local Brain = load("/colony/brain")

-- Initialize
State.load()
State.set("role", "eve")
State.set("generation", 0)

Nav.init()
Nav.setHome()

if Comms.hasModem() then
    Comms.open()
    Comms.announce("eve_online")
    print("[OK] Modem opened")
else
    print("[WARN] No modem - attach wireless modem!")
end

Reporter.init(Nav, Inv, State, Comms)
Miner.init(Nav, Inv, State, Comms)
Crafter.init(Nav, Inv, State, Comms)
Commander.init(Nav, Inv, State, Comms, Miner, Crafter, Brain)
Brain.init(Nav, Inv, State, Comms, Miner, Crafter)

-- Menu
local function menu()
    while true do
        print("")
        print("=== EVE MENU ===")
        print("1. Autonomous Mode (Brain)")
        print("2. Mine (Branch Pattern)")
        print("3. Go Home")
        print("4. Refuel")
        print("5. Drop Trash")
        print("6. Status")
        print("7. Test Broadcast")
        print("8. Remote Control Mode")
        print("0. Exit")
        print("")
        write("Choice: ")
        
        local choice = read()
        
        if choice == "1" then
            print("Starting Brain (Ctrl+T to stop)...")
            parallel.waitForAny(
                function()
                    Reporter.runParallel(function() 
                        Brain.run() 
                    end)
                end,
                function()
                    Commander.listen()
                end
            )
            
        elseif choice == "2" then
            print("Mining...")
            local mined = Miner.run(Miner.PATTERNS.BRANCH)
            print("Mined " .. mined .. " blocks")
            
        elseif choice == "3" then
            print("Going home...")
            Nav.goHome()
            print("Arrived!")
            
        elseif choice == "4" then
            print("Refueling...")
            local fuel = Inv.refuel(1000)
            print("Fuel: " .. fuel)
            
        elseif choice == "5" then
            print("Dropping trash...")
            Inv.dropTrash()
            print("Done!")
            
        elseif choice == "6" then
            print("")
            print("--- STATUS ---")
            print("Label: " .. (os.getComputerLabel() or "NOT SET"))
            print("ID: " .. os.getComputerID())
            print("Fuel: " .. turtle.getFuelLevel() .. "/" .. turtle.getFuelLimit())
            print("Position: " .. textutils.serialize(Nav.getPosition()))
            print("Free slots: " .. Inv.freeSlots())
            print("Modem: " .. (Comms.hasModem() and "Yes" or "No"))
            
        elseif choice == "7" then
            print("Sending 3 test broadcasts...")
            for i = 1, 3 do
                Reporter.heartbeat()
                print("  Sent #" .. i)
                sleep(1)
            end
            print("Done! Check bridge computer.")
            
        elseif choice == "8" then
            print("Remote Control Mode - Listening for commands...")
            print("(Ctrl+T to stop)")
            print("")
            print("Open the web dashboard and control this turtle!")
            print("")
            
            -- Send heartbeats while listening for commands
            parallel.waitForAny(
                function()
                    while true do
                        Reporter.heartbeat()
                        sleep(5)
                    end
                end,
                function()
                    Commander.listen()
                end
            )
            
        elseif choice == "0" then
            print("Goodbye!")
            return
        end
    end
end

menu()
