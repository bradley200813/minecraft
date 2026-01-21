-- ============================================
-- MONITOR.LUA - Big Screen Colony Display  
-- ============================================
-- For use with CC:Tweaked monitor peripheral
-- Attach monitors and run this program

local REFRESH_RATE = 1

-- Find monitor
local mon = peripheral.find("monitor")
if not mon then
    print("No monitor found! Attach a monitor and try again.")
    return
end

-- Setup
mon.setTextScale(0.5)
local width, height = mon.getSize()

-- Colony state (updated via rednet)
local colony = {
    turtles = {},
    events = {},
    stats = {
        totalBlocksMined = 0,
        totalTurtlesBorn = 0,
    }
}

-- Open rednet
local modemSide = nil
for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
    if peripheral.getType(side) == "modem" then
        modemSide = side
        rednet.open(side)
        break
    end
end

-- Colors
local COLORS = {
    bg = colors.black,
    header = colors.lime,
    text = colors.white,
    dim = colors.gray,
    warning = colors.yellow,
    danger = colors.red,
    success = colors.lime,
    info = colors.cyan,
    accent = colors.purple,
}

-- Draw functions
local function drawBox(x, y, w, h, color)
    mon.setBackgroundColor(color or colors.gray)
    for row = y, y + h - 1 do
        mon.setCursorPos(x, row)
        mon.write(string.rep(" ", w))
    end
end

local function drawText(x, y, text, fg, bg)
    mon.setCursorPos(x, y)
    if fg then mon.setTextColor(fg) end
    if bg then mon.setBackgroundColor(bg) end
    mon.write(text)
end

local function drawBar(x, y, w, percent, fgColor, bgColor)
    bgColor = bgColor or colors.gray
    fgColor = fgColor or colors.lime
    
    local filled = math.floor(w * percent / 100)
    
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(fgColor)
    mon.write(string.rep(" ", filled))
    mon.setBackgroundColor(bgColor)
    mon.write(string.rep(" ", w - filled))
end

