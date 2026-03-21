# On-Call Escalation

Level 1 (auto): Alertmanager → Slack #alerts
Level 2 (5 min no ack): ping @himanshu in Slack
Level 3 (15 min no ack): check EC2 manually

Runbook:
- High CPU: check docker stats, restart if needed
- High errors: check docker logs task-manager-app
- App down: check docker-compose ps, run docker-compose up -d
