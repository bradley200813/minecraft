/**
 * Colony Bridge Server
 * ====================
 * Bridges CC:Tweaked turtles to your web browser in real-time!
 * 
 * Run: node server.js
 * Then open: http://localhost:3000
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;
const WS_PORT = 3001;

// Colony state
let colonyData = {
    name: "Genesis",
    lastUpdate: Date.now(),
    turtles: {},
    events: [],
    stats: {
        totalBlocksMined: 0,
        totalTurtlesBorn: 0,
    }
};

// Connected WebSocket clients
let wsClients = [];

// Simple WebSocket server (no dependencies needed)
const wsServer = http.createServer();
wsServer.on('upgrade', (req, socket) => {
    // WebSocket handshake
    const key = req.headers['sec-websocket-key'];
    const hash = require('crypto')
        .createHash('sha1')
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
    sendToClient(socket, { type: 'init', data: colonyData });
    
    socket.on('close', () => {
        wsClients = wsClients.filter(c => c !== socket);
        console.log(`[WS] Client disconnected (${wsClients.length} remaining)`);
    });
    
    socket.on('error', () => {
        wsClients = wsClients.filter(c => c !== socket);
    });
});

function sendToClient(socket, data) {
    try {
        const json = JSON.stringify(data);
        const length = Buffer.byteLength(json);
        let frame;
        
        if (length < 126) {
            frame = Buffer.alloc(2 + length);
            frame[0] = 0x81; // text frame
            frame[1] = length;
            Buffer.from(json).copy(frame, 2);
        } else if (length < 65536) {
            frame = Buffer.alloc(4 + length);
            frame[0] = 0x81;
            frame[1] = 126;
            frame.writeUInt16BE(length, 2);
            Buffer.from(json).copy(frame, 4);
        } else {
            frame = Buffer.alloc(10 + length);
            frame[0] = 0x81;
            frame[1] = 127;
            frame.writeBigUInt64BE(BigInt(length), 2);
            Buffer.from(json).copy(frame, 10);
        }
        
        socket.write(frame);
    } catch (e) {
        // Client disconnected
    }
}

function broadcast(data) {
    wsClients.forEach(client => sendToClient(client, data));
}

// HTTP Server for both API and static files
const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://localhost:${PORT}`);
    
    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    // API: Receive updates from CC:Tweaked
    if (url.pathname === '/api/update' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const data = JSON.parse(body);
                handleTurtleUpdate(data);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true }));
            } catch (e) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: e.message }));
            }
        });
        return;
    }
    
    // API: Get current state
    if (url.pathname === '/api/status') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(colonyData));
        return;
    }
    
    // Serve static files
    let filePath = url.pathname === '/' ? '/index.html' : url.pathname;
    filePath = path.join(__dirname, filePath);
    
    const ext = path.extname(filePath);
    const contentTypes = {
        '.html': 'text/html',
        '.js': 'text/javascript',
        '.css': 'text/css',
        '.json': 'application/json',
    };
    
    fs.readFile(filePath, (err, content) => {
        if (err) {
            // Serve the dashboard HTML for any route
            fs.readFile(path.join(__dirname, 'live.html'), (err2, html) => {
                if (err2) {
                    res.writeHead(404);
                    res.end('Not found');
                } else {
                    res.writeHead(200, { 'Content-Type': 'text/html' });
                    res.end(html);
                }
            });
        } else {
            res.writeHead(200, { 'Content-Type': contentTypes[ext] || 'text/plain' });
            res.end(content);
        }
    });
});

// Handle turtle updates
function handleTurtleUpdate(data) {
    const now = Date.now();
    colonyData.lastUpdate = now;
    
    if (data.type === 'heartbeat' || data.type === 'status') {
        const turtle = data.turtle || data;
        const id = turtle.id;
        
        const isNew = !colonyData.turtles[id];
        
        colonyData.turtles[id] = {
            id: id,
            label: turtle.label || `Turtle-${id}`,
            role: turtle.role || 'worker',
            position: turtle.position || { x: 0, y: 0, z: 0 },
            fuel: turtle.fuel || 0,
            fuelLimit: turtle.fuelLimit || 20000,
            state: turtle.state || 'idle',
            generation: turtle.generation || 0,
            lastSeen: now,
        };
        
        if (isNew) {
            addEvent('birth', `${turtle.label || id} joined the colony`);
            colonyData.stats.totalTurtlesBorn++;
        }
        
        broadcast({ type: 'turtle', data: colonyData.turtles[id] });
        
    } else if (data.type === 'event') {
        addEvent(data.eventType || 'info', data.message, data.data);
        
    } else if (data.type === 'stats') {
        Object.assign(colonyData.stats, data.stats);
        broadcast({ type: 'stats', data: colonyData.stats });
    }
}

function addEvent(type, message, data = {}) {
    const event = {
        time: Date.now(),
        type,
        message,
        data,
    };
    
    colonyData.events.unshift(event);
    colonyData.events = colonyData.events.slice(0, 100);
    
    broadcast({ type: 'event', data: event });
    console.log(`[EVENT] ${type}: ${message}`);
}

// Start servers
server.listen(PORT, () => {
    console.log('');
    console.log('🐢 ═══════════════════════════════════════════');
    console.log('   GENESIS COLONY BRIDGE SERVER');
    console.log('═══════════════════════════════════════════════');
    console.log('');
    console.log(`   Dashboard:  http://localhost:${PORT}`);
    console.log(`   WebSocket:  ws://localhost:${WS_PORT}`);
    console.log(`   API:        http://localhost:${PORT}/api/update`);
    console.log('');
    console.log('   Waiting for turtles to connect...');
    console.log('═══════════════════════════════════════════════');
    console.log('');
});

wsServer.listen(WS_PORT, () => {
    console.log(`[WS] WebSocket server running on port ${WS_PORT}`);
});

// Cleanup stale turtles every 30 seconds
setInterval(() => {
    const now = Date.now();
    const staleThreshold = 60000; // 1 minute
    
    for (const id in colonyData.turtles) {
        if (now - colonyData.turtles[id].lastSeen > staleThreshold) {
            console.log(`[STALE] Turtle ${id} marked offline`);
        }
    }
}, 30000);
