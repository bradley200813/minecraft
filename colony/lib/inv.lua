-- ============================================
-- INV.LUA - Inventory Management
-- ============================================
-- Smart inventory handling for the colony

local Inv = {}

-- Item categories for organization
Inv.CATEGORIES = {
    fuel = {
        "minecraft:coal",
        "minecraft:charcoal",
        "minecraft:coal_block",
        "minecraft:lava_bucket",
        "minecraft:blaze_rod",
    },
    ore = {
        "minecraft:iron_ore",
        "minecraft:deepslate_iron_ore",
        "minecraft:gold_ore",
        "minecraft:deepslate_gold_ore",
        "minecraft:diamond_ore",
        "minecraft:deepslate_diamond_ore",
        "minecraft:redstone_ore",
        "minecraft:deepslate_redstone_ore",
        "minecraft:copper_ore",
        "minecraft:deepslate_copper_ore",
        "minecraft:emerald_ore",
        "minecraft:deepslate_emerald_ore",
        "minecraft:lapis_ore",
        "minecraft:deepslate_lapis_ore",
    },
    ingot = {
        "minecraft:iron_ingot",
        "minecraft:gold_ingot",
        "minecraft:copper_ingot",
    },
    gem = {
        "minecraft:diamond",
        "minecraft:emerald",
        "minecraft:redstone",
        "minecraft:lapis_lazuli",
    },
    wood = {
        "minecraft:oak_log",
        "minecraft:spruce_log",
        "minecraft:birch_log",
        "minecraft:jungle_log",
        "minecraft:acacia_log",
        "minecraft:dark_oak_log",
        "minecraft:mangrove_log",
        "minecraft:cherry_log",
    },
    planks = {
        "minecraft:oak_planks",
        "minecraft:spruce_planks",
        "minecraft:birch_planks",
        "minecraft:jungle_planks",
        "minecraft:acacia_planks",
        "minecraft:dark_oak_planks",
        "minecraft:mangrove_planks",
        "minecraft:cherry_planks",
    },
    stone = {
        "minecraft:cobblestone",
        "minecraft:stone",
        "minecraft:deepslate",
        "minecraft:cobbled_deepslate",
    },
    glass = {
        "minecraft:glass",
        "minecraft:glass_pane",
    },
    turtle_parts = {
        "computercraft:computer_normal",
        "computercraft:computer_advanced",
        "computercraft:turtle_normal",
        "computercraft:turtle_advanced",
        "computercraft:disk_drive",
        "computercraft:wireless_modem_normal",
        "computercraft:wireless_modem_advanced",
    },
    trash = {
        "minecraft:dirt",
        "minecraft:gravel",
        "minecraft:sand",
        "minecraft:netherrack",
        "minecraft:andesite",
        "minecraft:diorite",
        "minecraft:granite",
        "minecraft:tuff",
        "minecraft:calcite",
    },
}

-- Requirements for crafting a turtle
Inv.TURTLE_RECIPE = {
    iron_ingot = 7,
    redstone = 1,
    glass_pane = 1,
    planks = 8,  -- for chest
    diamond = 3,  -- for pickaxe
    stick = 2,   -- for pickaxe
}

-- Get item details in a slot
function Inv.getSlot(slot)
    slot = slot or turtle.getSelectedSlot()
    local count = turtle.getItemCount(slot)
    if count == 0 then
        return nil
    end
    return turtle.getItemDetail(slot)
end

-- Find item by name (partial match supported)
function Inv.find(itemName, exact)
    local results = {}
    for slot = 1, 16 do
        local item = Inv.getSlot(slot)
        if item then
            local match = false
            if exact then
                match = (item.name == itemName)
            else
                match = item.name:find(itemName, 1, true) ~= nil
            end
            if match then
                table.insert(results, {
                    slot = slot,
                    name = item.name,
                    count = item.count,
                })
            end
        end
    end
    return results
end

-- Find item by category
function Inv.findByCategory(category)
    local categoryItems = Inv.CATEGORIES[category]
    if not categoryItems then
        return {}
    end
    
    local results = {}
    for slot = 1, 16 do
        local item = Inv.getSlot(slot)
        if item then
            for _, catItem in ipairs(categoryItems) do
                if item.name == catItem then
                    table.insert(results, {
                        slot = slot,
                        name = item.name,
                        count = item.count,
                    })
                    break
                end
            end
        end
    end
    return results
end

-- Count total of an item
function Inv.count(itemName, exact)
    local total = 0
    local found = Inv.find(itemName, exact)
    for _, item in ipairs(found) do
        total = total + item.count
    end
    return total
end

-- Count items in a category
function Inv.countCategory(category)
    local total = 0
    local found = Inv.findByCategory(category)
    for _, item in ipairs(found) do
        total = total + item.count
    end
    return total
end

-- Select an item by name
function Inv.select(itemName, exact)
    local found = Inv.find(itemName, exact)
    if #found > 0 then
        turtle.select(found[1].slot)
        return true
    end
    return false
end

-- Select by category
function Inv.selectCategory(category)
    local found = Inv.findByCategory(category)
    if #found > 0 then
        turtle.select(found[1].slot)
        return true
    end
    return false
end

-- Get empty slot count
function Inv.emptySlots()
    local count = 0
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            count = count + 1
        end
    end
    return count
end

-- Check if inventory is full
function Inv.isFull()
    return Inv.emptySlots() == 0
