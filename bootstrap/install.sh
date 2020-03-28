#! /bin/bash

# After download this installs the custom files and starts
# services.

REMOTE=https://raw.githubusercontent.com/willmoffat/regenboog-laptops/master
REMOTE_TARBALL=$REMOTE/bootstrap/files.tgz

set -eu
cd "$(dirname "$0")"

check_rootuser_or_die() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

download() {
    mkdir /tmp/bootstrap
    cd /tmp/bootstrap
    curl -s -O $REMOTE_TARBALL
    tar xf files.tgz
}

install_updater() {
    NAME=regenboog-update
    SERVICE="$NAME.service"
    TIMER="$NAME.timer"

    cd updater
    cp "$SERVICE" "$TIMER" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable "$SERVICE"
    systemctl start "$TIMER"
    cd ..
}

check_rootuser_or_die
download
install_updater
