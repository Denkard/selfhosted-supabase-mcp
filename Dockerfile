# Dockerfile - selfhosted-supabase-mcp em modo HTTP (Bun)
FROM oven/bun:1.1-alpine AS builder

WORKDIR /app

# Copia manifestos primeiro (cache de dependências)
COPY package.json bun.lock* ./

# Instala dependências (frozen se o lock existir, senão normal)
RUN bun install --frozen-lockfile || bun install

# Copia o restante do código
COPY . .

# Builda o TypeScript -> dist/
RUN bun build src/index.ts --outdir dist --target bun

# ---- Runtime ----
FROM oven/bun:1.1-alpine AS runner

WORKDIR /app

RUN addgroup --system --gid 1001 mcp && \
    adduser --system --uid 1001 --ingroup mcp mcp

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

RUN chown -R mcp:mcp /app
USER mcp

ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3100/health || exit 1

EXPOSE 3100

CMD ["bun", "run", "dist/index.js", "--transport", "http", "--port", "3100", "--host", "0.0.0.0"]
