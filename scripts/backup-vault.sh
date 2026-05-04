#!/bin/bash
# pi-cortex Restic Vault Backup Script
# Phase 1.7: Run nightly via cron

REPO="/mnt/wd3t/backups/knowledge-vault"
SOURCE="/opt/knowledge-vault"
LOG="/var/log/pi-cortex/backup.log"

echo "[$(date)] Starting Vault backup..." >> "$LOG"
restic -r "$REPO" backup "$SOURCE" --exclude=.git --tag="vault-$(date +%Y-%m-%d)" >> "$LOG" 2>&1
echo "[$(date)] Backup complete." >> "$LOG"

# Keep 30 backups
restic -r "$REPO" forget --keep-daily 30 --prune >> "$LOG" 2>&1