local function centerText(y, text, fg, bg)
    local x = math.floor((width - #text) / 2) + 1
    drawText(x, y, text, fg, bg)
end

-- Draw header
local function drawHeader()
    drawBox(1, 1, width, 3, colors.gray)
    
    centerText(2, "🐢 GENESIS COLONY 🐢", COLORS.header, colors.gray)
    
    -- Time
    local timeStr = os.date("%H:%M:%S")
    drawText(width - #timeStr, 2, timeStr, COLORS.dim, colors.gray)
end

-- Draw stats bar
local function drawStats()
    local y = 4
    
    -- Count active turtles
    local activeCount = 0
    local totalFuel = 0
    for _, t in pairs(colony.turtles) do
        if (os.epoch("utc") - (t.lastSeen or 0)) < 30000 then
            activeCount = activeCount + 1
        end
        totalFuel = totalFuel + (t.fuel or 0)
    end
    
    local statsY = y
    
    -- Stats boxes
    local boxWidth = math.floor(width / 4)
    
    -- Turtles
    drawBox(1, statsY, boxWidth - 1, 3, colors.gray)
    drawText(2, statsY, "TURTLES", COLORS.info, colors.gray)
    drawText(2, statsY + 1, tostring(activeCount), COLORS.header, colors.gray)
    
    -- Mined
    drawBox(boxWidth + 1, statsY, boxWidth - 1, 3, colors.gray)
    drawText(boxWidth + 2, statsY, "MINED", COLORS.info, colors.gray)
    drawText(boxWidth + 2, statsY + 1, tostring(colony.stats.totalBlocksMined), COLORS.header, colors.gray)
    
    -- Born
    drawBox(boxWidth * 2 + 1, statsY, boxWidth - 1, 3, colors.gray)
    drawText(boxWidth * 2 + 2, statsY, "BORN", COLORS.info, colors.gray)
    drawText(boxWidth * 2 + 2, statsY + 1, tostring(colony.stats.totalTurtlesBorn), COLORS.header, colors.gray)
    
    -- Fuel
    drawBox(boxWidth * 3 + 1, statsY, boxWidth - 1, 3, colors.gray)
    drawText(boxWidth * 3 + 2, statsY, "FUEL", COLORS.info, colors.gray)
    drawText(boxWidth * 3 + 2, statsY + 1, tostring(totalFuel), COLORS.header, colors.gray)
end

-- Draw turtle list
local function drawTurtles()
    local startY = 8
    
    drawText(2, startY, "== TURTLES ==", COLORS.info, COLORS.bg)
    startY = startY + 1
    
    local y = startY
    local sorted = {}
    for id, t in pairs(colony.turtles) do
        table.insert(sorted, t)
    end
    table.sort(sorted, function(a, b) return (a.id or 0) < (b.id or 0) end)
    
    for _, t in ipairs(sorted) do
        if y > height - 8 then break end
        
        local isOnline = (os.epoch("utc") - (t.lastSeen or 0)) < 30000
        local statusColor = isOnline and COLORS.success or COLORS.danger
        local status = isOnline and "●" or "○"
        
        -- Status indicator
        drawText(2, y, status, statusColor, COLORS.bg)
        
        -- Name
        local name = (t.label or ("T-" .. t.id)):sub(1, 12)
        drawText(4, y, name, COLORS.text, COLORS.bg)
        
        -- Role
        local role = (t.role or "?"):sub(1, 6):upper()
        drawText(18, y, "[" .. role .. "]", COLORS.accent, COLORS.bg)
        
        -- Position
        local pos = string.format("(%d,%d,%d)", 
            t.position and t.position.x or 0,
            t.position and t.position.y or 0,
            t.position and t.position.z or 0
        )
        drawText(28, y, pos, COLORS.dim, COLORS.bg)
        
        -- Fuel bar
        local fuelPercent = math.floor(((t.fuel or 0) / (t.fuelLimit or 20000)) * 100)
        local fuelColor = COLORS.success
        if fuelPercent < 25 then fuelColor = COLORS.danger
        elseif fuelPercent < 50 then fuelColor = COLORS.warning end
        
        drawText(42, y, "F:", COLORS.dim, COLORS.bg)
        drawBar(44, y, 8, fuelPercent, fuelColor, colors.gray)
        
        -- State
        local state = (t.state or "idle"):sub(1, 8)
        drawText(54, y, state, COLORS.info, COLORS.bg)
        
        y = y + 1
    end
    
    if #sorted == 0 then
        drawText(4, startY, "No turtles connected...", COLORS.dim, COLORS.bg)
    end
    
    return y + 1
end

-- Draw event log
local function drawEvents(startY)
    startY = startY or height - 7
    
    drawText(2, startY, "== EVENTS ==", COLORS.info, COLORS.bg)
    startY = startY + 1
    
    local y = startY
    for i, event in ipairs(colony.events) do
        if i > 5 or y > height - 1 then break end
        
        -- Time ago
        local ago = math.floor((os.epoch("utc") - (event.time or 0)) / 1000)
        local timeStr
        if ago < 60 then timeStr = ago .. "s"
        elseif ago < 3600 then timeStr = math.floor(ago/60) .. "m"
        else timeStr = math.floor(ago/3600) .. "h" end
        
        drawText(2, y, timeStr, COLORS.dim, COLORS.bg)
        drawText(7, y, (event.message or ""):sub(1, width - 8), COLORS.text, COLORS.bg)
        
        y = y + 1
    end
end

-- Draw mini map
local function drawMap()
    local mapWidth = 20
    local mapHeight = 10
    local mapX = width - mapWidth - 1
    local mapY = 8
    
    drawBox(mapX, mapY, mapWidth, mapHeight, colors.black)
    drawText(mapX, mapY - 1, "MAP", COLORS.info, COLORS.bg)
    
    -- Draw turtles on map
    for _, t in pairs(colony.turtles) do
        if t.position then
            local mx = mapX + math.floor(mapWidth / 2) + math.floor((t.position.x or 0) / 5)
            local my = mapY + math.floor(mapHeight / 2) + math.floor((t.position.z or 0) / 5)
            
            if mx >= mapX and mx < mapX + mapWidth and my >= mapY and my < mapY + mapHeight then
                local char = "●"
                local color = COLORS.success
                if t.role == "eve" then 
                    char = "★"
                    color = colors.yellow
                end
                drawText(mx, my, char, color, colors.black)
            end
        end
    end
end

-- Main draw function
local function draw()
    mon.setBackgroundColor(COLORS.bg)
    mon.clear()
    
    drawHeader()
    drawStats()
    local nextY = drawTurtles()
    drawMap()
    drawEvents()
end

-- Process rednet messages
local function processMessage(senderId, message)
    if type(message) ~= "table" then return end
    
    local msgType = message.type
    
    if msgType == "heartbeat" or msgType == "status" or msgType == "hello" then
        local data = message.data or {}
        colony.turtles[senderId] = {
            id = senderId,
            label = data.label or ("Turtle-" .. senderId),
            role = data.role or "unknown",
            position = data.position or {x=0, y=0, z=0},
            fuel = data.fuel or 0,
            fuelLimit = data.fuelLimit or 20000,
            state = data.state or "idle",
            generation = data.generation or 0,
            lastSeen = os.epoch("utc"),
        }
        
        if msgType == "hello" and data.event == "birth" then
            table.insert(colony.events, 1, {
                time = os.epoch("utc"),
                message = "🐣 " .. (data.label or senderId) .. " born!",
            })
            colony.stats.totalTurtlesBorn = colony.stats.totalTurtlesBorn + 1
        end
        
    elseif msgType == "task_complete" then
        local data = message.data or {}
        local label = colony.turtles[senderId] and colony.turtles[senderId].label or senderId
        table.insert(colony.events, 1, {
            time = os.epoch("utc"),
            message = "✓ " .. label .. ": task done",
        })
        if data.blocksMined then
            colony.stats.totalBlocksMined = colony.stats.totalBlocksMined + data.blocksMined
        end
        
    elseif msgType == "low_fuel" then
        local label = colony.turtles[senderId] and colony.turtles[senderId].label or senderId
        table.insert(colony.events, 1, {
            time = os.epoch("utc"),
            message = "⚠ " .. label .. " low fuel!",
        })
    end
    
    -- Trim events
    while #colony.events > 20 do
        table.remove(colony.events)
    end
end

-- Rednet loop
local function rednetLoop()
    while true do
        local senderId, message = rednet.receive("COLONY", 0.5)
        if senderId then
            processMessage(senderId, message)
        end
    end
end

-- Display loop
local function displayLoop()
    while true do
        draw()
        sleep(REFRESH_RATE)
    end
end

-- Main
print("Colony Monitor Display")
print("Monitor size: " .. width .. "x" .. height)
print("Listening on COLONY protocol...")

parallel.waitForAll(displayLoop, rednetLoop)
