#!/bin/bash

#
# Script For Building crDroid 16.0 (Android 16) - Poco M3 Pro 5G (camellia)
#
set -o pipefail

# ================= CONFIGS & ENV =================
# Jika menggunakan file .env, pastikan file tersebut ada di folder yang sama
[ -f .env ] && source .env

# Variabel Utama Target Build
DEVICE="camellia"
ROM_NAME="crDroid"
ANDROID_VERSION="16.0"
PROJECT_VERSION="v12.x"
BUILD_TYPE="userdebug"
BUILD_FLAVOUR="GAPPS"

# Jika tidak pakai .env, kamu bisa isi langsung di sini:
BOT_TOKEN="${BOT_TOKEN:-YOUR_TELEGRAM_BOT_TOKEN}"
CHAT_ID="${CHAT_ID:-YOUR_TELEGRAM_CHAT_ID}"
UPLOAD_CHAT_ID="${UPLOAD_CHAT_ID:-$CHAT_ID}"
PIXELDRAIN="${PIXELDRAIN:-YOUR_PIXELDRAIN_API_KEY}"

# Directories & Time
OUT_DIR="out/target/product/${DEVICE}"
START_TIME=$(date +%s)
BUILD_LOG="build.log"
ERROR_LOG="out/error.log"

# ================= TIMEZONE =================
echo "🕒 Switching system timezone to Asia/Jakarta (WIB)"
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
echo "🕒 Current system time: $(date)"

# ================= JQ DEPENDENCY =================
if ! command -v jq &> /dev/null; then
    mkdir -p ~/bin
    curl -L -o ~/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64
    chmod +x ~/bin/jq
    export PATH=$HOME/bin:$PATH
fi

# ================= TELEGRAM FUNCTIONS =================
tg_send() {
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d parse_mode="Markdown" \
        -d disable_web_page_preview="true" \
        -d text="$1" >/dev/null
}

tg_send_id() {
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d parse_mode="Markdown" \
        -d disable_web_page_preview="true" \
        -d text="$1" | jq -r '.result.message_id'
}

tg_edit() {
    local MSG_ID="$1"
    local TEXT="$2"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
        -d chat_id="${CHAT_ID}" \
        -d message_id="${MSG_ID}" \
        -d parse_mode="Markdown" \
        -d disable_web_page_preview="true" \
        -d text="$TEXT" >/dev/null
}

tg_upload() {
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${UPLOAD_CHAT_ID}" \
        -d parse_mode="Markdown" \
        -d disable_web_page_preview="true" \
        -d text="$1" >/dev/null
}

tg_log() {
    local FILE="$1"
    local CAPTION="$2"

    curl -s -F "chat_id=${UPLOAD_CHAT_ID}" \
         -F "document=@${FILE}" \
         -F "caption=${CAPTION}" \
         "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" >/dev/null
}

# ================= LIVE MONITOR =================
format_time() {
    local SECS=$1
    local h=$(( SECS / 3600 ))
    local m=$(( (SECS % 3600) / 60 ))
    local s=$(( SECS % 60 ))

    if [ "$h" -gt 0 ]; then
        echo "${h}hr ${m}min ${s}s"
    else
        echo "${m}min ${s}s"
    fi
}

get_stats() {
    read -r _ u1 n1 s1 i1 w1 irq1 sirq1 st1 _ < /proc/stat
    sleep 1
    read -r _ u2 n2 s2 i2 w2 irq2 sirq2 st2 _ < /proc/stat

    idle1=$((i1 + w1))
    idle2=$((i2 + w2))
    total1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1 + st1))
    total2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2 + st2))

    diff_idle=$((idle2 - idle1))
    diff_total=$((total2 - total1))

    local CPU=0
    if [ "$diff_total" -gt 0 ]; then
        CPU=$(( 100 * (diff_total - diff_idle) / diff_total ))
    fi

    MEM_USED=$(free -m | awk '/Mem:/ {printf "%.1f", $3/1024}')
    MEM_TOTAL=$(free -m | awk '/Mem:/ {printf "%.1f", $2/1024}')
    LOAD=$(cut -d' ' -f1 /proc/loadavg)
    echo "$CPU|$MEM_USED|$MEM_TOTAL|$LOAD"
}

tg_send_with_button() {
    local TEXT="$1"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d parse_mode="Markdown" \
        -d disable_web_page_preview="true" \
        -d text="$TEXT" \
        -d reply_markup='{
          "inline_keyboard": [[
            {"text": "🔄 Refresh Info", "callback_data": "refresh"}
          ]]
        }' | jq -r '.result.message_id'
}

tg_edit_with_button() {
    local MSG_ID="$1"
    local TEXT="$2"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
        -d chat_id="${CHAT_ID}" \
        -d message_id="${MSG_ID}" \
        -d parse_mode="Markdown" \
        -d disable_web_page_preview="true" \
        -d text="$TEXT" \
        -d reply_markup='{
          "inline_keyboard": [[
            {"text": "🔄 Refresh Info", "callback_data": "refresh"}
          ]]
        }' > /dev/null
}

