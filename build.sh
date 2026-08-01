#!/bin/bash

# 1. Bersihkan manifest lokal lama
rm -rf .repo/local_manifests/

# 2. Repo Init crDroid Android 16
# Catatan: crDroid A16 umumnya menggunakan branch 16.0 / 12.0
repo init --no-repo-verify --git-lfs -u https://github.com/crdroidandroid/android.git -b 16.0 -g default,-mips,-darwin,-notdefault --depth=1
echo "=============================="
echo "Repo init crDroid A16 success"
echo "=============================="

# 3. Clone Local Manifest khusus camellia
# Ganti URL dan branch -b di bawah ini sesuai lokasi local manifest milikmu
git clone https://github.com/rwxrx-rx/local_manifest.git .repo/local_manifests -b crdroid-16
echo "============================"
echo "Local manifest clone success"
echo "============================"

# 4. Sinkronisasi Source Code via Crave Engine
if [ -f /opt/crave/resync.sh ]; then
  /opt/crave/resync.sh
else
  repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
fi
echo "============="
echo "Sync success"
echo "============="

# 5. Penanganan Error Log & Sisa Build Sebelumnya
if [ -f out/error.log ]; then
  grep '^FAILED: //' out/error.log | sed -E 's|^FAILED: //([^:]+):.*|out/soong/.intermediates/\1|' | sort -u | while read -r d; do rm -rf "$d" && echo "Removed: $d"; done
  rm -rf out/target/product/camellia
fi

# 6. Setup Environment Build
source build/envsetup.sh
export TZ=Asia/Jakarta
echo "======================"
echo "Env setup success"
echo "======================"

# 7. Selection Target Lunch crDroid Camellia
lunch crdroid_camellia-ap4a-userdebug || lunch crdroid_camellia-userdebug || lunch crdroid_camellia-user

# Bersihkan sisa kompilasi target ringan
make installclean

# 8. Proses Compiling ROM crDroid
mka bacon

# 9. Upload File Output ZIP ke Pixeldrain
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
        echo "=================================================="
        echo "Upload Success! 🎉"
        echo "Download Link: https://pixeldrain.com/u/$FILE_ID"
        echo "=================================================="
    else
        echo "Upload failed! Raw response:"
        echo "$RESPONSE"
    fi
else
    echo "No ZIP file found in out/target/product/camellia!"
fi

echo "Process Finished."
