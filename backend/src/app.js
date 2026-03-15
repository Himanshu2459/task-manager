const express = require('express');
const cors = require('cors');
const client = require('prom-client');

const app = express();

// ─── Middleware ───────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ─── Prometheus Metrics Setup ─────────────────────────────────
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route'],
  registers: [register],
});

// Middleware to track every request
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer({ method: req.method, route: req.path });
  res.on('finish', () => {
    httpRequestCounter.inc({ method: req.method, route: req.path, status: res.statusCode });
    end();
  });
  next();
});

// ─── In-Memory Task Store ─────────────────────────────────────
let tasks = [];
let nextId = 1;

// ─── Routes ───────────────────────────────────────────────────

// Health check — used by the CI/CD pipeline rollback system
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// GET all tasks
app.get('/tasks', (req, res) => {
  res.json({ success: true, count: tasks.length, tasks });
});

// GET single task by ID
app.get('/tasks/:id', (req, res) => {
  const task = tasks.find(t => t.id === parseInt(req.params.id));
  if (!task) return res.status(404).json({ success: false, message: 'Task not found' });
  res.json({ success: true, task });
});

// POST create new task
app.post('/tasks', (req, res) => {
  const { title, description, status } = req.body;
  if (!title) return res.status(400).json({ success: false, message: 'Title is required' });

  const task = {
    id: nextId++,
    title,
    description: description || '',
    status: status || 'pending',   // pending | in-progress | done
    createdAt: new Date().toISOString(),
  };
  tasks.push(task);
  res.status(201).json({ success: true, task });
});

// PUT update task
app.put('/tasks/:id', (req, res) => {
  const index = tasks.findIndex(t => t.id === parseInt(req.params.id));
  if (index === -1) return res.status(404).json({ success: false, message: 'Task not found' });

  const { title, description, status } = req.body;
  tasks[index] = {
    ...tasks[index],
    ...(title && { title }),
    ...(description !== undefined && { description }),
    ...(status && { status }),
    updatedAt: new Date().toISOString(),
  };
  res.json({ success: true, task: tasks[index] });
});

// DELETE task
app.delete('/tasks/:id', (req, res) => {
  const index = tasks.findIndex(t => t.id === parseInt(req.params.id));
  if (index === -1) return res.status(404).json({ success: false, message: 'Task not found' });

  tasks.splice(index, 1);
  res.json({ success: true, message: 'Task deleted' });
});

module.exports = app;