listen_refresh() {
    local LABEL="$1"
    local MSG_ID="$2"
    local PHASE_START="$3"
    local OFFSET=0

    while true; do
        UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}")
        COUNT=$(echo "$UPDATES" | jq '.result | length')

        if [ "$COUNT" -gt 0 ]; then
            for ((i=0; i<COUNT; i++)); do
                UPDATE=$(echo "$UPDATES" | jq -c ".result[$i]")
                UPDATE_ID=$(echo "$UPDATE" | jq '.update_id')
                OFFSET=$((UPDATE_ID + 1))

                CALLBACK=$(echo "$UPDATE" | jq -r '.callback_query.data // empty')
                MSG_ID=$(echo "$UPDATE" | jq -r '.callback_query.message.message_id // empty')

                if [ "$CALLBACK" = "refresh" ]; then
                    CALLBACK_ID=$(echo "$UPDATE" | jq -r '.callback_query.id // empty')

                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery" \
                         -d callback_query_id="$CALLBACK_ID" > /dev/null

                    STATS=$(get_stats)
                    CPU=$(echo "$STATS" | cut -d'|' -f1)
                    MEM_USED=$(echo "$STATS" | cut -d'|' -f2)
                    MEM_TOTAL=$(echo "$STATS" | cut -d'|' -f3)
                    LOAD=$(echo "$STATS" | cut -d'|' -f4)

                    ELAPSED=$(( $(date +%s) - PHASE_START ))
                    CONSOLE=$(grep -v '^\s*$' "$BUILD_LOG" 2>/dev/null | tail -n1 | cut -c1-110)
                    NOW_LOCAL=$(date +"%I:%M %p")

                    tg_edit_with_button "$MSG_ID" "📢 Building *${ROM_NAME} ${ANDROID_VERSION}* for *${DEVICE}*
🧪 Build Type: *${BUILD_TYPE}*

*Server Stats*
📊 CPU: ${CPU}%
🌡️ Load: ${LOAD}
📈 RAM: ${MEM_USED} GB / ${MEM_TOTAL} GB

