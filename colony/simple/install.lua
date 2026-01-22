-- ============================================
-- SIMPLE INSTALLER
-- ============================================
-- One command to install everything

local GITHUB_USER = "bradley200813"
local GITHUB_REPO = "minecraft"
local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. BRANCH .. "/colony/simple/"

print("========================================")
print("  SIMPLE COLONY INSTALLER")
print("========================================")
print("")

if not http then
    print("ERROR: HTTP not enabled!")
    return
end

-- Detect if turtle or computer
local isTurtle = turtle ~= nil

local files = isTurtle 
    and {"turtle.lua"}
    or {"bridge.lua"}

fs.makeDir("/colony")

for _, file in ipairs(files) do
    print("Downloading " .. file .. "...")
    
    local resp = http.get(BASE .. file)
    if resp then
        local content = resp.readAll()
        resp.close()
        
        local f = fs.open("/colony/" .. file, "w")
        f.write(content)
        f.close()
        
        print("  OK!")
    else
        print("  FAILED!")
    end
end

-- Create startup
print("")
print("Creating startup...")

local startup = isTurtle
    and 'shell.run("/colony/turtle.lua")'
    or 'shell.run("/colony/bridge.lua")'

local f = fs.open("/startup.lua", "w")
f.write(startup)
f.close()

print("")
print("========================================")
print("  DONE!")
print("========================================")
print("")

if isTurtle then
    print("This is a TURTLE")
    print("")
    print("1. Set a label:  label set MyTurtle")
    print("2. Add fuel (coal in inventory)")
    print("3. Reboot:  reboot")
else
    print("This is a COMPUTER (bridge)")
    print("")
    print("1. Edit /colony/bridge.lua")
    print("2. Set SERVER_URL to your ngrok URL")
    print("3. Reboot:  reboot")
end
