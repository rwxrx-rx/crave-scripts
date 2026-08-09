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
rm -rf device/xiaomi/camellia
rm -rf vendor/xiaomi/camellia
rm -rf device/xiaomi/camellia-kernel
rm -rf vendor/mediatek/ims
rm -rf device/mediatek/sepolicy_vndr
rm -rf hardware/mediatek
rm -rf hardware/xiaomi

git clone --depth=1 https://github.com/aLpHa-Git-69/device_xiaomi_camellia.git -b lineage-23.2 device/xiaomi/camellia
git clone --depth=1 https://github.com/aLpHa-Git-69/vendor_xiaomi_camellia.git vendor/xiaomi/camellia
git clone --depth=1 https://github.com/dm700-devs/device_xiaomi_camellia-kernel.git device/xiaomi/camellia-kernel
git clone --depth=1 https://github.com/techyminati/android_vendor_mediatek_ims.git vendor/mediatek/ims
git clone --depth=1 https://github.com/LineageOS/android_device_mediatek_sepolicy_vndr.git device/mediatek/sepolicy_vndr
git clone --depth=1 https://github.com/LineageOS/android_hardware_mediatek.git hardware/mediatek
git clone --depth=1 https://github.com/LineageOS/android_hardware_xiaomi.git hardware/xiaomi

# --- Adapting Lineage Tree to PixelOS ---
echo "---------------------------------"
echo "Adapting Device Tree for PixelOS"
echo "---------------------------------"
if [ -f device/xiaomi/camellia/lineage_camellia.mk ]; then
    # 1. Rename file makefile utama
    mv device/xiaomi/camellia/lineage_camellia.mk device/xiaomi/camellia/pixelos_camellia.mk
    
    # 2. Update AndroidProducts.mk
    sed -i 's/lineage_camellia/pixelos_camellia/g' device/xiaomi/camellia/AndroidProducts.mk
    
    # 3. Ganti PRODUCT_NAME
    sed -i 's/PRODUCT_NAME := lineage_camellia/PRODUCT_NAME := pixelos_camellia/g' device/xiaomi/camellia/pixelos_camellia.mk
    
    # 4. Hapus baris inherit Lineage yang lama
    sed -i '/vendor\/lineage/d' device/xiaomi/camellia/pixelos_camellia.mk
    
    # 5. Cari file config vendor PixelOS yang valid secara otomatis di folder vendor/
    PIXEL_VENDOR_MK=$(find vendor/pixel* vendor/aosp* -type f \( -name "common.mk" -o -name "common_full.mk" -o -name "common_full_phone.mk" -o -name "config.mk" \) 2>/dev/null | head -n 1)

    if [ -n "$PIXEL_VENDOR_MK" ]; then
        echo "--> Found PixelOS Vendor Config: $PIXEL_VENDOR_MK"
        echo "\$(call inherit-product, $PIXEL_VENDOR_MK)" >> device/xiaomi/camellia/pixelos_camellia.mk
    else
        echo "--> WARNING: Vendor config not found automatically, falling back to vendor/pixelos/config/common.mk"
        echo '$(call inherit-product, vendor/pixelos/config/common.mk)' >> device/xiaomi/camellia/pixelos_camellia.mk
    fi
fi

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

# Pilihan target lunch untuk Android 16 / PixelOS Sixteen
lunch pixelos_camellia-ap3a-userdebug || lunch pixelos_camellia-trunk_staging-userdebug || lunch pixelos_camellia-userdebug

m bacon -j$(nproc)

echo "----------"
echo "Build Done"
echo "----------"
