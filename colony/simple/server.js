/**
 * SIMPLE COLONY SERVER
 * ====================
 * Minimal Express-like server for turtle dashboard
 * 
 * Run: node server.js
 * Open: http://localhost:3000
 */

const http = require('http');
const fs = require('fs');
const crypto = require('crypto');

const PORT = 3000;
const WS_PORT = 3001;

// State
let turtles = {};
let commandQueue = [];
let commandId = 1;
let wsClients = [];

// ============================================
// WEBSOCKET SERVER
// ============================================

const wsServer = http.createServer();

wsServer.on('upgrade', (req, socket) => {
    const key = req.headers['sec-websocket-key'];
    const hash = crypto.createHash('sha1')
        .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
        .digest('base64');
    
    socket.write(
        'HTTP/1.1 101 Switching Protocols\r\n' +
        'Upgrade: websocket\r\n' +
        'Connection: Upgrade\r\n' +
        'Sec-WebSocket-Accept: ' + hash + '\r\n\r\n'
    );
    
    wsClients.push(socket);
    console.log(`[WS] Client connected (${wsClients.length} total)`);
    
    // Send current state
    wsSend(socket, { type: 'init', turtles });
    
    socket.on('data', (buffer) => {
        const data = parseWsFrame(buffer, socket);
        if (data) {
            try {
                const msg = JSON.parse(data);
                if (msg.type === 'command') {
                    queueCommand(msg.targetId, msg.command, msg.args);
                }
            } catch(e) {}
        }
    });
    
    socket.on('close', () => {
        wsClients = wsClients.filter(c => c !== socket);
    });
    
    socket.on('error', () => {
        wsClients = wsClients.filter(c => c !== socket);
    });
});

function wsSend(socket, data) {
    try {
        const json = JSON.stringify(data);
        const len = Buffer.byteLength(json);
        let frame;
        
        if (len < 126) {
            frame = Buffer.alloc(2 + len);
            frame[0] = 0x81;
            frame[1] = len;
            Buffer.from(json).copy(frame, 2);
        } else {
            frame = Buffer.alloc(4 + len);
            frame[0] = 0x81;
            frame[1] = 126;
            frame.writeUInt16BE(len, 2);
            Buffer.from(json).copy(frame, 4);
        }
        
        socket.write(frame);
    } catch(e) {}
}

function broadcast(data) {
    wsClients.forEach(c => wsSend(c, data));
}

function parseWsFrame(buffer, socket) {
    if (buffer.length < 2) return null;
    
    const opcode = buffer[0] & 0x0F;
    if (opcode === 0x9) { // ping
        const pong = Buffer.alloc(2);
        pong[0] = 0x8A;
        pong[1] = 0;
        socket.write(pong);
        return null;
    }
    if (opcode !== 0x1) return null; // only text frames
    
    let len = buffer[1] & 0x7F;
    let offset = 2;
    
    if (len === 126) {
        len = buffer.readUInt16BE(2);
        offset = 4;
    }
    
    const mask = buffer.slice(offset, offset + 4);
    offset += 4;
    
    const payload = buffer.slice(offset, offset + len);
    for (let i = 0; i < payload.length; i++) {
        payload[i] ^= mask[i % 4];
    }
    
    return payload.toString('utf8');
}

wsServer.listen(WS_PORT, () => {
    console.log(`[WS] Running on port ${WS_PORT}`);
});

// ============================================
// HTTP SERVER
// ============================================

function queueCommand(targetId, command, args) {
    const cmd = {
        id: commandId++,
        targetId,
        command,
        args: args || {},
        time: Date.now()
    };
    commandQueue.push(cmd);
    broadcast({ type: 'command_queued', command: cmd });
    console.log(`[CMD] ${command} -> ${targetId}`);
}

