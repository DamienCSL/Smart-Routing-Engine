FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src

ENV NODE_ENV=production
# Railway injects $PORT and probes /health
EXPOSE 3080

CMD ["sh", "-c", "node src/index.js"]
