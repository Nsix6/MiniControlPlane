#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="${PROJECT_ROOT}/envs"
LOG_FILE="${PROJECT_ROOT}/logs/cleanup.log"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Cleanup daemon started"

while true; do
    for STATE_FILE in "$ENV_DIR"/*.json; do
        [ -e "$STATE_FILE" ] || continue

        ENV_ID=$(jq -r '.env_id // empty' "$STATE_FILE" 2>/dev/null)
        CREATED_AT=$(jq -r '.created_at // empty' "$STATE_FILE" 2>/dev/null)
        TTL=$(jq -r '.ttl // empty' "$STATE_FILE" 2>/dev/null)

        if [ -z "$ENV_ID" ] || [ -z "$CREATED_AT" ] || [ -z "$TTL" ]; then
            log "Skipping corrupted or incomplete state file: $STATE_FILE"
            continue
        fi

        EXPIRATION=$((CREATED_AT + TTL))
        NOW=$(date +%s)

        if [ "$NOW" -ge "$EXPIRATION" ]; then
            log "Environment $ENV_ID expired (created_at=$CREATED_AT ttl=$TTL)"

            if "${PROJECT_ROOT}/platform/destroy_env.sh" "$ENV_ID"; then
                log "Environment $ENV_ID destroyed successfully"
            else
                log "Error destroying environment $ENV_ID"
            fi
        fi
    done

    sleep 60
done