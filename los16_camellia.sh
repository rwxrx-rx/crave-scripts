#!/bin/bash

# =================================================
#  Konfigurasi Notifikasi Telegram & Upload
# =================================================
# Mengambil token dan chat ID dari argumen eksekusi GitHub Actions
TG_TOKEN="$1"
TG_CHAT_ID="$2"

# Validasi keamanan: Pastikan token diisi, jika kosong batalkan eksekusi
if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
    echo "=> ERROR: TG_TOKEN atau TG_CHAT_ID kosong! Pastikan GitHub Secrets sudah dikirim."
    exit 1
fi

# Fungsi untuk mengirim pesan ke Telegram (format HTML)
function send_tg() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" \
        -d "text=$1" > /dev/null
}

echo "================================================="
echo "   LineageOS (Android 16) Crave Build Script     "
echo "   Target: camellia (Redmi Note 10 5G / POCO)    "
echo "================================================="

send_tg "🚀 <b>[CRAVE CI/CD] Build Started!</b>%0A%0A📱 <b>Device:</b> camellia%0A🤖 <b>ROM:</b> LineageOS (Android 16)%0A👨‍💻 <b>Builder:</b> @rwxrx-rx"

# 1. Inisialisasi Repositori LineageOS
echo "-> [1/7] Initializing LineageOS Repo..."
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

# 2. Injeksi Local Manifest
echo "-> [2/7] Injecting Local Manifest..."
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

# 3. Sinkronisasi Source
echo "-> [3/7] Syncing Source & Device Trees..."
/opt/crave/resync.sh

# 4. Clone Vendor Tree
echo "-> [4/7] Setting up Proprietary Vendor Blobs..."
if [ ! -d "vendor/xiaomi/camellia" ]; then
    git clone https://github.com/aLpHa-Git-69/vendor_xiaomi_camellia.git vendor/xiaomi/camellia
fi

# 5. Patch Konflik Namespace
echo "-> [5/7] Applying necessary patches..."
if [ -f "vendor/xiaomi/camellia/Android.bp" ]; then
    sed -i 's/name: "chipinfo",/name: "chipinfo_vendor",/g' vendor/xiaomi/camellia/Android.bp
fi

# 6. Mulai Kompilasi ROM
echo "-> [6/7] Starting Build Process..."
export BUILD_USERNAME="rwxrx-rx"
export BUILD_HOSTNAME="crave-cloud"

source build/envsetup.sh

# Jalankan brunch. Jika berhasil (exit code 0), lanjut ke proses upload
if brunch camellia; then
    
    # 7. Proses Auto-Upload
    echo "-> [7/7] Build Success! Searching for ZIP..."
    
    # PERUBAHAN: Mencari file zip berawalan lineage-
    ROM_ZIP=$(find out/target/product/camellia/ -maxdepth 1 -name "lineage-*.zip" -type f | head -n 1)
    
    if [ -f "$ROM_ZIP" ]; then
        ZIP_NAME=$(basename "$ROM_ZIP")
        send_tg "✅ <b>Build Selesai!</b>%0A%0A📦 <b>File:</b> <code>${ZIP_NAME}</code>%0A⏳ <i>Mengunggah ke Pixeldrain (Anonymous)...</i>"
        
        echo "=> Mengunggah ${ZIP_NAME} ke Pixeldrain..."
        
        # Eksekusi upload dan tangkap response JSON-nya
        UPLOAD_RESP=$(curl -s -T "$ROM_ZIP" https://pixeldrain.com/api/file/)
        
        # Ekstrak ID file dari response JSON menggunakan grep regex
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
    # Jika perintah `brunch camellia` gagal
    echo "=> BUILD GAGAL!"
    send_tg "❌ <b>[CRAVE CI/CD] Build GAGAL!</b>%0A%0ATerjadi error saat kompilasi LineageOS. Silakan cek log Crave via terminal."
fi
