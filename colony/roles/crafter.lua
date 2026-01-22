-- ============================================
-- CRAFTER.LUA - Crafting Role & Turtle Birth
-- ============================================
-- The most important role: creating new turtles

local Crafter = {}

-- Dependencies
local Nav, Inv, State, Comms

-- Recipes (slot layout for crafting grid)
-- Crafting uses slots 1,2,3,5,6,7,9,10,11
local RECIPES = {
    -- Sticks: 2 planks vertically
    stick = {
        result = "minecraft:stick",
        count = 4,
        grid = {
            [1] = "planks",
            [5] = "planks",
        },
        materials = { planks = 2 }
    },
    
    -- Chest: 8 planks in ring
    chest = {
        result = "minecraft:chest",
        count = 1,
        grid = {
            [1] = "planks", [2] = "planks", [3] = "planks",
            [5] = "planks",                 [7] = "planks",
            [9] = "planks", [10] = "planks", [11] = "planks",
        },
        materials = { planks = 8 }
    },
    
    -- Glass pane: 6 glass in 2 rows
    glass_pane = {
        result = "minecraft:glass_pane",
        count = 16,
        grid = {
            [1] = "glass", [2] = "glass", [3] = "glass",
            [5] = "glass", [6] = "glass", [7] = "glass",
        },
        materials = { glass = 6 }
    },
    
    -- Computer: 7 stone + 1 redstone + 1 glass pane
    computer = {
        result = "computercraft:computer_normal",
        count = 1,
        grid = {
            [1] = "stone", [2] = "stone", [3] = "stone",
            [5] = "stone", [6] = "redstone", [7] = "stone",
            [9] = "stone", [10] = "glass_pane", [11] = "stone",
        },
        materials = { stone = 7, redstone = 1, glass_pane = 1 }
    },
    
    -- Turtle: 7 iron + 1 computer + 1 chest
    turtle = {
        result = "computercraft:turtle_normal",
        count = 1,
        grid = {
            [1] = "iron_ingot", [2] = "iron_ingot", [3] = "iron_ingot",
            [5] = "iron_ingot", [6] = "computer",   [7] = "iron_ingot",
            [9] = "iron_ingot", [10] = "chest",     [11] = "iron_ingot",
        },
        materials = { iron_ingot = 7, computer = 1, chest = 1 }
    },
    
    -- Diamond pickaxe: 3 diamonds + 2 sticks
    diamond_pickaxe = {
        result = "minecraft:diamond_pickaxe",
        count = 1,
        grid = {
            [1] = "diamond", [2] = "diamond", [3] = "diamond",
                             [6] = "stick",
                             [10] = "stick",
        },
        materials = { diamond = 3, stick = 2 }
    },
    
    -- Furnace: 8 cobblestone
    furnace = {
        result = "minecraft:furnace",
        count = 1,
        grid = {
            [1] = "cobblestone", [2] = "cobblestone", [3] = "cobblestone",
            [5] = "cobblestone",                      [7] = "cobblestone",
            [9] = "cobblestone", [10] = "cobblestone", [11] = "cobblestone",
        },
        materials = { cobblestone = 8 }
    },
    
    -- Planks from logs
    planks = {
        result = "minecraft:oak_planks",  -- Varies by wood type
        count = 4,
        grid = {
            [1] = "log",
        },
        materials = { log = 1 }
    },
    
    -- Disk drive
    disk_drive = {
        result = "computercraft:disk_drive",
        count = 1,
        grid = {
            [1] = "stone", [2] = "stone", [3] = "stone",
            [5] = "stone", [6] = "redstone", [7] = "stone",
            [9] = "stone", [10] = "redstone", [11] = "stone",
        },
        materials = { stone = 7, redstone = 2 }
    },
    
    -- Mining turtle: turtle + diamond pickaxe (crafty mining turtle needs crafting table too)
    mining_turtle = {
        result = "computercraft:turtle_normal",  -- Becomes mining turtle after equip
        count = 1,
        grid = {
            [1] = "turtle",
            [2] = "diamond_pickaxe",
        },
        materials = { turtle = 1, diamond_pickaxe = 1 }
    },
    
    -- Crafting table
    crafting_table = {
        result = "minecraft:crafting_table",
        count = 1,
        grid = {
            [1] = "planks", [2] = "planks",
            [5] = "planks", [6] = "planks",
        },
        materials = { planks = 4 }
    },
    
    -- Crafty mining turtle: mining turtle + crafting table
    crafty_mining_turtle = {
        result = "computercraft:turtle_normal",  -- Actually becomes crafty mining turtle
        count = 1,
        grid = {
            [1] = "mining_turtle",
            [2] = "crafting_table",
        },
        materials = { mining_turtle = 1, crafting_table = 1 }
    },
}

