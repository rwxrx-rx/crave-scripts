# Rom repo init

repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --no-clone-bundle

echo "-----------------------------"
echo "Repo init cloned successfully"
echo "-----------------------------"

# sycning

echo "-----------------------"
echo "Starting to sync source"
echo "-----------------------"

/opt/crave/resync.sh

/opt/crave/resync.sh

/opt/crave/resync.sh

echo "------------------------"
echo "Source syncing comppeted"
echo "------------------------"


# Dt

git clone https://github.com/aLpHa-Git-69/device_xiaomi_camellia.git -b lineage-23.2 device/xiaomi/camellia
git clone https://github.com/aLpHa-Git-69/vendor_xiaomi_camellia.git vendor/xiaomi/camellia
git clone https://github.com/dm700-devs/device_xiaomi_camellia-kernel.git device/xiaomi/camellia-kernel
git clone https://github.com/techyminati/android_vendor_mediatek_ims.git vendor/mediatek/ims
git clone https://github.com/LineageOS/android_device_mediatek_sepolicy_vndr.git device/mediatek/sepolicy_vndr
git clone https://github.com/LineageOS/android_hardware_mediatek.git hardware/mediatek
git clone https://github.com/LineageOS/android_hardware_xiaomi.git hardware/xiaomi

echo "---------------------"
echo "Tress clone completed"
echo "---------------------"

# build env

. b*/e*

echo "---------------------------"
echo "Build/envsetup.sh completed"
echo "---------------------------"

# signing script

curl -sSf https://raw.githubusercontent.com/Trijal08/crDroid-build-signed-script-auto/main/create-signed-env.sh | bash

echo "----------------------------"
echo "Rom signed with private keys"
echo "----------------------------"

# lunch

brunch lavender

echo "----------"
echo "Brunch done"
echo "----------"
