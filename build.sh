#!/bin/bash

# Cleaning up
rm -rf .repo/local_manifests/

# Repo init rom
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault --depth=1
echo "=================="
echo "Repo init success"
echo "=================="


# Local manifests
git clone https://github.com/rwxrx-rx/local_manifest.git .repo/local_manifests -b Inf
echo "============================"
echo "Local manifest clone success"
echo "============================"


# Build Sync
/opt/crave/resync.sh
echo "============="
echo "Sync success"
echo "============="


# Set up build environment
source build/envsetup.sh
echo "============="

# Lunch
lunch infinity_haydn-user

# Build
m bacon

# Upload File
echo "Upload to GoFile will be started..."

ZIP=$(find out/target/product/haydn -maxdepth 1 -type f -name "*.zip" | head -n1)

if [ -n "$ZIP" ]; then
    wget -O upload.sh https://raw.githubusercontent.com/THE-EGO-999-GT/GoFile-Upload/master/upload.sh
    chmod +x upload.sh
    ./upload.sh "$ZIP"
else
    echo "No ZIP file found!"
fi

echo "finish_Upload"
