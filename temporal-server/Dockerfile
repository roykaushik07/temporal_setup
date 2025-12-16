FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    bash

# Create temporal user and group
RUN addgroup -g 1000 temporal && \
    adduser -u 1000 -G temporal -s /bin/sh -D temporal

# Create config directory
RUN mkdir -p /etc/temporal/config && \
    chown -R temporal:temporal /etc/temporal

# Copy binary (available after running download-binaries.sh)
COPY binaries/temporal-server /usr/local/bin/temporal-server

# Copy minimal config (values come from environment variables)
COPY config/development.yaml /etc/temporal/config/development.yaml

# Set permissions
RUN chmod +x /usr/local/bin/temporal-server && \
    chown -R temporal:temporal /etc/temporal

# Switch to temporal user
USER temporal

# Expose Temporal server ports
# 7233 - Frontend gRPC service (main client endpoint)
# 7234 - History service
# 7235 - Matching service
# 7239 - Worker service
EXPOSE 7233 7234 7235 7239

# Working directory
WORKDIR /etc/temporal

# Start server - configured via environment variables
CMD ["temporal-server", "start"]
