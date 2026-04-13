# Build context = repo root (so we can copy shared/ alongside server/)

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY shared/package.json ./shared/
COPY server/package.json ./server/
RUN npm ci
COPY shared ./shared
COPY server ./server
RUN cd server && npx tsc

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
COPY shared/package.json ./shared/
COPY server/package.json ./server/
RUN npm ci --omit=dev --workspace=server --include-workspace-root
COPY --from=build /app/shared ./shared
COPY --from=build /app/server/dist ./server/dist
EXPOSE 2567
WORKDIR /app/server
CMD ["node", "dist/index.js"]
