#!/bin/bash

# Cleaning up local manifests
rm -rf .repo/local_manifests/

# Repo init ROM (Project Infinity-X - Android 16)
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault --depth=1
echo "=================="
echo "Repo init success"
echo "=================="

# Local manifests untuk camellia
git clone https://github.com/rwxrx-rx/local_manifest.git .repo/local_manifests -b Inf
echo "============================"
echo "Local manifest clone success"
echo "============================"

# Build Sync via Crave
if [ -f /opt/crave/resync.sh ]; then
  /opt/crave/resync.sh
else
  repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
fi
echo "============="
echo "Sync success"
echo "============="

# Set up build environment
source build/envsetup.sh
echo "============="

# Lunch target khusus camellia
lunch infinity_camellia-ap4a-userdebug || lunch infinity_camellia-userdebug || lunch infinity_camellia-user

# Start Build Process
m bacon

# Upload File to Pixeldrain (Anonymous)
echo "Upload to Pixeldrain will be started..."

ZIP=$(find out/target/product/camellia -maxdepth 1 -type f -name "*.zip" | head -n1)

if [ -n "$ZIP" ]; then
    echo "Uploading $ZIP to Pixeldrain..."
    
    # Kirim request POST ke API Pixeldrain
    RESPONSE=$(curl -s -F "file=@$ZIP" https://pixeldrain.com/api/file)
    
    # Ambil ID file dari response JSON
    FILE_ID=$(echo "$RESPONSE" | jq -r .id 2>/dev/null)
    
    # Fallback parsing jika jq tidak terinstall di server
    if [ -z "$FILE_ID" ] || [ "$FILE_ID" = "null" ]; then
        FILE_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    fi

    if [ -n "$FILE_ID" ] && [ "$FILE_ID" != "null" ]; then
        echo "=================================================="
        echo "Upload Success!"
        echo "Download Link: https://pixeldrain.com/u/$FILE_ID"
        echo "=================================================="
    else
        echo "Upload failed! Raw response:"
        echo "$RESPONSE"
    fi
else
    echo "No ZIP file found!"
fi

echo "finish_Upload"
