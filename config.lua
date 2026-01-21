-- ============================================
-- CONFIG.LUA - Colony Configuration
-- ============================================
-- Central configuration for the colony

local Config = {}

-- Colony identity
Config.COLONY_NAME = "Genesis"
Config.REDNET_CHANNEL = 100
Config.PROTOCOL = "COLONY"

-- Eve (first turtle) settings
Config.EVE = {
    MIN_FUEL_TO_START = 100,
    FUEL_RESERVE = 500,
}

-- Mining configuration
Config.MINING = {
    DEFAULT_PATTERN = "branch",  -- branch, tunnel, quarry, strip
    BRANCH_LENGTH = 20,
    BRANCH_SPACING = 3,
    TUNNEL_LENGTH = 50,
    QUARRY_SIZE = 8,
    TORCH_SPACING = 8,
    MIN_FUEL = 500,
    RETURN_ON_FULL = true,
    RETURN_ON_LOW_FUEL = true,
    OPTIMAL_Y_LEVEL = -59,  -- Best for diamonds in 1.18+
}

-- Crafting priorities
Config.CRAFTING = {
    -- Priority order for what to craft
    PRIORITIES = {
        "turtle",           -- More turtles = more power
        "diamond_pickaxe",  -- Needed for turtle
        "furnace",          -- Needed for smelting
        "chest",            -- Storage
    },
}

-- Birth (new turtle creation) settings
Config.BIRTH = {
    -- How many children should one turtle have before stopping
    MAX_CHILDREN_PER_PARENT = 3,
    
    -- Minimum resources before attempting birth
    MIN_IRON = 7,
    MIN_DIAMONDS = 3,
    MIN_REDSTONE = 1,
    
    -- Delay between births (in seconds)
    BIRTH_COOLDOWN = 60,
}

-- Communication settings
Config.COMMS = {
    HEARTBEAT_INTERVAL = 30,  -- seconds
    DISCOVERY_TIMEOUT = 5,
    PEER_TIMEOUT = 120,       -- Consider peer dead after this many seconds
}

-- Fuel values for reference
Config.FUEL_VALUES = {
    ["minecraft:coal"] = 80,
    ["minecraft:charcoal"] = 80,
    ["minecraft:coal_block"] = 800,
    ["minecraft:lava_bucket"] = 1000,
    ["minecraft:blaze_rod"] = 120,
    ["minecraft:stick"] = 5,
    ["minecraft:planks"] = 15,
    ["minecraft:log"] = 15,
}

-- Item categories
Config.CATEGORIES = {
    ESSENTIAL = {
        "minecraft:diamond",
        "minecraft:diamond_pickaxe",
        "computercraft:computer_normal",
        "computercraft:turtle_normal",
    },
    FUEL = {
        "minecraft:coal",
        "minecraft:charcoal",
        "minecraft:coal_block",
        "minecraft:lava_bucket",
    },
    TRASH = {
        "minecraft:dirt",
        "minecraft:gravel",
        "minecraft:cobblestone",
        "minecraft:andesite",
        "minecraft:diorite",
        "minecraft:granite",
        "minecraft:tuff",
        "minecraft:deepslate",
        "minecraft:cobbled_deepslate",
    },
    VALUABLE = {
        "minecraft:diamond",
        "minecraft:emerald",
        "minecraft:gold_ingot",
        "minecraft:iron_ingot",
        "minecraft:redstone",
        "minecraft:lapis_lazuli",
    },
}

-- Role definitions
Config.ROLES = {
    EVE = {
        name = "eve",
        description = "The first turtle, mother of all",
        canMine = true,
        canCraft = true,
        canBirth = true,
        priority = "birth",  -- Focus on creating children
    },
    MINER = {
        name = "miner",
        description = "Resource gatherer",
        canMine = true,
        canCraft = false,
        canBirth = false,
        priority = "mine",
    },
    CRAFTER = {
        name = "crafter",
        description = "Item crafter and turtle birther",
        canMine = false,
        canCraft = true,
        canBirth = true,
        priority = "craft",
    },
    WORKER = {
        name = "worker",
        description = "General purpose worker",
        canMine = true,
        canCraft = true,
        canBirth = false,
        priority = "mine",
    },
}

-- Base layout
Config.BASE = {
    -- Relative positions for base structures
    STORAGE_CHEST = { x = 0, y = 0, z = 1 },
    FURNACE_ARRAY = { x = 2, y = 0, z = 0 },
    DISK_DRIVE = { x = -1, y = 0, z = 0 },
    NURSERY = { x = 0, y = 0, z = -2 },
}

return Config
