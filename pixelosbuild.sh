#!/bin/bash

# --- ROM Repo Init ---
echo "-----------------------------"
echo "Initializing Repo..."
echo "-----------------------------"
repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b sixteen-qpr2 --depth=1

# --- Syncing ---
echo "-----------------------"
echo "Starting to sync source"
echo "-----------------------"
/opt/crave/resync.sh

echo "------------------------"
echo "Source syncing completed"
echo "------------------------"

# --- Trees Clone ---
echo "-----------------------------"
echo "Cloning Device & Vendor Trees"
echo "-----------------------------"

# Hapus direktori lama jika ada untuk mencegah error "already exists"
rm -rf device/xiaomi/camellia
rm -rf vendor/xiaomi/camellia
rm -rf device/xiaomi/camellia-kernel
rm -rf vendor/mediatek/ims
rm -rf device/mediatek/sepolicy_vndr
rm -rf hardware/mediatek
rm -rf hardware/xiaomi

# Clone dengan --depth=1 agar proses berjalan lebih cepat
git clone --depth=1 https://github.com/aLpHa-Git-69/device_xiaomi_camellia.git -b lineage-23.2 device/xiaomi/camellia
git clone --depth=1 https://github.com/aLpHa-Git-69/vendor_xiaomi_camellia.git vendor/xiaomi/camellia
git clone --depth=1 https://github.com/dm700-devs/device_xiaomi_camellia-kernel.git device/xiaomi/camellia-kernel
git clone --depth=1 https://github.com/techyminati/android_vendor_mediatek_ims.git vendor/mediatek/ims
git clone --depth=1 https://github.com/LineageOS/android_device_mediatek_sepolicy_vndr.git device/mediatek/sepolicy_vndr
git clone --depth=1 https://github.com/LineageOS/android_hardware_mediatek.git hardware/mediatek
git clone --depth=1 https://github.com/LineageOS/android_hardware_xiaomi.git hardware/xiaomi

echo "---------------------"
echo "Trees clone completed"
echo "---------------------"

# --- Build Environment Setup ---
echo "---------------------------"
echo "Setting up Build Environment"
echo "---------------------------"
source build/envsetup.sh

# --- Lunch & Build ---
echo "----------------------------"
echo "Starting PixelOS Compilation"
echo "----------------------------"

# Menggunakan lunch target khas PixelOS/AOSP (bukan breakfast)
lunch pixelos_camellia-userdebug

# Target kompilasi standar untuk menghasilkan zip flashable
m bacon

echo "----------"
echo "Build Done"
echo "----------"