const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://localhost:${PORT}`);
    
    // CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }
    
    // API: Get commands for bridge
    if (url.pathname === '/api/commands' && req.method === 'GET') {
        const cmds = commandQueue;
        commandQueue = [];
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ commands: cmds }));
        return;
    }
    
    // API: Turtle update from bridge
    if (url.pathname === '/api/update' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const data = JSON.parse(body);
                if (data.type === 'heartbeat' && data.turtle) {
                    const t = data.turtle;
                    turtles[t.id] = {
                        ...t,
                        lastSeen: Date.now()
                    };
                    broadcast({ type: 'turtle_update', turtle: turtles[t.id] });
                }
            } catch(e) {}
            res.writeHead(200);
            res.end('OK');
        });
        return;
    }
    
    // API: Send command
    if (url.pathname === '/api/command' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const { targetId, command, args } = JSON.parse(body);
                queueCommand(targetId, command, args);
            } catch(e) {}
            res.writeHead(200);
            res.end('OK');
        });
        return;
    }
    
    // API: Get turtles
    if (url.pathname === '/api/turtles') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ turtles: Object.values(turtles) }));
        return;
    }
    
    // Serve dashboard HTML
    if (url.pathname === '/' || url.pathname === '/index.html') {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(DASHBOARD_HTML);
        return;
    }
    
    res.writeHead(404);
    res.end('Not found');
});

server.listen(PORT, () => {
    console.log(`[HTTP] Running on http://localhost:${PORT}`);
    console.log('');
    console.log('Open your browser to see the dashboard!');
    console.log('Waiting for turtles...');
});

// ============================================
// DASHBOARD HTML
// ============================================

