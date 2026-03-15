# ─── Stage 1: Builder ────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copy only package files first (better Docker layer caching)
COPY backend/package*.json ./

# Install ALL deps (including dev) for building
RUN npm ci

# ─── Stage 2: Production ─────────────────────────────────────────
FROM node:20-alpine AS production

WORKDIR /app

# Create non-root user for security (requirement from your portfolio sheet)
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# Copy only package files
COPY backend/package*.json ./

# Install ONLY production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application source code
COPY backend/src ./src

# Change ownership to non-root user
RUN chown -R nodeuser:nodejs /app

# Switch to non-root user
USER nodeuser

# Expose the app port
EXPOSE 3000

# Health check so Docker knows if container is alive
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Start the app
CMD ["node", "src/server.js"]
