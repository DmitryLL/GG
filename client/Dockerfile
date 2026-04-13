FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY shared/package.json ./shared/
COPY client/package.json ./client/
RUN npm ci
COPY shared ./shared
COPY client ./client
RUN npm run build --workspace=client

FROM alpine:3
COPY --from=build /app/client/dist /dist
CMD ["sh", "-c", "rm -rf /out/* && cp -r /dist/. /out/ && echo 'client dist published'"]
