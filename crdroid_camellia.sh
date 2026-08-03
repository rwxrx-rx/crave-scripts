#!/usr/bin/env bash

set -euo pipefail

# ==================== CONFIGURATION ====================
ROM_MANIFEST_URL="https://github.com/rwxrx-rx/local_manifests.git"
ROM_MANIFEST_BRANCH="main"
ROM_BRANCH="16.0"
DEVICE="camellia"
UPLOAD_PIXELDRAIN="${UPLOAD_PIXELDRAIN:-1}"
LOG_FILE="build_${DEVICE}_$(date +%Y%m%d_%H%M%S).log"
# =======================================================

exec > >(tee -a "${LOG_FILE}") 2>&1

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

require_command repo
require_command git
require_command tee

install_jq_if_missing() {
  if command -v jq >/dev/null 2>&1; then
    return
  fi

  echo "jq is missing; installing it in the temporary Crave build environment"

  if command -v sudo >/dev/null 2>&1; then
    sudo -n apt-get update
    sudo -n apt-get install -y --no-install-recommends jq
  elif [[ "$(id -u)" -eq 0 ]]; then
    apt-get update
    apt-get install -y --no-install-recommends jq
  else
    echo "ERROR: jq is missing and package installation is unavailable" >&2
    exit 1
  fi
}

if [[ "${UPLOAD_PIXELDRAIN}" == "1" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "WARNING: curl is unavailable; PixelDrain upload will be skipped" >&2
    UPLOAD_PIXELDRAIN=0
  elif ! command -v jq >/dev/null 2>&1; then
    if ! install_jq_if_missing; then
      echo "WARNING: jq could not be installed; PixelDrain upload will be skipped" >&2
      UPLOAD_PIXELDRAIN=0
    fi
  fi
fi

test -x /opt/crave/resync.sh || {
  echo "ERROR: /opt/crave/resync.sh is unavailable" >&2
  exit 1
}

handle_error() {
  local status=$?
  trap - ERR

  echo "ERROR: build script failed with status ${status}" >&2
  echo "Full log: ${LOG_FILE}" >&2
  exit "${status}"
}

trap handle_error ERR

echo "==> Initializing crDroid ${ROM_BRANCH}"
repo init \
  -u https://github.com/crdroidandroid/android.git \
  -b "${ROM_BRANCH}" \
  --git-lfs \
  --depth=1

echo "==> Installing public device manifest"
rm -rf .repo/local_manifests
git clone \
  --depth=1 \
  --branch "${ROM_MANIFEST_BRANCH}" \
  "${ROM_MANIFEST_URL}" \
  .repo/local_manifests

test -f .repo/local_manifests/local_manifest.xml || {
  echo "ERROR: expected local_manifest.xml was not found" >&2
  exit 1
}

echo "Manifest revision: $(git -C .repo/local_manifests rev-parse --short HEAD)"

echo "==> Syncing sources through Crave"
/opt/crave/resync.sh

echo "==> Validating essential device paths"
for required_path in \
  device/xiaomi/camellia \
  vendor/xiaomi/camellia; do
  test -e "${required_path}" || {
    echo "ERROR: synced path is missing: ${required_path}" >&2
    exit 1
  }
done

echo "==> Preparing environment for ${DEVICE}"
source build/envsetup.sh
brunch "${DEVICE}"

shopt -s nullglob
RELEASE_ASSETS=(out/target/product/${DEVICE}/*.zip)
shopt -u nullglob

upload_pixeldrain() {
  local asset upload_asset upload_response file_id success

  for asset in "${RELEASE_ASSETS[@]}"; do
    # Generate SHA256 checksum
    sha256sum "${asset}" > "${asset}.sha256"

    for upload_asset in "${asset}" "${asset}.sha256"; do
      echo "==> Uploading to PixelDrain: $(basename "${upload_asset}")"
      
      # Anonymous upload via PixelDrain API v1
      if upload_response="$(curl --fail-with-body --silent --show-error \
        --connect-timeout 30 --retry 3 --max-time 3600 \
        -F "file=@${upload_asset}" \
        "https://pixeldrain.com/api/file")"; then
        
        success="$(jq -r '.success // false' <<<"${upload_response}")"
        file_id="$(jq -r '.id // empty' <<<"${upload_response}")"

        if [[ "${success}" == "true" && -n "${file_id}" ]]; then
          echo "PixelDrain link for $(basename "${upload_asset}"): https://pixeldrain.com/u/${file_id}"
        else
          echo "WARNING: PixelDrain upload returned an error for $(basename "${upload_asset}"); continuing" >&2
        fi
      else
        echo "WARNING: PixelDrain upload failed for $(basename "${upload_asset}"); continuing" >&2
      fi
    done
  done
}

if [[ "${#RELEASE_ASSETS[@]}" -eq 0 ]]; then
  echo "WARNING: no ROM ZIP found; skipping post-build uploads" >&2
else
  if [[ "${UPLOAD_PIXELDRAIN}" == "1" ]]; then
    upload_pixeldrain || true
  fi
fi

echo "==> Build completed"
echo "Artifacts: out/target/product/${DEVICE}/"
