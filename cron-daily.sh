#!/bin/bash
# MK2 Daily Sync - runs at 03:00 MSK every day
set -e
cd /root/MK2-parser

LOG_DIR=/var/log/mk2
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/daily-$(date +%Y%m%d-%H%M).log"

echo "[MK2] Daily sync started at $(date)" | tee -a "$LOGFILE"
docker compose run --rm mk2-daily --once >> "$LOGFILE" 2>&1
EXITCODE=$?
echo "[MK2] Daily sync finished at $(date) exit=$EXITCODE" | tee -a "$LOGFILE"

# Prune old containers
docker container prune -f >> "$LOGFILE" 2>&1

exit $EXITCODE
