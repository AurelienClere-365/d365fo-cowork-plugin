# =============================================================================
# Stage 1 — build: compile d365fo-cli from source (linux-x64 self-contained)
# =============================================================================
FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build

WORKDIR /src

# Clone the fork (pinned to main; swap for a tag once the team creates releases)
RUN apk add --no-cache git \
 && git clone --depth 1 https://github.com/AurelienClere-365/d365fo-cli.git /src

# Build the MCP adapter as a self-contained linux-x64 binary
RUN dotnet publish src/D365FO.Mcp \
      -c Release \
      -r linux-musl-x64 \
      --self-contained true \
      -p:PublishSingleFile=true \
      -p:PublishTrimmed=false \
      -o /app/publish

# =============================================================================
# Stage 2 — runtime: minimal image, no SDK
# =============================================================================
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS runtime

LABEL maintainer="your-org"
LABEL description="D365FO CLI MCP server for Cowork connector"

# Create data directory for the pre-built SQLite index
RUN mkdir -p /data

# Copy self-contained binary from build stage
COPY --from=build /app/publish /app

# Copy the pre-built metadata index produced by:
#   d365fo index build && d365fo index extract
# from a developer workstation with PackagesLocalDirectory access.
# See README.md -> "Step 1: Copy the metadata index into the repo root".
COPY d365fo-index.sqlite /data/d365fo-index.sqlite

# d365fo-mcp reads D365FO_INDEX_PATH when set; falls back to D365FO_PACKAGES_PATH
ENV D365FO_INDEX_PATH=/data/d365fo-index.sqlite
ENV PORT=8080

EXPOSE 8080

# Health check — probes the MCP readiness endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD wget -qO- http://localhost:8080/health 2>/dev/null || exit 1

# Start MCP server in Streamable-HTTP mode so Azure Container Apps can front it
ENTRYPOINT ["/app/d365fo-mcp"]
CMD ["--transport", "streamable-http", "--port", "8080"]