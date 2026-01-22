-- ============================================
-- MINER.LUA - Mining Role Behavior
-- ============================================
-- Autonomous resource gathering

local Miner = {}

-- Dependencies (loaded at runtime)
local Nav, Inv, State, Comms

-- Mining patterns
Miner.PATTERNS = {
    BRANCH = "branch",      -- Branch mining (efficient for ores)
    QUARRY = "quarry",      -- Dig down in a square
    TUNNEL = "tunnel",      -- Straight tunnel
    STRIP = "strip",        -- Strip mine at one level
}

-- Ore values (for priority)
local ORE_VALUE = {
    ["minecraft:diamond_ore"] = 100,
    ["minecraft:deepslate_diamond_ore"] = 100,
    ["minecraft:emerald_ore"] = 80,
    ["minecraft:deepslate_emerald_ore"] = 80,
    ["minecraft:gold_ore"] = 40,
    ["minecraft:deepslate_gold_ore"] = 40,
    ["minecraft:iron_ore"] = 30,
    ["minecraft:deepslate_iron_ore"] = 30,
    ["minecraft:redstone_ore"] = 20,
    ["minecraft:deepslate_redstone_ore"] = 20,
    ["minecraft:copper_ore"] = 15,
    ["minecraft:deepslate_copper_ore"] = 15,
    ["minecraft:lapis_ore"] = 25,
    ["minecraft:deepslate_lapis_ore"] = 25,
    ["minecraft:coal_ore"] = 10,
    ["minecraft:deepslate_coal_ore"] = 10,
}

-- Config
local config = {
    pattern = Miner.PATTERNS.BRANCH,
    branchLength = 20,
    branchSpacing = 3,
    tunnelLength = 50,
    quarrySize = 8,
    miningLevel = -59,  -- Diamond level in 1.18+
    returnOnFull = true,
    returnOnLowFuel = true,
    minFuel = 500,
    torchSpacing = 8,
}

-- Stats for this session
local sessionStats = {
    blocksMined = 0,
    oresMined = 0,
    distanceTraveled = 0,
}

-- Initialize with dependencies
function Miner.init(nav, inv, state, comms)
    Nav = nav
    Inv = inv
    State = state
    Comms = comms
end

-- Set config
function Miner.configure(cfg)
    for k, v in pairs(cfg) do
        config[k] = v
    end
end

-- Check if block is valuable ore
local function isOre(blockData)
    if not blockData then return false, 0 end
    return ORE_VALUE[blockData.name] ~= nil, ORE_VALUE[blockData.name] or 0
end

-- Check and mine ore veins around current position
local function checkForOres()
    local found = 0
    
    -- Check all 6 directions
    local function checkAndMine(inspectFn, digFn, moveFn, returnFn)
        local hasBlock, data = inspectFn()
        if hasBlock then
            local isOreBlock, value = isOre(data)
            if isOreBlock then
                digFn()
                found = found + 1
                sessionStats.oresMined = sessionStats.oresMined + 1
                -- Recursively check new position
                if moveFn() then
                    found = found + checkForOres()
                    returnFn()
                end
            end
        end
    end
    
    checkAndMine(turtle.inspect, turtle.dig, 
        function() return Nav.forward(false) end, 
        function() Nav.back() end)
    
    checkAndMine(turtle.inspectUp, turtle.digUp,
        function() return Nav.up(false) end,
        function() Nav.down(false) end)
    
    checkAndMine(turtle.inspectDown, turtle.digDown,
        function() return Nav.down(false) end,
        function() Nav.up(false) end)
    
    -- Check sides
    Nav.turnLeft()
    checkAndMine(turtle.inspect, turtle.dig,
        function() return Nav.forward(false) end,
        function() Nav.back() end)
    
    Nav.turnRight()
    Nav.turnRight()
    checkAndMine(turtle.inspect, turtle.dig,
        function() return Nav.forward(false) end,
        function() Nav.back() end)
    
    Nav.turnLeft()  -- Face original direction
    
    return found
end

