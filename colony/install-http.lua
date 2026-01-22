-- ============================================
-- COLONY HTTP INSTALLER
-- ============================================
-- Downloads all colony files from your local server
--
-- Usage on turtle:
--   wget run http://YOUR_PC_IP:3000/colony/install-http.lua
--
-- Example:
--   wget run http://192.168.1.100:3000/colony/install-http.lua

-- CHANGE THIS to your computer's IP address!
local SERVER = "http://192.168.1.100:3000"

-- Auto-detect server from where we were downloaded
local args = {...}
if args[1] then
    SERVER = args[1]
end

local FILES = {
    -- Core
    "/colony/startup.lua",
    "/colony/eve.lua",
    "/colony/brain.lua",
    "/colony/config.lua",
    
    -- Libraries
    "/colony/lib/state.lua",
    "/colony/lib/inv.lua",
    "/colony/lib/nav.lua",
    "/colony/lib/comms.lua",
    "/colony/lib/reporter.lua",
    "/colony/lib/commander.lua",
    
    -- Roles
    "/colony/roles/miner.lua",
    "/colony/roles/crafter.lua",
}

print("========================================")
print("  GENESIS COLONY INSTALLER")
print("========================================")
print("")
print("Server: " .. SERVER)
print("")

-- Create directories
print("Creating directories...")
fs.makeDir("/colony")
fs.makeDir("/colony/lib")
fs.makeDir("/colony/roles")

-- Download files
local success = 0
local failed = 0

for _, filePath in ipairs(FILES) do
    local url = SERVER .. filePath
    local localPath = filePath
    
    write("[GET] " .. filePath .. " ... ")
    
    local response = http.get(url)
    
    if response then
        local content = response.readAll()
        response.close()
        
        if fs.exists(localPath) then
            fs.delete(localPath)
        end
        
        local f = fs.open(localPath, "w")
        f.write(content)
        f.close()
        
        print("OK")
        success = success + 1
    else
        print("FAILED")
        failed = failed + 1
    end
    
    sleep(0.1)
end

print("")
print("========================================")
print("  INSTALLATION COMPLETE")
print("========================================")
print("")
print("Downloaded: " .. success .. " files")
print("Failed: " .. failed .. " files")
print("")

if failed == 0 or success > 5 then
    print("Setting up startup...")
    
    -- Create startup file
    local f = fs.open("/startup.lua", "w")
    f.write('shell.run("/colony/startup.lua")')
    f.close()
    
    print("")
    print("SUCCESS!")
    print("")
    print("1. Label your turtle:")
    print("   label set Eve-1")
    print("")
    print("2. Add fuel (coal, etc)")
    print("")
    print("3. Reboot to start:")
    print("   reboot")
else
    print("Most files failed to download!")
    print("")
    print("Check that:")
    print("1. Server is running (node server.js)")
    print("2. HTTP is enabled in CC config")
    print("3. IP address is correct")
end
