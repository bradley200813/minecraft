-- ============================================
-- GENESIS COLONY - GITHUB INSTALLER
-- ============================================
-- Downloads all colony files from GitHub
--
-- HOW TO USE:
-- 1. Upload this file to pastebin.com
-- 2. In Minecraft on turtle: pastebin get XXXXX install
-- 3. Run: install

-- ===========================================
-- CONFIGURE YOUR GITHUB REPO HERE
-- ===========================================
local GITHUB_USER = "bradley200813"  -- Your GitHub username
local GITHUB_REPO = "minecraft"      -- Your repo name  
local BRANCH = "main"                -- or "master"
-- ===========================================

local BASE = "https://raw.githubusercontent.com/"..GITHUB_USER.."/"..GITHUB_REPO.."/"..BRANCH.."/colony/"

print("========================================")
print("  GENESIS COLONY - GITHUB INSTALLER")
print("========================================")
print("")

-- Check HTTP
if not http then
    print("[ERROR] HTTP is disabled!")
    print("")
    print("Edit computercraft-server.toml:")
    print("  [[http.rules]]")
    print('  host = "*"')
    print('  action = "allow"')
    return
end

-- Test connection
print("Testing GitHub connection...")
local test = http.get(BASE.."config.lua")
if not test then
    print("[ERROR] Cannot reach GitHub!")
    print("")
    print("Check your settings:")
    print("  GITHUB_USER = "..GITHUB_USER)
    print("  GITHUB_REPO = "..GITHUB_REPO)
    print("  BRANCH = "..BRANCH)
    print("")
    print("Make sure the repo is PUBLIC")
    return
else
    test.close()
    print("[OK] GitHub reachable")
end

-- Create directories
fs.makeDir("/colony")
fs.makeDir("/colony/lib")
fs.makeDir("/colony/roles")
print("[OK] Directories created")
print("")

-- Download function
local function get(path)
    local url = BASE..path
    local dest = "/colony/"..path
    
    write("  "..path.." ")
    
    local r = http.get(url)
    if r then
        local c = r.readAll()
        r.close()
        
        if c and #c > 0 then
            local f = fs.open(dest, "w")
            if f then
                f.write(c)
                f.close()
                print("OK ("..#c.." bytes)")
                return true
            end
        end
    end
    
    print("FAILED")
    return false
end

-- Files to download
local files = {
    "config.lua",
    "lib/state.lua",
    "lib/nav.lua",
    "lib/inv.lua",
    "lib/comms.lua",
    "lib/reporter.lua",
    "roles/miner.lua",
    "roles/crafter.lua",
    "brain.lua",
    "startup.lua",
    "eve.lua",
    "test.lua",
    "bridge.lua",
}

print("Downloading "..#files.." files...")
print("")

local ok = 0
local fail = 0

for _, f in ipairs(files) do
    if get(f) then ok = ok + 1 else fail = fail + 1 end
end

print("")
print("========================================")
if fail == 0 then
    print("  SUCCESS! All files downloaded")
else
    print("  WARNING: "..fail.." files failed")
end
print("========================================")
print("")
print("NEXT STEPS:")
print("  label set Eve-1")
print("  refuel all") 
print("  /colony/eve")
print("")
