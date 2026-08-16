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
mount_dir="$temp_root/mount"
rw_dmg="$temp_root/EdgeControl-rw.dmg"

cleanup() {
  if mount | grep -Fq "on $mount_dir "; then
    hdiutil detach "$mount_dir" -quiet || true
  fi
  rm -rf "$temp_root"
}
trap cleanup EXIT

mkdir -p "$stage_dir" "$mount_dir" "$(dirname "$output_path")"
ditto "$app_path" "$stage_dir/EdgeControl.app"
ln -s /Applications "$stage_dir/Applications"

hdiutil create \
  -volname "$volume_name" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDRW \
  "$rw_dmg"

hdiutil attach "$rw_dmg" -mountpoint "$mount_dir" -nobrowse -quiet

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$volume_name"
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
APPLESCRIPT

sync
hdiutil detach "$mount_dir" -quiet
hdiutil convert "$rw_dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$output_path"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$output_path"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$output_path" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$output_path"
fi

echo "DMG: $output_path"

