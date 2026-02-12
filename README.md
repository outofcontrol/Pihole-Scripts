# PiHole Scripts

<!-- 
SPDX-License-Identifier: MIT 
SPDX-FileCopyrightText: 2026 Out of Control, Inc.
-->

> **Note:** This script was created with the assistance of AI (Claude) under human oversight and direction. While the code has been tested and reviewed, please use it responsibly and verify results for critical applications.

A collection of utility scripts to help manage and monitor a [Pi-hole](https://pi-hole.net/) installation.

## Scripts

| Script | Description |
|--------|-------------|
| `pihole-flood-detection.sh` | Detects DNS query flooding by monitoring query rates and identifying abusive clients or domains. See [README-flood-detection.md](README-flood-detection.md) for details. |
| `pihole-top-queries.sh` | Queries the Pi-hole FTL database and displays the most frequently queried domains. Accepts an optional argument to set the number of results (default: 50). |
