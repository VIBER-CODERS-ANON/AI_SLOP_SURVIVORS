const WebSocket = require('ws');
const express = require('express');
const http = require('http');

// Create Express app for health check
const app = express();
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocket.Server({ 
  server,
  path: '/ws'
});

// Store connected clients
const clients = new Set();

// Event statistics
const stats = {
  totalEvents: 0,
  eventTypes: {},
  sessions: {},
  startTime: new Date()
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    clients: clients.size,
    uptime: Date.now() - stats.startTime.getTime(),
    stats: stats
  });
});

// Stats endpoint
app.get('/stats', (req, res) => {
  res.json(stats);
});

// WebSocket connection handler
wss.on('connection', (ws, req) => {
  const clientId = `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  clients.add(ws);
  
  console.log(`🔗 Client connected: ${clientId} (${clients.size} total)`);
  console.log(`   Remote address: ${req.socket.remoteAddress}`);
  
  // Send welcome message
  ws.send(JSON.stringify({
    type: 'server_welcome',
    clientId: clientId,
    timestamp: Date.now(),
    message: 'Connected to A.S.S WebSocket Test Server'
  }));

  // Handle incoming messages
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data.toString());
      handleGameEvent(message, clientId);
    } catch (error) {
      console.error(`❌ Failed to parse message from ${clientId}:`, error);
      console.error(`   Raw data: ${data.toString()}`);
    }
  });

  // Handle client disconnect
  ws.on('close', (code, reason) => {
    clients.delete(ws);
    console.log(`🔌 Client disconnected: ${clientId} (${clients.size} remaining)`);
    console.log(`   Code: ${code}, Reason: ${reason || 'No reason provided'}`);
  });

  // Handle errors
  ws.on('error', (error) => {
    console.error(`⚠️ WebSocket error for ${clientId}:`, error);
  });
});

// Game event handler
function handleGameEvent(event, clientId) {
  const { type, timestamp, channel, data } = event;
  
  // Update statistics
  stats.totalEvents++;
  stats.eventTypes[type] = (stats.eventTypes[type] || 0) + 1;
  
  // Track sessions by channel
  if (channel && !stats.sessions[channel]) {
    stats.sessions[channel] = {
      firstSeen: new Date(timestamp * 1000),
      lastSeen: new Date(timestamp * 1000),
      eventCount: 0
    };
  }
  if (channel) {
    stats.sessions[channel].lastSeen = new Date(timestamp * 1000);
    stats.sessions[channel].eventCount++;
  }

  // Format timestamp for display
  const eventTime = new Date(timestamp * 1000).toLocaleTimeString();
  
  // Log event based on type
  switch (type) {
    case 'session_start':
      console.log(`🎮 [${eventTime}] SESSION START - Channel: ${channel || 'unknown'}`);
      break;
      
    case 'session_end':
      console.log(`🛑 [${eventTime}] SESSION END - Channel: ${channel || 'unknown'}`);
      break;
      
    case 'monster_join':
      console.log(`👹 [${eventTime}] MONSTER JOIN - ${data.username} as ${data.monster_type}`);
      break;
      
    case 'entity_spawned':
      console.log(`🐣 [${eventTime}] ENTITY SPAWNED - ID:${data.enemy_id} ${data.username} (${data.monster_type})`);
      break;
      
    case 'monster_death':
      console.log(`💀 [${eventTime}] MONSTER DEATH - ${data.username}'s ${data.monster_type} killed by ${data.killer} (${data.cause})`);
      break;
      
    case 'monster_power_changed':
      console.log(`⚡ [${eventTime}] MONSTER POWER - ${data.current_power}/${data.threshold}`);
      break;
      
    case 'mxp_granted':
      console.log(`💰 [${eventTime}] MXP GRANTED - +${data.amount} (Total: ${data.total})`);
      break;
      
    case 'mxp_spent':
      console.log(`💸 [${eventTime}] MXP SPENT - ${data.username} spent ${data.amount} on ${data.upgrade_type} (${data.remaining} remaining)`);
      break;
      
    case 'vote_started':
      const options = data.options.map(opt => opt.name).join(', ');
      console.log(`🗳️ [${eventTime}] BOSS VOTE STARTED - Options: ${options} (${data.duration}s)`);
      break;
      
    case 'vote_updated':
      const voteStr = Object.entries(data.votes).map(([boss, votes]) => `${boss}:${votes}`).join(', ');
      console.log(`📊 [${eventTime}] VOTE UPDATE - ${voteStr}`);
      break;
      
    case 'vote_result':
      console.log(`🏆 [${eventTime}] VOTE RESULT - Winner: ${data.winner.display_name || data.winner.name}`);
      break;
      
    case 'boss_spawned':
      console.log(`👑 [${eventTime}] BOSS SPAWNED - ${data.boss_name}`);
      break;
      
    case 'boss_killed':
      console.log(`⚔️ [${eventTime}] BOSS KILLED - ${data.boss_name} defeated by ${data.killer}`);
      break;
      
    case 'player_level_up':
      console.log(`🎉 [${eventTime}] PLAYER LEVEL UP - Level ${data.level}`);
      break;
      
    case 'player_experience_gained':
      console.log(`✨ [${eventTime}] PLAYER XP - +${data.amount} (Total: ${data.total_xp})`);
      break;
      
    case 'player_health_changed':
      console.log(`❤️ [${eventTime}] PLAYER HEALTH - ${Math.round(data.current_health)}/${Math.round(data.max_health)} (${Math.round(data.health_percentage)}%)`);
      break;
      
    case 'player_death':
      console.log(`💀 [${eventTime}] PLAYER DEATH - Killed by ${data.killer} (${data.cause})`);
      break;
      
    case 'evolution':
      console.log(`🧬 [${eventTime}] EVOLUTION - ${data.username}: ${data.old_form} → ${data.new_form} ${data.rarity_type ? `(${data.rarity_type})` : ''}`);
      break;
      
    case 'rarity_assigned':
      console.log(`💎 [${eventTime}] RARITY ASSIGNED - ${data.username} → ${data.rarity_type}`);
      break;
      
    case 'game_paused':
      console.log(`⏸️ [${eventTime}] GAME PAUSED`);
      break;
      
    case 'game_resumed':
      console.log(`▶️ [${eventTime}] GAME RESUMED`);
      break;
      
    case 'game_restart':
      console.log(`🔄 [${eventTime}] GAME RESTART REQUESTED`);
      break;
      
    default:
      console.log(`❓ [${eventTime}] UNKNOWN EVENT - ${type}:`, JSON.stringify(data, null, 2));
      break;
  }
  
  // Broadcast to all connected clients (for potential dashboard/monitoring)
  const broadcastMessage = JSON.stringify({
    type: 'game_event',
    originalEvent: event,
    receivedAt: Date.now(),
    clientId: clientId
  });
  
  clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(broadcastMessage);
    }
  });
}

// Start server
const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`🚀 A.S.S WebSocket Test Server running on port ${PORT}`);
  console.log(`📡 WebSocket endpoint: ws://localhost:${PORT}/ws`);
  console.log(`🔍 Health check: http://localhost:${PORT}/health`);
  console.log(`📊 Statistics: http://localhost:${PORT}/stats`);
  console.log(`⏰ Started at: ${stats.startTime.toLocaleString()}`);
  console.log('');
  console.log('Waiting for game connections...');
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down server...');
  
  // Close all WebSocket connections
  clients.forEach(client => {
    client.close(1000, 'Server shutting down');
  });
  
  // Close server
  server.close(() => {
    console.log('✅ Server closed gracefully');
    process.exit(0);
  });
});

// Error handling
process.on('uncaughtException', (error) => {
  console.error('💥 Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('💥 Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});
