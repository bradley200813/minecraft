-- CC:Tweaked Turtle Mining Script
-- A 3x3 tunnel mining program with automatic fuel management and inventory handling

-- Configuration
local TUNNEL_LENGTH = 50      -- How far to mine (change this!)
local MIN_FUEL = 100          -- Minimum fuel before refueling
local TORCH_SPACING = 8       -- Place torch every X blocks (set to 0 to disable)

-- Track position for returning home
local depth = 0

-- Check if inventory is full
local function isInventoryFull()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            return false
        end
    end
    return true
end

-- Find and select fuel in inventory
local function findFuel()
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then  -- Test if item is fuel without consuming
            return true
        end
    end
    return false
end

-- Refuel the turtle if needed
local function refuel()
    local fuelLevel = turtle.getFuelLevel()
    
    if fuelLevel == "unlimited" then
        return true
    end
    
    if fuelLevel < MIN_FUEL then
        print("Low fuel! Attempting to refuel...")
        if findFuel() then
            turtle.refuel()
            print("Fuel level: " .. turtle.getFuelLevel())
            return true
        else
            print("WARNING: No fuel found in inventory!")
            return false
        end
    end
    return true
end

-- Dig forward with gravel/sand handling
local function digForward()
    while turtle.detect() do
        turtle.dig()
        sleep(0.5)  -- Wait for falling blocks
    end
end

-- Dig up with gravel/sand handling
local function digUp()
    while turtle.detectUp() do
        turtle.digUp()
        sleep(0.5)
    end
end

-- Dig down
local function digDown()
    turtle.digDown()
end

-- Move forward, digging if necessary
local function forward()
    refuel()
    digForward()
    local tries = 0
    while not turtle.forward() do
        turtle.attack()  -- Attack if mob is blocking
        digForward()
        tries = tries + 1
        if tries > 10 then
            print("Cannot move forward!")
            return false
        end
    end
    return true
end

-- Move up, digging if necessary
local function up()
    refuel()
    digUp()
    local tries = 0
    while not turtle.up() do
        turtle.attackUp()
        digUp()
        tries = tries + 1
        if tries > 10 then
            print("Cannot move up!")
            return false
        end
    end
    return true
end

-- Move down, digging if necessary
local function down()
    refuel()
    digDown()
    local tries = 0
    while not turtle.down() do
        turtle.attackDown()
        digDown()
        tries = tries + 1
        if tries > 10 then
            print("Cannot move down!")
            return false
        end
    end
    return true
end

-- Find and place a torch
local function placeTorch()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name:find("torch") then
            turtle.select(slot)
            turtle.placeDown()
            return true
        end
    end
    return false
end

-- Mine a 3x3 section (turtle starts in middle)
local function mine3x3()
    -- Dig the block in front (middle)
    digForward()
    
    -- Dig top and bottom of front column
    digUp()
    digDown()
    
    -- Go up and dig left column
    up()
    turtle.turnLeft()
    digForward()
    if forward() then
        digUp()
        digDown()
        
        -- Go back and dig right column (2 blocks right)
        turtle.turnRight()
        turtle.turnRight()
        if forward() then end  -- back to center
        digForward()
        if forward() then
            digUp()
            digDown()
            
            -- Return to center
            turtle.turnRight()
            turtle.turnRight()
            if forward() then end
        end
    end
    turtle.turnLeft()  -- Face forward again
    
    -- Go back down to middle level
    down()
end

-- Simple 1x2 tunnel (more efficient for basic mining)
local function mine1x2()
    digForward()
    digUp()
end

-- Main 3x3 tunnel mining function
local function mineTunnel3x3()
    print("Starting 3x3 tunnel mining...")
    print("Length: " .. TUNNEL_LENGTH .. " blocks")
    print("Fuel: " .. turtle.getFuelLevel())
    print("")
    
    for i = 1, TUNNEL_LENGTH do
        -- Check fuel
        if not refuel() then
            print("Out of fuel at depth " .. depth)
            break
        end
        
        -- Check inventory
        if isInventoryFull() then
            print("Inventory full at depth " .. depth)
            print("Returning home to drop items...")
            break
        end
        
        -- Mine the 3x3 section
        mine3x3()
        
        -- Move forward into the mined area
        if not forward() then
            print("Cannot proceed at depth " .. depth)
            break
        end
        
        depth = depth + 1
        
        -- Place torch if needed
        if TORCH_SPACING > 0 and depth % TORCH_SPACING == 0 then
            placeTorch()
        end
        
        -- Progress update
        if depth % 10 == 0 then
            print("Depth: " .. depth .. "/" .. TUNNEL_LENGTH .. " | Fuel: " .. turtle.getFuelLevel())
        end
    end
    
    print("")
    print("Mining complete! Mined " .. depth .. " blocks deep.")
    print("Remaining fuel: " .. turtle.getFuelLevel())
end

