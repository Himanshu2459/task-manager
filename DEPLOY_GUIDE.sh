# Task Manager API — Complete AWS Deployment Guide
# Read this top to bottom. Do each step fully before the next.

# ═══════════════════════════════════════════════════════════════
# PHASE 1 — LOCAL SETUP (Your computer)
# ═══════════════════════════════════════════════════════════════

# Step 1: Install dependencies locally to test
cd backend
npm install
npm test
# You should see all tests PASS. If not, DO NOT continue.

# Step 2: Test Docker locally
cd ..   # go back to task-manager/ folder
docker build -t task-manager-test .
docker run -p 3000:3000 task-manager-test

# Open browser → http://localhost:3000/health
# You should see: {"status":"ok","uptime":...}
# Press Ctrl+C to stop

# ═══════════════════════════════════════════════════════════════
# PHASE 2 — AWS SETUP (AWS Console in browser)
# ═══════════════════════════════════════════════════════════════

# Step 3: Create ECR Repository
# 1. Go to AWS Console → ECR → Create Repository
# 2. Name: task-manager-api
# 3. Keep all defaults → Create
# 4. Copy the repository URI — looks like:
#    123456789.dkr.ecr.us-east-1.amazonaws.com/task-manager-api

# Step 4: Create IAM User for GitHub Actions
# 1. AWS Console → IAM → Users → Create User
# 2. Name: github-actions-user
# 3. Attach policy: AmazonEC2ContainerRegistryFullAccess
# 4. Create → Go to Security Credentials → Create Access Key
# 5. Save the Access Key ID and Secret — you will need them for GitHub Secrets

# Step 5: EC2 Setup
# 1. Go to your EC2 from Project 1 (or launch new t3.small)
# 2. Make sure Security Group allows:
#    - Port 22 (SSH)
#    - Port 80 (HTTP)
#    - Port 443 (HTTPS)
#    - Port 3001 (Grafana) — only your IP
#    - Port 9090 (Prometheus) — only your IP

# ═══════════════════════════════════════════════════════════════
# PHASE 3 — EC2 SERVER SETUP (SSH into your EC2)
# ═══════════════════════════════════════════════════════════════

# Connect to EC2:
# ssh -i your-key.pem ec2-user@YOUR_EC2_IP

# Step 6: Install Docker and Docker Compose on EC2
sudo yum update -y
sudo yum install -y docker git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install AWS CLI (to pull from ECR)
sudo yum install -y awscli

# IMPORTANT: Log out and log back in so docker group takes effect
exit
# ssh back in again

# Step 7: Copy project files to EC2
# Run this on YOUR LOCAL machine:
scp -i your-key.pem -r /path/to/task-manager ec2-user@YOUR_EC2_IP:/home/ec2-user/

# Step 8: Configure AWS on EC2
# SSH back into EC2, then run:
aws configure
# Enter: your Access Key ID, Secret, Region (e.g. us-east-1), output: json

# ═══════════════════════════════════════════════════════════════
# PHASE 4 — GITHUB SECRETS SETUP
# ═══════════════════════════════════════════════════════════════

# Step 9: Add Secrets to GitHub
# Go to your GitHub repo → Settings → Secrets and Variables → Actions
# Add these secrets one by one:

# AWS_ACCESS_KEY_ID     → from Step 4
# AWS_SECRET_ACCESS_KEY → from Step 4
# AWS_REGION            → e.g. us-east-1
# EC2_HOST              → Your EC2 public IP address
# EC2_SSH_KEY           → Contents of your .pem file (open it, copy ALL text including -----BEGIN-----)

# ═══════════════════════════════════════════════════════════════
# PHASE 5 — SSL CERTIFICATE (Nginx + Certbot)
# ═══════════════════════════════════════════════════════════════

# Step 10: Point your domain to EC2
# Go to Route 53 → your domain → Add A Record
# Name: @ or api
# Value: YOUR_EC2_IP

