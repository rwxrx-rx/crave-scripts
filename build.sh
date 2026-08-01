#!/bin/bash

repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --no-clone-bundle
git clone https://github.com/rwxrx-rx/local_manifest.git -b main .repo/local_manifests
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune -j$(nproc --all)
repo sync -c -j32 --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh
. build/envsetup.sh
lunch crdroid_camellia-bp4a-userdebug
m installclean
m bacon
