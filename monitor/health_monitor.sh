#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="${PROJECT_ROOT}/envs"
LOG_FILE="${PROJECT_ROOT}/logs/monitor.log"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Health monitor started"

while true; do
    for STATE_FILE in "$ENV_DIR"/*.json; do
        [ -e "$STATE_FILE" ] || continue

        ENV_ID=$(jq -r '.env_id // empty' "$STATE_FILE")
        ROUTE_URL=$(jq -r '.url // empty' "$STATE_FILE")
        FAILURE_COUNT=$(jq -r '.failure_count // 0' "$STATE_FILE")
        CURRENT_STATUS=$(jq -r '.status // "unknown"' "$STATE_FILE")

        if [ -z "$ENV_ID" ] || [ -z "$ROUTE_URL" ]; then
            log "Skipping invalid state file: $STATE_FILE"
            continue
        fi

        START=$(date +%s%3N)

        HTTP_STATUS=$(curl -s -o /dev/null \
            -w "%{http_code}" \
            --max-time 5 \
            "${ROUTE_URL}/health")

        END=$(date +%s%3N)

        LATENCY=$((END - START))

        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

        if [ "$HTTP_STATUS" = "200" ]; then

            if [ "$CURRENT_STATUS" != "healthy" ]; then
                log "Environment $ENV_ID transitioned to healthy"
            fi

            jq \
              --arg ts "$TIMESTAMP" \
              --argjson latency "$LATENCY" \
              '
              .failure_count = 0 |
              .status = "healthy" |
              .last_checked = $ts |
              .last_response_ms = $latency
              ' \
              "$STATE_FILE" > "${STATE_FILE}.tmp"

            mv "${STATE_FILE}.tmp" "$STATE_FILE"

            log "Environment $ENV_ID healthy (latency=${LATENCY}ms)"

        else
            FAILURE_COUNT=$((FAILURE_COUNT + 1))

            NEW_STATUS="unhealthy"

            if [ "$FAILURE_COUNT" -ge 3 ]; then
                NEW_STATUS="degraded"
            fi

            if [ "$CURRENT_STATUS" != "$NEW_STATUS" ]; then
                log "Environment $ENV_ID transitioned to $NEW_STATUS"
            fi

            jq \
              --arg ts "$TIMESTAMP" \
              --arg status "$NEW_STATUS" \
              --argjson latency "$LATENCY" \
              --argjson failures "$FAILURE_COUNT" \
              '
              .failure_count = $failures |
              .status = $status |
              .last_checked = $ts |
              .last_response_ms = $latency
              ' \
              "$STATE_FILE" > "${STATE_FILE}.tmp"

            mv "${STATE_FILE}.tmp" "$STATE_FILE"

            log "Environment $ENV_ID failed health check (status=$HTTP_STATUS, failure_count=$FAILURE_COUNT)"
        fi
    done

    sleep 30
done