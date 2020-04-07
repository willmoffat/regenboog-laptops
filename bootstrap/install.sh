#! /bin/bash

# After download this installs the custom files and starts
# services. Runs as root in $TMP_DIR

# For testing without using GitHub use:
# BS=http://xxx.ngrok.io/bootstrap
# curl -sL $BS/install.sh | bash -s Will $BS/files.tgz

# Download files from GitHub.
REMOTE=https://raw.githubusercontent.com/willmoffat/regenboog-laptops/master
DEFAULT_TARBALL=$REMOTE/bootstrap/files.tgz
REMOTE_TARBALL=${2-$DEFAULT_TARBALL}

LOCAL_TARBALL=/tmp/files.tgz
LOCAL_USER=leerling

set -eu

GEEK="${1:-}"
if [ "$GEEK" == "" ] ; then
    echo "Error: Name is required for inventory form"
    exit 1
fi

# Don't use NL for tool output. Makes it easier to grep.
export LANGUAGE=en_US.UTF-8

check_rootuser_or_die() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root"
        exit 1
    fi
    if [ ! -d /home/$LOCAL_USER ]; then
        echo "Error $LOCAL_USER not setup"
        exit 1
    fi
}

download() {
    curl -s -o $LOCAL_TARBALL $REMOTE_TARBALL
    cd /
    tar xfv $LOCAL_TARBALL
}

install_updater() {
    NAME=regenboog-update
    SERVICE="$NAME.service"
    TIMER="$NAME.timer"

    systemctl daemon-reload
    systemctl enable "$TIMER"
    systemctl start "$TIMER"
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
    LIST=/etc/apt/sources.list.d/google-chrome.list
    if [ ! -r $LIST ] ; then
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
        echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > $LIST
        apt update
    fi
    apt install -y google-chrome-stable

    # Add Desktop shortcut
    SHORTCUT=/home/$LOCAL_USER/Bureaublad/google-chrome.desktop
    cp /usr/share/applications/google-chrome.desktop $SHORTCUT
    chown $LOCAL_USER:$LOCAL_USER $SHORTCUT
    chmod a+x $SHORTCUT
}

install_zoom() {
    if [ -r /usr/bin/zoom ] ; then
       echo 'Zoom already installed'
       return
    fi
    TMP_DEB=/tmp/zoom_amd64.deb
    curl -sL -o $TMP_DEB https://zoom.us/client/latest/zoom_amd64.deb
    apt install -y $TMP_DEB
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

# Send to https://docs.google.com/spreadsheets/d/1K6yCXS1v6yj8uXx8VXz95tTuIZKX7cbApuVadkcW2dE
send_inventory() {
    set +e # Don't stop for errors in this function.

    # Find the device mounted on /
    # Trim the last character (the partition digit)
    rootdev=$(mount | grep ' on / ' | cut -d' ' -f1)
    dev=${rootdev::-1}

    # HOSTNAME - set during Linux install
    MODEL=$(dmidecode -s system-product-name)
    BIOS_DATE=$(dmidecode -s bios-release-date)
    SERIAL=$(dmidecode -s system-serial-number)
    MAC=$(cat /sys/class/net/wl*/address)
    CORES=$(cat /proc/cpuinfo  | grep processor | wc -l)
    CPU=$(dmidecode -s processor-version)
    RAM=$(dmidecode -t 17 | grep "Size.*MB" | awk '{s+=$2} END {print s / 1024}')
    DISK=$(lsblk  --output SIZE -n -d $dev)
    BATTERY_CAPACITY=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0  | grep capacity | cut -d: -f2 | sed 's/ //g')
    BOOT_TIME=$(systemd-analyze time | head -1 | cut -d' ' -f10)
    # GEEK - typed by user
    printf '%s' "
HOSTNAME=$HOSTNAME
MODEL=$MODEL
BIOS_DATE=$BIOS_DATE
SERIAL=$SERIAL
MAC=$MAC
CORES=$CORES
CPU=$CPU
RAM=$RAM
DISK=$DISK
BATTERY_CAPACITY=$BATTERY_CAPACITY
BOOT_TIME=$BOOT_TIME
GEEK=$GEEK
"
    # The entry numbers come from the pre-fill link:
    # https://docs.google.com/forms/d/1whIxQAbOKrA3P-gIemGjeanjEIMZQrHSy7HpH8Sj8T4/prefill

    FORM='1FAIpQLSedHoX6hK3nwCpTrKg3ZJuweRzxn3wcnpnReAg4-sNs-Cmu2Q'
    URL=https://docs.google.com/forms/d/e/$FORM/formResponse

    # Post to Google Form.
    # Only show status code
    curl $URL \
         -s -o /dev/null -w "%{http_code}" \
         -d ifq \
         -d entry.1814162735="$HOSTNAME" \
         -d entry.1215446301="$MODEL" \
         -d entry.2045176631="$BIOS_DATE" \
         -d entry.1669587106="$SERIAL" \
         -d entry.1946320022="$MAC" \
         -d entry.2025752678="$CORES" \
         -d entry.1375974966="$CPU" \
         -d entry.1262751032="$RAM" \
         -d entry.1323787092="$DISK" \
         -d entry.146454854="$BATTERY_CAPACITY" \
         -d entry.485034353="$BOOT_TIME" \
         -d entry.1744186849="$GEEK" \
         -d submit=Submit

    set -e
}

# Setup UI options.
# You can find the names of these options by setting them using the Linux Mint UI
# and then running
#    dconf dump / > /tmp/conf

# This function is written out using declare to be run as the user (not root).
# Variables must be local to function or echo-ed below.
setup_user() {
    # Desktop
    URI=file:///regenboog/logoRegenboog.png
    gsettings set org.cinnamon.desktop.background picture-uri $URI
    gsettings set org.cinnamon.desktop.background picture-options stretched

    # No screen lock since it requires user password to log back in.
    # Note(wdm) Now are have user passwords, so defaults are OK.
    # gsettings set org.cinnamon.desktop.lockdown disable-lock-screen true
    # gsettings set org.cinnamon.desktop.screensaver lock-enabled false
    # gsettings set org.cinnamon.settings-daemon.plugins.power lock-on-suspend false

    printf '

============================
| Install part 2 finished! |
============================

'
}

# We generate this file so that we don't have to update the tarball on each change.
SETUP_FILE=/regenboog/setup_user.sh
write_setup_user() {
    cat << EOF > $SETUP_FILE
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
remove_packages
update_packages
install_google_chrome
install_zoom
apt install -y skypeforlinux
remove_sudo
write_setup_user
send_inventory
show_success
