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
function Crafter.canBirthTurtle()
    local requirements = {
        -- Raw materials needed (considering intermediate crafting)
        iron_ingot = 7,
        stone = 7,
        redstone = 1,
        glass = 6,  -- Makes 16 panes, only need 1
        planks = 10, -- 8 for chest + 2 for sticks
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

-- Craft all prerequisites for a turtle
function Crafter.craftTurtlePrereqs()
    print("[CRAFTER] Crafting turtle prerequisites...")
    
    -- Craft planks if we have logs
    local logs = countMaterial("log")
    if logs > 0 and countMaterial("planks") < 10 then
        local success, result = Crafter.craft("planks", math.ceil((10 - countMaterial("planks")) / 4))
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
    
    -- Craft the turtle itself!
    success, err = Crafter.craft("turtle", 1)
    if not success then
        print("[CRAFTER] Failed to craft turtle: " .. tostring(err))
        return false, err
    end
    
    print("[CRAFTER] Turtle crafted! Preparing to deploy...")
    
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
    
    -- Find the pickaxe
    local pickSlot = nil
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name:find("diamond_pickaxe") then
            pickSlot = slot
            break
        end
    end
    
    -- Place the new turtle
    turtle.select(turtleSlot)
    
    -- Find a spot to place it
    local placed = false
    if not turtle.detect() then
        placed = turtle.place()
    elseif not turtle.detectUp() then
        placed = turtle.placeUp()
    elseif not turtle.detectDown() then
        placed = turtle.placeDown()
    else
        -- Try turning and placing
        turtle.turnRight()
        if not turtle.detect() then
            placed = turtle.place()
        end
        if not placed then
            turtle.turnRight()
            if not turtle.detect() then
                placed = turtle.place()
            end
        end
        if not placed then
            turtle.turnRight()
            if not turtle.detect() then
                placed = turtle.place()
            end
        end
        turtle.turnRight()  -- Face original direction
    end
    
    if not placed then
        return false, "No space to place turtle"
    end
    
    print("[CRAFTER] Turtle placed! Equipping pickaxe...")
    
    -- The new turtle needs to equip the pickaxe
    -- We'll need to give it the pickaxe
    if pickSlot then
        turtle.select(pickSlot)
        turtle.drop()  -- Drop it so new turtle can pick it up
    end
    
    -- Update stats
    if State then
        State.increment("stats.childrenBorn")
    end
    
    -- Announce birth
    if Comms then
        Comms.broadcast(Comms.MSG.HELLO, {
            event = "birth",
            parent = os.getComputerID(),
            generation = generation,
        })
    end
    
    print("[CRAFTER] =============================")
    print("[CRAFTER] NEW TURTLE BORN!")
    print("[CRAFTER] Generation " .. generation)
    print("[CRAFTER] =============================")
    
    return true, generation
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

return Crafter
