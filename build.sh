#!/bin/bash

# ==============================================================================
# 0. Load Environment Variables & Telegram Helper Functions
# ==============================================================================
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "Warning: File .env tidak ditemukan! Notifikasi Telegram akan dilewati."
fi

send_telegram() {
    local MSG="$1"
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d "chat_id=${CHAT_ID}" \
            -d "text=${MSG}" \
            -d "parse_mode=HTML" > /dev/null
    fi
}

send_telegram_file() {
    local FILE="$1"
    local CAPTION="$2"
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ] && [ -f "$FILE" ]; then
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
            -F "chat_id=${CHAT_ID}" \
            -F "document=@${FILE}" \
            -F "caption=${CAPTION}" \
            -F "parse_mode=HTML" > /dev/null
    fi
}

START_TIME=$(date +%s)
send_telegram "🚀 <b>Build crDroid 16 Started!</b>%0ADevice: <code>camellia</code>%0ADate: <code>$(date '+%Y-%m-%d %H:%M:%S')</code>"

# ==============================================================================
# 1. Bersihkan manifest lokal lama
# ==============================================================================
rm -rf .repo/local_manifests/

# ==============================================================================
# 2. Repo Init crDroid Android 16
# ==============================================================================
repo init --no-repo-verify --git-lfs -u https://github.com/crdroidandroid/android.git -b 16.0 -g default,-mips,-darwin,-notdefault --depth=1
echo "=============================="
echo "Repo init crDroid A16 success"
echo "=============================="

# ==============================================================================
# 3. Clone Local Manifest khusus camellia
# ==============================================================================
git clone https://github.com/rwxrx-rx/local_manifest.git .repo/local_manifests -b main
echo "============================"
echo "Local manifest clone success"
echo "============================"

# ==============================================================================
# 4. Sinkronisasi Source Code via Crave Engine
# ==============================================================================
if [ -f /opt/crave/resync.sh ]; then
  /opt/crave/resync.sh
else
  repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
fi
echo "============="
echo "Sync success"
echo "============="

# ==============================================================================
# 5. Penanganan Error Log & Sisa Build Sebelumnya
# ==============================================================================
if [ -f out/error.log ]; then
  grep '^FAILED: //' out/error.log | sed -E 's|^FAILED: //([^:]+):.*|out/soong/.intermediates/\1|' | sort -u | while read -r d; do rm -rf "$d" && echo "Removed: $d"; done
  rm -rf out/target/product/camellia
fi

# ==============================================================================
# 6. Setup Environment Build
# ==============================================================================
source build/envsetup.sh
export TZ=Asia/Jakarta
echo "======================"
echo "Env setup success"
echo "======================"

# ==============================================================================
# 7. Selection Target Lunch crDroid Camellia
# ==============================================================================
lunch crdroid_camellia-ap4a-userdebug || lunch crdroid_camellia-userdebug || lunch crdroid_camellia-user

# Bersihkan sisa kompilasi target ringan
make installclean

send_telegram "⚙️ <b>Sync & Setup Completed. Starting Compilation...</b>"

# ==============================================================================
# 8. Proses Compiling ROM crDroid
# ==============================================================================
if mka bacon; then
    BUILD_SUCCESS=1
else
    BUILD_SUCCESS=0
fi

# Calculate duration
END_TIME=$(date +%s)
DIFF_TIME=$((END_TIME - START_TIME))
BUILD_DURATION="$((DIFF_TIME / 3600))h $(((DIFF_TIME % 3600) / 60))m $((DIFF_TIME % 60))s"

# ==============================================================================
# 9. Upload & Handling Result
# ==============================================================================
if [ "$BUILD_SUCCESS" -eq 1 ]; then
    echo "=========================================="
    echo "Starting upload process to Pixeldrain..."
    echo "=========================================="
    
    ZIP=$(find out/target/product/camellia -maxdepth 1 -type f \( -name "crDroidAndroid*.zip" -o -name "*camellia*.zip" \) | head -n1)

    if [ -n "$ZIP" ]; then
        echo "Uploading $ZIP to Pixeldrain..."
        RESPONSE=$(curl -s -F "file=@$ZIP" https://pixeldrain.com/api/file)
        FILE_ID=$(echo "$RESPONSE" | jq -r .id 2>/dev/null)
        
        if [ -z "$FILE_ID" ] || [ "$FILE_ID" = "null" ]; then
            FILE_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
        fi

        if [ -n "$FILE_ID" ] && [ "$FILE_ID" != "null" ]; then
            DL_LINK="https://pixeldrain.com/u/$FILE_ID"
            FILE_NAME=$(basename "$ZIP")
            FILE_SIZE=$(du -h "$ZIP" | cut -f1)

            echo "=================================================="
            echo "Upload Success! 🎉"
            echo "Download Link: $DL_LINK"
            echo "=================================================="

            send_telegram "🎉 <b>crDroid 16 Build Finished Successfully!</b>%0A%0A📱 <b>Device:</b> <code>camellia</code>%0A📁 <b>File:</b> <code>${FILE_NAME}</code>%0A📊 <b>Size:</b> <code>${FILE_SIZE}</code>%0A⏱ <b>Duration:</b> <code>${BUILD_DURATION}</code>%0A%0A🔗 <a href=\"${DL_LINK}\">Download ZIP</a>"
        else
            echo "Upload failed! Raw response:"
            echo "$RESPONSE"
            send_telegram "⚠️ <b>Build Success</b> but Upload to Pixeldrain Failed.%0A⏱ Duration: <code>${BUILD_DURATION}</code>"
        fi
    else
        echo "No ZIP file found in out/target/product/camellia!"
        send_telegram "⚠️ <b>Build Success</b> but output ZIP file was not found.%0A⏱ Duration: <code>${BUILD_DURATION}</code>"
    fi
else
    echo "=========================================="
    echo "Build Failed!"
    echo "=========================================="
    
    send_telegram "❌ <b>Build Failed!</b>%0A📱 Device: <code>camellia</code>%0A⏱ Duration: <code>${BUILD_DURATION}</code>"
    
    # Kirimkan file log jika build error
    if [ -f out/error.log ]; then
        send_telegram_file "out/error.log" "❌ Build Error Log (camellia)"
    fi
fi

echo "Process Finished."
