#! /bin/bash

# See https://papertrailapp.com/account/profile for token.

set -eu

echo 'Active in the last 7 days'

LOG=/tmp/log
papertrail --min-time "7 days ago" > $LOG
cut -d' ' -f4 $LOG | sort -u
