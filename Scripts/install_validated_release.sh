#!/bin/bash
# Resume local installation from a published, downloaded and signed release.
set -euo pipefail
[[ $# == 1 || ( $# == 2 && "$2" == --verify-only ) ]] || {
    echo "Usage: $0 release-evidence-directory [--verify-only]" >&2; exit 2;
}
release_dir="$(cd "$1" && pwd)"
script_dir="$(cd "$(dirname "$0")" && pwd)"
version=1.8.5
build=19
archive="$release_dir/downloaded/EdgeControl-$version-macOS.zip"
(cd "$release_dir/downloaded" && shasum -a 256 -c "$release_dir/SHA256SUMS")
# Keep extracted bundles outside Documents/File Provider managed directories.
install_work="$(mktemp -d "${TMPDIR:-/tmp}/EdgeControl-install.XXXXXX")"
trap 'rm -rf "$install_work"' EXIT
signature="$(python3 - "$release_dir/downloaded/appcast.xml" "$version" "$build" "$script_dir" <<'PYXML'
import sys, xml.etree.ElementTree as ET
path, version, build, script_dir = sys.argv[1:]
sys.path.insert(0, script_dir)
from appcast import signature_for
print(signature_for(ET.parse(path).getroot(), version, build))
PYXML
)"
# Anchor the update signature to the key already trusted by the installed app.
public_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' /Applications/EdgeControl.app/Contents/Info.plist)"
xcrun swift -sdk "$(xcrun --show-sdk-path)" -module-cache-path "$install_work/module-cache" "$script_dir/verify_update.swift" "$archive" "$public_key" "$signature"
ditto -x -k "$archive" "$install_work/unpacked"
app="$install_work/unpacked/EdgeControl.app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "$build" ]]
codesign --verify --deep --strict "$app"
architectures="$(lipo -archs "$app/Contents/MacOS/EdgeControl")"
[[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]]
if [[ "${2:-}" == --verify-only ]]; then
    echo "Verified $version ($build); installation unchanged."
    exit 0
fi
# Prepare and verify the complete replacement before stopping the running app.
# Omit copied Finder/resource metadata, explicitly retaining quarantine and ACLs.
stage_dir="$(mktemp -d /Applications/EdgeControl-install.XXXXXX)"
staged_app="$stage_dir/EdgeControl.app"
ditto --norsrc --noextattr --qtn --acl "$app" "$staged_app"
codesign --verify --deep --strict "$staged_app"
python3 - "$app" "$staged_app" <<'PYCOPY'
import hashlib, os, pathlib, stat, sys
def manifest(root):
    root = pathlib.Path(root)
    result = {}
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            p = pathlib.Path(directory) / name
            mode = p.lstat().st_mode
            value = (stat.S_IFMT(mode), stat.S_IMODE(mode))
            if p.is_symlink():
                value += (os.readlink(p),)
            elif p.is_file():
                value += (hashlib.sha256(p.read_bytes()).hexdigest(),)
            result[str(p.relative_to(root))] = value
    return result
assert manifest(sys.argv[1]) == manifest(sys.argv[2]), 'Staged bundle differs from verified archive'
print('Staged bundle bytes, modes and symbolic links verified')
PYCOPY
backup_dir="$(mktemp -d "$release_dir/installation-backup.XXXXXX")"
if pgrep -x EdgeControl >/dev/null; then
    killall -TERM EdgeControl
    for _ in {1..50}; do
        pgrep -x EdgeControl >/dev/null || break
        sleep 0.1
    done
    if pgrep -x EdgeControl >/dev/null; then
        echo "EdgeControl did not exit; installation unchanged." >&2
        exit 1
    fi
fi
mv /Applications/EdgeControl.app "$backup_dir/EdgeControl.app"
if ! mv "$staged_app" /Applications/EdgeControl.app; then
    mv "$backup_dir/EdgeControl.app" /Applications/EdgeControl.app
    open /Applications/EdgeControl.app
    exit 1
fi
rmdir "$stage_dir"
if ! codesign --verify --deep --strict /Applications/EdgeControl.app; then
    mv /Applications/EdgeControl.app "$backup_dir/EdgeControl-failed.app"
    mv "$backup_dir/EdgeControl.app" /Applications/EdgeControl.app
    open /Applications/EdgeControl.app
    exit 1
fi
open /Applications/EdgeControl.app
sleep 2
pgrep -x EdgeControl >/dev/null
echo "Installed $version ($build). Previous version: $backup_dir/EdgeControl.app"
