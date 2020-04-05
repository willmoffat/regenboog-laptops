#! /bin/bash

# Update the zip file used to bootstrap a new laptop.

set -eu
cd "$(dirname "$0")"

CUR=$PWD/files.tgz
NEW=/tmp/files.tgz

cd root/
# Using 'z' option directly includes a timestamp which creates unnecessary
# git diffs, so we invoke gzip separately.
tar c . | gzip -n > $NEW
if [ ! -r $CUR ] || ! cmp $CUR $NEW ; then
    cp $NEW $CUR
    echo 'Updated:'
    ls -lh $CUR
fi
rm $NEW
