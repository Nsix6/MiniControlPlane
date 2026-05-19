#!/bin/bash
set -e

NAME=$1
TTL=${2:-1800}
CREATED_AT=$(date +%s)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$NAME" ]; then
    echo "Usage: ./create_env.sh <name> [ttl]"
    exit 1
fi

ENV_ID="env-$(openssl rand -hex 3)"
echo "Generated ENV_ID: $ENV_ID"

APP_NAME="sandbox-${ENV_ID}-app"
ROUTE_FILE="${PROJECT_ROOT}/nginx/conf.d/${ENV_ID}.conf"
STATE_FILE="${PROJECT_ROOT}/envs/${ENV_ID}.json"
LOG_DIR="${PROJECT_ROOT}/logs/${ENV_ID}"
LOG_FILE="${LOG_DIR}/app.log"
LOG_PID=""

rollback() {
    echo "Rollback: cleaning up failed environment $ENV_ID"

    docker rm -f "$APP_NAME" 2>/dev/null || true

    rm -f "$ROUTE_FILE" 2>/dev/null || true

    docker exec sandbox-nginx nginx -s reload 2>/dev/null || true

    [ -n "$LOG_PID" ] && kill "$LOG_PID" 2>/dev/null || true

    rm -rf "$LOG_DIR" 2>/dev/null || true

    rm -f "$STATE_FILE" 2>/dev/null || true
}

trap rollback ERR

docker run -d \
  --name "$APP_NAME" \
  --network sandbox-shared-net \
  --label "sandbox.env=$ENV_ID" \
  sandbox-demo:optimized

echo "Started app container: $APP_NAME"

mkdir -p "${PROJECT_ROOT}/nginx/conf.d"

TMP_ROUTE_FILE="${ROUTE_FILE}.tmp"

cat > "$TMP_ROUTE_FILE" <<EOF
location /${ENV_ID}/ {
    proxy_pass http://${APP_NAME}:5000/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
}
EOF

mv "$TMP_ROUTE_FILE" "$ROUTE_FILE"

echo "Generated route file: $ROUTE_FILE"

echo "Validating nginx configuration"

docker exec sandbox-nginx nginx -t

docker exec sandbox-nginx nginx -s reload

echo "Reloaded nginx with new route"

TMP_FILE="${STATE_FILE}.tmp"

mkdir -p "${PROJECT_ROOT}/envs"

cat > "$TMP_FILE" <<EOF
{
  "env_id": "$ENV_ID",
  "name": "$NAME",
  "ttl": "$TTL",
  "created_at": $CREATED_AT,
  "app_container": "$APP_NAME",
  "route_file": "$ROUTE_FILE",
  "url": "http://localhost/${ENV_ID}",
  "status": "running",
  "failure_count": 0,
  "last_checked": null,
  "last_response_ms": null,
  "outage_mode": null
}
EOF

mv "$TMP_FILE" "$STATE_FILE"

echo "Created state file: $STATE_FILE"

mkdir -p "$LOG_DIR"

docker logs -f "$APP_NAME" > "$LOG_FILE" 2>&1 &

LOG_PID=$!

jq ". + {\"log_dir\": \"$LOG_DIR\", \"log_file\": \"$LOG_FILE\", \"log_pid\": $LOG_PID}" \
  "$STATE_FILE" > "${STATE_FILE}.tmp" && \
  mv "${STATE_FILE}.tmp" "$STATE_FILE"

echo "Started log shipping to $LOG_FILE"

trap - ERR

echo "Environment provisioned!"
echo "URL: http://localhost/${ENV_ID}"
