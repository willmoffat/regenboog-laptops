#! /bin/bash

set -eu

echo 'Active in the last 24 hours'

LOG=/tmp/log
papertrail --min-time "24 hours ago" > $LOG
cut -d' ' -f4 $LOG | sort -u
