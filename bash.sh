#!/bin/bash

# =====================================================================
# crDroid Android 16 (branch 16.0) build script - Xiaomi camellia
# (POCO M3 Pro 5G / Redmi Note 10 5G)
#
# Runs ON a crave.io build node via:
#   crave run --no-patch -- "bash build_camellia_crdroid16.sh"
#
# Assumes you're already inside a repo-init'ed crave workspace
# (e.g. a "closest cousin" LineageOS 23 / Android 16 clone made with
# `crave clone create`) - see https://fosson.top/crave/
# =====================================================================

DEVICE="camellia"
BRANCH="16.0"

# ---------------------------------------------------------------
# 1. Local manifest: device/kernel/vendor trees for camellia
# ---------------------------------------------------------------
echo "-----------------------------"
echo "Writing local manifest"
echo "-----------------------------"
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

cat > .repo/local_manifests/camellia.xml << 'EOF'
<manifest>
  <project name="cristidclxvi/android_device_xiaomi_camellia"
           path="device/xiaomi/camellia" remote="github" revision="lineage-23.2" />
  <project name="cristidclxvi/android_kernel_xiaomi_camellia"
           path="kernel/xiaomi/camellia" remote="github" revision="lineage-23.2" />
  <project name="cristidclxvi/android_kernel_modules_xiaomi_camellia"
           path="kernel/xiaomi/vendor" remote="github" revision="lineage-23.2" />
  <project name="LineageOS/android_device_mediatek_sepolicy_vndr"
           path="device/mediatek/sepolicy_vndr" remote="github" />
  <project name="LineageOS/android_hardware_mediatek"
           path="hardware/mediatek" remote="github" />
  <project name="LineageOS/android_hardware_xiaomi"
           path="hardware/xiaomi" remote="github" />

  <!-- MediaTek IMS. Provides com.mediatek.ims, which binds the
       IRadio/imsAospSlot1|2 instances the MTK RIL registers. Without it no
       ImsService is bound and calls fall back to GSM instead of using VoLTE.
       Pinned to a SHA on purpose: the payload is a prebuilt APK that gets our
       platform signature, so it must not change under us. -->
  <project name="cristidclxvi/android_vendor_mediatek_ims"
           path="vendor/mediatek/ims" remote="github"
           revision="32a265afc6a297b20e8c8a4c870133de0e188884" />

  <!-- Kernel toolchain. LineageOS ships clang r547379 and newer; this 4.14
       tree needs r383902, which AOSP keeps only on its Android 12 branches. -->
  <project name="platform/prebuilts/clang/host/linux-x86"
           path="prebuilts/clang/host/linux-x86-r383902"
           remote="aosp" revision="refs/tags/android-12.1.0_r27"
           clone-depth="1" />
</manifest>
EOF

# ---------------------------------------------------------------
# 2. repo init - switch the base tree to crDroid 16.0
# ---------------------------------------------------------------
echo "-----------------------------"
echo "Starting Repo Init (crDroid $BRANCH)"
echo "-----------------------------"
repo init -u https://github.com/crdroidandroid/android.git -b "$BRANCH" --git-lfs --no-clone-bundle --depth=1

# ---------------------------------------------------------------
# 3. Sync - always via crave's resync.sh, never raw `repo sync`
# ---------------------------------------------------------------
echo "-----------------------"
echo "Starting to sync source"
echo "-----------------------"
/opt/crave/resync.sh
echo "------------------------"
echo "Source syncing completed"
echo "------------------------"

# ---------------------------------------------------------------
# 4. Build environment + build
# ---------------------------------------------------------------
echo "----------------------------"
echo "Setting up Build Environment"
echo "----------------------------"
source build/envsetup.sh

echo "----------"
echo "Starting Brunch $DEVICE"
echo "----------"
brunch "$DEVICE"
