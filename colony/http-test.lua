-- Quick HTTP test for CC:Tweaked
-- Run this on your turtle to test HTTP access

print("=== HTTP TEST ===")
print("")

if not http then
    print("ERROR: HTTP API is disabled!")
    print("")
    print("Fix: Edit computercraft-server.toml")
    print("Set: enabled = true")
    return
end

print("[OK] HTTP API enabled")
print("")

-- Test URLs
local tests = {
    {"GitHub Raw", "https://raw.githubusercontent.com/bradley200813/minecraft/main/colony/version.txt"},
    {"GitHub API", "https://api.github.com"},
    {"Pastebin", "https://pastebin.com"},
    {"Google", "https://www.google.com"},
}

for _, test in ipairs(tests) do
    write(test[1] .. ": ")
    local ok, err = pcall(function()
        local r = http.get(test[2])
        if r then
            print("OK (" .. #r.readAll() .. " bytes)")
            r.close()
        else
            print("BLOCKED")
        end
    end)
    if not ok then
        print("ERROR: " .. tostring(err))
    end
end

print("")
print("If GitHub is blocked, add to computercraft-server.toml:")
print("")
print('[[http.rules]]')
print('host = "raw.githubusercontent.com"')
print('action = "allow"')
print("")
print('[[http.rules]]')
print('host = "*.github.com"')
print('action = "allow"')
