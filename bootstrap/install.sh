#! /bin/bash

# After download this installs the custom files and starts
# services. Runs as root.

REMOTE=https://raw.githubusercontent.com/willmoffat/regenboog-laptops/master
REMOTE_TARBALL=$REMOTE/bootstrap/files.tgz

LOCAL_DIR=/regenboog

set -eu
cd "$(dirname "$0")"

check_rootuser_or_die() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

download() {
    DIR=/tmp/bootstrap
    rm -rf $DIR
    mkdir $DIR
    cd $DIR
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
    systemctl enable "$TIMER"
    systemctl start "$TIMER"
    cd ..
}

# Check size of packages with:
# dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n
remove_packages() {
    # firefox - school needs Google Chrome, remove to reduce confusion.
    # thunderbird - webmail only
    # hexchat - no chat
    # tranmission - no torrents
    # help files are 22MB each.
    apt purge -y \
        firefox \
        thunderbird \
        hexchat \
        transmission-common \
        libreoffice-help-de \
        libreoffice-help-pt-br \
        libreoffice-help-zh-cn \
        libreoffice-help-es \
        libreoffice-help-it \
        libreoffice-help-pt \
        libreoffice-help-ru \
        libreoffice-help-zh-tw \
        || true
}

update_packages() {
    apt update && apt upgrade -y || true
}

install_google_chrome() {
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
    echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
    apt update
    apt install google-chrome-stable
}

tweak_ui() {
    mkdir -p $LOCAL_DIR
    chown -R leerling:leerling $LOCAL_DIR
    sudo -u leerling cp -r ui $LOCAL_DIR

    # We are root, so we must send gsettings to the correct process.
    PID=$(pgrep cinnamon)
    export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$PID/environ|cut -d= -f2-)

    URI=file://$LOCAL_DIR/ui/logoRegenboog.png
    gsettings set org.cinnamon.desktop.background picture-uri $URI
    gsettings set org.cinnamon.desktop.background picture-options stretched
}

check_rootuser_or_die
download
install_updater
remove_packages
update_packages
install_google_chrome
tweak_ui
