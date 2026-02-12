#!/bin/bash

# SPDX-FileCopyrightText: Out of Control Inc
# SPDX-License-Identifier: MIT

# Pi-hole Query Flood Detection
# Compares recent query count against historical average
# Sends ntfy alert on initial flood detection only

DB="/etc/pihole/pihole-FTL.db"
STATE_FILE="/var/lib/pihole/flood-detect-state"
NTFY_SERVER="https://ntfy.outofcontrol.ca"  # Your ntfy server URL
NTFY_TOPIC="pihole"              # Your ntfy topic
NTFY_TOKEN="tk_0ivy1zx0tpwnl4115g76il47crrca"         # Your ntfy access token
THRESHOLD_MULTIPLIER=3  # Alert if current count > 3x the average
WINDOW_MINUTES=15
HISTORY_HOURS=24

if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    cat <<EOF
Pi-hole Query Flood Detection
==============================

Monitors Pi-hole DNS query rates and sends an ntfy notification
when a query flood is detected (initial detection only).

USAGE:
  ./pihole-flood-detection.sh          Run the flood check
  ./pihole-flood-detection.sh help     Show this help message

CONFIGURATION:
  Edit the variables at the top of the script:

  NTFY_SERVER           URL of your ntfy server (e.g. https://ntfy.example.com)
  NTFY_TOPIC            ntfy topic to publish alerts to
  NTFY_TOKEN            ntfy access token (Bearer auth)
  THRESHOLD_MULTIPLIER  Alert when queries exceed this multiple of the average (default: 3)
  WINDOW_MINUTES        Size of the recent query window in minutes (default: 15)
  HISTORY_HOURS         Hours of history to calculate the average from (default: 24)

STATE FILE:
  $STATE_FILE
  Tracks whether a flood is currently active. The alert only fires on
  the transition from normal to flood state. Delete this file to reset.

SETUP:
  1. Copy this script to /usr/local/bin/ or similar
  2. Set your NTFY_SERVER, NTFY_TOPIC, and NTFY_TOKEN values
  3. Make executable: chmod +x pihole-flood-detection.sh
  4. Add a cron entry to run every 15 minutes:
     */15 * * * * /usr/local/bin/pihole-flood-detection.sh

DEPENDENCIES:
  - sqlite3
  - curl
  - Pi-hole FTL database at /etc/pihole/pihole-FTL.db

EOF
    exit 0
fi

NOW=$(date +%s)
WINDOW_START=$((NOW - WINDOW_MINUTES * 60))
HISTORY_START=$((NOW - HISTORY_HOURS * 3600))

# Count queries in the recent window
RECENT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM queries WHERE timestamp >= $WINDOW_START;")

# Calculate average count per same-sized window over the history period
HISTORY_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM queries WHERE timestamp >= $HISTORY_START AND timestamp < $WINDOW_START;")
HISTORY_WINDOWS=$(( (HISTORY_HOURS * 60 - WINDOW_MINUTES) / WINDOW_MINUTES ))

# Ensure state directory exists
STATE_DIR=$(dirname "$STATE_FILE")
if [ ! -d "$STATE_DIR" ]; then
    mkdir -p "$STATE_DIR"
fi

if [ "$HISTORY_WINDOWS" -eq 0 ]; then
    exit 0
fi

AVG_COUNT=$((HISTORY_COUNT / HISTORY_WINDOWS))

# Avoid false alerts when traffic is very low
if [ "$AVG_COUNT" -lt 10 ]; then
    AVG_COUNT=10
fi

THRESHOLD=$((AVG_COUNT * THRESHOLD_MULTIPLIER))

# Log for debugging
logger -t pihole-flood "Recent: $RECENT_COUNT, Avg: $AVG_COUNT, Threshold: $THRESHOLD"

# Read previous state (0 = normal, 1 = flooding)
PREV_STATE=0
if [ -f "$STATE_FILE" ]; then
    PREV_STATE=$(cat "$STATE_FILE")
fi

if [ "$RECENT_COUNT" -gt "$THRESHOLD" ]; then
    if [ "$PREV_STATE" -eq 0 ]; then
        # Transition from normal to flood - send alert
        TOP_DOMAINS=$(sqlite3 "$DB" "SELECT domain, COUNT(*) as c FROM queries WHERE timestamp >= $WINDOW_START GROUP BY domain ORDER BY c DESC LIMIT 10;")
        TOP_CLIENTS=$(sqlite3 "$DB" "SELECT client, COUNT(*) as c FROM queries WHERE timestamp >= $WINDOW_START GROUP BY client ORDER BY c DESC LIMIT 5;")

        SUBJECT="[Pi-hole ALERT] Query flood detected: ${RECENT_COUNT} queries in ${WINDOW_MINUTES}min (avg: ${AVG_COUNT})"

        BODY="Query flood detected on $(hostname) at $(date)

Recent ${WINDOW_MINUTES}-minute window: ${RECENT_COUNT} queries
${HISTORY_HOURS}-hour average per ${WINDOW_MINUTES}-min window: ${AVG_COUNT}
Threshold (${THRESHOLD_MULTIPLIER}x): ${THRESHOLD}

Top domains in this window:
${TOP_DOMAINS}

Top clients in this window:
${TOP_CLIENTS}
"

        curl -s \
            -H "Authorization: Bearer ${NTFY_TOKEN}" \
            -H "Title: ${SUBJECT}" \
            -H "Priority: high" \
            -d "$BODY" \
            "${NTFY_SERVER}/${NTFY_TOPIC}"

        logger -t pihole-flood "ALERT sent: $RECENT_COUNT queries exceeds threshold $THRESHOLD"
    fi
    echo 1 > "$STATE_FILE"
else
    echo 0 > "$STATE_FILE"
fi
