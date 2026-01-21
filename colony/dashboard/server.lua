-- ============================================
-- DASHBOARD SERVER - Colony Web Interface
-- ============================================
-- Run this on a Computer (not turtle) with modem
-- Access via http://localhost:8080 in browser

-- Configuration
local HTTP_PORT = 8080
local REFRESH_RATE = 2  -- seconds

-- Colony state
local colony = {
    name = "Genesis",
    startTime = os.epoch("utc"),
    turtles = {},
    resources = {},
    events = {},
    stats = {
        totalBlocksMined = 0,
        totalTurtlesBorn = 0,
        totalFuelConsumed = 0,
    }
}

-- Initialize rednet
local modemSide = nil
for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
    if peripheral.getType(side) == "modem" then
        modemSide = side
        break
    end
end

if modemSide then
    rednet.open(modemSide)
    rednet.host("COLONY", "Dashboard")
    print("[DASHBOARD] Rednet opened on " .. modemSide)
else
    print("[DASHBOARD] WARNING: No modem found!")
end

-- Add event to log
local function logEvent(eventType, message, data)
    table.insert(colony.events, 1, {
        time = os.epoch("utc"),
        type = eventType,
        message = message,
        data = data,
    })
    -- Keep only last 100 events
    while #colony.events > 100 do
        table.remove(colony.events)
    end
end

-- Update turtle data
local function updateTurtle(id, data)
    local isNew = colony.turtles[id] == nil
    
    colony.turtles[id] = {
        id = id,
        label = data.label or ("Turtle-" .. id),
        role = data.role or "unknown",
        position = data.position or {x=0, y=0, z=0},
        fuel = data.fuel or 0,
        fuelLimit = data.fuelLimit or 20000,
        state = data.state or "idle",
        task = data.task,
        inventory = data.inventory or {},
        generation = data.generation or 0,
        lastSeen = os.epoch("utc"),
        stats = data.stats or {},
    }
    
    if isNew then
        logEvent("birth", data.label .. " joined the colony", {id = id})
        colony.stats.totalTurtlesBorn = colony.stats.totalTurtlesBorn + 1
    end
end