-- Simple 1x2 tunnel (height 2, width 1)
local function mineTunnel1x2()
    print("Starting 1x2 tunnel mining...")
    print("Length: " .. TUNNEL_LENGTH .. " blocks")
    print("Fuel: " .. turtle.getFuelLevel())
    print("")
    
    for i = 1, TUNNEL_LENGTH do
        if not refuel() then
            print("Out of fuel at depth " .. depth)
            break
        end
        
        if isInventoryFull() then
            print("Inventory full at depth " .. depth)
            break
        end
        
        mine1x2()
        
        if not forward() then
            print("Cannot proceed at depth " .. depth)
            break
        end
        
        depth = depth + 1
        
        if TORCH_SPACING > 0 and depth % TORCH_SPACING == 0 then
            placeTorch()
        end
        
        if depth % 10 == 0 then
            print("Depth: " .. depth .. "/" .. TUNNEL_LENGTH .. " | Fuel: " .. turtle.getFuelLevel())
        end
    end
    
    print("")
    print("Mining complete! Mined " .. depth .. " blocks deep.")
end

-- Branch mining pattern (efficient for finding ores)
local function branchMine()
    local BRANCH_LENGTH = 20
    local BRANCH_SPACING = 3
    local NUM_BRANCHES = 5
    
    print("Starting branch mining...")
    print("Main tunnel: " .. (NUM_BRANCHES * BRANCH_SPACING) .. " blocks")
    print("Branch length: " .. BRANCH_LENGTH .. " blocks each side")
    print("")
    
    for branch = 1, NUM_BRANCHES do
        -- Mine main tunnel section
        for i = 1, BRANCH_SPACING do
            if not refuel() or isInventoryFull() then
                print("Stopping - fuel or inventory issue")
                return
            end
            mine1x2()
            forward()
            depth = depth + 1
        end
        
        -- Mine right branch
        print("Mining branch " .. branch .. " right...")
        turtle.turnRight()
        for i = 1, BRANCH_LENGTH do
            if not refuel() or isInventoryFull() then break end
            mine1x2()
            forward()
        end
        -- Return
        turtle.turnRight()
        turtle.turnRight()
        for i = 1, BRANCH_LENGTH do
            if not refuel() then break end
            forward()
        end
        turtle.turnRight()
        
        -- Mine left branch
        print("Mining branch " .. branch .. " left...")
        turtle.turnLeft()
        for i = 1, BRANCH_LENGTH do
            if not refuel() or isInventoryFull() then break end
            mine1x2()
            forward()
        end
        -- Return
        turtle.turnRight()
        turtle.turnRight()
        for i = 1, BRANCH_LENGTH do
            if not refuel() then break end
            forward()
        end
        turtle.turnLeft()
    end
    
    print("Branch mining complete!")
end

-- Quarry mining (dig down in a square pattern)
local function quarry()
    local SIZE = 8  -- 8x8 quarry
    local MAX_DEPTH = 50
    
    print("Starting " .. SIZE .. "x" .. SIZE .. " quarry...")
    print("Max depth: " .. MAX_DEPTH)
    print("")
    
    local currentDepth = 0
    
    while currentDepth < MAX_DEPTH do
        if not refuel() or isInventoryFull() then
            print("Stopping quarry")
            break
        end
        
        -- Mine current layer
        for row = 1, SIZE do
            for col = 1, SIZE - 1 do
                digDown()
                if not forward() then break end
            end
            
            -- Turn for next row
            if row < SIZE then
                if row % 2 == 1 then
                    turtle.turnRight()
                    digDown()
                    forward()
                    turtle.turnRight()
                else
                    turtle.turnLeft()
                    digDown()
                    forward()
                    turtle.turnLeft()
                end
            end
        end
        
        -- Go down one level
        if not down() then
            print("Cannot go deeper!")
            break
        end
        currentDepth = currentDepth + 1
        
        -- Turn around for next layer
        turtle.turnRight()
        turtle.turnRight()
        
        print("Layer " .. currentDepth .. " complete")
    end
    
    print("Quarry complete! Depth: " .. currentDepth)
end

-- Menu system
local function showMenu()
    print("=== Turtle Mining Program ===")
    print("")
    print("1. Mine 1x2 tunnel")
    print("2. Mine 3x3 tunnel")
    print("3. Branch mining")
    print("4. Quarry")
    print("5. Check fuel")
    print("6. Refuel")
    print("")
    print("Select option (1-6):")
end

-- Main program
local args = {...}

if #args > 0 then
    -- Command line argument provided
    local choice = tonumber(args[1])
    if choice == 1 then
        mineTunnel1x2()
    elseif choice == 2 then
        mineTunnel3x3()
    elseif choice == 3 then
        branchMine()
    elseif choice == 4 then
        quarry()
    else
        print("Usage: mine <1-4>")
        print("  1 = 1x2 tunnel")
        print("  2 = 3x3 tunnel")
        print("  3 = branch mine")
        print("  4 = quarry")
    end
else
    -- Interactive menu
    showMenu()
    local input = read()
    local choice = tonumber(input)
    
    if choice == 1 then
        mineTunnel1x2()
    elseif choice == 2 then
        mineTunnel3x3()
    elseif choice == 3 then
        branchMine()
    elseif choice == 4 then
        quarry()
    elseif choice == 5 then
        print("Fuel level: " .. turtle.getFuelLevel())
        print("Fuel limit: " .. turtle.getFuelLimit())
    elseif choice == 6 then
        if findFuel() then
            local before = turtle.getFuelLevel()
            turtle.refuel()
            local after = turtle.getFuelLevel()
            print("Refueled! " .. before .. " -> " .. after)
        else
            print("No fuel items in inventory!")
        end
    else
        print("Invalid option!")
    end
end
