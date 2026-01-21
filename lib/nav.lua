-- ============================================
-- NAV.LUA - Navigation & Positioning
-- ============================================
-- GPS integration, dead reckoning, pathfinding

local Nav = {}

-- Direction constants
Nav.NORTH = 0
Nav.EAST = 1
Nav.SOUTH = 2
Nav.WEST = 3

-- Direction names
Nav.DIR_NAMES = { [0] = "north", [1] = "east", [2] = "south", [3] = "west" }

-- Direction vectors (x, z changes when moving in that direction)
Nav.DIR_VECTORS = {
    [0] = { x = 0, z = -1 },  -- North
    [1] = { x = 1, z = 0 },   -- East
    [2] = { x = 0, z = 1 },   -- South
    [3] = { x = -1, z = 0 },  -- West
}

-- Current position and facing (relative if no GPS)
local position = { x = 0, y = 0, z = 0 }
local facing = Nav.NORTH
local hasGPS = false
local home = { x = 0, y = 0, z = 0 }

-- Movement history for backtracking
local moveHistory = {}
local MAX_HISTORY = 1000

-- Initialize navigation (tries GPS, falls back to relative)
function Nav.init()
    Nav.locateGPS(2)
    return true
end

-- Try to get GPS coordinates
function Nav.locateGPS(timeout)
    timeout = timeout or 2
    local x, y, z = gps.locate(timeout)
    if x then
        position.x = x
        position.y = y
        position.z = z
        hasGPS = true
        return true
    end
    return false
end

-- Determine facing by moving and checking GPS
function Nav.calibrate()
    if not hasGPS then
        if not Nav.locateGPS() then
            print("[NAV] No GPS available, using relative positioning")
            return false
        end
    end
    
    local startPos = { x = position.x, y = position.y, z = position.z }
    
    -- Try to move forward to determine facing
    if turtle.forward() then
        if Nav.locateGPS() then
            local dx = position.x - startPos.x
            local dz = position.z - startPos.z
            
            if dz == -1 then facing = Nav.NORTH
            elseif dx == 1 then facing = Nav.EAST
            elseif dz == 1 then facing = Nav.SOUTH
            elseif dx == -1 then facing = Nav.WEST
            end
            
            -- Move back
            turtle.back()
            position = startPos
            print("[NAV] Calibrated! Facing " .. Nav.DIR_NAMES[facing])
            return true
        end
        turtle.back()
    end
    
    return false
end

-- Get current position
function Nav.getPosition()
    return { x = position.x, y = position.y, z = position.z }
end

-- Get current facing
function Nav.getFacing()
    return facing
end

-- Get facing name
function Nav.getFacingName()
    return Nav.DIR_NAMES[facing]
end

-- Set position manually
function Nav.setPosition(x, y, z)
    position.x = x
    position.y = y
    position.z = z
end

-- Set facing manually
function Nav.setFacing(dir)
    if type(dir) == "string" then
        for d, name in pairs(Nav.DIR_NAMES) do
            if name == dir:lower() then
                facing = d
                return
            end
        end
    else
        facing = dir % 4
    end
end

-- Set home position
function Nav.setHome(x, y, z)
    if x then
        home.x = x
        home.y = y or position.y
        home.z = z or position.z
    else
        home.x = position.x
        home.y = position.y
        home.z = position.z
    end
    print("[NAV] Home set to " .. home.x .. ", " .. home.y .. ", " .. home.z)
end

-- Get home position
function Nav.getHome()
    return { x = home.x, y = home.y, z = home.z }
end

-- Distance to a point
function Nav.distanceTo(x, y, z)
    return math.abs(x - position.x) + math.abs(y - position.y) + math.abs(z - position.z)
end

-- Distance to home
function Nav.distanceToHome()
    return Nav.distanceTo(home.x, home.y, home.z)
end

-- Record move for backtracking
local function recordMove(moveType)
    table.insert(moveHistory, moveType)
    if #moveHistory > MAX_HISTORY then
        table.remove(moveHistory, 1)
    end
end

-- ==========================================
-- BASIC MOVEMENT (with position tracking)
-- ==========================================

-- Turn left
function Nav.turnLeft()
    turtle.turnLeft()
    facing = (facing - 1) % 4
    return true
end

-- Turn right
function Nav.turnRight()
    turtle.turnRight()
    facing = (facing + 1) % 4
    return true
end

-- Turn to face a specific direction
function Nav.turnTo(targetDir)
    if type(targetDir) == "string" then
        for d, name in pairs(Nav.DIR_NAMES) do
            if name == targetDir:lower() then
                targetDir = d
                break
            end
        end
    end
    
    targetDir = targetDir % 4
    
    while facing ~= targetDir do
        local diff = (targetDir - facing) % 4
        if diff == 1 then
            Nav.turnRight()
        elseif diff == 3 then
            Nav.turnLeft()
        else
            Nav.turnRight()
        end
    end
    return true
end

