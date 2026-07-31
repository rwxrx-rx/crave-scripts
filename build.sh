#!/bin/bash

# ==========================================================
#              USER CONFIGURATION (EDIT HERE)
# ==========================================================
BOT_TOKEN="8904656935:AAFCTdVm05W61esurBpPf8nXdY8Lh7UxLyo"
CHAT_ID="-1003710648323"

DEVICE="camellia"
ROM_NAME="crDroid"
BRANCH="16.0" # Change to 16.0 when crDroid 16 branch is released
GITHUB_USER="rwxrx-rx"

# ==========================================================
#                   TELEGRAM BOT FUNCTIONS
# ==========================================================
send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "text=${message}" > /dev/null
}

# Trap Errors: Sends an automatic failure alert if any command fails
on_error() {
    local line_no=$1
    local msg="❌ <b>Build Failed!</b>%0A%0A"
    msg+="<b>ROM:</b> ${ROM_NAME}%0A"
    msg+="<b>Device:</b> ${DEVICE}%0A"
    msg+="<b>Failed at line:</b> ${line_no}"
    send_telegram "$msg"
    exit 1
}
trap 'on_error $LINENO' ERR

START_TIME=$(date +%s)

# ==========================================================
#              1. START NOTIFICATION
# ==========================================================
echo "--> Sending start notification to Telegram..."
send_telegram "🚀 <b>Build Started!</b>%0A%0A<b>ROM:</b> ${ROM_NAME}%0A<b>Device:</b> ${DEVICE} (Redmi Note 10 5G)%0A<b>Branch:</b> ${BRANCH}"

# ==========================================================
#          2. PREPARE LOCAL MANIFEST FOR CAMELLIA
# ==========================================================
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

# ==========================================================
#           3. REPO INIT & REPO SYNC
# ==========================================================
echo "--> Initializing repository..."
repo init -u https://github.com/crdroidandroid/android.git -b ${BRANCH} --git-lfs

echo "--> Syncing sources..."
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags

# ==========================================================
#              4. BUILD PROCESS
# ==========================================================
echo "--> Setting up environment and lunch target..."
source build/envsetup.sh
lunch crdroid_${DEVICE}-userdebug

echo "--> Starting compilation..."
m bacon

# ==========================================================
#          5. UPLOAD RESULT & SUCCESS NOTIFICATION
# ==========================================================
END_TIME=$(date +%s)
ELAPSED=$(( (END_TIME - START_TIME) / 60 ))

# Locate the compiled output ZIP inside the out directory
ZIP_PATH=$(find out/target/product/${DEVICE}/ -name "*${DEVICE}*.zip" ! -name "*ota*" | head -n 1)

if [ -f "$ZIP_PATH" ]; then
    ZIP_NAME=$(basename "$ZIP_PATH")
    ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

    echo "--> Uploading ${ZIP_NAME} to PixelDrain..."
    send_telegram "📤 <b>Build Finished!</b> Uploading ROM to PixelDrain..."

    # Upload to PixelDrain via API
    RESPONSE=$(curl -s -F "file=@${ZIP_PATH}" https://pixeldrain.com/api/file)
    FILE_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

    if [ -n "$FILE_ID" ]; then
        DOWNLOAD_URL="https://pixeldrain.com/u/${FILE_ID}"
        
        # Send Final Success Message
        SUCCESS_MSG="✅ <b>Build Successful!</b>%0A%0A"
        SUCCESS_MSG+="<b>ROM:</b> ${ROM_NAME}%0A"
        SUCCESS_MSG+="<b>Device:</b> ${DEVICE}%0A"
        SUCCESS_MSG+="<b>File Size:</b> ${ZIP_SIZE}%0A"
        SUCCESS_MSG+="<b>Build Time:</b> ${ELAPSED} minutes%0A%0A"
        SUCCESS_MSG+="🔗 <b>Download Link:</b>%0A${DOWNLOAD_URL}"
        
        send_telegram "$SUCCESS_MSG"
        echo "--> Success! Link: ${DOWNLOAD_URL}"
    else
        send_telegram "⚠️ Build succeeded (${ZIP_NAME}), but failed to upload to PixelDrain."
    fi
else
    send_telegram "❌ Build finished, but no .zip file was found in the output directory."
fi
