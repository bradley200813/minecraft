-- ============================================
-- STATE.LUA - Persistence & State Management
-- ============================================
-- Allows turtles to save/load their state
-- Survives reboots and chunk unloading

local State = {}

-- Default state file location
local STATE_FILE = "/.colony/state.json"
local BACKUP_FILE = "/.colony/state.backup.json"

-- Current state (cached in memory)
local currentState = nil

-- Ensure directory exists
local function ensureDir(path)
    local dir = path:match("(.+)/[^/]+$")
    if dir and not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

-- Deep copy a table
local function deepCopy(orig)
    if type(orig) ~= 'table' then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

-- Initialize default state
function State.getDefault()
    return {
        -- Identity
        id = os.getComputerID(),
        label = os.getComputerLabel() or ("Turtle-" .. os.getComputerID()),
        generation = 0,  -- 0 = Eve, 1 = first children, etc.
        birthTime = os.epoch("utc"),
        
        -- Role
        role = "unassigned",  -- miner, crafter, builder, smelter, scout
        
        -- Position (relative to home if no GPS)
        position = { x = 0, y = 0, z = 0 },
        facing = 0,  -- 0=north, 1=east, 2=south, 3=west
        homePosition = { x = 0, y = 0, z = 0 },
        hasGPS = false,
        
        -- Task management
        currentTask = nil,
        taskQueue = {},
        taskHistory = {},
        
        -- Statistics
        stats = {
            blocksMined = 0,
            blocksMoved = 0,
            itemsCrafted = 0,
            fuelConsumed = 0,
            childrenBorn = 0,
            deaths = 0,  -- times we've had to recover
        },
        
        -- Colony info
        colony = {
            name = "Genesis",
            queenId = nil,
            members = {},
            channel = 100,  -- Rednet channel
        },
        
        -- Inventory snapshot (for recovery)
        lastInventory = {},
        
        -- Timestamps
        lastSave = 0,
        lastHeartbeat = 0,
    }
end

-- Load state from disk
function State.load()
    -- Try main file first
    if fs.exists(STATE_FILE) then
        local file = fs.open(STATE_FILE, "r")
        if file then
            local content = file.readAll()
            file.close()
            local success, data = pcall(textutils.unserializeJSON, content)
            if success and data then
                currentState = data
                return currentState
            end
        end
    end
    
    -- Try backup
    if fs.exists(BACKUP_FILE) then
        local file = fs.open(BACKUP_FILE, "r")
        if file then
            local content = file.readAll()
            file.close()
            local success, data = pcall(textutils.unserializeJSON, content)
            if success and data then
                currentState = data
                print("[STATE] Recovered from backup")
                return currentState
            end
        end
    end
    
    -- No state found, create default
    currentState = State.getDefault()
    State.save()
    return currentState
end

-- Save state to disk
function State.save()
    if not currentState then
        return false
    end
    
    currentState.lastSave = os.epoch("utc")
    ensureDir(STATE_FILE)
    
    -- Backup old state first
    if fs.exists(STATE_FILE) then
        if fs.exists(BACKUP_FILE) then
            fs.delete(BACKUP_FILE)
        end
        fs.copy(STATE_FILE, BACKUP_FILE)
    end
    
    -- Write new state
    local content = textutils.serializeJSON(currentState)
    local file = fs.open(STATE_FILE, "w")
    if file then
        file.write(content)
        file.close()
        return true
    end
    return false
end

-- Get current state (loads if needed)
function State.get()
    if not currentState then
        State.load()
    end
    return currentState
end

-- Set a value in state (supports dot notation: "stats.blocksMined")
function State.set(key, value)
    local state = State.get()
    
    -- Handle dot notation
    local parts = {}
    for part in key:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    
    local current = state
    for i = 1, #parts - 1 do
        if type(current[parts[i]]) ~= "table" then
            current[parts[i]] = {}
        end
        current = current[parts[i]]
    end
    
    current[parts[#parts]] = value
    return State.save()
end

-- Increment a numeric value
function State.increment(key, amount)
    amount = amount or 1
    local state = State.get()
    
    local parts = {}
    for part in key:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    
    local current = state
    for i = 1, #parts - 1 do
        current = current[parts[i]]
        if not current then return false end
    end
    
    local finalKey = parts[#parts]
    if type(current[finalKey]) == "number" then
        current[finalKey] = current[finalKey] + amount
        return State.save()
    end
    return false
end

-- Get a value (supports dot notation)
function State.getValue(key)
    local state = State.get()
    
    local parts = {}
    for part in key:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    
    local current = state
    for i = 1, #parts do
        current = current[parts[i]]
        if current == nil then return nil end
    end
    
    return current
end

-- Update position
function State.updatePosition(x, y, z, facing)
    local state = State.get()
    if x then state.position.x = x end
    if y then state.position.y = y end
    if z then state.position.z = z end
    if facing then state.facing = facing end
    return State.save()
end

-- Set home position
function State.setHome()
    local state = State.get()
    state.homePosition = deepCopy(state.position)
    return State.save()
end

-- Add task to queue
function State.addTask(task)
    local state = State.get()
    table.insert(state.taskQueue, task)
    return State.save()
end

-- Get next task
function State.getNextTask()
    local state = State.get()
    if #state.taskQueue > 0 then
        local task = table.remove(state.taskQueue, 1)
        state.currentTask = task
        State.save()
        return task
    end
    return nil
end

-- Complete current task
function State.completeTask(success)
    local state = State.get()
    if state.currentTask then
        state.currentTask.completed = os.epoch("utc")
        state.currentTask.success = success
        table.insert(state.taskHistory, state.currentTask)
        -- Keep only last 50 tasks in history
        while #state.taskHistory > 50 do
            table.remove(state.taskHistory, 1)
        end
        state.currentTask = nil
        State.save()
    end
end

-- Snapshot inventory
function State.snapshotInventory()
    local state = State.get()
    state.lastInventory = {}
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            state.lastInventory[slot] = {
                name = item.name,
                count = item.count,
            }
        end
    end
    return State.save()
end

-- Reset state (for testing)
function State.reset()
    if fs.exists(STATE_FILE) then
        fs.delete(STATE_FILE)
    end
    if fs.exists(BACKUP_FILE) then
        fs.delete(BACKUP_FILE)
    end
    currentState = nil
end

-- Export state for debugging
function State.dump()
    return textutils.serialize(State.get())
end

return State
