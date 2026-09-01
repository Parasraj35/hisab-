# ---- Stage 1: install production dependencies only -------------------------
FROM node:20-alpine AS deps

WORKDIR /app
COPY package*.json ./

# `npm ci` needs package-lock.json. It isn't committed here, so fall back to
# `npm install`. Commit a lock file and the faster, reproducible path is used.
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev; \
    else \
      npm install --omit=dev; \
    fi && npm cache clean --force

# ---- Stage 2: runtime ------------------------------------------------------
FROM node:20-alpine AS runtime

# dumb-init gives us correct PID 1 signal handling so SIGTERM reaches Node
# and the graceful shutdown in server.js actually runs.
RUN apk add --no-cache dumb-init

ENV NODE_ENV=production
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY src ./src
COPY scripts ./scripts

# Run unprivileged. The node image already ships a `node` user.
RUN chown -R node:node /app
USER node

EXPOSE 5000

# Hits the same /health route the API exposes.
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:5000/api/v1/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/server.js"]
