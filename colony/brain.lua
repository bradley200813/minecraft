-- ============================================
-- BRAIN.LUA - Colony Intelligence & Decisions
-- ============================================
-- The thinking core that decides what to do

local Brain = {}

-- Dependencies
local Nav, Inv, State, Comms
local Miner, Crafter

-- Decision weights
local PRIORITIES = {
    CRITICAL_FUEL = 100,      -- About to run out
    INVENTORY_FULL = 90,      -- Can't pick up more items
    CAN_BIRTH = 80,           -- Have materials for new turtle
    NEED_RESOURCES = 50,      -- Colony needs specific items
    IDLE_MINE = 20,           -- Nothing else to do
    EXPLORE = 10,             -- Look for new areas
}

-- State machine states
Brain.STATE = {
    BOOT = "boot",
    IDLE = "idle",
    MINING = "mining",
    CRAFTING = "crafting",
    RETURNING = "returning",
    DEPOSITING = "depositing",
    REFUELING = "refueling",
    BIRTHING = "birthing",
    HELPING = "helping",
    ERROR = "error",
}

-- Current state
local currentState = Brain.STATE.BOOT
local stateData = {}
local lastDecision = nil
local decisionHistory = {}

-- Colony knowledge
local colonyData = {
    members = {},
    resources = {},
    needsList = {},
    lastUpdate = 0,
}

-- Initialize
function Brain.init(nav, inv, state, comms, miner, crafter)
    Nav = nav
    Inv = inv
    State = state
    Comms = comms
    Miner = miner
    Crafter = crafter
    
    -- Initialize miner and crafter with dependencies
    if Miner then Miner.init(Nav, Inv, State, Comms) end
    if Crafter then Crafter.init(Nav, Inv, State, Comms) end
end

-- Get current state
function Brain.getState()
    return currentState
end

-- Set state
function Brain.setState(newState, data)
    local oldState = currentState
    currentState = newState
    stateData = data or {}
    
    print("[BRAIN] State: " .. oldState .. " -> " .. newState)
    
    if State then
        State.set("currentTask", {
            state = newState,
            data = data,
            startedAt = os.epoch("utc"),
        })
    end
end

-- ==========================================
-- EVALUATION FUNCTIONS
-- ==========================================

-- Check fuel status
local function evaluateFuel()
    local fuel = turtle.getFuelLevel()
    if fuel == "unlimited" then
        return 0
    end
    
    if fuel < 100 then
        return PRIORITIES.CRITICAL_FUEL
    elseif fuel < 500 then
        return 50
    end
    return 0
end

-- Check inventory status
local function evaluateInventory()
    if Inv.isFull() then
        return PRIORITIES.INVENTORY_FULL
    elseif Inv.emptySlots() <= 2 then
        return 70
    end
    return 0
end

-- Check if we can create a new turtle
local function evaluateBirth()
    if Crafter then
        local canBirth = Crafter.canBirthTurtle()
        if canBirth then
            return PRIORITIES.CAN_BIRTH
        end
    end
    return 0
end

-- Check colony needs
local function evaluateColonyNeeds()
    -- Check if colony has requested resources
    if #colonyData.needsList > 0 then
        -- Check if we have any of the needed resources
        for _, need in ipairs(colonyData.needsList) do
            if Inv.count(need.resource) > 0 then
                return PRIORITIES.NEED_RESOURCES
            end
        end
    end
    return 0
end

-- ==========================================
-- DECISION ENGINE
-- ==========================================

function Brain.decide()
    local decisions = {}
    
    -- Evaluate all possible actions
    table.insert(decisions, {
        action = "refuel",
        priority = evaluateFuel(),
        reason = "Low fuel",
    })
    
    table.insert(decisions, {
        action = "deposit",
        priority = evaluateInventory(),
        reason = "Inventory management",
    })
    
    table.insert(decisions, {
        action = "birth",
        priority = evaluateBirth(),
        reason = "Can create new turtle!",
    })
    
    table.insert(decisions, {
        action = "supply",
        priority = evaluateColonyNeeds(),
        reason = "Colony needs resources",
    })
    
    -- Default action
    table.insert(decisions, {
        action = "mine",
        priority = PRIORITIES.IDLE_MINE,
        reason = "Gather resources",
    })
    
    -- Sort by priority
    table.sort(decisions, function(a, b)
        return a.priority > b.priority
    end)
    
    -- Get highest priority action
    local best = decisions[1]
    
    if best.priority > 0 then
        lastDecision = best
        table.insert(decisionHistory, {
            decision = best,
            time = os.epoch("utc"),
        })
        
        -- Keep history limited
        while #decisionHistory > 50 do
            table.remove(decisionHistory, 1)
        end
        
        print("[BRAIN] Decision: " .. best.action .. " (priority: " .. best.priority .. ")")
        print("[BRAIN] Reason: " .. best.reason)
        
        return best.action
    end
    
    return "idle"
end

-- ==========================================
-- ACTION EXECUTORS
-- ==========================================

function Brain.executeAction(action)
    if action == "refuel" then
        return Brain.doRefuel()
    elseif action == "deposit" then
        return Brain.doDeposit()
    elseif action == "birth" then
        return Brain.doBirth()
    elseif action == "mine" then
        return Brain.doMine()
    elseif action == "supply" then
        return Brain.doSupply()
    elseif action == "idle" then
        return Brain.doIdle()
    else
        print("[BRAIN] Unknown action: " .. action)
        return false
    end
