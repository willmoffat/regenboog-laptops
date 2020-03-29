#! /bin/bash

# After download this installs the custom files and starts
# services. Runs as root in $TMP_DIR

# For testing without using GitHub use:
# BS=http://xxx.nrok.io/bootstrap
# curl -sL $BS/install.sh | bash -s $BS/files.tgz

# Download files from GitHub.
REMOTE=https://raw.githubusercontent.com/willmoffat/regenboog-laptops/master
DEFAULT_TARBALL=$REMOTE/bootstrap/files.tgz
REMOTE_TARBALL=${1-$DEFAULT_TARBALL}

TMP_DIR=/tmp/bootstrap
LOCAL_DIR=/regenboog

set -eu

check_rootuser_or_die() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

download() {
    mkdir -p $LOCAL_DIR
    rm -rf $TMP_DIR
    mkdir -p $TMP_DIR
    cd $TMP_DIR
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
    # backgrounds are 300MB.
    # help files are 22MB each.
    apt purge -y \
        firefox \
        thunderbird \
        hexchat \
        transmission-common \
        'mint-backgrounds-*' \
        libreoffice-help-de \
        libreoffice-help-pt-br \
        libreoffice-help-zh-cn \
        libreoffice-help-es \
        libreoffice-help-it \
        libreoffice-help-pt \
        libreoffice-help-ru \
        libreoffice-help-zh-tw \
        || true
    # Removes 600MB of packages.
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

# Setup UI options.
# You can find the names of these options by setting them using the Linux Mint UI
# and then running
#    dconf dump /tmp/conf

# This function is written out using declare to be run as the user (not root).
# Variables must be local to function or echo-ed below.
setup_user() {
    # Desktop
    URI=file://$LOCAL_DIR/ui/logoRegenboog.png
    gsettings set org.cinnamon.desktop.background picture-uri $URI
    gsettings set org.cinnamon.desktop.background picture-options stretched

    # No screen lock since it requires user password to log back in.
    gsettings set org.cinnamon.desktop.lockdown disable-lock-screen true
    gsettings set org.cinnamon.desktop.screensaver lock-enabled false
    gsettings set org.cinnamon.settings-daemon.plugins.power lock-on-suspend false
}

write_setup_user() {
    FILE=$LOCAL_DIR/setup_user.sh
    cat << EOF > $FILE
LOCAL_DIR=$LOCAL_DIR
$(declare -f setup_user)
setup_user
EOF
    chown leerling:leerling $FILE
    chmod 700 $FILE
    echo "Please run"
    echo $FILE
}

check_rootuser_or_die
download
install_updater
remove_packages
update_packages
install_google_chrome
write_setup_user
