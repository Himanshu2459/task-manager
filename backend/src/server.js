const app = require('./app');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Task Manager API running on port ${PORT}`);
  console.log(`Health: http://localhost:${PORT}/health`);
  console.log(`Metrics: http://localhost:${PORT}/metrics`);
  console.log(`Tasks: http://localhost:${PORT}/tasks`);
});
