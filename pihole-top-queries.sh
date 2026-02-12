#!/bin/bash
# Top queried domains from Pi-hole FTL database

DBPATH="/etc/pihole/pihole-FTL.db"
LIMIT="${1:-50}"

sudo sqlite3 "$DBPATH" "SELECT domain, COUNT(*) as query_count FROM queries GROUP BY domain ORDER BY query_count DESC LIMIT $LIMIT;"
