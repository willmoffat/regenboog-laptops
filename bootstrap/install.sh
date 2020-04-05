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
LOCAL_USER=leerling

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
    cp "55-regenboog.conf" /etc/rsyslog.d/
    systemctl daemon-reload
    systemctl enable "$TIMER"
    systemctl start "$TIMER"
    cd ..
}

setup_software_sources() {
    LIST=etc/apt/sources.list.d/official-package-repositories.list
    cp /$LIST /$LIST.orig
    cp $LIST /$LIST
}

# Check size of packages with:
# dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n
remove_packages() {
    # firefox - school needs Google Chrome, remove to reduce confusion.
    # thunderbird - webmail only
    # hexchat - no chat
    # tranmission - no torrents
    # backgrounds are 300MB.
    #   mint-backgrounds-tricia removes mint-artwork which is needed for the start menu.
    #   TODO(wdm) Remove 'mint-backgrounds-*'
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
    # Removes 600MB of packages.
}

update_packages() {
    apt update && apt upgrade -y || true
}

install_google_chrome() {
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
    echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
    apt update
    apt install -y google-chrome-stable
}

install_zoom() {
    cd /tmp
    curl -sL -O https://zoom.us/client/latest/zoom_amd64.deb
    apt install -y ./zoom_amd64.deb
    cd -
}

# Linux Mint has a simple auto-update system.
# See:
# https://github.com/linuxmint/mintupdate/blob/master/usr/bin/mintupdate-automation
# https://github.com/linuxmint/mintupdate/blob/master/usr/share/linuxmint/mintupdate/automation/index.json
enable_automatic_updates() {
    # Auto-update packages.
    mintupdate-automation upgrade enable
    # Remove old files.
    mintupdate-automation autoremove enable
}

remove_sudo() {
    if id -nG "$LOCAL_USER" | grep -qw sudo; then
        echo "Removing $LOCAL_USER from sudo group"
        deluser $LOCAL_USER sudo
    else
        echo "Already removed $LOCAL_USER from sudo"
    fi
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
    # Note(wdm) Now are have user passwords, so defaults are OK.
    # gsettings set org.cinnamon.desktop.lockdown disable-lock-screen true
    # gsettings set org.cinnamon.desktop.screensaver lock-enabled false
    # gsettings set org.cinnamon.settings-daemon.plugins.power lock-on-suspend false

    printf '

Install part 2 finished!
'
}

SETUP_FILE=$LOCAL_DIR/setup_user.sh
write_setup_user() {
    cat << EOF > $SETUP_FILE
LOCAL_DIR=$LOCAL_DIR
$(declare -f setup_user)
setup_user
EOF
    chown $LOCAL_USER:$LOCAL_USER $SETUP_FILE
    chmod 700 $SETUP_FILE
}

show_success() {
    printf "

===========================
| Install part 1 finished |
===========================

Now please run:

$SETUP_FILE
"
}

check_rootuser_or_die
download
install_updater
setup_software_sources
remove_packages
update_packages
install_google_chrome
install_zoom
apt install -y skypeforlinux
remove_sudo
write_setup_user
show_success
