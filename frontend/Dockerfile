FROM node:22-bookworm-slim
RUN corepack enable && mkdir -p /app && chown node:node /app
USER node
ENV npm_config_store_dir=/home/node/.pnpm-store
RUN corepack prepare pnpm@10.28.1 --activate
WORKDIR /app
COPY --chown=node:node package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY --chown=node:node . .
ENV CI=true
EXPOSE 5173
CMD ["sh", "-c", "pnpm install --frozen-lockfile && pnpm dev"]
