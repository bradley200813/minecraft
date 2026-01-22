-- ============================================
-- REPORTER.LUA - Turtle Status Reporter
-- ============================================
-- Add this to your turtle's startup to report to dashboard
-- Sends periodic updates to the colony dashboard

local REPORT_INTERVAL = 5  -- seconds

local Reporter = {}

-- Dependencies (set via init)
local Nav, Inv, State, Comms

function Reporter.init(nav, inv, state, comms)
    Nav = nav
    Inv = inv
    State = state
    Comms = comms
end

-- Build status report
function Reporter.buildReport()
    local report = {
        id = os.getComputerID(),
        label = os.getComputerLabel() or ("Turtle-" .. os.getComputerID()),
        role = State and State.get("role") or "unknown",
        generation = State and State.get("generation") or 0,
        
        position = Nav and Nav.getPosition() or {x=0, y=0, z=0},
        facing = Nav and Nav.getFacing() or 0,
        
        fuel = turtle.getFuelLevel(),
        fuelLimit = turtle.getFuelLimit(),
        
        state = State and State.get("currentState") or "idle",
        
        timestamp = os.epoch("utc"),
    }
    
    return report
end

-- Send heartbeat
function Reporter.heartbeat()
    if not Comms then 
        print("[REPORTER] No Comms module!")
        return false 
    end
    
    local ok, report = pcall(Reporter.buildReport)
    if not ok then
        print("[REPORTER] Failed to build report: " .. tostring(report))
        return false
    end
    
    local msgType = Comms.MSG and Comms.MSG.HEARTBEAT or "heartbeat"
    local success = Comms.broadcast(msgType, report)
    
    if not success then
        print("[REPORTER] Broadcast failed - modem closed?")
    end
    
    return success
end

-- Report specific event
function Reporter.event(eventType, message, data)
    if not Comms then return false end
    
    return Comms.broadcast(eventType, {
        message = message,
        data = data,
        turtle = {
            id = os.getComputerID(),
            label = os.getComputerLabel(),
        },
        position = Nav and Nav.getPosition() or nil,
        timestamp = os.epoch("utc"),
    })
end

-- Report task completion
function Reporter.taskComplete(taskName, result)
    if not Comms then return false end
    
    local report = Reporter.buildReport()
    report.task = taskName
    report.result = result
    
    return Comms.broadcast(Comms.MSG.TASK_COMPLETE, report)
end

-- Report low fuel
function Reporter.lowFuel()
    return Reporter.event(Comms.MSG.LOW_FUEL, "Low fuel warning", {
        fuel = turtle.getFuelLevel(),
        fuelLimit = turtle.getFuelLimit(),
    })
end

-- Report inventory full
function Reporter.inventoryFull()
    return Reporter.event(Comms.MSG.INVENTORY_FULL, "Inventory full", {
        inventory = Inv and Inv.summary() or {},
    })
end

-- Report help needed
function Reporter.needHelp(issue, details)
    return Reporter.event(Comms.MSG.HELP, "Help needed: " .. issue, {
        issue = issue,
        details = details,
    })
end

-- Background reporting loop
function Reporter.startReporting()
    print("[REPORTER] Starting heartbeat loop...")
    local failures = 0
    while true do
        local ok, err = pcall(Reporter.heartbeat)
        if not ok then
            failures = failures + 1
            print("[REPORTER] Error: " .. tostring(err))
            if failures > 5 then
                print("[REPORTER] Too many failures, retrying modem...")
                if Comms and Comms.open then
                    Comms.open()
                end
                failures = 0
            end
        else
            failures = 0
        end
        sleep(REPORT_INTERVAL)
    end
end

-- Start reporter as parallel task
function Reporter.runParallel(mainFunc)
    parallel.waitForAll(mainFunc, Reporter.startReporting)
end

return Reporter
