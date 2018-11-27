#!/bin/bash

set -x
set -e

function cleanup {
    # clean up the tmpdir
    rm -rf $tmpdir
}
trap cleanup EXIT

git_remote=origin
git_branch=master

# Change to the dir where the script is located
cd "$(dirname "$0")"

# Pull from git first to make sure everything is up to date
git pull $git_remote $git_branch

if [ $? -ne 0 ]; then
    echo -n "$(date) " | tee -a log.txt
    echo "[WARRNING]: Have troubble when pulling from the reposiotry." | tee -a log.txt
    exit 1
fi

rootdir=$(pwd)
tmpdir=$(mktemp -d)

# Get the json file containing the info about latest apk
jsonURL="https://updates.signal.org/android/latest.json"
wget -O $tmpdir/latest.json $jsonURL

# Extra info from the json file
apkURL=$(cat $tmpdir/latest.json | python3 -c "import sys, json; print(json.load(sys.stdin)['url'], end='')")
checksum256=$(cat $tmpdir/latest.json | python3 -c "import sys, json; print(json.load(sys.stdin)['sha256sum'], end='')")
latest_version=$(cat $tmpdir/latest.json | python3 -c "import sys, json; print(json.load(sys.stdin)['versionName'], end='')")
current_version=$(cat $rootdir/latest.json | python3 -c "import sys, json; print(json.load(sys.stdin)['versionName'], end='')")

if [ "$latest_version" == "$current_version" ]; then
    echo "[NOTICE]: The apk file is already up-to-date." | tee -a log.txt
    exit 0
fi

# Get the latest apk file
wget -O $tmpdir/Signal-website-release-latest.apk $apkURL

# Make a checksum file
echo -n $checksum256 > $tmpdir/Signal-website-release-latest.apk.sha256
echo -n "  " >> $tmpdir/Signal-website-release-latest.apk.sha256
echo "Signal-website-release-latest.apk" >> $tmpdir/Signal-website-release-latest.apk.sha256

# Check integrity against the downloaded file
cd $tmpdir
sha256sum -c $tmpdir/Signal-website-release-latest.apk.sha256

if [ $? -ne 0 ]; then
    echo -n "$(date) " | tee -a log.txt
    echo "[WARRNING]: The apk file is corrupted." | tee -a log.txt
    exit 1
fi

# Check certificate against the apk file
jarsigner -verify -certs $tmpdir/Signal-website-release-latest.apk

if [ $? -ne 0 ]; then
    echo -n "$(date) " | tee -a log.txt
    echo "[WARRNING]: The apk file failed in verification." | tee -a log.txt
    exit 1
fi

# Overwritten the old files with the latest one
mv $tmpdir/Signal-website-release-latest.apk.sha256 $rootdir/Signal-website-release-latest.apk.sha256
mv $tmpdir/Signal-website-release-latest.apk $rootdir/Signal-website-release-latest.apk
mv $tmpdir/latest.json $rootdir/latest.json

# Publish the code

cd $rootdir
git add $rootdir/Signal-website-release-latest.apk.sha256 $rootdir/Signal-website-release-latest.apk $rootdir/latest.json

git commit -m "Update to Signal $latest_version"

git push $remote $branch
