#!/usr/bin/env bash
#
# update-manifest.sh
#
# Update manifest.json for a new esp32e22-fw release.
#
# Computes size_bytes and sha256 from the firmware binary and rewrites
# manifest.json with the values supplied via command-line options.
#
# Usage:
#   tools/update-manifest.sh \
#     --version 3 \
#     --source-commit a3f9c129 \
#     --source-branch main \
#     [--build-date 2026-04-20T12:34:56Z] \
#     [--features wifi,bt] \
#     [--secure-download false] \
#     [--firmware esp32e22-fw.bin] \
#     [--manifest manifest.json]
#
# Defaults:
#   --build-date       current UTC time (ISO 8601)
#   --features         wifi,bt
#   --secure-download  false
#   --firmware         esp32e22-fw.bin
#   --manifest         manifest.json
#
# Requires: bash, sha256sum, stat, python3 (for JSON serialization).

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

die() {
    echo "${SCRIPT_NAME}: error: $*" >&2
    exit 1
}

VERSION=""
SOURCE_COMMIT=""
SOURCE_BRANCH=""
BUILD_DATE=""
FEATURES_CSV="wifi,bt"
SECURE_DOWNLOAD="false"
FIRMWARE="esp32e22-fw.bin"
MANIFEST="manifest.json"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)          VERSION="$2"; shift 2 ;;
        --source-commit)    SOURCE_COMMIT="$2"; shift 2 ;;
        --source-branch)    SOURCE_BRANCH="$2"; shift 2 ;;
        --build-date)       BUILD_DATE="$2"; shift 2 ;;
        --features)         FEATURES_CSV="$2"; shift 2 ;;
        --secure-download)  SECURE_DOWNLOAD="$2"; shift 2 ;;
        --firmware)         FIRMWARE="$2"; shift 2 ;;
        --manifest)         MANIFEST="$2"; shift 2 ;;
        -h|--help)          usage 0 ;;
        *)                  die "unknown argument: $1" ;;
    esac
done

[[ -n "$VERSION" ]]       || die "--version is required"
[[ -n "$SOURCE_COMMIT" ]] || die "--source-commit is required"
[[ -n "$SOURCE_BRANCH" ]] || die "--source-branch is required"

[[ "$VERSION" =~ ^[0-9]+$ ]] \
    || die "--version must be a non-negative integer, got: $VERSION"

if [[ "$VERSION" -eq 0 ]]; then
    echo "${SCRIPT_NAME}: warning: version 0 is reserved as a non-official placeholder" >&2
fi

[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{8}$ ]] \
    || die "--source-commit must be an 8-character lowercase hex SHA"

case "$SECURE_DOWNLOAD" in
    true|false) ;;
    *) die "--secure-download must be 'true' or 'false', got: $SECURE_DOWNLOAD" ;;
esac

[[ -f "$FIRMWARE" ]] || die "firmware binary not found: $FIRMWARE"
[[ -f "$MANIFEST" ]] || die "manifest file not found: $MANIFEST"

CURRENT_VERSION="$(python3 - "$MANIFEST" <<'PY'
import json, sys, pathlib

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
print(data.get("firmware", {}).get("version", 0))
PY
)"

[[ "$CURRENT_VERSION" =~ ^[0-9]+$ ]] \
    || die "current manifest firmware.version is invalid: $CURRENT_VERSION"

if [[ "$CURRENT_VERSION" -eq 0 ]]; then
    if [[ "$VERSION" -ne 0 && "$VERSION" -ne 1 ]]; then
        die "when current manifest version is 0, the next version must be 0 or 1, got: $VERSION"
    fi
else
    EXPECTED_VERSION=$((CURRENT_VERSION + 1))
    [[ "$VERSION" -eq "$EXPECTED_VERSION" ]] \
        || die "new version must be exactly current version + 1 (expected: $EXPECTED_VERSION, got: $VERSION)"
fi

if [[ -z "$BUILD_DATE" ]]; then
    BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
fi

SIZE_BYTES="$(stat -c '%s' "$FIRMWARE" 2>/dev/null || stat -f '%z' "$FIRMWARE")"
SHA256="$(sha256sum "$FIRMWARE" | awk '{print $1}')"

IFS=',' read -ra FEATURES_ARR <<< "$FEATURES_CSV"
FEATURES_JSON="$(printf '%s\n' "${FEATURES_ARR[@]}" \
    | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"

python3 - "$MANIFEST" "$VERSION" "$BUILD_DATE" "$SIZE_BYTES" "$SHA256" \
              "$SOURCE_COMMIT" "$SOURCE_BRANCH" "$FEATURES_JSON" "$SECURE_DOWNLOAD" <<'PY'
import json, sys, pathlib

(manifest_path, version, build_date, size_bytes, sha256,
 source_commit, source_branch, features_json, secure_download) = sys.argv[1:]

path = pathlib.Path(manifest_path)
data = json.loads(path.read_text())

data.setdefault("chip", "esp32e22")
data.setdefault("firmware", {})
data.setdefault("source", {})

data["firmware"]["version"]    = int(version)
data["firmware"]["build_date"] = build_date
data["firmware"]["size_bytes"] = int(size_bytes)
data["firmware"]["sha256"]     = sha256

data["source"]["repo"]   = "esp-firmware-system"
data["source"]["commit"] = source_commit
data["source"]["branch"] = source_branch

data["features"]        = json.loads(features_json)
data["secure_download"] = secure_download == "true"

path.write_text(json.dumps(data, indent=2) + "\n")
PY

echo "Updated $MANIFEST:"
echo "  version         = $VERSION"
echo "  build_date      = $BUILD_DATE"
echo "  size_bytes      = $SIZE_BYTES"
echo "  sha256          = $SHA256"
echo "  source.commit   = $SOURCE_COMMIT"
[[ -n "$SOURCE_BRANCH" ]] && echo "  source.branch   = $SOURCE_BRANCH"
echo "  features        = $FEATURES_CSV"
echo "  secure_download = $SECURE_DOWNLOAD"
