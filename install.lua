-- GENESIS COLONY INSTALLER - ALL IN ONE
-- Just paste this and run. No downloads needed!
print("========================================")
print("  GENESIS COLONY - INSTALLER")
print("========================================")
fs.makeDir("/colony")
fs.makeDir("/colony/lib")
fs.makeDir("/colony/roles")
print("Created directories")

local function w(path, content)
    local f = fs.open(path, "w")
    if f then f.write(content); f.close(); print("  + "..path); return true end
    print("  ! "..path); return false
end

-- LIB/STATE
w("/colony/lib/state.lua", [[
local S = {}
local file = "/.colony/state.json"
local data = {}
function S.load()
    if fs.exists(file) then
        local f = fs.open(file, "r")
        if f then data = textutils.unserializeJSON(f.readAll()) or {}; f.close() end
    end
    return data
end
function S.save()
    if not fs.exists("/.colony") then fs.makeDir("/.colony") end
    local f = fs.open(file, "w")
    if f then f.write(textutils.serializeJSON(data)); f.close() end
end
function S.get(k)
    if not k then return data end
    local v = data
    for p in k:gmatch("[^.]+") do if type(v)~="table" then return nil end; v=v[p] end
    return v
end
function S.set(k, val)
    local ps = {}
    for p in k:gmatch("[^.]+") do table.insert(ps, p) end
    local t = data
    for i=1,#ps-1 do if type(t[ps[i]])~="table" then t[ps[i]]={} end; t=t[ps[i]] end
    t[ps[#ps]] = val
    S.save()
end
return S
]])

-- LIB/NAV
w("/colony/lib/nav.lua", [[
local N = {}
local pos = {x=0,y=0,z=0}
local facing = 0
local home = {x=0,y=0,z=0}
local D = {{x=0,z=-1},{x=1,z=0},{x=0,z=1},{x=-1,z=0}}
function N.init() if gps then local x,y,z=gps.locate(2); if x then pos={x=x,y=y,z=z} end end end
function N.getPosition() return {x=pos.x,y=pos.y,z=pos.z} end
function N.getFacing() return facing end
function N.setHome(p) home = p or {x=pos.x,y=pos.y,z=pos.z} end
function N.getHome() return home end
function N.forward() if turtle.forward() then pos.x=pos.x+D[facing+1].x; pos.z=pos.z+D[facing+1].z; return true end return false end
function N.back() if turtle.back() then pos.x=pos.x-D[facing+1].x; pos.z=pos.z-D[facing+1].z; return true end return false end
function N.up() if turtle.up() then pos.y=pos.y+1; return true end return false end
function N.down() if turtle.down() then pos.y=pos.y-1; return true end return false end
function N.turnLeft() turtle.turnLeft(); facing=(facing-1)%4 end
function N.turnRight() turtle.turnRight(); facing=(facing+1)%4 end
function N.face(d) while facing~=d do N.turnRight() end end
function N.digForward() while turtle.detect() do turtle.dig(); sleep(0.3) end return N.forward() end
function N.digUp() while turtle.detectUp() do turtle.digUp(); sleep(0.3) end return N.up() end
function N.digDown() turtle.digDown(); return N.down() end
function N.goTo(tx,ty,tz)
    while pos.y<ty do if not N.digUp() then break end end
    while pos.y>ty do if not N.digDown() then break end end
    while pos.x<tx do N.face(1); if not N.digForward() then break end end
    while pos.x>tx do N.face(3); if not N.digForward() then break end end
    while pos.z<tz do N.face(2); if not N.digForward() then break end end
    while pos.z>tz do N.face(0); if not N.digForward() then break end end
end
function N.goHome() N.goTo(home.x,home.y,home.z) end
return N
]])

-- LIB/INV
w("/colony/lib/inv.lua", [[
local I = {}
local FUEL = {["minecraft:coal"]=80,["minecraft:charcoal"]=80,["minecraft:coal_block"]=800}
local ORES = {"diamond","emerald","gold","iron","copper","redstone","lapis","coal"}
local TRASH = {"cobblestone","dirt","gravel","netherrack","cobbled_deepslate","tuff","granite","diorite","andesite"}
function I.isFuel(n) return FUEL[n]~=nil end
function I.isOre(n) for _,o in ipairs(ORES) do if n:find(o) then return true end end return false end
function I.isTrash(n) for _,t in ipairs(TRASH) do if n:find(t) then return true end end return false end
function I.freeSlots() local c=0; for i=1,16 do if turtle.getItemCount(i)==0 then c=c+1 end end return c end
function I.isFull() return I.freeSlots()==0 end
function I.refuel(min)
    min=min or 1000
    while turtle.getFuelLevel()<min do
        local found=false
        for i=1,16 do local it=turtle.getItemDetail(i); if it and I.isFuel(it.name) then turtle.select(i); if turtle.refuel(1) then found=true; break end end end
        if not found then break end
    end
    turtle.select(1); return turtle.getFuelLevel()
end
function I.dropTrash() for i=1,16 do local it=turtle.getItemDetail(i); if it and I.isTrash(it.name) then turtle.select(i); turtle.drop() end end turtle.select(1) end
function I.dumpToChest() for i=1,16 do if turtle.getItemCount(i)>0 then turtle.select(i); turtle.drop() end end turtle.select(1) end
function I.countItem(n) local c=0; for i=1,16 do local it=turtle.getItemDetail(i); if it and it.name:find(n) then c=c+it.count end end return c end
function I.findItem(n) for i=1,16 do local it=turtle.getItemDetail(i); if it and it.name:find(n) then return i end end return nil end
return I
]])

-- LIB/COMMS
w("/colony/lib/comms.lua", [[
local C = {}
local proto = "COLONY"
C.MSG = {PING="ping",PONG="pong",HELLO="hello",HEARTBEAT="heartbeat"}
function C.hasModem() for _,s in ipairs({"top","bottom","left","right","front","back"}) do if peripheral.getType(s)=="modem" then return true,s end end return false end
function C.open() local h,s=C.hasModem(); if h then rednet.open(s); return true end return false end
function C.broadcast(t,d) rednet.broadcast({type=t,data=d,from=os.getComputerID()},proto) end
function C.send(id,t,d) rednet.send(id,{type=t,data=d,from=os.getComputerID()},proto) end
function C.receive(to) return rednet.receive(proto,to or 1) end
function C.announce(e,d) C.broadcast(C.MSG.HELLO,{event=e,label=os.getComputerLabel() or ("T-"..os.getComputerID()),data=d}) end
function C.setupDefaultHandlers() end
return C
]])

-- LIB/REPORTER
w("/colony/lib/reporter.lua", [[
local R = {}
local Nav,Inv,State,Comms
function R.init(n,i,s,c) Nav=n;Inv=i;State=s;Comms=c end
function R.buildReport()
    return {id=os.getComputerID(),label=os.getComputerLabel() or ("T-"..os.getComputerID()),
        role=State and State.get("role") or "?",generation=State and State.get("generation") or 0,
        position=Nav and Nav.getPosition() or {x=0,y=0,z=0},fuel=turtle.getFuelLevel(),
        fuelLimit=turtle.getFuelLimit(),state=State and State.get("currentState") or "idle"}
end
function R.heartbeat() if Comms then Comms.broadcast("heartbeat",R.buildReport()) end end
function R.startReporting() while true do R.heartbeat(); sleep(5) end end
function R.runParallel(fn) parallel.waitForAll(fn,R.startReporting) end
return R
]])

-- ROLES/MINER
w("/colony/roles/miner.lua", [[
local M = {}
local Nav,Inv,State,Comms
local cfg = {branchLength=20,branchSpacing=3,minFuel=300}
M.PATTERNS = {BRANCH="branch",TUNNEL="tunnel"}
function M.init(n,i,s,c) Nav=n;Inv=i;State=s;Comms=c end
function M.shouldReturn() if Inv.isFull() then return true,"full" end if turtle.getFuelLevel()<cfg.minFuel then return true,"fuel" end return false end
function M.mineBranch(len)
    len=len or cfg.branchLength; local mined=0
    for i=1,len do
        local r,why=M.shouldReturn()
        if r then Nav.goHome(); if why=="full" then Inv.dumpToChest() else Inv.refuel(1000) end return mined end
        if not Nav.digForward() then break end
        Nav.digUp(); mined=mined+2
    end
    return mined
end
function M.run(pat)
    pat=pat or M.PATTERNS.BRANCH; print("[MINER] "..pat); local total=0
    if pat==M.PATTERNS.BRANCH then
        for b=1,10 do
            total=total+M.mineBranch()
            Nav.turnRight();Nav.turnRight()
            for i=1,cfg.branchLength do Nav.forward() end
            Nav.turnRight();Nav.turnRight();Nav.turnRight()
            for i=1,cfg.branchSpacing do Nav.digForward() end
            Nav.turnLeft()
        end
    else total=M.mineBranch(100) end
    Nav.goHome(); return total
end
return M
]])

-- ROLES/CRAFTER
w("/colony/roles/crafter.lua", [[
local C = {}
local Nav,Inv,State,Comms
function C.init(n,i,s,c) Nav=n;Inv=i;State=s;Comms=c end
function C.canCraftTurtle() return Inv.countItem("iron_ingot")>=7 and Inv.countItem("redstone")>=1 and Inv.countItem("diamond")>=3 end
function C.birthTurtle()
    local s=Inv.findItem("turtle")
    if s then turtle.select(s);turtle.place();peripheral.call("front","turnOn");sleep(2);return true end
    return false
end
return C
]])

-- BRAIN
w("/colony/brain.lua", [[
local B = {}
local Nav,Inv,State,Comms,Miner,Crafter
local running=false
function B.init(n,i,s,c,m,cr) Nav=n;Inv=i;State=s;Comms=c;Miner=m;Crafter=cr end
function B.assess()
    local d={}
    if turtle.getFuelLevel()<100 then table.insert(d,{p=100,a="refuel"}) end
    if Inv.isFull() then table.insert(d,{p=90,a="dump"}) end
    if Crafter and Crafter.canCraftTurtle() then table.insert(d,{p=80,a="birth"}) end
    table.insert(d,{p=50,a="mine"})
    table.sort(d,function(a,b) return a.p>b.p end)
    return d[1]
end
function B.execute(dec)
    State.set("currentState",dec.a)
    if dec.a=="refuel" then Nav.goHome();Inv.refuel(1000)
    elseif dec.a=="dump" then Nav.goHome();Inv.dropTrash();Inv.dumpToChest()
    elseif dec.a=="birth" then Nav.goHome();Crafter.birthTurtle()
    elseif dec.a=="mine" then Miner.run() end
    State.set("currentState","idle")
end
function B.run() running=true; while running do local d=B.assess();print("[BRAIN] "..d.a);B.execute(d);sleep(1) end end
function B.stop() running=false end
return B
]])

-- STARTUP
w("/colony/startup.lua", [[
print("=== GENESIS COLONY ===")
local function ld(p) if fs.exists(p..".lua") then return dofile(p..".lua") elseif fs.exists(p) then return dofile(p) else error("Missing: "..p) end end
local State=ld("/colony/lib/state")
local Nav=ld("/colony/lib/nav")
local Inv=ld("/colony/lib/inv")
local Comms=ld("/colony/lib/comms")
local Reporter=ld("/colony/lib/reporter")
local Miner=ld("/colony/roles/miner")
local Crafter=ld("/colony/roles/crafter")
local Brain=ld("/colony/brain")
local function getId()
    if fs.exists("/.colony/state.json") then
        local f=fs.open("/.colony/state.json","r")
        if f then local d=textutils.unserializeJSON(f.readAll());f.close();if d then return d.role or "worker",d.generation or 0 end end
    end
    local l=os.getComputerLabel() or ""
    if l:find("Eve") then return "eve",0 end
    return "newborn",-1
end
local role,gen=getId(); print("Role: "..role)
State.load();Nav.init()
if Comms.hasModem() then Comms.open();print("[OK] Modem") end
Reporter.init(Nav,Inv,State,Comms)
Miner.init(Nav,Inv,State,Comms)
Crafter.init(Nav,Inv,State,Comms)
Brain.init(Nav,Inv,State,Comms,Miner,Crafter)
if role=="eve" then dofile("/colony/eve.lua")
else
    if role=="newborn" then State.set("role","worker");State.set("generation",1);os.setComputerLabel("Worker-"..os.getComputerID());Nav.setHome() end
    Reporter.runParallel(function() Brain.run() end)
end
]])

-- EVE
w("/colony/eve.lua", [[
print("=== EVE ===")
local function ld(p) if fs.exists(p..".lua") then return dofile(p..".lua") else return dofile(p) end end
local State=ld("/colony/lib/state")
local Nav=ld("/colony/lib/nav")
local Inv=ld("/colony/lib/inv")
local Comms=ld("/colony/lib/comms")
local Reporter=ld("/colony/lib/reporter")
local Miner=ld("/colony/roles/miner")
local Crafter=ld("/colony/roles/crafter")
local Brain=ld("/colony/brain")
State.load();State.set("role","eve");State.set("generation",0)
Nav.init();Nav.setHome()
if Comms.hasModem() then Comms.open();Comms.announce("eve_online");print("[OK] Modem") end
Reporter.init(Nav,Inv,State,Comms)
Miner.init(Nav,Inv,State,Comms)
Crafter.init(Nav,Inv,State,Comms)
Brain.init(Nav,Inv,State,Comms,Miner,Crafter)
while true do
    print("\n=== MENU ===")
    print("1.Auto 2.Mine 3.Home 4.Fuel 5.Status 6.Test 0.Exit")
    write("> ");local c=read()
    if c=="1" then Reporter.runParallel(function() Brain.run() end)
    elseif c=="2" then print("Mined: "..Miner.run())
    elseif c=="3" then Nav.goHome();print("Home!")
    elseif c=="4" then print("Fuel: "..Inv.refuel(1000))
    elseif c=="5" then print("ID:"..os.getComputerID().." Fuel:"..turtle.getFuelLevel())
    elseif c=="6" then for i=1,3 do Reporter.heartbeat();print("Sent "..i);sleep(1) end
    elseif c=="0" then return end
end
]])

-- TEST
w("/colony/test.lua", [[
print("=== TEST ===")
local m=nil
for _,s in ipairs({"top","bottom","left","right","front","back"}) do if peripheral.getType(s)=="modem" then m=s;break end end
if m then print("[OK] Modem: "..m);rednet.open(m) else print("[ERROR] No modem!");return end
print("ID: "..os.getComputerID())
print("Label: "..(os.getComputerLabel() or "NOT SET"))
print("Sending 5 broadcasts...")
for i=1,5 do
    rednet.broadcast({type="heartbeat",data={id=os.getComputerID(),label=os.getComputerLabel() or "Test",role="eve",position={x=0,y=64,z=0},fuel=turtle.getFuelLevel(),fuelLimit=turtle.getFuelLimit(),state="testing",generation=0}},"COLONY")
    print("Sent "..i);sleep(2)
end
print("Done!")
]])

-- BRIDGE (configurable URL)
w("/colony/bridge.lua", [[
-- CONFIGURE THIS: Your computer's IP where Node.js runs
-- For local testing: "http://localhost:3000/api/update"
-- For remote server: "http://YOUR_EXTERNAL_IP:3000/api/update"
local URL = "http://localhost:3000/api/update"

print("=== COLONY BRIDGE ===")
print("Dashboard URL: "..URL)
print("")

-- Find modem
local m = nil
for _,s in ipairs({"top","bottom","left","right","front","back"}) do 
    if peripheral.getType(s) == "modem" then m = s; break end 
end
if not m then print("[ERROR] Attach a modem!"); return end
print("[OK] Modem: "..m)
rednet.open(m)

-- Check HTTP
if not http then 
    print("[ERROR] HTTP is disabled!")
    print("Enable in computercraft-server.toml:")
    print("  [[http.rules]]")
    print("  host = \"*\"")
    print("  action = \"allow\"")
    return 
end
print("[OK] HTTP enabled")
print("")
print("Listening for colony broadcasts...")
print("Press Ctrl+T to stop")
print("")

local received = 0
while true do
    local id, msg = rednet.receive("COLONY", 1)
    if id and type(msg) == "table" then
        received = received + 1
        local lbl = msg.data and msg.data.label or ("ID:"..id)
        local msgType = msg.type or "?"
        print(string.format("[%s] #%d %s: %s", os.date("%H:%M:%S"), received, lbl, msgType))
        
        local ok, err = pcall(function() 
            local payload = textutils.serializeJSON({type = msg.type, turtle = msg.data})
            local response = http.post(URL, payload, {["Content-Type"] = "application/json"})
            if response then 
                response.close()
                print("  -> sent to dashboard")
            else
                print("  [!] No response from server")
            end
        end)
        
        if not ok then
            print("  [!] HTTP Error: "..(err or "unknown"))
        end
    end
end
]])

print("\n========================================")
print("  DONE! Files in /colony/")
print("========================================")
print("\nNext: label set Eve-1")
print("      refuel all")
print("      /colony/eve")
