-- ============================================
-- GITHUB INSTALLER FOR CC:TWEAKED
-- ============================================
-- Downloads colony files directly from your GitHub repo
--
-- SETUP:
-- 1. Push your minecraft folder to GitHub
-- 2. Edit REPO below with your username/repo
-- 3. Run: pastebin get <code> install
--    Or:  wget https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/colony/github-install.lua install
-- 4. Run: install

-- ===========================================
-- CONFIGURE THIS WITH YOUR GITHUB INFO
-- ===========================================
local GITHUB_USER = "bradley200813"
local GITHUB_REPO = "minecraft"
local BRANCH = "main"
-- ===========================================

local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. BRANCH .. "/colony/"

-- Files to download
local FILES = {
    -- Config
    "config.lua",
    
    -- Libraries
    "lib/state.lua",
    "lib/nav.lua",
    "lib/inv.lua",
    "lib/comms.lua",
    "lib/reporter.lua",
    "lib/commander.lua",
    
    -- Roles
    "roles/miner.lua",
    "roles/crafter.lua",
    
    -- Core
    "brain.lua",
    "startup.lua",
    "eve.lua",
    
    -- Tools
    "test.lua",
    "bridge.lua",
    "update.lua",
    
    -- Version tracking
    "version.txt",
}

-- Optional files (won't fail if missing)
local OPTIONAL = {
    "dashboard/server.lua",
    "dashboard/monitor.lua",
    "dashboard/bridge/sender.lua",
}

print("========================================")
print("  GENESIS COLONY - GITHUB INSTALLER")
print("========================================")
print("")
print("Repo: " .. GITHUB_USER .. "/" .. GITHUB_REPO)
print("Branch: " .. BRANCH)
print("")

-- Check HTTP is enabled
if not http then
    print("ERROR: HTTP API not enabled!")
    print("")
    print("Ask the server admin to edit:")
    print("  config/computercraft-server.toml")
    print("")
    print("Add:")
    print('  [[http.rules]]')
    print('  host = "*"')
    print('  action = "allow"')
    return
end

-- Create directories
local function ensureDir(path)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

-- Download a file
local function download(remotePath, localPath)
    local url = BASE_URL .. remotePath
    localPath = localPath or ("/colony/" .. remotePath)
    
    ensureDir(localPath)
    
    local response, err = http.get(url)
    
    if response then
        local content = response.readAll()
        response.close()
        
        local file = fs.open(localPath, "w")
        if file then
            file.write(content)
            file.close()
            return true
        end
    end
    
    return false, err
end

-- Download all files
print("Downloading files...")
print("")

local success = 0
local failed = 0

for _, file in ipairs(FILES) do
    write("  " .. file .. " ... ")
    local ok, err = download(file)
    if ok then
        print("OK")
        success = success + 1
    else
        print("FAILED")
        failed = failed + 1
    end
end

-- Try optional files
print("")
print("Optional files...")
for _, file in ipairs(OPTIONAL) do
    write("  " .. file .. " ... ")
    local ok = download(file)
    if ok then
        print("OK")
        success = success + 1
    else
        print("skipped")
    end
end

print("")
print("========================================")
if failed == 0 then
    print("  INSTALLATION COMPLETE!")
else
    print("  INSTALLED WITH WARNINGS")
    print("  " .. failed .. " files failed")
end
print("========================================")
print("")
print("Downloaded: " .. success .. " files")
print("")
print("NEXT STEPS:")
print("  1. label set Eve-1")
print("  2. Put fuel in inventory")
print("  3. refuel all")
print("  4. /colony/eve")
print("")
print("========================================")
