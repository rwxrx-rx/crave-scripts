#!/bin/bash

# 1. Repo init
echo "-----------------------------"
echo "Starting Repo Init"
echo "-----------------------------"
repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --no-clone-bundle --depth=1

# 2. Syncing Source (Cukup 1x)
echo "-----------------------"
echo "Starting to sync source"
echo "-----------------------"
/opt/crave/resync.sh

echo "------------------------"
echo "Source syncing completed"
echo "------------------------"

# 3. Clean & Clone Trees (Pembersihan agar tidak error 'directory already exists')
echo "---------------------"
echo "Cloning Device Trees"
echo "---------------------"
rm -rf device/xiaomi/camellia
rm -rf vendor/xiaomi/camellia
rm -rf device/xiaomi/camellia-kernel
rm -rf vendor/mediatek/ims
rm -rf device/mediatek/sepolicy_vndr
rm -rf hardware/mediatek
rm -rf hardware/xiaomi

git clone https://github.com/cristidclxvi/android_device_xiaomi_camellia.git -b lineage-23.2 device/xiaomi/camellia
git clone https://github.com/aLpHa-Git-69/vendor_xiaomi_camellia.git vendor/xiaomi/camellia
git clone https://github.com/cristidclxvi/android_kernel_xiaomi_camellia.git device/xiaomi/camellia-kernel
git clone https://github.com/techyminati/android_vendor_mediatek_ims.git vendor/mediatek/ims
git clone https://github.com/LineageOS/android_device_mediatek_sepolicy_vndr.git device/mediatek/sepolicy_vndr
git clone https://github.com/LineageOS/android_hardware_mediatek.git hardware/mediatek
git clone https://github.com/LineageOS/android_hardware_xiaomi.git hardware/xiaomi

echo "---------------------"
echo "Trees clone completed"
echo "---------------------"

# 4. Setup Environment
echo "---------------------------"
echo "Setting up Build Environment"
echo "---------------------------"
source build/envsetup.sh

# 5. Build ROM (Sesuai Device: camellia)
echo "----------"
echo "Starting Brunch Camellia"
echo "----------"
brunch camellia
