#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 /absolute/path/to/EdgeControl.app [output.dmg]" >&2
  exit 2
fi

app_path="$1"
if [[ ! -d "$app_path" || "$(basename "$app_path")" != "EdgeControl.app" ]]; then
  echo "Expected an EdgeControl.app bundle: $app_path" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
output_path="${2:-$project_root/build/EdgeControl.dmg}"
volume_name="EdgeControl"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/edgecontrol-dmg.XXXXXX")"
stage_dir="$temp_root/stage"
rw_dmg="$temp_root/EdgeControl-rw.dmg"
attached_device=""
mounted_path=""
layout_template="$script_dir/dmg_layout/.DS_Store"

cleanup() {
  if [[ -n "$attached_device" ]]; then
    hdiutil detach "$attached_device" -quiet || true
  fi
  rm -rf "$temp_root"
}
trap cleanup EXIT

mkdir -p "$stage_dir" "$(dirname "$output_path")"
ditto "$app_path" "$stage_dir/EdgeControl.app"
ln -s /Applications "$stage_dir/Applications"
if [[ -f "$layout_template" ]]; then
  cp "$layout_template" "$stage_dir/.DS_Store"
fi

hdiutil create \
  -volname "$volume_name" \
  -srcfolder "$stage_dir" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -ov \
  -format UDRW \
  "$rw_dmg"

attach_output="$(hdiutil attach "$rw_dmg" -nobrowse)"
attached_device="$(printf '%s\n' "$attach_output" | awk '$1 ~ /^\/dev\// { print $1; exit }')"
mounted_path="$(printf '%s\n' "$attach_output" | awk 'match($0, /\/Volumes\//) { print substr($0, RSTART); exit }')"

if [[ -z "$attached_device" || -z "$mounted_path" || ! -d "$mounted_path" ]]; then
  echo "Unable to determine the attached DMG device or mount path." >&2
  exit 1
fi

if [[ ! -f "$layout_template" ]]; then
  # Wait until Finder can address the volume (race on attach). Finder only
  # registers volumes mounted under /Volumes. Resolve the disk from the exact
  # mount path so a pre-existing same-name volume cannot be targeted by mistake.
  finder_ready=false
  for _ in $(seq 1 20); do
    if osascript - "$mounted_path" 2>/dev/null <<'APPLESCRIPT' | grep -qi true; then
on run argv
  try
    set mountAlias to POSIX file (item 1 of argv) as alias
    tell application "Finder" to get disk of mountAlias
    return true
  on error
    return false
  end try
end run
APPLESCRIPT
      finder_ready=true
      break
    fi
    sleep 0.5
  done

  if [[ "$finder_ready" != true ]]; then
    echo "Finder did not register the mounted volume: $mounted_path" >&2
    exit 1
  fi

  osascript - "$mounted_path" <<'APPLESCRIPT'
on run argv
set mountAlias to POSIX file (item 1 of argv) as alias
tell application "Finder"
  set targetDisk to disk of mountAlias
  tell targetDisk
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 200, 760, 560}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 104
    set position of item "EdgeControl.app" of container window to {145, 175}
    set position of item "Applications" of container window to {410, 175}
    update without registering applications
    delay 2
    close
  end tell
end tell
end run
APPLESCRIPT
fi

sync
hdiutil detach "$attached_device" -quiet
attached_device=""
mounted_path=""
hdiutil convert "$rw_dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$output_path"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$output_path"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$output_path" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$output_path"
fi

echo "DMG: $output_path"
