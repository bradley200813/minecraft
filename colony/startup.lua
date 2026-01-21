-- ============================================
-- STARTUP.LUA - Colony Turtle Boot Sequence
-- ============================================

print("========================================")
print("  GENESIS COLONY - BOOTING")
print("========================================")

-- Load a module using dofile (works in CC:Tweaked)
local function load(path)
    if fs.exists(path) then
        return dofile(path)
    elseif fs.exists(path .. ".lua") then
        return dofile(path .. ".lua")
    else
        error("File not found: " .. path)
    end
end

-- Load libraries
local State = load("/colony/lib/state")
local Nav = load("/colony/lib/nav")
local Inv = load("/colony/lib/inv")
local Comms = load("/colony/lib/comms")
local Reporter = load("/colony/lib/reporter")
local Commander = load("/colony/lib/commander")
local Miner = load("/colony/roles/miner")
local Crafter = load("/colony/roles/crafter")
local Brain = load("/colony/brain")

-- Determine identity
local function getIdentity()
    local stateFile = "/.colony/state.json"
    if fs.exists(stateFile) then
        local f = fs.open(stateFile, "r")
        if f then
            local data = textutils.unserializeJSON(f.readAll())
            f.close()
            if data then 
                return data.role or "worker", data.generation or 0 
            end
        end
    end
    local label = os.getComputerLabel() or ""
    if label:find("Eve") then return "eve", 0 end
    return "newborn", -1
end

local role, gen = getIdentity()
print("Role: " .. role .. " | Gen: " .. gen)

-- Initialize
State.load()
Nav.init()

if Comms.hasModem() then
    Comms.open()
    Comms.setupDefaultHandlers()
    print("[OK] Modem opened")
else
    print("[WARN] No modem found")
end

Reporter.init(Nav, Inv, State, Comms)
Miner.init(Nav, Inv, State, Comms)
Crafter.init(Nav, Inv, State, Comms)
Commander.init(Nav, Inv, State, Comms, Miner, Crafter, Brain)
Brain.init(Nav, Inv, State, Comms, Miner, Crafter)

if role == "eve" then
    dofile("/colony/eve.lua")
else
    if role == "newborn" then
        State.set("role", "worker")
        State.set("generation", 1)
        os.setComputerLabel("Worker-" .. os.getComputerID())
        Nav.setHome()
    end
    
    print("[WORKER] Starting autonomous mode with command listener...")
    
    -- Run brain with command listener in parallel
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
end