end

function Brain.doRefuel()
    Brain.setState(Brain.STATE.REFUELING)
    
    -- First try from inventory
    if Inv.hasFuel() then
        Inv.refuel(1000)
        if turtle.getFuelLevel() >= 500 then
            Brain.setState(Brain.STATE.IDLE)
            return true
        end
    end
    
    -- Need to find fuel
    print("[BRAIN] Need to find fuel source...")
    
    -- If we have coal ore, we need to smelt it
    -- For now, broadcast need
    if Comms then
        Comms.broadcast(Comms.MSG.LOW_FUEL, {
            fuel = turtle.getFuelLevel(),
            position = Nav.getPosition(),
        })
    end
    
    Brain.setState(Brain.STATE.IDLE)
    return false
end

function Brain.doDeposit()
    Brain.setState(Brain.STATE.RETURNING)
    
    -- Go home
    local success = Nav.goHome(true)
    if not success then
        print("[BRAIN] Failed to return home")
        Brain.setState(Brain.STATE.ERROR)
        return false
    end
    
    Brain.setState(Brain.STATE.DEPOSITING)
    
    -- Look for chest
    local foundChest = false
    for i = 1, 4 do
        local hasBlock, data = turtle.inspect()
        if hasBlock and data.name:find("chest") then
            foundChest = true
            break
        end
        turtle.turnRight()
    end
    
    if foundChest then
        Inv.dumpToChest(true, true)  -- Keep fuel and essentials
        print("[BRAIN] Deposited items")
    else
        print("[BRAIN] No chest found, dropping trash")
        Inv.dropTrash()
    end
    
    Brain.setState(Brain.STATE.IDLE)
    return true
end

function Brain.doBirth()
    Brain.setState(Brain.STATE.BIRTHING)
    
    -- Go home for birthing
    Nav.goHome(true)
    
    -- Get current generation
    local myGen = State and State.getValue("generation") or 0
    local childGen = myGen + 1
    
    -- Birth the turtle!
    local success, result = Crafter.birthTurtle(childGen)
    
    if success then
        print("[BRAIN] Successfully birthed generation " .. childGen .. " turtle!")
        
        -- Announce to colony
        if Comms then
            Comms.broadcast(Comms.MSG.HELLO, {
                event = "birth",
                parent = os.getComputerID(),
                childGeneration = childGen,
            })
        end
    else
        print("[BRAIN] Birth failed: " .. tostring(result))
    end
    
    Brain.setState(Brain.STATE.IDLE)
    return success
end

function Brain.doMine()
    Brain.setState(Brain.STATE.MINING)
    
    if Miner then
        local stats = Miner.mine()
        print("[BRAIN] Mining complete. Mined " .. stats.blocksMined .. " blocks")
        print("[BRAIN] Found " .. stats.oresMined .. " ores")
    else
        print("[BRAIN] Miner not available!")
    end
    
    Brain.setState(Brain.STATE.IDLE)
    return true
end

function Brain.doSupply()
    print("[BRAIN] Supply action - delivering resources")
    -- TODO: Implement resource delivery to colony members
    Brain.setState(Brain.STATE.IDLE)
    return true
end

function Brain.doIdle()
    Brain.setState(Brain.STATE.IDLE)
    
    -- Heartbeat to colony
    if Comms then
        Comms.heartbeat({
            role = State and State.getValue("role") or "unknown",
            position = Nav.getPosition(),
            currentTask = nil,
            inventorySummary = Inv.summary(),
        })
    end
    
    sleep(1)
    return true
end

-- ==========================================
-- MAIN LOOP
-- ==========================================

function Brain.run()
    print("[BRAIN] Starting brain...")
    Brain.setState(Brain.STATE.BOOT)
    
    -- Initial setup
    if Nav then
        Nav.setHome()
        Nav.locateGPS()
    end
    
    if Comms then
        Comms.open()
        Comms.setupDefaultHandlers()
        Comms.announce(
            State and State.getValue("role") or "worker",
            Nav and Nav.getPosition() or {x=0, y=0, z=0}
        )
    end
    
    Brain.setState(Brain.STATE.IDLE)
    
    -- Main loop
    while true do
        -- Process any incoming messages
        if Comms then
            Comms.process(0.1)
        end
        
        -- Make decision
        local action = Brain.decide()
        
        -- Execute action
        Brain.executeAction(action)
        
        -- Save state
        if State then
            State.save()
        end
        
        -- Small delay to prevent tight loop
        sleep(0.5)
    end
end

-- Run once (for testing)
function Brain.step()
    local action = Brain.decide()
    return Brain.executeAction(action)
end

-- Get status
function Brain.status()
    return {
        state = currentState,
        stateData = stateData,
        lastDecision = lastDecision,
        fuel = turtle.getFuelLevel(),
        position = Nav and Nav.getPosition() or "unknown",
        inventory = Inv and Inv.summary() or "unknown",
    }
end

-- Print status
function Brain.printStatus()
    local status = Brain.status()
    print("=== Brain Status ===")
    print("State: " .. status.state)
    print("Fuel: " .. tostring(status.fuel))
    if status.position ~= "unknown" then
        print("Position: " .. status.position.x .. ", " .. status.position.y .. ", " .. status.position.z)
    end
    if status.lastDecision then
        print("Last decision: " .. status.lastDecision.action)
    end
    if status.inventory ~= "unknown" then
        print("Empty slots: " .. status.inventory.emptySlots)
    end
end

return Brain