-- Material aliases (what items can satisfy a material requirement)
local MATERIAL_ALIASES = {
    planks = {"minecraft:oak_planks", "minecraft:spruce_planks", "minecraft:birch_planks", 
              "minecraft:jungle_planks", "minecraft:acacia_planks", "minecraft:dark_oak_planks"},
    log = {"minecraft:oak_log", "minecraft:spruce_log", "minecraft:birch_log",
           "minecraft:jungle_log", "minecraft:acacia_log", "minecraft:dark_oak_log"},
    stone = {"minecraft:stone", "minecraft:cobblestone"},
    cobblestone = {"minecraft:cobblestone"},
    glass = {"minecraft:glass"},
    glass_pane = {"minecraft:glass_pane"},
    iron_ingot = {"minecraft:iron_ingot"},
    redstone = {"minecraft:redstone"},
    diamond = {"minecraft:diamond"},
    stick = {"minecraft:stick"},
    computer = {"computercraft:computer_normal", "computercraft:computer_advanced"},
    chest = {"minecraft:chest"},
    turtle = {"computercraft:turtle_normal", "computercraft:turtle_advanced"},
    diamond_pickaxe = {"minecraft:diamond_pickaxe"},
    mining_turtle = {"computercraft:turtle_normal"},  -- Will have pickaxe attached
    crafting_table = {"minecraft:crafting_table"},
    wireless_modem = {"computercraft:wireless_modem_normal", "computercraft:wireless_modem_advanced"},
}

-- Initialize
function Crafter.init(nav, inv, state, comms)
    Nav = nav
    Inv = inv
    State = state
    Comms = comms
end

-- Find items matching a material type
local function findMaterial(materialType)
    local aliases = MATERIAL_ALIASES[materialType]
    if not aliases then
        -- Try exact match
        return Inv.find(materialType, true)
    end
    
    for _, alias in ipairs(aliases) do
        local found = Inv.find(alias, true)
        if #found > 0 then
            return found
        end
    end
    return {}
end

-- Count available material
local function countMaterial(materialType)
    local total = 0
    local aliases = MATERIAL_ALIASES[materialType]
    if not aliases then
        return Inv.count(materialType, true)
    end
    
    for _, alias in ipairs(aliases) do
        total = total + Inv.count(alias, true)
    end
    return total
end

-- Check if we can craft a recipe
function Crafter.canCraft(recipeName)
    local recipe = RECIPES[recipeName]
    if not recipe then
        return false, "Unknown recipe: " .. recipeName
    end
    
    local missing = {}
    for material, needed in pairs(recipe.materials) do
        local have = countMaterial(material)
        if have < needed then
            missing[material] = needed - have
        end
    end
    
    if next(missing) then
        return false, missing
    end
    return true, nil
end

-- Clear crafting grid (slots 1,2,3,5,6,7,9,10,11)
local function clearCraftingGrid()
    local craftSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}
    local storageSlots = {4, 8, 12, 13, 14, 15, 16}
    
    for _, craftSlot in ipairs(craftSlots) do
        if turtle.getItemCount(craftSlot) > 0 then
            turtle.select(craftSlot)
            -- Find empty storage slot
            for _, storeSlot in ipairs(storageSlots) do
                if turtle.getItemCount(storeSlot) == 0 or 
                   (turtle.getItemDetail(storeSlot) and 
                    turtle.getItemDetail(craftSlot) and
                    turtle.getItemDetail(storeSlot).name == turtle.getItemDetail(craftSlot).name) then
                    turtle.transferTo(storeSlot)
                    break
                end
            end
        end
    end
    turtle.select(1)