-- Move forward (with digging if needed)
function Nav.forward(dig)
    if dig and turtle.detect() then
        turtle.dig()
        sleep(0.5)  -- Wait for falling blocks
        while turtle.detect() do
            turtle.dig()
            sleep(0.5)
        end
    end
    
    if turtle.forward() then
        local vec = Nav.DIR_VECTORS[facing]
        position.x = position.x + vec.x
        position.z = position.z + vec.z
        recordMove("forward")
        return true
    end
    
    -- Maybe a mob?
    turtle.attack()
    if turtle.forward() then
        local vec = Nav.DIR_VECTORS[facing]
        position.x = position.x + vec.x
        position.z = position.z + vec.z
        recordMove("forward")
        return true
    end
    
    return false
end

-- Move backward
function Nav.back()
    if turtle.back() then
        local vec = Nav.DIR_VECTORS[facing]
        position.x = position.x - vec.x
        position.z = position.z - vec.z
        recordMove("back")
        return true
    end
    return false
end

-- Move up (with digging if needed)
function Nav.up(dig)
    if dig and turtle.detectUp() then
        turtle.digUp()
        sleep(0.5)
        while turtle.detectUp() do
            turtle.digUp()
            sleep(0.5)
        end
    end
    
    if turtle.up() then
        position.y = position.y + 1
        recordMove("up")
        return true
    end
    
    turtle.attackUp()
    if turtle.up() then
        position.y = position.y + 1
        recordMove("up")
        return true
    end
    
    return false
end

-- Move down (with digging if needed)
function Nav.down(dig)
    if dig then
        turtle.digDown()
    end
    
    if turtle.down() then
        position.y = position.y - 1
        recordMove("down")
        return true
    end
    
    turtle.attackDown()
    if turtle.down() then
        position.y = position.y - 1
        recordMove("down")
        return true
    end
    
    return false
end

-- ==========================================
-- NAVIGATION (go to specific coordinates)
-- ==========================================

-- Go to Y level
function Nav.goToY(targetY, dig)
    while position.y < targetY do
        if not Nav.up(dig) then
            return false
        end
    end
    while position.y > targetY do
        if not Nav.down(dig) then
            return false
        end
    end
    return true
end

-- Go to X coordinate
function Nav.goToX(targetX, dig)
    if position.x < targetX then
        Nav.turnTo(Nav.EAST)
    elseif position.x > targetX then
        Nav.turnTo(Nav.WEST)
    else
        return true
    end
    
    while position.x ~= targetX do
        if not Nav.forward(dig) then
            return false
        end
    end
    return true
end

-- Go to Z coordinate
function Nav.goToZ(targetZ, dig)
    if position.z < targetZ then
        Nav.turnTo(Nav.SOUTH)
    elseif position.z > targetZ then
        Nav.turnTo(Nav.NORTH)
    else
        return true
    end
    
    while position.z ~= targetZ do
        if not Nav.forward(dig) then
            return false
        end
    end
    return true
end

-- Go to coordinates (simple: Y first, then X, then Z)
function Nav.goTo(x, y, z, dig)
    -- Go to Y first (usually safest)
    if not Nav.goToY(y, dig) then
        return false
    end
    
    -- Then X
    if not Nav.goToX(x, dig) then
        return false
    end
    
    -- Then Z
    if not Nav.goToZ(z, dig) then
        return false
    end
    
    return true
end

-- Go home
function Nav.goHome(dig)
    print("[NAV] Going home to " .. home.x .. ", " .. home.y .. ", " .. home.z)
    return Nav.goTo(home.x, home.y, home.z, dig)
end

-- Backtrack (undo last moves)
function Nav.backtrack(steps)
    steps = steps or #moveHistory
    local moved = 0
    
    for i = 1, steps do
        if #moveHistory == 0 then break end
        
        local lastMove = table.remove(moveHistory)
        local success = false
        
        if lastMove == "forward" then
            success = Nav.back()
            if success then table.remove(moveHistory) end  -- Remove the back we just recorded
        elseif lastMove == "back" then
            success = Nav.forward(false)
            if success then table.remove(moveHistory) end
        elseif lastMove == "up" then
            success = Nav.down(false)
            if success then table.remove(moveHistory) end
        elseif lastMove == "down" then
            success = Nav.up(false)
            if success then table.remove(moveHistory) end
        end
        
        if success then
            moved = moved + 1
        else
            break
        end
    end
    
    return moved
end

-- Get position as string
function Nav.posString()
    return string.format("(%d, %d, %d) facing %s", 
        position.x, position.y, position.z, Nav.DIR_NAMES[facing])
end

-- Serialize state for saving
function Nav.serialize()
    return {
        position = { x = position.x, y = position.y, z = position.z },
        facing = facing,
        hasGPS = hasGPS,
        home = { x = home.x, y = home.y, z = home.z },
    }
end

-- Load state
function Nav.deserialize(data)
    if data.position then
        position = data.position
    end
    if data.facing then
        facing = data.facing
    end
    if data.hasGPS ~= nil then
        hasGPS = data.hasGPS
    end
    if data.home then
        home = data.home
    end
end

return Nav
