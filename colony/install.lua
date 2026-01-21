-- ============================================
-- COLONY INSTALLER
-- ============================================
-- Run this on your turtle to download the colony
--
-- Usage: pastebin run <PASTE_CODE>
-- Or:    wget run http://your-server/install.lua

local FILES = {
    -- Core
    {path = "/colony/startup.lua", url = "startup"},
    {path = "/colony/eve.lua", url = "eve"},
    {path = "/colony/brain.lua", url = "brain"},
    {path = "/colony/config.lua", url = "config"},
    
    -- Libraries
    {path = "/colony/lib/state.lua", url = "lib_state"},
    {path = "/colony/lib/inv.lua", url = "lib_inv"},
    {path = "/colony/lib/nav.lua", url = "lib_nav"},
    {path = "/colony/lib/comms.lua", url = "lib_comms"},
    {path = "/colony/lib/reporter.lua", url = "lib_reporter"},
    
    -- Roles
    {path = "/colony/roles/miner.lua", url = "roles_miner"},
    {path = "/colony/roles/crafter.lua", url = "roles_crafter"},
}

-- Pastebin codes - YOU NEED TO FILL THESE IN
local PASTEBIN_CODES = {
    startup = "XXXXXXXX",      -- Replace with actual pastebin code
    eve = "XXXXXXXX",
    brain = "XXXXXXXX",
    config = "XXXXXXXX",
    lib_state = "XXXXXXXX",
    lib_inv = "XXXXXXXX",
    lib_nav = "XXXXXXXX",
    lib_comms = "XXXXXXXX",
    lib_reporter = "XXXXXXXX",
    roles_miner = "XXXXXXXX",
    roles_crafter = "XXXXXXXX",
}

print("========================================")
print("  GENESIS COLONY INSTALLER")
print("========================================")
print("")

-- Create directories
print("Creating directories...")
fs.makeDir("/colony")
fs.makeDir("/colony/lib")
fs.makeDir("/colony/roles")

-- Download files
local success = 0
local failed = 0

for _, file in ipairs(FILES) do
    local code = PASTEBIN_CODES[file.url]
    
    if code == "XXXXXXXX" then
        print("[SKIP] " .. file.path .. " (no pastebin code)")
        failed = failed + 1
    else
        print("[GET]  " .. file.path)
        
        if fs.exists(file.path) then
            fs.delete(file.path)
        end
        
        local ok = shell.run("pastebin", "get", code, file.path)
        
        if ok and fs.exists(file.path) then
            success = success + 1
        else
            print("       FAILED!")
            failed = failed + 1
        end
    end
    
    sleep(0.5)  -- Don't spam pastebin
end

print("")
print("========================================")
print("  INSTALLATION COMPLETE")
print("========================================")
print("")
print("Downloaded: " .. success .. " files")
print("Failed: " .. failed .. " files")
print("")

if failed == 0 then
    print("Setting up startup...")
    
    -- Create startup file
    local f = fs.open("/startup.lua", "w")
    f.write('shell.run("/colony/startup.lua")')
    f.close()
    
    print("")
    print("SUCCESS! Reboot to start the colony.")
    print("")
    print("Run: reboot")
else
    print("Some files failed to download.")
    print("Check your internet connection and")
    print("make sure pastebin codes are correct.")
end
