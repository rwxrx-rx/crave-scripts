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
git clone https://github.com/dm700-devs/device_xiaomi_camellia-kernel.git device/xiaomi/camellia-kernel
git clone https://github.com/cristidclxvi/android_vendor_mediatek_ims.git vendor/mediatek/ims
git clone https://github.com/LineageOS/android_device_mediatek_sepolicy_vndr.git device/mediatek/sepolicy_vndr
git clone https://github.com/LineageOS/android_hardware_mediatek.git hardware/mediatek
git clone https://github.com/LineageOS/android_hardware_xiaomi.git hardware/xiaomi

echo "---------------------"
echo "Trees clone completed"
echo "---------------------"

# 3.5. Patching Vendor Conflict
echo "-----------------------------------"
echo "Patching Namespace Collision Errors"
echo "-----------------------------------"
# Mencegah bentrok modul "chipinfo" antara vendor dan hardware/mediatek
if [ -f "vendor/xiaomi/camellia/Android.bp" ]; then
    sed -i 's/name: "chipinfo",/name: "chipinfo_vendor",/g' vendor/xiaomi/camellia/Android.bp
    echo "Patch applied to vendor chipinfo!"
else
    echo "Warning: vendor/xiaomi/camellia/Android.bp not found, skipping patch."
fi

# 4. Setup Environment
echo "---------------------------"
echo "Setting up Build Environment"
echo "---------------------------"
source build/envsetup.sh

# 4.5. Bypass Prebuilt Kernel (FIX NINJA ERROR)
echo "-----------------------------------"
echo "Preparing Prebuilt Kernel for Ninja"
echo "-----------------------------------"
mkdir -p out/target/product/camellia/

# Mengecek dan menyalin file kernel dari repo prebuilt agar Ninja tidak error
if [ -f "device/xiaomi/camellia-kernel/kernel" ]; then
    cp device/xiaomi/camellia-kernel/kernel out/target/product/camellia/kernel
    echo "=> Success: Copied 'kernel' to out/ directory."
elif [ -f "device/xiaomi/camellia-kernel/Image.gz-dtb" ]; then
    cp device/xiaomi/camellia-kernel/Image.gz-dtb out/target/product/camellia/kernel
    echo "=> Success: Copied 'Image.gz-dtb' to out/ directory as 'kernel'."
else
    echo "=> WARNING: Prebuilt kernel not found in device/xiaomi/camellia-kernel!"
    echo "=> Creating dummy file to bypass Ninja error. (You must flash kernel separately later)"
    touch out/target/product/camellia/kernel
fi

# 5. Build ROM (Sesuai Device: camellia)
echo "----------"
echo "Starting Brunch Camellia"
echo "----------"
brunch camellia
