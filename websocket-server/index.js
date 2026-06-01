const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  path: '/ws',
  cors: {
    origin: '*',
  }
});

app.use(cors());
app.use(bodyParser.json());

app.post('/notify-update', (req, res) => {
  const updateData = req.body;
  console.log('Update received:', updateData);
  io.emit('data-updated', updateData);
  res.status(200).send({ status: 'ok' });
});

io.on('connection', (socket) => {
  console.log('A client connected');
  socket.on('disconnect', () => {
    console.log('A client disconnected');
  });
});

const PORT = process.env.WS_PORT || 3000;
server.listen(PORT, '127.0.0.1', () => {
  console.log(`WebSocket server listening on http://127.0.0.1:${PORT}`);
});
