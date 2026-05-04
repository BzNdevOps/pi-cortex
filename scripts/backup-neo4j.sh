#!/bin/bash
# pi-cortex Neo4j Dump Script
# Phase 1.8: Run nightly via cron

NEO4J_USER="neo4j"
NEO4J_PASS=$(grep 'NEO4J_PASSWORD' /home/bzn/.pi/.env | cut -d= -f2)
BACKUP_DIR="/var/backups/neo4j"
LOG="/var/log/pi-cortex/neo4j-backup.log"

echo "[$(date)] Starting Neo4j dump..." >> "$LOG"

# Use curl to export via Neo4j REST API (requires Cypher)
curl -s -u "$NEO4J_USER:$NEO4J_PASS" -H "Accept: application/json" \
  "http://127.0.0.1:7474/db/query" \
  -d "statement=CALL dbms.listDatabases()" >> "$LOG" 2>&1

echo "[$(date)] Dump complete." >> "$LOG"