⏳ Elapsed: $(format_time "$ELAPSED")
⚡ Status: Compiling...
📟 Console: \`${CONSOLE}\`

🔄 Last Refreshed: ${NOW_LOCAL}"
                fi
            done
        fi

        sleep 2
    done
}

# ================= UPLOADERS =================
pixeldrain_upload() {
    local FILE="$1"

    if [ -f "$FILE" ]; then
        RESPONSE=$(curl -s -u ":$PIXELDRAIN" -F "file=@$FILE" https://pixeldrain.com/api/file)
        FILE_ID=$(echo "$RESPONSE" | jq -r '.id')

        if [[ "$FILE_ID" != "null" && -n "$FILE_ID" ]]; then
            echo "https://pixeldrain.com/u/$FILE_ID"
            return
        fi
    fi

    return 1
}

gofile_upload() {
    local FILE="$1"

    RESP=$(curl -s -F "file=@${FILE}" "https://upload.gofile.io/uploadfile")
    LINK=$(echo "$RESP" | jq -r '.data.downloadPage // empty')

    if [ -n "$LINK" ]; then
        echo "$LINK"
        return 0
    fi

    return 1
}

# ================= ON FAIL =================
on_fail() {
    tg_edit "$STATUS_MSG_ID" "💥 *Build Failed!*
📜 Check build logs"

    [ -f "$ERROR_LOG" ] && tg_log "$ERROR_LOG" "${DEVICE} ⋄ Error Log"

    exit 1
}

# ================= MAIN WORKFLOW =================
tg_send "┌───────────────────┐
🤖 *Buildbot* initialized for
🛸 *${ROM_NAME} ${ANDROID_VERSION}*
└───────────────────┘
📱 Device: *${DEVICE}*
🧪 Type: *${BUILD_TYPE}*
🌏 _$(date +"%d %b %Y %I:%M %p WIB")_"

echo ">>>> [STEP 1] Cleaning old manifests"
rm -rf .repo/local_manifests

echo ">>>> [STEP 2] Repo Init crDroid 16.0"
repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --depth=1

echo ">>>> [STEP 3] Cloning Local Manifests"
git clone -b main https://github.com/rwxrx-rx/local_manifest .repo/local_manifests

echo ">>>> [STEP 4] Repo Sync"
SYNC_START=$(date +%s)

if [ -f /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh
elif [ -f /usr/bin/resync ]; then
    /usr/bin/resync
else
    repo sync -c --force-sync --no-tags --no-clone-bundle -j$(nproc --all)
fi

SYNC_END=$(date +%s)
SYNC_DIFF=$((SYNC_END - SYNC_START))

if [ $SYNC_DIFF -ge 3600 ]; then
    SYNC_TIME="$((SYNC_DIFF/3600))hr $(((SYNC_DIFF%3600)/60))min"
else
    SYNC_TIME="$((SYNC_DIFF/60)) min"
fi

echo ">>>> [STEP 5] Setup Build Environment"
. build/envsetup.sh

# Lunch Target crDroid 16 untuk camellia (Platform bp4a)
lunch crdroid_camellia-bp4a-${BUILD_TYPE}

export BUILD_USERNAME=${USER:-akbar}
export BUILD_HOSTNAME=crave

# Bersihkan out folder secara aman di Crave
make installclean

touch "$BUILD_LOG"

STATUS_MSG_ID=$(tg_send_with_button "⌛️ RepoSync took ${SYNC_TIME}
🔄 Tap Refresh Info for live stats!")

# Jalankan listener live monitor di background
listen_refresh "Building ${DEVICE}" "$STATUS_MSG_ID" "$START_TIME" &
LISTENER_PID=$!

# ================= BUILD RUN =================
echo ">>>> [STEP 6] Compiling ROM"
m bacon 2>&1 | tee "$BUILD_LOG"
BUILD_STATUS=${PIPESTATUS[0]}

# Hentikan listener monitor setelah build selesai
kill "$LISTENER_PID" 2>/dev/null
wait "$LISTENER_PID" 2>/dev/null

if [ "$BUILD_STATUS" -ne 0 ]; then
    on_fail
fi

if grep -q -E "ninja failed|failed to build some targets" "$BUILD_LOG"; then
    on_fail
fi

# ================= SUCCESS & UPLOAD =================
END_TIME=$(date +%s)
DUR=$((END_TIME - START_TIME))

if [ $DUR -ge 3600 ]; then
    BUILD_TIME="$((DUR/3600))h $(((DUR%3600)/60))min"
else
    BUILD_TIME="$((DUR/60)) min"
fi

ROM_ZIP=$(ls -t "${OUT_DIR}"/*.zip 2>/dev/null | head -n 1)

if [ -z "$ROM_ZIP" ]; then
    on_fail
fi

BUILD_ID=$(basename "$ROM_ZIP" .zip)
ROM_SIZE=$(du -h "$ROM_ZIP" | awk '{print $1}')

tg_edit "$STATUS_MSG_ID" "┌───────────────────┐
     🎉 Buildbot finished its job
└───────────────────┘
🆔 \`${BUILD_ID}\`
🧩 Build size: *${ROM_SIZE}*
⏳ Compilation took *${BUILD_TIME}*

📤 Uploading artifacts..."

echo ">>>> [STEP 7] Uploading Artifacts"

UPLOAD_MSG=""
IMG_MSG=""
JSON_MSG=""

# Upload ROM Zip
GO_URL=$(gofile_upload "$ROM_ZIP")
PD_URL=$(pixeldrain_upload "$ROM_ZIP")

[ -n "$GO_URL" ] && UPLOAD_MSG="${UPLOAD_MSG}[GoFile](${GO_URL})\n"
[ -n "$PD_URL" ] && UPLOAD_MSG="${UPLOAD_MSG}[PixelDrain](${PD_URL})\n"

# Upload Images (boot, recovery, etc.)
for IMG in boot.img vendor_boot.img init_boot.img super_empty.img recovery.img; do
    FILEPATH="${OUT_DIR}/${IMG}"
    if [ -f "$FILEPATH" ]; then
        LINK=$(gofile_upload "$FILEPATH")
        [ -n "$LINK" ] && IMG_MSG="${IMG_MSG}[${IMG}](${LINK})\n"
    fi
done

# Upload OTA JSON
declare -A UPLOADED
JSON_CANDIDATES=(
    "${OUT_DIR}/${DEVICE}.json"
    "${ROM_ZIP}.json"
)

shopt -s nullglob
for CAND in "${JSON_CANDIDATES[@]}"; do
    if [ -f "$CAND" ]; then
        if [ -z "${UPLOADED[$CAND]:-}" ]; then
            GO_URL=$(gofile_upload "$CAND")
            if [ -n "$GO_URL" ]; then
                JSON_MSG="${JSON_MSG}[${CAND##*/}](${GO_URL})\n"
                UPLOADED["$CAND"]=1
            fi
        fi
    fi
done
shopt -u nullglob

# Send Final Message to Telegram
FINAL_MESSAGE="
✦ *${ROM_NAME} ${ANDROID_VERSION} Artifacts*
────────────────
📱 Device: *${DEVICE}*
🆔 \`${BUILD_ID}\`

📦 *ROM*
$(echo -e "$UPLOAD_MSG")"

if [ -n "$IMG_MSG" ]; then
    FINAL_MESSAGE="${FINAL_MESSAGE}

🧩 *Images*
$(echo -e "$IMG_MSG")"
fi

if [ -n "$JSON_MSG" ]; then
    FINAL_MESSAGE="${FINAL_MESSAGE}

📜 *JSON*
$(echo -e "$JSON_MSG")"
fi

tg_upload "$FINAL_MESSAGE"

tg_edit "$STATUS_MSG_ID" "┌───────────────────┐
     🎉 Buildbot finished its job
└───────────────────┘
🆔 \`${BUILD_ID}\`
🧩 Build size: *${ROM_SIZE}*
⏳ Compilation took *${BUILD_TIME}*

✅ Artifacts uploaded successfully!"

exit 0
