# Taskwise sync server as a plain Node server, for self-hosting.
# See docs/server-setup-vercel.md ("Self-hosting with Docker").
#
#   docker build -t taskwise-server server
#   docker run -p 8787:8787 -v taskwise-data:/data \
#     -e SETUP_SECRET=... -e CRON_SECRET=... taskwise-server
#
# Debian-based image: the argon2 and libSQL native packages need glibc.
FROM node:24-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:24-slim
ENV NODE_ENV=production \
    PORT=8787 \
    DATABASE_URL=file:/data/taskwise.db
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
RUN mkdir -p /data && chown node:node /data
VOLUME /data
USER node
EXPOSE 8787
CMD ["node", "dist/node.js"]
