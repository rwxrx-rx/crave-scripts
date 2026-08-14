#!/bin/bash

# =================================================
#  Konfigurasi Notifikasi Telegram & Upload Pixeldrain
# =================================================
TG_TOKEN="$1"
TG_CHAT_ID="$2"

if [ -z "$TG_TOKEN" ] \vert{}\vert{} [ -z "$TG_CHAT_ID" ]; then
    echo "=> ERROR: TG_TOKEN atau TG_CHAT_ID kosong! Pastikan GitHub Secrets sudah dikirim."
    exit 1
fi

function send_tg() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" \
        -d "text=$1" > /dev/null
}

echo "================================================="
echo "      crDroid (Android 16) Crave Build Script    "
echo "      Target: camellia (Redmi Note 10 5G)        "
echo "================================================="

send_tg "🚀 <b>[CRAVE CI/CD] Build Started!</b>%0A%0A📱 <b>Device:</b> camellia%0A🤖 <b>ROM:</b> crDroid (Android 16)%0A👨‍💻 <b>Builder:</b> @rwxrx-rx"

# 1. Inisialisasi Repositori
echo "-> [1/6] Initializing crDroid Repo..."
repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --depth=1

# 2. Injeksi Local Manifest
echo "-> [2/6] Injecting Local Manifest..."
mkdir -p .repo/local_manifests
rm -rf .repo/local_manifests/camellia_manifest.xml

cat << 'EOF' > .repo/local_manifests/camellia_manifest.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="cristidclxvi/android_device_xiaomi_camellia" path="device/xiaomi/camellia" remote="github" revision="lineage-23.2" />
  <project name="cristidclxvi/android_kernel_xiaomi_camellia" path="kernel/xiaomi/camellia" remote="github" revision="lineage-23.2" />
  <project name="cristidclxvi/android_kernel_modules_xiaomi_camellia" path="kernel/xiaomi/vendor" remote="github" revision="lineage-23.2" />
  <project name="LineageOS/android_device_mediatek_sepolicy_vndr" path="device/mediatek/sepolicy_vndr" remote="github" />
  <project name="LineageOS/android_hardware_mediatek" path="hardware/mediatek" remote="github" />
  <project name="LineageOS/android_hardware_xiaomi" path="hardware/xiaomi" remote="github" />
  <project name="cristidclxvi/android_vendor_mediatek_ims" path="vendor/mediatek/ims" remote="github" revision="32a265afc6a297b20e8c8a4c870133de0e188884" />
  <project name="platform/prebuilts/clang/host/linux-x86" path="prebuilts/clang/host/linux-x86-r383902" remote="aosp" revision="refs/tags/android-12.1.0_r27" clone-depth="1" />
</manifest>
EOF

# 3. Clean & Pembersihan Direktori Lama sebelum Sinkronisasi
echo "-------------------------------------------------"
echo "-> [3/6] Cleaning up old directories..."
echo "-------------------------------------------------"
rm -rf device/xiaomi/camellia
rm -rf vendor/xiaomi/camellia
rm -rf kernel/xiaomi/camellia
rm -rf kernel/xiaomi/vendor
rm -rf vendor/mediatek/ims
rm -rf device/mediatek/sepolicy_vndr
rm -rf hardware/mediatek
rm -rf hardware/xiaomi

# Sinkronisasi Source & Manifest
echo "-------------------------------------------------"
echo "-> Syncing Source & Local Manifest Trees..."
echo "-------------------------------------------------"
/opt/crave/resync.sh

# 4. Patch Konflik Namespace (Jika diperlukan oleh vendor/device tree cristidclxvi)
echo "-> [4/6] Applying necessary patches..."
if [ -f "vendor/xiaomi/camellia/Android.bp" ]; then
    sed -i 's/name: "chipinfo",/name: "chipinfo_vendor",/g' vendor/xiaomi/camellia/Android.bp
fi

# 5. Mulai Kompilasi ROM
echo "-> [5/6] Starting Build Process..."
export BUILD_USERNAME="rwxrx-rx"
export BUILD_HOSTNAME="crave-cloud"

# Hapus file Android.mk terlarang di prebuilts clang yang memicu blokir build system
if [ -f "prebuilts/clang/host/linux-x86-r383902/Android.mk" ]; then
    echo "=> Menghapus file Android.mk yang diblokir oleh build system..."
    rm -f prebuilts/clang/host/linux-x86-r383902/Android.mk
fi

source build/envsetup.sh

# Menggunakan perintah lunch manual agar lebih spesifik dibanding brunch
lunch lineage_camellia-bp4a-userdebug
if mka bacon; then
    
    # 6. Proses Auto-Upload ke Pixeldrain
    echo "-> [6/6] Build Success! Searching for ZIP..."
    
    ROM_ZIP=$(find out/target/product/camellia/ -maxdepth 1 -name "crDroidAndroid-*.zip" -type f | head -n 1)
    
    if [ -f "$ROM_ZIP" ]; then
        ZIP_NAME=$(basename "$ROM_ZIP")
        send_tg "✅ <b>Build Selesai!</b>%0A%0A📦 <b>File:</b> <code>${ZIP_NAME}</code>%0A⏳ <i>Mengunggah ke Pixeldrain (Anonymous)...</i>"
        
        echo "=> Mengunggah ${ZIP_NAME} ke Pixeldrain..."
        
        UPLOAD_RESP=$(curl -s -T "$ROM_ZIP" https://pixeldrain.com/api/file/)
        FILE_ID=$(echo "$UPLOAD_RESP" | grep -oP '"id":"\K[^"]+')
        
        if [ ! -z "$FILE_ID" ]; then
            DOWNLOAD_LINK="https://pixeldrain.com/u/${FILE_ID}"
            echo "=> Upload Sukses: $DOWNLOAD_LINK"
            send_tg "🎉 <b>Upload Sukses!</b>%0A%0A📥 <b>Link Download:</b>%0A<a href='${DOWNLOAD_LINK}'>${DOWNLOAD_LINK}</a>"
        else
            echo "=> Gagal mendapatkan ID dari Pixeldrain: $UPLOAD_RESP"
            send_tg "⚠️ <b>Upload Gagal!</b>%0ATidak mendapat respon valid dari Pixeldrain."
        fi
    else
        echo "=> ERROR: File ROM ZIP tidak ditemukan di direktori out/!"
        send_tg "⚠️ <b>Build dilaporkan sukses, tapi file .zip ROM tidak ditemukan di direktori output!</b>"
    fi

else
    echo "=> BUILD GAGAL!"
    send_tg "❌ <b>[CRAVE CI/CD] Build GAGAL!</b>%0A%0ATerjadi error saat kompilasi. Silakan cek log Crave via terminal."
fi