-- Should we return to base?
local function shouldReturn()
    if config.returnOnFull and Inv.isFull() then
        print("[MINER] Inventory full, returning")
        if Comms then
            Comms.broadcast(Comms.MSG.INVENTORY_FULL, {
                position = Nav.getPosition()
            })
        end
        return true
    end
    
    if config.returnOnLowFuel then
        local fuel = turtle.getFuelLevel()
        local distHome = Nav.distanceToHome()
        if fuel ~= "unlimited" and fuel < (distHome + config.minFuel) then
            print("[MINER] Low fuel, returning")
            if Comms then
                Comms.broadcast(Comms.MSG.LOW_FUEL, {
                    fuel = fuel,
                    position = Nav.getPosition()
                })
            end
            return true
        end
    end
    
    return false
end

-- Dig forward handling falling blocks
local function digForward()
    while turtle.detect() do
        turtle.dig()
        sessionStats.blocksMined = sessionStats.blocksMined + 1
        sleep(0.5)
    end
end

-- Dig up handling falling blocks
local function digUp()
    while turtle.detectUp() do
        turtle.digUp()
        sessionStats.blocksMined = sessionStats.blocksMined + 1
        sleep(0.5)
    end
end

-- Dig down
local function digDown()
    if turtle.digDown() then
        sessionStats.blocksMined = sessionStats.blocksMined + 1
    end
end

-- Mine a 1x2 tunnel forward one block
local function mine1x2()
    digForward()
    digUp()
    checkForOres()
end

-- Mine a 3x3 section
local function mine3x3()
    digForward()
    digUp()
    digDown()
    
    Nav.up(true)
    Nav.turnLeft()
    
    if Nav.forward(true) then
        digUp()
        digDown()
        Nav.turnRight()
        Nav.turnRight()
        Nav.forward(true)
        
        if Nav.forward(true) then
            digUp()
            digDown()
            Nav.turnRight()
            Nav.turnRight()
            Nav.forward(true)
        end
    end
    
    Nav.turnLeft()
    Nav.down(true)
    
    checkForOres()
end

-- Place a torch if we have one
local function placeTorch()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name:find("torch") then
            turtle.select(slot)
            turtle.placeDown()
            turtle.select(1)
            return true
        end
    end
    return false
end

-- ==========================================
-- MINING PATTERNS
-- ==========================================

-- Branch mining pattern
function Miner.branchMine()
    print("[MINER] Starting branch mining")
    print("[MINER] Branch length: " .. config.branchLength)
    print("[MINER] Branch spacing: " .. config.branchSpacing)
    
    local branches = 0
    
    while not shouldReturn() do
        -- Mine main tunnel section
        for i = 1, config.branchSpacing do
            if shouldReturn() then break end
            mine1x2()
            if Nav.forward(true) then
                sessionStats.distanceTraveled = sessionStats.distanceTraveled + 1
            else
                print("[MINER] Blocked, ending")
                return sessionStats
            end
        end
        
        if shouldReturn() then break end
        
        -- Mine right branch
        Nav.turnRight()
        for i = 1, config.branchLength do
            if shouldReturn() then break end
            mine1x2()
            if not Nav.forward(true) then break end
        end
        
        -- Return to main tunnel
        Nav.turnRight()
        Nav.turnRight()
        for i = 1, config.branchLength do
            if not Nav.forward(false) then break end
        end
        Nav.turnRight()
        
        -- Mine left branch
        Nav.turnLeft()
        for i = 1, config.branchLength do
            if shouldReturn() then break end
            mine1x2()
            if not Nav.forward(true) then break end
        end
        
        -- Return to main tunnel
        Nav.turnRight()
        Nav.turnRight()
        for i = 1, config.branchLength do
            if not Nav.forward(false) then break end
        end
        Nav.turnLeft()
        
        branches = branches + 1
        print("[MINER] Completed branch pair " .. branches)
        
        -- Drop trash periodically
        Inv.dropTrash()
    end
    
    return sessionStats
end

-- Straight tunnel mining
function Miner.tunnelMine()
    print("[MINER] Starting tunnel mining")
    print("[MINER] Length: " .. config.tunnelLength)
    
    local depth = 0
    
    for i = 1, config.tunnelLength do
        if shouldReturn() then break end
        
        mine1x2()
        
        if Nav.forward(true) then
            depth = depth + 1
            sessionStats.distanceTraveled = sessionStats.distanceTraveled + 1
            
            -- Torch placement
            if config.torchSpacing > 0 and depth % config.torchSpacing == 0 then
                placeTorch()
            end
            
            if depth % 10 == 0 then
                print("[MINER] Depth: " .. depth .. "/" .. config.tunnelLength)
            end
        else
            print("[MINER] Blocked at depth " .. depth)
            break
        end
    end
    
    return sessionStats
