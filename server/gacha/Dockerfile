FROM node:22-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && mkdir -p /data && chown node:node /data
COPY --chown=node:node src ./src
USER node
ENV NODE_ENV=production PORT=8081 DB_PATH=/data/gacha.sqlite
EXPOSE 8081
CMD ["node", "src/server.mjs"]