end

-- Place item in crafting slot
local function placeInSlot(slot, materialType, count)
    count = count or 1
    local items = findMaterial(materialType)
    
    if #items == 0 then
        return false
    end
    
    local placed = 0
    for _, item in ipairs(items) do
        if placed >= count then break end
        
        turtle.select(item.slot)
        local toPlace = math.min(item.count, count - placed)
        turtle.transferTo(slot, toPlace)
        placed = placed + toPlace
    end
    
    return placed >= count
end

-- Craft a recipe
function Crafter.craft(recipeName, count)
    count = count or 1
    
    local recipe = RECIPES[recipeName]
    if not recipe then
        return false, "Unknown recipe: " .. recipeName
    end
    
    local canDo, missing = Crafter.canCraft(recipeName)
    if not canDo then
        return false, missing
    end
    
    local crafted = 0
    
    for i = 1, count do
        -- Clear grid
        clearCraftingGrid()
        
        -- Place materials
        for slot, material in pairs(recipe.grid) do
            if not placeInSlot(slot, material, 1) then
                return false, "Failed to place " .. material .. " in slot " .. slot
            end
        end
        
        -- Craft!
        turtle.select(4)  -- Output slot
        if turtle.craft(1) then
            crafted = crafted + 1
            if State then
                State.increment("stats.itemsCrafted")
            end
        else
            return false, "Crafting failed at item " .. i
        end
    end
    
    turtle.select(1)
    return true, crafted
end

-- ==========================================
-- TURTLE BIRTH PROCESS
-- ==========================================

-- Full requirements check for making a new turtle
-- This calculates the RAW materials needed to craft a Crafty Mining Turtle
function Crafter.canBirthTurtle()
    -- Raw materials needed for a Crafty Mining Turtle:
    -- Turtle = 7 iron + computer + chest
    -- Computer = 7 stone + 1 redstone + 1 glass pane (from 6 glass)
    -- Chest = 8 planks
    -- Diamond Pickaxe = 3 diamonds + 2 sticks (from 1 plank)
    -- Crafting Table = 4 planks
    -- Total planks needed: 8 (chest) + 4 (crafting table) + 2 (sticks for pick) = 14, but sticks give 4, so 8+4+1=13
    local requirements = {
        iron_ingot = 7,
        stone = 7,
        redstone = 1,
        glass = 6,  -- Makes 16 panes, only need 1
        planks = 13, -- 8 for chest + 4 for crafting table + 1 for sticks
        diamond = 3,
    }
    
    local missing = {}
    for material, needed in pairs(requirements) do
        local have = countMaterial(material)
        if have < needed then
            missing[material] = needed - have
        end
    end
    
    if next(missing) then
        return false, missing
    end
    return true, nil
end

-- Check if we have a wireless modem to give to child
function Crafter.hasModemForChild()
    local modems = findMaterial("wireless_modem")
    return #modems > 0
end

-- Craft all prerequisites for a crafty mining turtle
function Crafter.craftTurtlePrereqs()
    print("[CRAFTER] Crafting turtle prerequisites...")
    
    -- Craft planks if we have logs
    local logs = countMaterial("log")
    if logs > 0 and countMaterial("planks") < 13 then
        local needed = math.ceil((13 - countMaterial("planks")) / 4)
        local success, result = Crafter.craft("planks", needed)
        if success then
            print("[CRAFTER] Crafted planks: " .. result)
        end
    end
    
    -- Craft sticks
    if countMaterial("stick") < 2 then
        local success, result = Crafter.craft("stick", 1)
        if success then
            print("[CRAFTER] Crafted sticks: " .. result)
        else
            return false, "Failed to craft sticks"
        end
    end
    
    -- Craft glass panes
    if countMaterial("glass_pane") < 1 then
        local success, result = Crafter.craft("glass_pane", 1)
        if success then
            print("[CRAFTER] Crafted glass panes: " .. result)
        else
            return false, "Failed to craft glass panes"
        end
    end
    
    -- Craft chest
    if countMaterial("chest") < 1 then
        local success, result = Crafter.craft("chest", 1)
        if success then
            print("[CRAFTER] Crafted chest")
        else
            return false, "Failed to craft chest"
        end
    end
    
    -- Craft computer
    if countMaterial("computer") < 1 then
        local success, result = Crafter.craft("computer", 1)
        if success then
            print("[CRAFTER] Crafted computer")
        else
            return false, "Failed to craft computer"
        end
    end
    
    -- Craft diamond pickaxe
    local pickCount = Inv.count("diamond_pickaxe", false)
    if pickCount < 1 then
        local success, result = Crafter.craft("diamond_pickaxe", 1)
        if success then
            print("[CRAFTER] Crafted diamond pickaxe")
        else
            return false, "Failed to craft diamond pickaxe"
        end
    end
    
    -- Craft crafting table
    if countMaterial("crafting_table") < 1 then
        local success, result = Crafter.craft("crafting_table", 1)
        if success then
            print("[CRAFTER] Crafted crafting table")
        else
            return false, "Failed to craft crafting table"
        end
    end
    
    return true
