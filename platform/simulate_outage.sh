#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="${PROJECT_ROOT}/envs"
LOG_FILE="${PROJECT_ROOT}/logs/outages.log"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [ $# -ne 2 ]; then
    echo "Usage: ./simulate_outage.sh <env-id> <mode>"
    echo "Modes: crash | pause | recover"
    exit 1
fi

ENV_ID="$1"
MODE="$2"

STATE_FILE="${ENV_DIR}/${ENV_ID}.json"

if [ ! -f "$STATE_FILE" ]; then
    echo "No state file found for $ENV_ID"
    exit 1
fi

APP_NAME=$(jq -r '.app_container // empty' "$STATE_FILE")
OUTAGE_MODE=$(jq -r '.outage_mode // empty' "$STATE_FILE")

if [ -z "$APP_NAME" ]; then
    echo "No app container found in state file"
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

case "$MODE" in

    crash)
        log "Applying crash outage to $ENV_ID"

        docker stop "$APP_NAME"

        jq \
          --arg ts "$TIMESTAMP" \
          '
          .outage_mode = "crash" |
          .status = "degraded" |
          .last_checked = $ts
          ' \
          "$STATE_FILE" > "${STATE_FILE}.tmp"

        mv "${STATE_FILE}.tmp" "$STATE_FILE"
        ;;

    pause)
        log "Applying pause outage to $ENV_ID"

        docker pause "$APP_NAME"

        jq \
          --arg ts "$TIMESTAMP" \
          '
          .outage_mode = "pause" |
          .status = "degraded" |
          .last_checked = $ts
          ' \
          "$STATE_FILE" > "${STATE_FILE}.tmp"

        mv "${STATE_FILE}.tmp" "$STATE_FILE"
        ;;

    recover)
        log "Recovering $ENV_ID from outage mode: $OUTAGE_MODE"

        jq \
          --arg ts "$TIMESTAMP" \
          '
          .status = "recovering" |
          .last_checked = $ts
          ' \
          "$STATE_FILE" > "${STATE_FILE}.tmp"

        mv "${STATE_FILE}.tmp" "$STATE_FILE"

        case "$OUTAGE_MODE" in

            crash)
                docker start "$APP_NAME"
                ;;

            pause)
                docker unpause "$APP_NAME"
                ;;

            *)
                log "No recoverable outage mode recorded"
                exit 1
                ;;
        esac

        jq \
          --arg ts "$TIMESTAMP" \
          '
          .outage_mode = null |
          .last_checked = $ts
          ' \
          "$STATE_FILE" > "${STATE_FILE}.tmp"

        mv "${STATE_FILE}.tmp" "$STATE_FILE"
        ;;

    *)
        echo "Invalid mode: $MODE"
        exit 1
        ;;
esac

log "Outage operation '$MODE' applied to $ENV_ID"
