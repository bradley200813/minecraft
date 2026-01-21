-- ============================================
-- STARTUP.LUA - Colony Turtle Boot Sequence
-- ============================================
-- Every turtle runs this on startup

print("========================================")
print("  COLONY TURTLE - BOOTING")
print("========================================")

-- Determine if we're Eve or a child
local stateFile = "/.colony/state.json"

local function loadLibraries()
    -- Add colony to path
    package.path = package.path .. ";/colony/?.lua;/colony/lib/?.lua;/colony/roles/?.lua"
    
    local State = require("lib.state")
    local Inv = require("lib.inv")
    local Nav = require("lib.nav")
    local Comms = require("lib.comms")
    local Reporter = require("lib.reporter")
    local Miner = require("roles.miner")
    local Crafter = require("roles.crafter")
    local Brain = require("brain")
    
    return State, Inv, Nav, Comms, Reporter, Miner, Crafter, Brain
end

local function determineIdentity()
    if fs.exists(stateFile) then
        -- We have state - we're not new
        local file = fs.open(stateFile, "r")
        if file then
            local content = file.readAll()
            file.close()
            local data = textutils.unserializeJSON(content)
            if data then
                return data.role or "worker", data.generation or 0
            end
        end
    end
    
    -- No state - check if we're Eve
    if os.getComputerLabel() and os.getComputerLabel():find("Eve") then
        return "eve", 0
    end
    
    -- We're a new turtle!
    return "newborn", -1
end

local function newbornSequence(State, Inv, Nav, Comms, Reporter, Miner, Crafter, Brain)
    print("[NEWBORN] I just woke up!")
    print("[NEWBORN] Initializing...")
    
    -- Initialize reporter
    Reporter.init(Nav, Inv, State, Comms)
    
    -- Pick up diamond pickaxe if available
    turtle.suck()  -- Pick up whatever parent dropped
    
    -- Find and equip pickaxe
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name:find("pickaxe") then
            turtle.select(slot)
            turtle.equipLeft()
            print("[NEWBORN] Equipped pickaxe!")
            break
        end
    end
    
    -- Initialize state
    State.load()
    State.set("role", "worker")
    State.set("generation", 1)  -- Will be corrected by parent
    State.set("birthTime", os.epoch("utc"))
    
    -- Set label
    os.setComputerLabel("Worker-" .. os.getComputerID())
    
    -- Set home as birth location
    Nav.setHome()
    
    -- Try to join colony
    if Comms.hasModem() then
        Comms.open()
        Comms.setupDefaultHandlers()
        
        -- Announce ourselves
        Comms.announce("newborn", Nav.getPosition())
        
        -- Wait for role assignment
        print("[NEWBORN] Waiting for colony instructions...")
        local timeout = 10
        local startTime = os.epoch("utc")
        
        while (os.epoch("utc") - startTime) < (timeout * 1000) do
            local gotMsg, senderId, msg = Comms.process(1)
            if gotMsg and msg.type == Comms.MSG.ASSIGN_ROLE then
                State.set("role", msg.data.role)
                State.set("generation", msg.data.generation or 1)
                print("[NEWBORN] Assigned role: " .. msg.data.role)
                break
            end
        end
    end
    
    print("[NEWBORN] Becoming worker...")
    return "worker"
end

local function workerLoop(State, Inv, Nav, Comms, Reporter, Miner, Crafter, Brain)
    print("[WORKER] Starting worker routine")
    
    -- Initialize
    Reporter.init(Nav, Inv, State, Comms)
    Miner.init(Nav, Inv, State, Comms)
    Crafter.init(Nav, Inv, State, Comms)
    Brain.init(Nav, Inv, State, Comms, Miner, Crafter)
    
    -- Set worker-specific config
    Miner.configure({
        pattern = Miner.PATTERNS.BRANCH,
        branchLength = 15,
        branchSpacing = 3,
        returnOnFull = true,
        returnOnLowFuel = true,
        minFuel = 300,
    })
    
    -- Start brain with reporter
    Reporter.runParallel(function()
        Brain.run()
    end)
end

-- MAIN
local role, generation = determineIdentity()
print("Identity: " .. role .. " (GReporter, Miner, Crafter, Brain = loadLibraries()
    
    if role == "eve" then
        -- Run Eve's special program
        shell.run("/colony/eve.lua")
        
    elseif role == "newborn" then
        role = newbornSequence(State, Inv, Nav, Comms, Reporter, Miner, Crafter, Brain)
        workerLoop(State, Inv, Nav, Comms, Reporter, Miner, Crafter, Brain)
        
    else
        -- Normal worker
        workerLoop(State, Inv, Nav, Comms, Reporter
    else
        -- Normal worker
        workerLoop(State, Inv, Nav, Comms, Miner, Crafter, Brain)
    end
end)

if not ok then
    print("ERROR: " .. tostring(err))
    print("")
    print("Press any key to reboot...")
    os.pullEvent("key")
    os.reboot()
end