# Step 11: Install Certbot on EC2
sudo yum install -y certbot

# Get the SSL certificate (replace YOUR_DOMAIN.com):
sudo certbot certonly --standalone -d YOUR_DOMAIN.com --email your@email.com --agree-tos

# Certificate will be at: /etc/letsencrypt/live/YOUR_DOMAIN.com/

# Step 12: Update nginx.conf
# Edit nginx/nginx.conf — replace all instances of YOUR_DOMAIN.com with your actual domain

# ═══════════════════════════════════════════════════════════════
# PHASE 6 — FIRST MANUAL DEPLOY (on EC2)
# ═══════════════════════════════════════════════════════════════

# Step 13: Push first image manually to ECR
# Run on YOUR LOCAL machine:

AWS_ACCOUNT=YOUR_AWS_ACCOUNT_ID
REGION=us-east-1
ECR_URI=$AWS_ACCOUNT.dkr.ecr.$REGION.amazonaws.com

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

docker build -t $ECR_URI/task-manager-api:latest .
docker push $ECR_URI/task-manager-api:latest

# Step 14: Start everything on EC2
cd /home/ec2-user/task-manager

# Set your ECR image in environment
export APP_IMAGE=YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/task-manager-api:latest

# Pull and start all services
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $APP_IMAGE
docker-compose up -d

# Check everything is running:
docker-compose ps

# Test your endpoints:
curl http://localhost:3000/health
curl http://localhost:3000/tasks

# ═══════════════════════════════════════════════════════════════
# PHASE 7 — TEST THE PIPELINE
# ═══════════════════════════════════════════════════════════════

# Step 15: Trigger the GitHub Actions pipeline
# On your local machine, make any small change and push:
git add .
git commit -m "trigger pipeline test"
git push origin main

# Go to GitHub → Actions tab → Watch the pipeline run
# All steps should go GREEN

# ═══════════════════════════════════════════════════════════════
# PHASE 8 — GRAFANA DASHBOARDS
# ═══════════════════════════════════════════════════════════════

# Step 16: Setup Grafana
# Open browser: http://YOUR_EC2_IP:3001
# Login: admin / admin123 (change the password!)

# Add Prometheus data source:
# Settings → Data Sources → Add → Prometheus
# URL: http://prometheus:9090
# Save & Test

# Create Dashboard 1 — System Health:
# + New Dashboard → Add Panel
# Metric: node_cpu_seconds_total
# Query: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
# Title: CPU Usage %

# Create Dashboard 2 — App Latency:
# Metric: http_request_duration_seconds_bucket
# Query: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
# Title: 95th Percentile Latency

# Create Dashboard 3 — Error Rate:
# Query: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100
# Title: Error Rate %

# ═══════════════════════════════════════════════════════════════
# PHASE 9 — ALERTMANAGER + SLACK
# ═══════════════════════════════════════════════════════════════

# Step 17: Create Slack Webhook
# 1. Go to https://api.slack.com/apps
# 2. Create New App → From Scratch
# 3. Add Incoming Webhooks feature → Activate
# 4. Add to Workspace → Choose channel #alerts
# 5. Copy the Webhook URL

# Step 18: Update alertmanager.yml
# Replace YOUR_SLACK_WEBHOOK_URL with the URL from Step 17
# Replace #alerts with your actual Slack channel name

# Restart alertmanager:
docker-compose restart alertmanager

# ═══════════════════════════════════════════════════════════════
# VERIFY EVERYTHING IS WORKING
# ═══════════════════════════════════════════════════════════════

# These URLs should all work:
# https://YOUR_DOMAIN.com/health        ← Your API with SSL
# https://YOUR_DOMAIN.com/tasks         ← Task list
# http://YOUR_EC2_IP:9090               ← Prometheus
# http://YOUR_EC2_IP:3001               ← Grafana
# http://YOUR_EC2_IP:9093               ← Alertmanager

echo "Deployment complete!"