end

-- Quarry mining - digs a square straight down layer by layer
function Miner.quarryMine()
    print("[MINER] Starting quarry")
    print("[MINER] Size: " .. config.quarrySize .. "x" .. config.quarrySize)
    
    local size = config.quarrySize
    local layers = 0
    local goingRight = true  -- Track serpentine direction
    
    while not shouldReturn() do
        -- Mine current layer (dig down, then move across)
        for row = 1, size do
            for col = 1, size do
                if shouldReturn() then 
                    return sessionStats
                end
                
                -- Dig down at current position
                digDown()
                
                -- Move to next column (unless last column in row)
                if col < size then
                    digForward()
                    if Nav.forward(true) then
                        sessionStats.distanceTraveled = sessionStats.distanceTraveled + 1
                    end
                end
            end
            
            -- Turn for next row (unless last row)
            if row < size then
                if goingRight then
                    Nav.turnRight()
                    digForward()
                    Nav.forward(true)
                    Nav.turnRight()
                else
                    Nav.turnLeft()
                    digForward()
                    Nav.forward(true)
                    Nav.turnLeft()
                end
                goingRight = not goingRight
            end
        end
        
        -- Completed one layer - now go down
        layers = layers + 1
        print("[MINER] Layer " .. layers .. " complete")
        
        -- Drop trash periodically
        Inv.dropTrash()
        
        -- Check fuel before going deeper
        if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < config.minFuel then
            print("[MINER] Low fuel, stopping")
            break
        end
        
        -- Go down to next layer
        if not turtle.detectDown() then
            -- Nothing below, dig and move down
            if not Nav.down(true) then
                print("[MINER] Cannot go deeper (void/bedrock)")
                break
            end
        else
            -- Something below, dig it first
            digDown()
            if not Nav.down(true) then
                print("[MINER] Cannot go deeper (bedrock?)")
                break
            end
        end
        
        -- Turn around for next layer serpentine
        Nav.turnRight()
        Nav.turnRight()
        goingRight = not goingRight
    end
    
    print("[MINER] Quarry complete: " .. layers .. " layers")
    return sessionStats
end

-- Strip mining at current level
function Miner.stripMine()
    print("[MINER] Starting strip mine at Y=" .. Nav.getPosition().y)
    
    local strips = 0
    local stripLength = config.tunnelLength
    
    while not shouldReturn() do
        -- Mine one strip
        for i = 1, stripLength do
            if shouldReturn() then break end
            mine1x2()
            if not Nav.forward(true) then break end
            sessionStats.distanceTraveled = sessionStats.distanceTraveled + 1
        end
        
        -- Move to next strip
        Nav.turnRight()
        for i = 1, 3 do  -- 3 blocks between strips
            mine1x2()
            if not Nav.forward(true) then break end
        end
        Nav.turnRight()
        
        strips = strips + 1
        print("[MINER] Strip " .. strips .. " complete")
        
        -- Return and go to next
        for i = 1, stripLength do
            if shouldReturn() then break end
            mine1x2()
            if not Nav.forward(true) then break end
        end
        
        Nav.turnLeft()
        for i = 1, 3 do
            mine1x2()
            if not Nav.forward(true) then break end
        end
        Nav.turnLeft()
        
        strips = strips + 1
    end
    
    return sessionStats
end

-- Main mining function (uses configured pattern)
function Miner.mine()
    -- Refuel first
    Inv.refuel(config.minFuel * 2)
    
    -- Record home if not set
    if Nav.distanceToHome() == 0 then
        Nav.setHome()
    end
    
    -- Select pattern
    local stats
    if config.pattern == Miner.PATTERNS.BRANCH then
        stats = Miner.branchMine()
    elseif config.pattern == Miner.PATTERNS.QUARRY then
        stats = Miner.quarryMine()
    elseif config.pattern == Miner.PATTERNS.STRIP then
        stats = Miner.stripMine()
    else
        stats = Miner.tunnelMine()
    end
    
    -- Return home
    print("[MINER] Mining complete, returning home")
    Nav.goHome(true)
    
    return stats
end

-- Get session stats
function Miner.getStats()
    return sessionStats
end

-- Reset session stats
function Miner.resetStats()
    sessionStats = {
        blocksMined = 0,
        oresMined = 0,
        distanceTraveled = 0,
    }
end

return Miner