end

-- The main event: birth a new turtle!
function Crafter.birthTurtle(generation)
    generation = generation or 1
    
    print("[CRAFTER] =============================")
    print("[CRAFTER] INITIATING TURTLE BIRTH")
    print("[CRAFTER] Generation: " .. generation)
    print("[CRAFTER] =============================")
    
    -- Check if we can do this
    local canBirth, missing = Crafter.canBirthTurtle()
    if not canBirth then
        print("[CRAFTER] Missing materials:")
        for mat, count in pairs(missing) do
            print("  - " .. mat .. ": " .. count)
        end
        return false, missing
    end
    
    -- Craft prerequisites
    local success, err = Crafter.craftTurtlePrereqs()
    if not success then
        print("[CRAFTER] Failed to craft prereqs: " .. tostring(err))
        return false, err
    end
    
    -- First craft the basic turtle
    success, err = Crafter.craft("turtle", 1)
    if not success then
        print("[CRAFTER] Failed to craft turtle: " .. tostring(err))
        return false, err
    end
    
    -- Now craft the mining turtle (turtle + pickaxe)
    success, err = Crafter.craft("mining_turtle", 1)
    if not success then
        print("[CRAFTER] Failed to craft mining turtle: " .. tostring(err))
        return false, err
    end
    
    -- Finally craft the crafty mining turtle (mining turtle + crafting table)
    success, err = Crafter.craft("crafty_mining_turtle", 1)
    if not success then
        print("[CRAFTER] Failed to craft crafty mining turtle: " .. tostring(err))
        return false, err
    end
    
    print("[CRAFTER] Crafty Mining Turtle crafted! Preparing to deploy...")
    
    -- Find the turtle in inventory
    local turtleSlot = nil
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name:find("turtle") then
            turtleSlot = slot
            break
        end
    end
    
    if not turtleSlot then
        return false, "Lost the turtle somehow!"
    end
    
    -- Place the new turtle
    turtle.select(turtleSlot)
    
    -- Find a spot to place it and track where we placed it
    local placed = false
    local placeDirection = nil  -- "front", "up", or "down"
    
    if not turtle.detect() then
        placed = turtle.place()
        if placed then placeDirection = "front" end
    end
    
    if not placed and not turtle.detectUp() then
        placed = turtle.placeUp()
        if placed then placeDirection = "up" end
    end
    
    if not placed and not turtle.detectDown() then
        placed = turtle.placeDown()
        if placed then placeDirection = "down" end
    end
    
    if not placed then
        -- Try turning and placing
        for i = 1, 3 do
            turtle.turnRight()
            if not turtle.detect() then
                placed = turtle.place()
                if placed then
                    placeDirection = "front"
                    break
                end
            end
        end
        turtle.turnRight()  -- Face original direction
    end
    
    if not placed then
        return false, "No space to place turtle"
    end
    
    print("[CRAFTER] Turtle placed (" .. placeDirection .. ")! Programming child...")
    
    -- Get the peripheral for the new turtle
    local childTurtle = nil
    if placeDirection == "front" then
        childTurtle = peripheral.wrap("front")
    elseif placeDirection == "up" then
        childTurtle = peripheral.wrap("top")
    elseif placeDirection == "down" then
        childTurtle = peripheral.wrap("bottom")
    end
    
    if not childTurtle then
        print("[CRAFTER] Warning: Could not wrap child peripheral")
    end
    
    -- Transfer fuel to the child
    print("[CRAFTER] Transferring fuel to child...")
    local fuelSlots = Inv.findByCategory("fuel")
    if #fuelSlots > 0 then
        turtle.select(fuelSlots[1].slot)
        local fuelToGive = math.min(fuelSlots[1].count, 32)  -- Give up to 32 fuel items
        if placeDirection == "front" then
            turtle.drop(fuelToGive)
        elseif placeDirection == "up" then
            turtle.dropUp(fuelToGive)
        elseif placeDirection == "down" then
            turtle.dropDown(fuelToGive)
        end
        print("[CRAFTER] Gave " .. fuelToGive .. " fuel items")
    end
    
    -- Transfer a wireless modem if we have one
    local modemSlot = nil
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name:find("modem") then
            modemSlot = slot
            break
        end
    end
    
    if modemSlot then
        print("[CRAFTER] Transferring wireless modem to child...")
        turtle.select(modemSlot)
        if placeDirection == "front" then
            turtle.drop(1)
        elseif placeDirection == "up" then
            turtle.dropUp(1)
        elseif placeDirection == "down" then
            turtle.dropDown(1)
        end
    end
    
    -- Program the child turtle with bootstrap code
    -- The child will need to: 1) refuel, 2) equip modem, 3) download colony software, 4) start
    local childId = nil
    if childTurtle and childTurtle.getID then
        childId = childTurtle.getID()
        print("[CRAFTER] Child turtle ID: " .. childId)
    end
    
    -- Turn on the child turtle
    if childTurtle and childTurtle.turnOn then
        childTurtle.turnOn()
        print("[CRAFTER] Turned on child turtle")
    end
    
    -- We need to write a startup file to the child
    -- This requires using the peripheral to write files
    local childBootstrap = [[
-- Genesis Colony Child Bootstrap
print("========================================")
print("  GENESIS COLONY - CHILD BOOT")
print("========================================")

-- Step 1: Refuel
print("[BOOT] Refueling...")
for slot = 1, 16 do
    turtle.select(slot)
    if turtle.refuel(0) then
        turtle.refuel()
    end
end
print("[BOOT] Fuel level: " .. turtle.getFuelLevel())

-- Step 2: Equip modem (on right side)
print("[BOOT] Looking for modem to equip...")
for slot = 1, 16 do
    local item = turtle.getItemDetail(slot)
    if item and item.name:find("modem") then
        turtle.select(slot)
        turtle.equipRight()
        print("[BOOT] Equipped modem!")
        break
    end
end

-- Step 3: Set label
os.setComputerLabel("Worker-" .. os.getComputerID())
print("[BOOT] Label: " .. os.getComputerLabel())

-- Step 4: Try to download colony software
print("[BOOT] Downloading colony software...")

-- Create directories
fs.makeDir("/colony")
fs.makeDir("/colony/lib")
fs.makeDir("/colony/roles")

-- Try HTTP download from parent's server
local serverUrl = "]] .. (os.getenv and os.getenv("COLONY_SERVER") or "http://localhost:3000") .. [["

local success = false

-- Try pastebin install first (more reliable)
if not success then
    print("[BOOT] Trying pastebin install...")
    local ok = shell.run("pastebin", "run", "PASTE_ID_HERE")
    if ok then
        success = true
    end
end

-- If no install method worked, create minimal startup
if not success then
    print("[BOOT] Creating minimal startup...")
    -- Create state file
    if not fs.exists("/.colony") then
        fs.makeDir("/.colony")
    end
    local f = fs.open("/.colony/state.json", "w")
    f.write('{"role":"worker","generation":]] .. generation .. [[}')
    f.close()
    
    print("[BOOT] Waiting for parent to provide software...")
    -- Just wait and announce presence
    if peripheral.find("modem") then
        local modem = peripheral.find("modem")
        rednet.open(peripheral.getName(modem))
        while true do
            rednet.broadcast({type="hello", id=os.getComputerID(), status="awaiting_software"}, "COLONY")
            sleep(10)
        end
    end
end

-- Reboot to start colony software
print("[BOOT] Rebooting...")
sleep(2)
os.reboot()
]]

    -- Write the bootstrap to the child via disk or direct file if possible
    -- Since we can't directly write to the child's filesystem in vanilla CC:Tweaked,
    -- we'll use rednet to send the code once the child is running
    
    -- Update stats
    if State then
        State.increment("stats.childrenBorn")
        local children = State.getValue("children") or {}
        table.insert(children, {
            id = childId,
            generation = generation,
            birthTime = os.epoch("utc"),
        })
        State.set("children", children)
    end
    
    -- Announce birth
    if Comms then
        Comms.broadcast(Comms.MSG.HELLO, {
            event = "birth",
            parent = os.getComputerID(),
            childId = childId,
            generation = generation,
        })
    end
    
    print("[CRAFTER] =============================")
    print("[CRAFTER] NEW TURTLE BORN!")
    print("[CRAFTER] Generation " .. generation)
    if childId then
        print("[CRAFTER] Child ID: " .. childId)
    end
    print("[CRAFTER] =============================")
    
    turtle.select(1)
    return true, { generation = generation, childId = childId, direction = placeDirection }
