-- ============================================
-- COLONY UPDATER
-- ============================================
-- Smart update system with version checking
--
-- Usage on turtle:
--   update           - Check for updates and download if newer
--   update force     - Force download all files
--   update check     - Just check version without downloading
--   update <file>    - Update specific file (e.g., "update brain.lua")
--
-- One-liner install:
--   wget run https://raw.githubusercontent.com/bradley200813/minecraft/main/colony/update.lua

-- ===========================================
-- CONFIGURE THIS
-- ===========================================
local GITHUB_USER = "bradley200813"
local GITHUB_REPO = "minecraft"
local BRANCH = "main"
-- ===========================================

local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. BRANCH .. "/colony/"
local VERSION_FILE = "/.colony/version"
local CURRENT_VERSION = nil

-- All colony files
local FILES = {
    -- Core (update these first)
    {path = "startup.lua", critical = true},
    {path = "eve.lua", critical = true},
    {path = "brain.lua", critical = true},
    {path = "config.lua", critical = false},
    
    -- Libraries
    {path = "lib/state.lua", critical = true},
    {path = "lib/nav.lua", critical = true},
    {path = "lib/inv.lua", critical = true},
    {path = "lib/comms.lua", critical = true},
    {path = "lib/reporter.lua", critical = true},
    {path = "lib/commander.lua", critical = true},
    
    -- Roles
    {path = "roles/miner.lua", critical = false},
    {path = "roles/crafter.lua", critical = false},
    
    -- Tools
    {path = "test.lua", critical = false},
    {path = "bridge.lua", critical = false},
    {path = "update.lua", critical = false},  -- Self-update!
}

-- ============================================
-- HELPERS
-- ============================================

local function ensureDir(path)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

local function readFile(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local content = f.readAll()
    f.close()
    return content
end

local function writeFile(path, content)
    ensureDir(path)
    local f = fs.open(path, "w")
    if not f then return false end
    f.write(content)
    f.close()
    return true
end

local function getLocalVersion()
    return readFile(VERSION_FILE) or "0"
end

local function setLocalVersion(v)
    ensureDir(VERSION_FILE)
    writeFile(VERSION_FILE, tostring(v))
end

local function httpGet(url)
    local ok, response = pcall(http.get, url)
    if ok and response then
        local content = response.readAll()
        response.close()
        return content
    end
    return nil
end

local function getRemoteVersion()
    local content = httpGet(BASE_URL .. "version.txt")
    if content then
        return content:match("^%s*(.-)%s*$")  -- trim whitespace
    end
    -- Fallback: use commit timestamp or just return "unknown"
    return nil
end

-- ============================================
-- UPDATE FUNCTIONS
-- ============================================

local function downloadFile(remotePath, localPath)
    local url = BASE_URL .. remotePath
    localPath = localPath or ("/colony/" .. remotePath)
    
    local content = httpGet(url)
    if content then
        -- Backup existing file
        if fs.exists(localPath) then
            local backupPath = localPath .. ".bak"
            if fs.exists(backupPath) then fs.delete(backupPath) end
            fs.copy(localPath, backupPath)
        end
        
        if writeFile(localPath, content) then
            return true, #content
        end
    end
    return false, 0
end

local function checkForUpdates()
    print("Checking for updates...")
    
    local local_v = getLocalVersion()
    local remote_v = getRemoteVersion()
    
    print("  Local version:  " .. local_v)
    print("  Remote version: " .. (remote_v or "unknown"))
    
    if remote_v and remote_v ~= local_v then
        return true, remote_v
    elseif remote_v == nil then
        return nil, "Could not check remote version"
    else
        return false, local_v
    end
end

local function updateAll(force)
    print("")
    print("========================================")
    print("  GENESIS COLONY UPDATER")
    print("========================================")
    print("")
    print("Repo: " .. GITHUB_USER .. "/" .. GITHUB_REPO)
    print("Branch: " .. BRANCH)
    print("")
    
    if not http then
        print("ERROR: HTTP API not enabled!")
        return false
    end
    
    if not force then
        local hasUpdate, info = checkForUpdates()
        if hasUpdate == false then
            print("")
            print("Already up to date! (v" .. info .. ")")
            print("Use 'update force' to force re-download.")
            return true
        elseif hasUpdate == nil then
            print("Warning: " .. info)
            print("Continuing anyway...")
        else
            print("")
            print("Update available: v" .. info)
        end
    else
        print("Force update mode - downloading all files...")
    end
    
    print("")
    
    -- Create directories
    fs.makeDir("/colony")
    fs.makeDir("/colony/lib")
    fs.makeDir("/colony/roles")
    fs.makeDir("/.colony")
    
    -- Download files
    local success = 0
    local failed = 0
    local failedFiles = {}
    
    for _, file in ipairs(FILES) do
        write("[" .. (file.critical and "*" or " ") .. "] " .. file.path .. " ")
        
        local ok, size = downloadFile(file.path)
        
        if ok then
            print("OK (" .. size .. "b)")
            success = success + 1
        else
            print("FAILED")
            failed = failed + 1
            table.insert(failedFiles, file.path)
        end
        
        sleep(0.05)  -- Small delay to not hammer the server
    end
    
    print("")
    print("========================================")
    print("  Downloaded: " .. success .. "/" .. #FILES .. " files")
    print("========================================")
    
    if failed > 0 then
        print("")
        print("Failed files:")
        for _, f in ipairs(failedFiles) do
            print("  - " .. f)
        end
    end
    
    -- Update version
    local remote_v = getRemoteVersion()
    if remote_v then
        setLocalVersion(remote_v)
        print("")
        print("Updated to version: " .. remote_v)
    else
        -- Use timestamp as version
        setLocalVersion(os.epoch("utc"))
    end
    
    print("")
    print("Reboot to apply changes? (y/n)")
    local input = read()
    if input == "y" or input == "Y" then
        os.reboot()
    end
    
    return success > 0
end

local function updateSingleFile(filename)
    print("Updating: " .. filename)
    
    -- Find the file in our list
    local found = nil
    for _, file in ipairs(FILES) do
        if file.path == filename or file.path:match("[^/]+$") == filename then
            found = file
            break
        end
    end
    
    if not found then
        -- Try direct path anyway
        found = {path = filename}
        print("Warning: File not in manifest, trying anyway...")
    end
    
    local ok, size = downloadFile(found.path)
    if ok then
        print("Success! Downloaded " .. size .. " bytes")
        return true
    else
        print("Failed to download " .. found.path)
        return false
    end
end

-- ============================================
-- MAIN
-- ============================================

local args = {...}
local command = args[1]

if command == "check" then
    local hasUpdate, info = checkForUpdates()
    if hasUpdate == true then
        print("Update available: v" .. info)
    elseif hasUpdate == false then
        print("Up to date (v" .. info .. ")")
    else
        print("Could not check: " .. info)
    end
    
elseif command == "force" then
    updateAll(true)
    
elseif command and command ~= "" then
    -- Treat as filename
    updateSingleFile(command)
    
else
    updateAll(false)
end