end

-- Check if inventory is empty
function Inv.isEmpty()
    return Inv.emptySlots() == 16
end

-- Find first empty slot
function Inv.findEmpty()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            return slot
        end
    end
    return nil
end

-- Consolidate inventory (stack similar items)
function Inv.consolidate()
    for slot = 1, 16 do
        local item = Inv.getSlot(slot)
        if item then
            turtle.select(slot)
            for targetSlot = 1, slot - 1 do
                local targetItem = Inv.getSlot(targetSlot)
                if targetItem and targetItem.name == item.name then
                    if turtle.transferTo(targetSlot) then
                        break
                    end
                end
            end
        end
    end
    turtle.select(1)
end

-- Drop trash items
function Inv.dropTrash()
    local dropped = 0
    for slot = 1, 16 do
        local item = Inv.getSlot(slot)
        if item then
            for _, trashItem in ipairs(Inv.CATEGORIES.trash) do
                if item.name == trashItem then
                    turtle.select(slot)
                    turtle.drop()
                    dropped = dropped + 1
                    break
                end
            end
        end
    end
    turtle.select(1)
    return dropped
end

-- Check if we have fuel
function Inv.hasFuel()
    return #Inv.findByCategory("fuel") > 0
end

-- Refuel from inventory
function Inv.refuel(targetLevel)
    targetLevel = targetLevel or 1000
    
    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == "unlimited" then
        return true
    end
    
    while fuelLevel < targetLevel do
        if Inv.selectCategory("fuel") then
            if turtle.refuel(1) then
                fuelLevel = turtle.getFuelLevel()
            else
                break
            end
        else
            break
        end
    end
    
    turtle.select(1)
    return turtle.getFuelLevel() >= targetLevel
end

-- Get full inventory summary
function Inv.summary()
    local summary = {
        slots = {},
        categories = {},
        emptySlots = 0,
        totalItems = 0,
    }
    
    for slot = 1, 16 do
        local item = Inv.getSlot(slot)
        if item then
            summary.slots[slot] = item
            summary.totalItems = summary.totalItems + item.count
        else
            summary.emptySlots = summary.emptySlots + 1
        end
    end
    
    for category, _ in pairs(Inv.CATEGORIES) do
        summary.categories[category] = Inv.countCategory(category)
    end
    
    return summary
end

-- Check if we can craft a turtle (returns missing items)
function Inv.canCraftTurtle()
    local missing = {}
    local have = {
        iron_ingot = Inv.count("iron_ingot", true),
        redstone = Inv.count("redstone", true),
        glass_pane = Inv.count("glass_pane", true),
        planks = Inv.countCategory("planks"),
        diamond = Inv.count("diamond", true),
        stick = Inv.count("stick", true),
    }
    
    for item, needed in pairs(Inv.TURTLE_RECIPE) do
        if (have[item] or 0) < needed then
            missing[item] = needed - (have[item] or 0)
        end
    end
    
    return next(missing) == nil, missing
end

-- Dump inventory to nearby chest
function Inv.dumpToChest(keepFuel, keepEssentials)
    keepFuel = keepFuel ~= false
    keepEssentials = keepEssentials or false
    
    local dumped = 0
    for slot = 1, 16 do
        local item = Inv.getSlot(slot)
        if item then
            local shouldKeep = false
            
            -- Check if fuel
            if keepFuel then
                for _, fuelItem in ipairs(Inv.CATEGORIES.fuel) do
                    if item.name == fuelItem then
                        shouldKeep = true
                        break
                    end
                end
            end
            
            -- Check if essential (diamonds, turtle parts)
            if keepEssentials then
                if item.name:find("diamond") or item.name:find("computercraft") then
                    shouldKeep = true
                end
            end
            
            if not shouldKeep then
                turtle.select(slot)
                if turtle.drop() then
                    dumped = dumped + item.count
                end
            end
        end
    end
    
    turtle.select(1)
    return dumped
end

-- Pull items from chest in front
function Inv.pullFromChest(itemName, maxCount)
    maxCount = maxCount or 64
    local pulled = 0
    
    while pulled < maxCount and Inv.emptySlots() > 0 do
        if turtle.suck(math.min(64, maxCount - pulled)) then
            local item = Inv.getSlot(turtle.getSelectedSlot())
            if item then
                if itemName and not item.name:find(itemName) then
                    -- Wrong item, put it back
                    turtle.drop()
                else
                    pulled = pulled + item.count
                end
            end
        else
            break
        end
    end
    
    return pulled
end

-- Organize inventory by category
function Inv.organize()
    Inv.consolidate()
    
    -- Define slot ranges for categories
    local layout = {
        { category = "fuel", slots = {1, 2} },
        { category = "gem", slots = {3, 4} },
        { category = "ingot", slots = {5, 6} },
        { category = "ore", slots = {7, 8, 9, 10} },
    }
    
    -- Move items to correct slots
    for _, rule in ipairs(layout) do
        local items = Inv.findByCategory(rule.category)
        local targetIdx = 1
        for _, item in ipairs(items) do
            if targetIdx <= #rule.slots then
                local targetSlot = rule.slots[targetIdx]
                if item.slot ~= targetSlot then
                    turtle.select(item.slot)
                    turtle.transferTo(targetSlot)
                end
                targetIdx = targetIdx + 1
            end
        end
    end
    
    turtle.select(1)
end

return Inv