end

-- Get list of craftable items
function Crafter.listRecipes()
    local list = {}
    for name, recipe in pairs(RECIPES) do
        local canDo, missing = Crafter.canCraft(name)
        table.insert(list, {
            name = name,
            result = recipe.result,
            canCraft = canDo,
            missing = missing,
        })
    end
    return list
end

-- Print crafting status
function Crafter.status()
    print("=== Crafter Status ===")
    
    local canBirth, missing = Crafter.canBirthTurtle()
    if canBirth then
        print("Ready to birth new turtle!")
    else
        print("Cannot birth turtle. Missing:")
        for mat, count in pairs(missing) do
            print("  - " .. mat .. ": " .. count)
        end
    end
    
    print("")
    print("Available recipes:")
    for _, recipe in ipairs(Crafter.listRecipes()) do
        local status = recipe.canCraft and "[READY]" or "[MISSING]"
        print("  " .. status .. " " .. recipe.name)
    end
end

-- ==========================================
-- CHILD PROGRAMMING VIA DISK
-- ==========================================

-- Generate the bootstrap code that will be written to a floppy disk
-- This is what the child turtle runs when it first boots
function Crafter.generateChildBootstrap(generation, parentId, serverUrl)
    serverUrl = serverUrl or "http://localhost:3000"
    
    local bootstrap = [[
-- ============================================
-- GENESIS COLONY - CHILD BOOTSTRAP
-- ============================================
-- This file was placed by the parent turtle
-- Generation: ]] .. generation .. [[

-- Parent info
local PARENT_ID = ]] .. parentId .. [[

local GENERATION = ]] .. generation .. [[

local SERVER_URL = "]] .. serverUrl .. [["

print("========================================")
print("  GENESIS COLONY - NEWBORN")
print("  Generation: " .. GENERATION)
print("========================================")
print("")

-- Step 1: Refuel from inventory
print("[BOOT] Step 1: Refueling...")
for slot = 1, 16 do
    turtle.select(slot)
    if turtle.refuel(0) then
        turtle.refuel()
    end
end
print("[BOOT] Fuel level: " .. turtle.getFuelLevel())

-- Step 2: Equip wireless modem (on right side)
print("[BOOT] Step 2: Equipping modem...")
for slot = 1, 16 do
    local item = turtle.getItemDetail(slot)
    if item and item.name:find("modem") then
        turtle.select(slot)
        turtle.equipRight()
        print("[BOOT] Modem equipped!")
        break
    end
end

-- Step 3: Set computer label
local label = "Worker-" .. os.getComputerID()
os.setComputerLabel(label)
print("[BOOT] Label set: " .. label)

-- Step 4: Initialize state
print("[BOOT] Step 4: Creating state...")
if not fs.exists("/.colony") then
    fs.makeDir("/.colony")
end
local stateData = {
    id = os.getComputerID(),
    label = label,
    role = "worker",
    generation = GENERATION,
    parentId = PARENT_ID,
    birthTime = os.epoch("utc"),
    position = { x = 0, y = 0, z = 0 },
    homePosition = { x = 0, y = 0, z = 0 },
}
local f = fs.open("/.colony/state.json", "w")
f.write(textutils.serializeJSON(stateData))
f.close()
print("[BOOT] State saved")

-- Step 5: Try to download colony software
print("[BOOT] Step 5: Downloading software...")
fs.makeDir("/colony")
fs.makeDir("/colony/lib")
fs.makeDir("/colony/roles")

local FILES = {
    "/colony/startup.lua",
    "/colony/eve.lua",
    "/colony/brain.lua",
    "/colony/config.lua",
    "/colony/lib/state.lua",
    "/colony/lib/inv.lua",
    "/colony/lib/nav.lua",
    "/colony/lib/comms.lua",
    "/colony/lib/reporter.lua",
    "/colony/lib/commander.lua",
    "/colony/roles/miner.lua",
    "/colony/roles/crafter.lua",
}

local downloaded = 0
local failed = 0

for _, filePath in ipairs(FILES) do
    local url = SERVER_URL .. filePath
    write("[GET] " .. filePath .. " ... ")
    
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        
        if fs.exists(filePath) then
            fs.delete(filePath)
        end
        
        local file = fs.open(filePath, "w")
        file.write(content)
        file.close()
        
        print("OK")
        downloaded = downloaded + 1
    else
        print("FAILED")
        failed = failed + 1
    end
end

print("")
print("Downloaded: " .. downloaded .. " files")
print("Failed: " .. failed .. " files")

-- Step 6: Create startup file
print("[BOOT] Step 6: Creating startup...")
local startupCode = 'shell.run("/colony/startup.lua")'
local sf = fs.open("/startup.lua", "w")
sf.write(startupCode)
sf.close()

-- Step 7: Announce to colony
print("[BOOT] Step 7: Announcing to colony...")
local modem = peripheral.find("modem")
if modem then
    rednet.open(peripheral.getName(modem))
    rednet.broadcast({
        type = "hello",
        event = "newborn_ready",
        id = os.getComputerID(),
        generation = GENERATION,
        parentId = PARENT_ID,
    }, "COLONY")
    print("[BOOT] Announced!")
else
    print("[BOOT] No modem - skipping announce")
end

-- Step 8: Reboot to start colony software
print("")
print("========================================")
print("  BOOTSTRAP COMPLETE!")
print("  Rebooting in 3 seconds...")
print("========================================")
sleep(3)
os.reboot()
]]

    return bootstrap
