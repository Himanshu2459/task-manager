const request = require('supertest');
const app = require('../src/app');

describe('Health Check', () => {
  test('GET /health returns 200', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('Tasks API', () => {
  test('GET /tasks returns empty array initially', async () => {
    const res = await request(app).get('/tasks');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('POST /tasks creates a task', async () => {
    const res = await request(app)
      .post('/tasks')
      .send({ title: 'Test Task', description: 'Test description' });
    expect(res.statusCode).toBe(201);
    expect(res.body.task.title).toBe('Test Task');
    expect(res.body.task.status).toBe('pending');
  });

  test('POST /tasks fails without title', async () => {
    const res = await request(app).post('/tasks').send({});
    expect(res.statusCode).toBe(400);
  });

  test('GET /tasks/:id returns a task', async () => {
    // Create first
    const create = await request(app).post('/tasks').send({ title: 'Find Me' });
    const id = create.body.task.id;

    const res = await request(app).get(`/tasks/${id}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.task.title).toBe('Find Me');
  });

  test('PUT /tasks/:id updates a task', async () => {
    const create = await request(app).post('/tasks').send({ title: 'Old Title' });
    const id = create.body.task.id;

    const res = await request(app).put(`/tasks/${id}`).send({ title: 'New Title', status: 'done' });
    expect(res.statusCode).toBe(200);
    expect(res.body.task.title).toBe('New Title');
    expect(res.body.task.status).toBe('done');
  });

  test('DELETE /tasks/:id deletes a task', async () => {
    const create = await request(app).post('/tasks').send({ title: 'Delete Me' });
    const id = create.body.task.id;

    const res = await request(app).delete(`/tasks/${id}`);
    expect(res.statusCode).toBe(200);
  });

  test('GET /tasks/:id returns 404 for missing task', async () => {
    const res = await request(app).get('/tasks/99999');
    expect(res.statusCode).toBe(404);
  });
});
