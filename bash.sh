#!/bin/bash

# =====================================================================
# crDroid 16.0 build script - Xiaomi camellia (POCO M3 Pro 5G)
# Lingkungan: Crave.io
# Sesuai dengan standar instruksi crDroid README.mkdn
# =====================================================================

DEVICE="camellia"
BRANCH="16.0"

echo "======================================"
echo " 1. Menyiapkan Local Manifest"
echo "======================================"
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

cat > .repo/local_manifests/camellia.xml << 'EOF'
<manifest>
  <!-- Device, Kernel, & Modules -->
  <project name="cristidclxvi/android_device_xiaomi_camellia" path="device/xiaomi/camellia" remote="github" revision="lineage-23.2" />
  <project name="cristidclxvi/android_kernel_xiaomi_camellia" path="kernel/xiaomi/camellia" remote="github" revision="lineage-23.2" />
  <project name="cristidclxvi/android_kernel_modules_xiaomi_camellia" path="kernel/xiaomi/vendor" remote="github" revision="lineage-23.2" />
  
  <!-- Vendor Blobs Pribadi -->
  <project name="cristidclxvi/android_vendor_xiaomi_camellia" path="vendor/xiaomi/camellia" remote="github" revision="lineage-23.2" />

  <!-- Dependensi Hardware & IMS MediaTek -->
  <project name="LineageOS/android_device_mediatek_sepolicy_vndr" path="device/mediatek/sepolicy_vndr" remote="github" />
  <project name="LineageOS/android_hardware_mediatek" path="hardware/mediatek" remote="github" />
  <project name="LineageOS/android_hardware_xiaomi" path="hardware/xiaomi" remote="github" />
  <project name="cristidclxvi/android_vendor_mediatek_ims" path="vendor/mediatek/ims" remote="github" revision="32a265afc6a297b20e8c8a4c870133de0e188884" />
  
  <!-- Toolchain Clang lawas -->
  <project name="platform/prebuilts/clang/host/linux-x86" path="prebuilts/clang/host/linux-x86-r383902" remote="aosp" revision="refs/tags/android-12.1.0_r27" clone-depth="1" />
</manifest>
EOF

echo "======================================"
echo " 2. Inisialisasi crDroid & Sinkronisasi"
echo "======================================"
# Standar inisialisasi dari README.mkdn crDroid
repo init -u https://github.com/crdroidandroid/android.git -b "$BRANCH" --git-lfs --no-clone-bundle --depth=1
/opt/crave/resync.sh

echo "======================================"
echo " 3. Memperbaiki Kompatibilitas Tree"
echo "======================================"
# A. Menghapus blocker kompilasi Clang (Error pada log sebelumnya)
rm -f prebuilts/clang/host/linux-x86-r383902/Android.mk

# B. Konversi Tree dari LineageOS menjadi standar crDroid
echo "Mengonversi Makefiles lineage_camellia ke crdroid_camellia..."
cd device/xiaomi/camellia || exit 1

# Rename file utama mk
if [ -f lineage_camellia.mk ]; then
    mv lineage_camellia.mk crdroid_camellia.mk
fi

# Edit isi file mk agar mewarisi konfigurasi crDroid (bukan Lineage)
sed -i 's/lineage_camellia/crdroid_camellia/g' crdroid_camellia.mk
sed -i 's/vendor\/lineage\/config\/common_full_phone.mk/vendor\/crdroid\/config\/common.mk/g' crdroid_camellia.mk
sed -i 's/vendor\/lineage\/config\/common.mk/vendor\/crdroid\/config\/common.mk/g' crdroid_camellia.mk

# Pastikan nama produk di AndroidProducts.mk juga berubah
if [ -f AndroidProducts.mk ]; then
    sed -i 's/lineage_camellia/crdroid_camellia/g' AndroidProducts.mk
fi

# Kembali ke root
cd ../../..

echo "======================================"
echo " 4. Build Sesuai Panduan README.mkdn"
echo "======================================"
export ALLOW_MISSING_DEPENDENCIES=true

# 1. Source environment sesuai README
. build/envsetup.sh

# 2. Perintah Build standar crDroid dari README
brunch "$DEVICE"
