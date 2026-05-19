
#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$1" ]; then
    echo "Usage: ./destroy_env.sh <env-id>"
    exit 1
fi

ENV_ID="$1"

STATE_FILE="${PROJECT_ROOT}/envs/${ENV_ID}.json"

if [ ! -f "$STATE_FILE" ]; then
    echo "Environment $ENV_ID already destroyed (no state file found)"
    exit 0
fi

APP_NAME=$(jq -r '.app_container' "$STATE_FILE")
NETWORK_NAME=$(jq -r '.network' "$STATE_FILE")
ROUTE_FILE=$(jq -r '.route_file' "$STATE_FILE")
LOG_DIR=$(jq -r '.log_dir' "$STATE_FILE")
LOG_PID=$(jq -r '.log_pid' "$STATE_FILE")

# Stop log shipper
if [ -n "$LOG_PID" ] && kill -0 "$LOG_PID" 2>/dev/null; then
    echo "Stopping log shipper process $LOG_PID"
    kill "$LOG_PID" 2>/dev/null || true
else
    echo "No active log shipper process found for $ENV_ID"
fi

# Remove app container
if [ -n "$APP_NAME" ]; then
    echo "Removing app container: $APP_NAME"
    docker rm -f "$APP_NAME" 2>/dev/null || true
else
    echo "No app container name found in state file for $ENV_ID"
fi

# Remove route file
ROUTE_REMOVED=false

if [ -n "$ROUTE_FILE" ] && [ -f "$ROUTE_FILE" ]; then
    echo "Removing route file: $ROUTE_FILE"
    rm -f "$ROUTE_FILE"

    if [ -f "$ROUTE_FILE" ]; then
        echo "Failed to remove route file: $ROUTE_FILE"
    else
        echo "Route file removed successfully"
        ROUTE_REMOVED=true
    fi
else
    echo "No route file found for $ENV_ID"
fi

# Validate and reload nginx only if route changed
if [ "$ROUTE_REMOVED" = true ]; then
    echo "Validating nginx configuration"

    if docker exec sandbox-nginx nginx -t; then
        echo "Reloading nginx to apply changes"
        docker exec sandbox-nginx nginx -s reload
    else
        echo "Warning: nginx configuration test failed"
        echo "Manual intervention may be required"
    fi
else
    echo "No route changes detected, skipping nginx reload"
fi


# Archive logs
ARCHIVE_DIR="${PROJECT_ROOT}/logs/archived/${ENV_ID}"

if [ -d "$LOG_DIR" ]; then
    echo "Archiving logs from $LOG_DIR to $ARCHIVE_DIR"
    mkdir -p "$(dirname "$ARCHIVE_DIR")"
    mv "$LOG_DIR" "$ARCHIVE_DIR"
else
    echo "No log directory found for $ENV_ID"
fi

# Delete state file
if [ -f "$STATE_FILE" ]; then
    echo "Deleting state file: $STATE_FILE"
    rm -f "$STATE_FILE"
else
    echo "No state file found for $ENV_ID (already removed?)"
fi

echo "Environment $ENV_ID destroyed successfully"

