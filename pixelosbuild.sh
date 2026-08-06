# rom repo init

repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b sixteen --git-lfs

echo "-----------------------------"
echo "Repo init cloned successfully"
echo "-----------------------------"

# syncing

echo "-----------------------"
echo "Starting to sync source"
echo "-----------------------"

/opt/crave/resync.sh

/opt/crave/resync.sh

/opt/crave/resync.sh

echo "------------------------"
echo "Source syncing completed"
echo "------------------------"

# Trees Clone

git clone https://github.com/dm700-devs/device_xiaomi_camellia -b lineage-23.2 device/xiaomi/camellia
git clone https://github.com/aLpHa-Git-69/vendor_xiaomi_camellia -b main vendor/xiaomi/camellia
git clone https://github.com/camellia-devs/kernel_xiaomi_mt6833 -b flyme kernel/xiaomi/camellia

# Hardware dependencies
git clone https://github.com/LineageOS/android_hardware_mediatek -b lineage-22.0 hardware/mediatek
git clone https://github.com/LineageOS/android_hardware_xiaomi -b lineage-22.0 hardware/xiaomi

echo "---------------------"
echo "Trees clone completed"
echo "---------------------"

# build env

. b*/e*

echo "---------------------------"
echo "Build/envsetup.sh completed"
echo "---------------------------"

# Lunch & Build

lunch pixelos_camellia-ap3a-userdebug || lunch pixelos_camellia-userdebug

echo "----------------------------"
echo "Starting PixelOS Compilation"
echo "----------------------------"

m bacon

echo "----------"
echo "Done"
echo "----------"
