#!/bin/bash
set -e # Stop script immediately if any command fails

# ==========================================================
#              CONFIGURATION (EDIT YOUR DETAILS)
# ==========================================================
DEVICE="camellia"
ROM_NAME="crDroid"
BRANCH="16.0"
GITHUB_USER="rwxrx-rx"

echo "=========================================="
echo "   Starting Build: ${ROM_NAME} for ${DEVICE}   "
echo "=========================================="

# 1. Prepare Local Manifest
echo "--> Creating Local Manifest..."
mkdir -p .repo/local_manifests
cat << EOF > .repo/local_manifests/camellia.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <project path="device/xiaomi/camellia" name="${GITHUB_USER}/device_xiaomi_camellia" remote="github" revision="${BRANCH}" />
    <project path="vendor/xiaomi/camellia" name="${GITHUB_USER}/vendor_xiaomi_camellia" remote="github" revision="${BRANCH}" />
    <project path="kernel/xiaomi/camellia" name="${GITHUB_USER}/android_kernel_xiaomi_camellia" remote="github" revision="${BRANCH}" />
    <project path="hardware/mediatek" name="${GITHUB_USER}/android_hardware_mediatek" remote="github" revision="${BRANCH}" />
</manifest>
EOF

# 2. Repo Init & Sync
echo "--> Initializing repository and syncing sources..."
repo init -u https://github.com/crdroidandroid/android.git -b ${BRANCH} --git-lfs
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags

# 3. Build Process
echo "--> Setting up environment and lunch target..."
source build/envsetup.sh
lunch crdroid_${DEVICE}-userdebug

echo "--> Starting compilation..."
m bacon

# 4. Check & Upload to PixelDrain
echo "--> Checking build output..."
ZIP_PATH=$(find out/target/product/${DEVICE}/ -name "*${DEVICE}*.zip" ! -name "*ota*" | head -n 1)

if [ -f "$ZIP_PATH" ]; then
    ZIP_NAME=$(basename "$ZIP_PATH")
    ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

    echo "=========================================="
    echo " Build Successful: ${ZIP_NAME} (${ZIP_SIZE})"
    echo "=========================================="
    echo "--> Uploading to PixelDrain..."

    RESPONSE=$(curl -s -F "file=@${ZIP_PATH}" https://pixeldrain.com/api/file)
    FILE_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

    if [ -n "$FILE_ID" ]; then
        echo ""
        echo "=========================================="
        echo "  🎉 YOUR ROM DOWNLOAD LINK:"
        echo "  https://pixeldrain.com/u/${FILE_ID}"
        echo "=========================================="
        echo ""
    else
        echo "⚠️ Upload failed, but file is saved locally at: ${ZIP_PATH}"
    fi
else
    echo "❌ Error: ROM .zip file was not found!"
    exit 1
fi
