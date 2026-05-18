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

        ENV_ID=$(jq -r '.env_id // empty' "$STATE_FILE" 2>/dev/null)
        ROUTE_URL=$(jq -r '.url // empty' "$STATE_FILE" 2>/dev/null)
        FAILURE_COUNT=$(jq -r '.failure_count // 0' "$STATE_FILE" 2>/dev/null)

        if [ -z "$ENV_ID" ] || [ -z "$ROUTE_URL" ]; then
            log "Skipping invalid state file: $STATE_FILE"
            continue
        fi

        # Normalize URL (remove trailing slash)
        ROUTE_URL="${ROUTE_URL%/}"

        START=$(date +%s%3N)
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$ROUTE_URL/health" || echo "000")
        END=$(date +%s%3N)
        LATENCY=$((END - START))
        CHECKED_AT=$(date +%s)

        if [ "$HTTP_STATUS" -eq 200 ]; then
            log "Environment $ENV_ID healthy (latency=${LATENCY}ms)"
            jq ".failure_count = 0 | .status = \"healthy\" | .last_checked = $CHECKED_AT | .last_response_ms = $LATENCY" \
                "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
        else
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            log "Environment $ENV_ID failed health check (status=$HTTP_STATUS, failure_count=$FAILURE_COUNT)"
            if [ "$FAILURE_COUNT" -ge 3 ]; then
                log "Environment $ENV_ID marked degraded"
                jq ".failure_count = $FAILURE_COUNT | .status = \"degraded\" | .last_checked = $CHECKED_AT | .last_response_ms = $LATENCY" \
                    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
            else
                jq ".failure_count = $FAILURE_COUNT | .last_checked = $CHECKED_AT | .last_response_ms = $LATENCY" \
                    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
            fi
        fi
    done

    sleep 30
done