-- Generate HTML dashboard
local function generateHTML()
    local uptime = math.floor((os.epoch("utc") - colony.startTime) / 1000)
    local hours = math.floor(uptime / 3600)
    local minutes = math.floor((uptime % 3600) / 60)
    local seconds = uptime % 60
    local uptimeStr = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    
    -- Count active turtles
    local activeTurtles = 0
    local totalFuel = 0
    for _, t in pairs(colony.turtles) do
        if (os.epoch("utc") - t.lastSeen) < 30000 then
            activeTurtles = activeTurtles + 1
        end
        totalFuel = totalFuel + (t.fuel or 0)
    end
    
    local html = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="]] .. REFRESH_RATE .. [[">
    <title>🐢 ]] .. colony.name .. [[ Colony Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            color: #e0e0e0;
            min-height: 100vh;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding: 20px;
            background: rgba(255,255,255,0.05);
            border-radius: 15px;
            border: 1px solid rgba(255,255,255,0.1);
        }
        
        .header h1 {
            font-size: 2.5em;
            background: linear-gradient(90deg, #00ff87, #60efff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 10px;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: rgba(255,255,255,0.05);
            border-radius: 15px;
            padding: 20px;
            text-align: center;
            border: 1px solid rgba(255,255,255,0.1);
            transition: transform 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-value {
            font-size: 2.5em;
            font-weight: bold;
            color: #00ff87;
        }
        
        .stat-label {
            color: #888;
            font-size: 0.9em;
            margin-top: 5px;
        }
        
        .section {
            background: rgba(255,255,255,0.05);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            border: 1px solid rgba(255,255,255,0.1);
        }
        
        .section h2 {
            color: #60efff;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        
        .turtle-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 15px;
        }
        
        .turtle-card {
            background: rgba(0,0,0,0.3);
            border-radius: 10px;
            padding: 15px;
            border-left: 4px solid #00ff87;
        }
        
        .turtle-card.offline {
            border-left-color: #ff4444;
            opacity: 0.6;
        }
        
        .turtle-card.busy {
            border-left-color: #ffaa00;
        }
        
        .turtle-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        
        .turtle-name {
            font-size: 1.2em;
            font-weight: bold;
        }
        
        .turtle-role {
            background: #60efff;
            color: #1a1a2e;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
        }
        
        .turtle-info {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 8px;
            font-size: 0.9em;
        }
        
        .turtle-info span {
            color: #888;
        }
        
        .fuel-bar {
            height: 8px;
            background: #333;
            border-radius: 4px;
            margin-top: 10px;
            overflow: hidden;
        }
        
        .fuel-bar-fill {
            height: 100%;
            background: linear-gradient(90deg, #ff4444, #ffaa00, #00ff87);
            border-radius: 4px;
            transition: width 0.5s ease;
        }
        
        .events-list {
            max-height: 300px;
            overflow-y: auto;
        }
        
        .event {
            padding: 10px;
            border-bottom: 1px solid rgba(255,255,255,0.05);
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .event-icon {
            font-size: 1.2em;
        }
        
        .event-time {
            color: #666;
            font-size: 0.8em;
            min-width: 80px;
        }
        
        .event-message {
            flex: 1;
        }
        
        .map-container {
            height: 400px;
            background: #0a0a15;
            border-radius: 10px;
            position: relative;
            overflow: hidden;
        }
        
        .map-grid {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-image: 
                linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px),
                linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px);
            background-size: 20px 20px;
        }
        
        .turtle-marker {
            position: absolute;
            width: 20px;
            height: 20px;
            background: #00ff87;
            border-radius: 50%;
            transform: translate(-50%, -50%);
            border: 2px solid white;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .turtle-marker:hover {
            transform: translate(-50%, -50%) scale(1.5);
            z-index: 100;
        }
        
        .turtle-marker.eve {
            background: gold;
            width: 25px;
            height: 25px;
        }
        
        @keyframes pulse {
            0%, 100% { box-shadow: 0 0 0 0 rgba(0,255,135,0.4); }
            50% { box-shadow: 0 0 0 10px rgba(0,255,135,0); }
        }
        
        .turtle-marker.active {
            animation: pulse 2s infinite;
        }
        
        .no-turtles {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🐢 ]] .. colony.name .. [[ Colony</h1>
        <p>Uptime: ]] .. uptimeStr .. [[ | Last update: ]] .. os.date("%H:%M:%S") .. [[</p>
    </div>
    
    <div class="stats-grid">
        <div class="stat-card">
            <div class="stat-value">]] .. activeTurtles .. [[</div>
            <div class="stat-label">Active Turtles</div>
        </div>
        <div class="stat-card">
            <div class="stat-value">]] .. colony.stats.totalTurtlesBorn .. [[</div>
            <div class="stat-label">Total Born</div>
        </div>
        <div class="stat-card">
            <div class="stat-value">]] .. colony.stats.totalBlocksMined .. [[</div>
            <div class="stat-label">Blocks Mined</div>
        </div>
        <div class="stat-card">
            <div class="stat-value">]] .. totalFuel .. [[</div>
            <div class="stat-label">Total Fuel</div>
        </div>
    </div>
    
    <div class="section">
        <h2>🗺️ Colony Map</h2>
        <div class="map-container">
            <div class="map-grid"></div>
]]

    -- Add turtle markers to map
    for id, t in pairs(colony.turtles) do
        local x = 200 + (t.position.x or 0) * 5
        local y = 200 + (t.position.z or 0) * 5
        local class = "turtle-marker"
        if t.role == "eve" then class = class .. " eve" end
        if (os.epoch("utc") - t.lastSeen) < 10000 then class = class .. " active" end
        
        html = html .. string.format(
            '<div class="%s" style="left: %dpx; top: %dpx;" title="%s"></div>\n',
            class, x, y, t.label
        )
    end
    
    html = html .. [[
        </div>
    </div>
    
    <div class="section">
        <h2>🐢 Turtles</h2>
        <div class="turtle-grid">
]]

    -- Add turtle cards
    local turtleCount = 0
    for id, t in pairs(colony.turtles) do
        turtleCount = turtleCount + 1
        local isOnline = (os.epoch("utc") - t.lastSeen) < 30000
        local cardClass = "turtle-card"
        if not isOnline then cardClass = cardClass .. " offline" end
        if t.state == "mining" or t.state == "crafting" then cardClass = cardClass .. " busy" end
        
        local fuelPercent = math.floor((t.fuel / t.fuelLimit) * 100)
        
        html = html .. string.format([[
            <div class="%s">
                <div class="turtle-header">
                    <span class="turtle-name">%s</span>
                    <span class="turtle-role">%s</span>
                </div>
                <div class="turtle-info">
                    <div><span>Position:</span> %d, %d, %d</div>
                    <div><span>State:</span> %s</div>
                    <div><span>Generation:</span> %d</div>
                    <div><span>Fuel:</span> %d / %d</div>
                </div>
                <div class="fuel-bar">
                    <div class="fuel-bar-fill" style="width: %d%%"></div>
                </div>
            </div>
]],
            cardClass,
            t.label,
            t.role:upper(),
            t.position.x or 0, t.position.y or 0, t.position.z or 0,
            t.state or "idle",
            t.generation or 0,
            t.fuel or 0, t.fuelLimit or 20000,
            fuelPercent
        )
    end
    
    if turtleCount == 0 then
        html = html .. [[
            <div class="no-turtles">
                <p>🥚 No turtles connected yet...</p>
                <p>Start Eve to begin the colony!</p>
            </div>
]]
    end
    
    html = html .. [[
        </div>
    </div>
    
    <div class="section">
        <h2>📜 Event Log</h2>
        <div class="events-list">
]]

    -- Add events
    for i, event in ipairs(colony.events) do
        if i > 20 then break end
        
        local icon = "📋"
        if event.type == "birth" then icon = "🐣"
        elseif event.type == "mining" then icon = "⛏️"
        elseif event.type == "crafting" then icon = "🔧"
        elseif event.type == "fuel" then icon = "⛽"
        elseif event.type == "error" then icon = "❌"
        end
        
        local timeAgo = math.floor((os.epoch("utc") - event.time) / 1000)
        local timeStr
        if timeAgo < 60 then
            timeStr = timeAgo .. "s ago"
        elseif timeAgo < 3600 then
            timeStr = math.floor(timeAgo/60) .. "m ago"
        else
            timeStr = math.floor(timeAgo/3600) .. "h ago"
        end
        
        html = html .. string.format([[
            <div class="event">
                <span class="event-icon">%s</span>
                <span class="event-time">%s</span>
                <span class="event-message">%s</span>
            </div>
]], icon, timeStr, event.message)
    end
    
    if #colony.events == 0 then
        html = html .. '<div class="event"><span class="event-message">No events yet...</span></div>'
    end
    
    html = html .. [[
        </div>
    </div>
    
    <div class="footer">
        <p>Genesis Colony Dashboard v1.0 | 🐢 Powered by CC:Tweaked</p>
    </div>
</body>
</html>
]]
    
    return html
end

-- Generate JSON API response
local function generateAPI()
    return textutils.serializeJSON({
        colony = colony.name,
        uptime = os.epoch("utc") - colony.startTime,
        stats = colony.stats,
        turtles = colony.turtles,
        events = colony.events,
    })
end

-- Handle HTTP request (if http server available)
local function handleRequest(request)
    local path = request.path or "/"
    
    if path == "/api" or path == "/api/status" then
        return {
            status = 200,
            headers = {["Content-Type"] = "application/json"},
            body = generateAPI(),
        }
    else
        return {
            status = 200,
            headers = {["Content-Type"] = "text/html"},
            body = generateHTML(),
        }
    end
end

-- Process rednet messages
local function processMessage(senderId, message)
    if type(message) ~= "table" then return end
    
    local msgType = message.type
    
    if msgType == "heartbeat" or msgType == "status" then
        updateTurtle(senderId, message.data)
        
    elseif msgType == "hello" then
        updateTurtle(senderId, message.data)
        if message.data.event == "birth" then
            logEvent("birth", "New turtle born! Generation " .. (message.data.generation or "?"), message.data)
        else
            logEvent("join", (message.data.label or senderId) .. " connected", message.data)
        end
        
    elseif msgType == "goodbye" then
        logEvent("leave", senderId .. " disconnected", {})
        
    elseif msgType == "task_complete" then
        local turtleLabel = colony.turtles[senderId] and colony.turtles[senderId].label or senderId
        logEvent("task", turtleLabel .. " completed: " .. (message.data.task or "task"), message.data)
        
        -- Update stats
        if message.data.blocksMined then
            colony.stats.totalBlocksMined = colony.stats.totalBlocksMined + message.data.blocksMined
        end
        
    elseif msgType == "low_fuel" then
        local turtleLabel = colony.turtles[senderId] and colony.turtles[senderId].label or senderId
        logEvent("fuel", turtleLabel .. " low on fuel! (" .. (message.data.fuel or "?") .. ")", message.data)
        
    elseif msgType == "inventory_full" then
        local turtleLabel = colony.turtles[senderId] and colony.turtles[senderId].label or senderId
        logEvent("inventory", turtleLabel .. " inventory full", message.data)
        
    elseif msgType == "help" then
        local turtleLabel = colony.turtles[senderId] and colony.turtles[senderId].label or senderId
        logEvent("error", turtleLabel .. " needs help: " .. (message.data.issue or "unknown"), message.data)
    end
end

-- Display on attached monitor
local function updateMonitor()
    local mon = peripheral.find("monitor")
    if not mon then return end
    
    mon.setTextScale(0.5)
    mon.clear()
    mon.setCursorPos(1, 1)
    
    -- Header
    mon.setTextColor(colors.lime)
    mon.write("=== " .. colony.name .. " Colony ===")
    
    -- Stats
    mon.setCursorPos(1, 3)
    mon.setTextColor(colors.white)
    
    local activeCount = 0
    for id, t in pairs(colony.turtles) do
        if (os.epoch("utc") - t.lastSeen) < 30000 then
            activeCount = activeCount + 1
        end
    end
    
    mon.write("Turtles: " .. activeCount)
    mon.setCursorPos(1, 4)
    mon.write("Mined: " .. colony.stats.totalBlocksMined)
    mon.setCursorPos(1, 5)
    mon.write("Born: " .. colony.stats.totalTurtlesBorn)
    
    -- Turtle list
    mon.setCursorPos(1, 7)
    mon.setTextColor(colors.yellow)
    mon.write("Active Turtles:")
    
    local y = 8
    for id, t in pairs(colony.turtles) do
        if y > 18 then break end
        
        local isOnline = (os.epoch("utc") - t.lastSeen) < 30000
        mon.setCursorPos(1, y)
        
        if isOnline then
            mon.setTextColor(colors.lime)
        else
            mon.setTextColor(colors.red)
        end
        
        mon.write(string.format("%s [%s] F:%d", 
            t.label:sub(1, 12), 
            t.role:sub(1, 6):upper(),
            t.fuel or 0
        ))
        y = y + 1
    end
    
    -- Recent events
    mon.setCursorPos(1, 20)
    mon.setTextColor(colors.cyan)
    mon.write("Recent Events:")
    
    y = 21
    for i, event in ipairs(colony.events) do
        if i > 5 or y > 25 then break end
        mon.setCursorPos(1, y)
        mon.setTextColor(colors.lightGray)
        mon.write(event.message:sub(1, 35))
        y = y + 1
    end
end

-- Main display loop
local function displayLoop()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        
        print("======================================")
        print("  " .. colony.name .. " Colony Dashboard")
        print("======================================")
        print("")
        
        -- Count turtles
        local activeCount = 0
        local totalCount = 0
        for id, t in pairs(colony.turtles) do
            totalCount = totalCount + 1
            if (os.epoch("utc") - t.lastSeen) < 30000 then
                activeCount = activeCount + 1
            end
        end
        
        print("Turtles: " .. activeCount .. "/" .. totalCount .. " active")
        print("Total Mined: " .. colony.stats.totalBlocksMined)
        print("Total Born: " .. colony.stats.totalTurtlesBorn)
        print("")
        
        print("--- Turtles ---")
        for id, t in pairs(colony.turtles) do
            local status = (os.epoch("utc") - t.lastSeen) < 30000 and "ON " or "OFF"
            print(string.format("[%s] %s (%s) F:%d", status, t.label, t.role, t.fuel or 0))
        end
        print("")
        
        print("--- Recent Events ---")
        for i, event in ipairs(colony.events) do
            if i > 5 then break end
            print(event.message)
        end
        
        print("")
        print("Web: http://<computer-ip>:" .. HTTP_PORT)
        
        updateMonitor()
        sleep(2)
    end
end

-- Rednet listener
local function rednetLoop()
    while true do
        local senderId, message = rednet.receive("COLONY", 1)
        if senderId then
            processMessage(senderId, message)
        end
    end
end

-- Respond to pings
local function pingResponder()
    while true do
        local senderId, message = rednet.receive("COLONY", 0.5)
        if senderId and type(message) == "table" and message.type == "ping" then
            rednet.send(senderId, {
                type = "pong",
                data = {
                    role = "dashboard",
                    label = "Colony Dashboard",
                }
            }, "COLONY")
        end
    end
end

-- Main
print("[DASHBOARD] Starting Genesis Colony Dashboard...")
print("[DASHBOARD] Monitoring colony on channel: COLONY")
print("")

logEvent("system", "Dashboard started", {})

-- Run all loops
parallel.waitForAll(displayLoop, rednetLoop, pingResponder)