end

-- Program a child turtle using a disk drive
-- This is the most reliable method in CC:Tweaked
function Crafter.programChildViaDisk(direction, generation)
    -- We need a disk drive and a floppy disk
    local hasDiskDrive = false
    local hasDisk = false
    
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            if item.name:find("disk_drive") then
                hasDiskDrive = true
            elseif item.name == "computercraft:disk" then
                hasDisk = true
            end
        end
    end
    
    if not hasDiskDrive or not hasDisk then
        print("[CRAFTER] No disk drive/disk available - using basic method")
        return false
    end
    
    -- Place disk drive next to the child turtle
    -- (This is complex spatial logic - for now, return false and use simpler method)
    print("[CRAFTER] Disk-based programming not yet implemented")
    return false
end

-- Alternative: Send bootstrap code via rednet once child is online
function Crafter.sendBootstrapViaRednet(childId, generation)
    if not Comms then
        return false
    end
    
    local serverUrl = "http://localhost:3000"  -- Default, child should try to discover
    local bootstrap = Crafter.generateChildBootstrap(generation, os.getComputerID(), serverUrl)
    
    -- Send the bootstrap code
    Comms.send(childId, "BOOTSTRAP_CODE", {
        code = bootstrap,
        generation = generation,
    })
    
    print("[CRAFTER] Sent bootstrap code to child " .. childId)
    return true
end

return Crafter