const DASHBOARD_HTML = `<!DOCTYPE html>
<html>
<head>
    <title>Colony Dashboard</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: system-ui, sans-serif; background: #1a1a2e; color: #eee; padding: 20px; }
        h1 { color: #4ade80; margin-bottom: 20px; }
        .container { display: flex; gap: 20px; }
        .turtles { flex: 1; }
        .controls { width: 300px; }
        .turtle { background: #16213e; border-radius: 8px; padding: 15px; margin-bottom: 10px; border: 2px solid #0f3460; }
        .turtle.selected { border-color: #4ade80; }
        .turtle h3 { color: #4ade80; margin-bottom: 10px; }
        .turtle .info { font-size: 14px; color: #aaa; }
        .turtle .fuel { margin-top: 5px; }
        .fuel-bar { height: 8px; background: #333; border-radius: 4px; overflow: hidden; margin-top: 3px; }
        .fuel-fill { height: 100%; background: linear-gradient(90deg, #f59e0b, #4ade80); }
        .panel { background: #16213e; border-radius: 8px; padding: 15px; margin-bottom: 10px; }
        .panel h3 { color: #4ade80; margin-bottom: 10px; font-size: 14px; }
        .btn-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 5px; }
        .btn { background: #0f3460; border: none; color: #eee; padding: 10px; border-radius: 5px; cursor: pointer; font-size: 12px; }
        .btn:hover { background: #4ade80; color: #000; }
        .btn.danger { background: #dc2626; }
        .btn.danger:hover { background: #ef4444; color: #fff; }
        .status { font-size: 12px; color: #888; margin-top: 10px; }
        input { background: #0f3460; border: 1px solid #333; color: #eee; padding: 8px; border-radius: 5px; width: 100%; margin-bottom: 10px; }
    </style>
</head>
<body>
    <h1>🐢 Colony Dashboard</h1>
    
    <div class="container">
        <div class="turtles" id="turtles">
            <div class="panel">
                <h3>Waiting for turtles...</h3>
                <p class="info">Make sure bridge.lua is running on a computer in Minecraft</p>
            </div>
        </div>
        
        <div class="controls">
            <div class="panel">
                <h3>Movement</h3>
                <div class="btn-grid">
                    <button class="btn" onclick="cmd('turnLeft')">↶ Left</button>
                    <button class="btn" onclick="cmd('forward')">↑ Fwd</button>
                    <button class="btn" onclick="cmd('turnRight')">↷ Right</button>
                    <button class="btn" onclick="cmd('up')">⬆ Up</button>
                    <button class="btn" onclick="cmd('back')">↓ Back</button>
                    <button class="btn" onclick="cmd('down')">⬇ Down</button>
                </div>
            </div>
            
            <div class="panel">
                <h3>Digging</h3>
                <div class="btn-grid">
                    <button class="btn" onclick="cmd('digUp')">Dig ⬆</button>
                    <button class="btn" onclick="cmd('dig')">Dig →</button>
                    <button class="btn" onclick="cmd('digDown')">Dig ⬇</button>
                </div>
            </div>
            
            <div class="panel">
                <h3>Mining</h3>
                <input type="number" id="quarrySize" value="8" placeholder="Quarry size">
                <div class="btn-grid">
                    <button class="btn" onclick="cmd('quarry', {size: +document.getElementById('quarrySize').value})">Quarry</button>
                    <button class="btn" onclick="cmd('tunnel', {length: 50})">Tunnel</button>
                    <button class="btn danger" onclick="cmd('stop')">STOP</button>
                </div>
            </div>
            
            <div class="panel">
                <h3>Actions</h3>
                <div class="btn-grid">
                    <button class="btn" onclick="cmd('refuel')">Refuel</button>
                    <button class="btn" onclick="cmd('dropTrash')">Drop Trash</button>
                    <button class="btn" onclick="cmd('goHome')">Go Home</button>
                    <button class="btn" onclick="cmd('setHome')">Set Home</button>
                    <button class="btn" onclick="cmd('status')">Status</button>
                    <button class="btn" onclick="cmd('dumpAll')">Dump All</button>
                </div>
            </div>
            
            <div class="status" id="status">Connecting...</div>
        </div>
    </div>

    <script>
        let turtles = {};
        let selected = null;
        let ws;
        
        function connect() {
            const wsUrl = 'ws://' + location.hostname + ':3001';
            ws = new WebSocket(wsUrl);
            
            ws.onopen = () => {
                document.getElementById('status').textContent = 'Connected';
            };
            
            ws.onmessage = (e) => {
                const msg = JSON.parse(e.data);
                
                if (msg.type === 'init') {
                    turtles = msg.turtles || {};
                    render();
                } else if (msg.type === 'turtle_update') {
                    turtles[msg.turtle.id] = msg.turtle;
                    render();
                }
            };
            
            ws.onclose = () => {
                document.getElementById('status').textContent = 'Disconnected - reconnecting...';
                setTimeout(connect, 2000);
            };
        }
        
        function render() {
            const el = document.getElementById('turtles');
            const ids = Object.keys(turtles);
            
            if (ids.length === 0) {
                el.innerHTML = '<div class="panel"><h3>Waiting for turtles...</h3></div>';
                return;
            }
            
            el.innerHTML = ids.map(id => {
                const t = turtles[id];
                const fuelPct = t.fuelLimit ? (t.fuel / t.fuelLimit * 100) : 100;
                const isSelected = selected === id;
                const ago = Math.round((Date.now() - t.lastSeen) / 1000);
                
                return \`
                    <div class="turtle \${isSelected ? 'selected' : ''}" onclick="select('\${id}')">
                        <h3>🐢 \${t.label || 'Turtle-' + id}</h3>
                        <div class="info">
                            ID: \${id} | Pos: \${t.position?.x || 0}, \${t.position?.y || 0}, \${t.position?.z || 0}
                        </div>
                        <div class="fuel">
                            Fuel: \${t.fuel} / \${t.fuelLimit}
                            <div class="fuel-bar"><div class="fuel-fill" style="width: \${fuelPct}%"></div></div>
                        </div>
                        <div class="info" style="margin-top: 5px">
                            Free slots: \${t.freeSlots || '?'} | Last seen: \${ago}s ago
                        </div>
                    </div>
                \`;
            }).join('');
            
            // Auto-select first if none selected
            if (!selected && ids.length > 0) {
                selected = ids[0];
                render();
            }
        }
        
        function select(id) {
            selected = id;
            render();
        }
        
        function cmd(command, args) {
            if (!selected) {
                alert('Select a turtle first!');
                return;
            }
            
            ws.send(JSON.stringify({
                type: 'command',
                targetId: selected,
                command,
                args: args || {}
            }));
            
            document.getElementById('status').textContent = 'Sent: ' + command;
        }
        
        connect();
    </script>
</body>
</html>`;
