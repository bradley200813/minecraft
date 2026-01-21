-- ============================================
-- EVE.LUA - The First Turtle (Bootstrap)
-- ============================================
-- This is the program for the first turtle
-- She will bootstrap the entire colony

print("========================================")
print("  EVE - Genesis Colony Bootstrap")
print("  Generation 0 - The Mother of All")
print("========================================")
print("")

-- Load libraries using dofile (CC:Tweaked compatible)
local State = dofile("/colony/lib/state.lua")
local Inv = dofile("/colony/lib/inv.lua")
local Nav = dofile("/colony/lib/nav.lua")
local Comms = dofile("/colony/lib/comms.lua")
local Miner = dofile("/colony/roles/miner.lua")
local Crafter = dofile("/colony/roles/crafter.lua")
local Brain = dofile("/colony/brain.lua")

-- Initialize Eve's identity
local function initEve()
    print("[EVE] Initializing...")
    
    -- Set up state
    State.load()
    State.set("role", "eve")
    State.set("generation", 0)
    State.set("colony.name", "Genesis")
    State.set("colony.queenId", os.getComputerID())
    
    -- Set label
    os.setComputerLabel("Eve-" .. os.getComputerID())
    
    -- Initialize navigation
    Nav.setHome()
    Nav.locateGPS()
    
    -- Initialize communications
    if Comms.hasModem() then
        Comms.open()
        Comms.setupDefaultHandlers()
        print("[EVE] Communications online")
    else
        print("[EVE] No modem - operating solo")
    end
    
    -- Initialize modules
    Miner.init(Nav, Inv, State, Comms)
    Crafter.init(Nav, Inv, State, Comms)
    Brain.init(Nav, Inv, State, Comms, Miner, Crafter)
    
    print("[EVE] Initialization complete")
    print("")
end

-- Eve's special bootstrap sequence
local function bootstrap()
    print("[EVE] Starting bootstrap sequence...")
    print("")
    
    -- Check current resources
    local summary = Inv.summary()
    print("[EVE] Inventory check:")
    print("  Empty slots: " .. summary.emptySlots)
    print("  Fuel items: " .. summary.categories.fuel)
    print("  Diamonds: " .. summary.categories.gem)
    print("")
    
    -- Check fuel
    local fuel = turtle.getFuelLevel()
    print("[EVE] Fuel level: " .. fuel)
    
    if fuel < 100 then
        print("[EVE] Low fuel! Attempting to refuel...")
        Inv.refuel(1000)
        fuel = turtle.getFuelLevel()
        print("[EVE] New fuel level: " .. fuel)
    end
    
    if fuel < 50 then
        print("[EVE] CRITICAL: Need fuel to continue!")
        print("[EVE] Please add fuel items and restart")
        return false
    end
    
    -- Check if we can already birth a turtle
    local canBirth, missing = Crafter.canBirthTurtle()
    if canBirth then
        print("[EVE] I have enough materials for a child!")
        print("[EVE] Shall I birth now? (y/n)")
        local input = read()
        if input:lower() == "y" then
            Crafter.birthTurtle(1)
            return true
        end
    else
        print("[EVE] Need materials for first child:")
        for mat, count in pairs(missing) do
            print("  - " .. mat .. ": " .. count)
        end
    end
    
    print("")
    return true
end

-- Eve's main menu
local function menu()
    while true do
        print("")
        print("=== EVE CONTROL MENU ===")
        print("1. Start autonomous mode")
        print("2. Mining expedition")
        print("3. Check birth readiness")
        print("4. Birth turtle now")
        print("5. Status report")
        print("6. Inventory management")
        print("7. Manual control")
        print("8. Exit")
        print("")
        print("Choice: ")
        
        local choice = read()
        
        if choice == "1" then
            print("[EVE] Starting autonomous mode...")
            print("[EVE] Press any key to stop")
            Brain.run()
            
        elseif choice == "2" then
            print("[EVE] Select mining pattern:")
            print("  1. Branch mining (best for ores)")
            print("  2. Tunnel mining")
            print("  3. Quarry")
            print("  4. Strip mining")
            local pattern = read()
            
            if pattern == "1" then
                Miner.configure({ pattern = Miner.PATTERNS.BRANCH })
            elseif pattern == "2" then
                Miner.configure({ pattern = Miner.PATTERNS.TUNNEL })
            elseif pattern == "3" then
                Miner.configure({ pattern = Miner.PATTERNS.QUARRY })
            elseif pattern == "4" then
                Miner.configure({ pattern = Miner.PATTERNS.STRIP })
            end
            
            print("[EVE] Starting mining...")
            local stats = Miner.mine()
            print("[EVE] Mining complete!")
            print("  Blocks mined: " .. stats.blocksMined)
            print("  Ores found: " .. stats.oresMined)
            print("  Distance: " .. stats.distanceTraveled)
            
        elseif choice == "3" then
            Crafter.status()
            
        elseif choice == "4" then
            local canBirth, missing = Crafter.canBirthTurtle()
            if canBirth then
                print("[EVE] Initiating birth sequence...")
                Crafter.birthTurtle(1)
            else
                print("[EVE] Cannot birth - missing materials:")
                for mat, count in pairs(missing) do
                    print("  - " .. mat .. ": " .. count)
                end
            end
            
        elseif choice == "5" then
            print("")
            print("=== STATUS REPORT ===")
            print("ID: " .. os.getComputerID())
            print("Label: " .. (os.getComputerLabel() or "none"))
            print("Fuel: " .. turtle.getFuelLevel() .. "/" .. turtle.getFuelLimit())
            print("Position: " .. Nav.posString())
            print("Generation: " .. (State.getValue("generation") or 0))
            print("Children born: " .. (State.getValue("stats.childrenBorn") or 0))
            print("Blocks mined: " .. (State.getValue("stats.blocksMined") or 0))
            print("")
            local summary = Inv.summary()
            print("Inventory: " .. (16 - summary.emptySlots) .. "/16 slots used")
            
        elseif choice == "6" then
            print("")
            print("1. Consolidate inventory")
            print("2. Drop trash")
            print("3. Dump to chest")
            print("4. Organize")
            local subChoice = read()
            
            if subChoice == "1" then
                Inv.consolidate()
                print("Done!")
            elseif subChoice == "2" then
                local dropped = Inv.dropTrash()
                print("Dropped " .. dropped .. " trash items")
            elseif subChoice == "3" then
                local dumped = Inv.dumpToChest()
                print("Dumped " .. dumped .. " items")
            elseif subChoice == "4" then
                Inv.organize()
                print("Organized!")
            end
            
        elseif choice == "7" then
            print("[EVE] Manual control mode")
            print("  w/a/s/d = move")
            print("  q/e = up/down")
            print("  z/c = turn")
            print("  x = exit")
            
            while true do
                local _, key = os.pullEvent("char")
                if key == "w" then Nav.forward(true)
                elseif key == "s" then Nav.back()
                elseif key == "a" then Nav.turnLeft()
                elseif key == "d" then Nav.turnRight()
                elseif key == "q" then Nav.up(true)
                elseif key == "e" then Nav.down(true)
                elseif key == "z" then Nav.turnLeft()
                elseif key == "c" then Nav.turnRight()
                elseif key == "x" then break
                end
                print("Pos: " .. Nav.posString())
            end
            
        elseif choice == "8" then
            print("[EVE] Goodbye!")
            State.save()
            return
        end
    end
end

-- Main program
initEve()

if bootstrap() then
    menu()
else
    print("[EVE] Bootstrap failed. Please check resources.")
end
