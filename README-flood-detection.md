# Pi-hole Query Flood Detection

<!-- 
SPDX-License-Identifier: MIT 
SPDX-FileCopyrightText: 2026 Out of Control, Inc.
-->

> **Note:** This script was created with the assistance of AI (Claude) under human oversight and direction. While the code has been tested and reviewed, please use it responsibly and verify results for critical applications.

A lightweight bash script that monitors Pi-hole DNS query rates and sends a notification via [ntfy](https://ntfy.sh) when a query flood is detected.

The script compares the query count in a recent time window against a rolling historical average. If the count exceeds a configurable threshold, it sends a single alert on initial detection and suppresses further notifications until traffic returns to normal.

## Requirements

- Pi-hole with FTL database (`/etc/pihole/pihole-FTL.db`)
- `sqlite3`
- `curl`
- An [ntfy](https://ntfy.sh) server (self-hosted or hosted)

## Installation

1. Clone the repository:

       git clone https://github.com/youruser/pihole-flood-detection.git
       cd pihole-flood-detection

2. Copy the script to a suitable location:

       sudo cp pihole-flood-detection.sh /usr/local/bin/
       sudo chmod +x /usr/local/bin/pihole-flood-detection.sh

3. Edit the script and set your ntfy configuration:

       NTFY_SERVER="https://ntfy.example.com"
       NTFY_TOPIC="pihole-alerts"
       NTFY_TOKEN="tk_your_token_here"

4. Add a cron entry to run every 15 minutes:

       sudo crontab -e

   Add the following line:

       */15 * * * * /usr/local/bin/pihole-flood-detection.sh

## Configuration

| Variable              | Default                        | Description                                      |
|-----------------------|--------------------------------|--------------------------------------------------|
| `NTFY_SERVER`         | `https://ntfy.example.com`     | URL of your ntfy server                          |
| `NTFY_TOPIC`          | `pihole-alerts`                | ntfy topic to publish alerts to                  |
| `NTFY_TOKEN`          | `tk_your_token_here`           | ntfy access token (Bearer auth)                  |
| `THRESHOLD_MULTIPLIER`| `3`                            | Alert when queries exceed this multiple of the average |
| `WINDOW_MINUTES`      | `15`                           | Size of the recent query window in minutes       |
| `HISTORY_HOURS`       | `24`                           | Hours of history used to calculate the average   |

## How It Works

1. Counts DNS queries in the most recent time window (default: 15 minutes).
2. Calculates the average query count per window over the history period (default: 24 hours).
3. If the recent count exceeds the average multiplied by the threshold multiplier, and the system was not already in a flood state, it sends an ntfy notification with details including top queried domains and top clients.
4. A state file (`/var/lib/pihole/flood-detect-state`) tracks whether a flood is currently active. Alerts only fire on the transition from normal to flood. Once traffic drops below the threshold, the state resets.

To manually reset the flood state, delete the state file:

    sudo rm /var/lib/pihole/flood-detect-state

## Usage

    ./pihole-flood-detection.sh           # Run the flood check
    ./pihole-flood-detection.sh help      # Show the help menu

## Logging

The script logs to syslog via `logger` under the tag `pihole-flood`. View logs with:

    grep pihole-flood /var/log/syslog

## Licence

MIT
