#!/bin/bash
# Run from a normal local terminal with the existing Sparkle signing key.
# No private key is exported, uploaded, or written to a file.
set -euo pipefail
[[ $# == 2 ]] || { echo "Usage: $0 successful-ci-run-id /path/to/Sparkle/bin/sign_update" >&2; exit 2; }
run_id="$1"
signer="$2"
[[ "$run_id" =~ ^[0-9]+$ && -x "$signer" ]] || exit 2
repo="leecdiang/EdgeControl"
version="1.7.5"
build="11"
tag="v$version"
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
mkdir -p "$project_root/build"
release_dir="$(mktemp -d "$project_root/build/release-$version.XXXXXX")"
echo "Release evidence and installation backup: $release_dir"
# Retain staging, downloaded bytes, and the old installation for recovery.
gh run view "$run_id" --repo "$repo" --json conclusion,headSha,workflowName > "$release_dir/run.json"
commit="$(python3 - "$release_dir/run.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r['conclusion']=='success' and r['workflowName']=='CI', r
assert len(r['headSha'])==40
print(r['headSha'])
PY
)"
gh run download "$run_id" --repo "$repo" --name "EdgeControl-candidate-$commit" --dir "$release_dir/candidate"
candidate="$release_dir/candidate"
[[ "$(cat "$candidate/SOURCE_COMMIT")" == "$commit" ]]
# CI hashes use build/ paths; verify them without changing archive contents.
mkdir "$release_dir/hashcheck"
ln -s "$candidate" "$release_dir/hashcheck/build"
(cd "$release_dir/hashcheck" && shasum -a 256 -c "$candidate/SHA256SUMS")
mkdir "$release_dir/unpacked"
ditto -x -k "$candidate/EdgeControl-macOS.zip" "$release_dir/unpacked"
app="$release_dir/unpacked/EdgeControl.app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "$build" ]]
codesign --verify --deep --strict "$app"
architectures="$(lipo -archs "$app/Contents/MacOS/EdgeControl")"
[[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]]
hdiutil verify "$candidate/EdgeControl-macOS.dmg"
mkdir "$release_dir/assets"
cp "$candidate/EdgeControl-macOS.zip" "$release_dir/assets/EdgeControl-$version-macOS.zip"
cp "$candidate/EdgeControl-macOS.dmg" "$release_dir/assets/EdgeControl-$version-macOS.dmg"
archive="$release_dir/assets/EdgeControl-$version-macOS.zip"
# Fail before creating/publishing a release if the original Keychain key is unavailable.
signature="$("$signer" -p "$archive")"
public_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")"
xcrun swift -sdk "$(xcrun --show-sdk-path)" -module-cache-path "$release_dir/module-cache" "$script_dir/verify_update.swift" "$archive" "$public_key" "$signature"
mkdir "$release_dir/previous"
gh release download v1.7.4 --repo "$repo" --pattern appcast.xml --dir "$release_dir/previous"
python3 - "$release_dir" "$version" "$build" "$signature" <<'PY'
import sys, pathlib, datetime, email.utils, xml.etree.ElementTree as ET
root,version,build,sig=sys.argv[1:];root=pathlib.Path(root)
ns='http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle',ns)
p=root/'previous/appcast.xml'; tree=ET.parse(p);channel=tree.getroot().find('channel')
assert channel is not None
item=ET.Element('item');ET.SubElement(item,'title').text=f'EdgeControl {version}'
ET.SubElement(item,'pubDate').text=email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
ET.SubElement(item,f'{{{ns}}}minimumSystemVersion').text='13.0'
ET.SubElement(item,'description').text='Brightness write deduplication, horizontal jitter filtering, invalid input rejection, and empty-display handling.'
archive=root/f'assets/EdgeControl-{version}-macOS.zip'
ET.SubElement(item,'enclosure',{'url':f'https://github.com/leecdiang/EdgeControl/releases/download/v{version}/{archive.name}','length':str(archive.stat().st_size),'type':'application/octet-stream',f'{{{ns}}}version':build,f'{{{ns}}}shortVersionString':version,f'{{{ns}}}edSignature':sig})
channel.insert(0,item);tree.write(root/'assets/appcast.xml',encoding='utf-8',xml_declaration=True)
PY
# Resolve release notes from the exact tested commit.
gh api "repos/$repo/contents/RELEASE_NOTES_$version.md?ref=$commit" --jq .content | base64 --decode > "$release_dir/notes.md"
(cd "$release_dir/assets" && shasum -a 256 ./* > "$release_dir/SHA256SUMS")
# An existing tag is deliberately not overwritten. Resume an interrupted draft manually.
gh api "repos/$repo/git/refs" --method POST -f "ref=refs/tags/$tag" -f "sha=$commit" > "$release_dir/tag.json"
gh release create "$tag" --repo "$repo" --verify-tag --draft --title "EdgeControl $version" --notes-file "$release_dir/notes.md"
gh release upload "$tag" --repo "$repo" "$release_dir/assets/EdgeControl-$version-macOS.dmg" "$archive" "$release_dir/assets/appcast.xml"
mkdir "$release_dir/downloaded"
gh release download "$tag" --repo "$repo" --dir "$release_dir/downloaded"
(cd "$release_dir/downloaded" && shasum -a 256 -c "$release_dir/SHA256SUMS")
gh release edit "$tag" --repo "$repo" --draft=false --latest
# Replace only this app, retaining a complete recoverable copy.
if pgrep -x EdgeControl >/dev/null; then
    killall -TERM EdgeControl
    for _ in {1..50}; do
        pgrep -x EdgeControl >/dev/null || break
        sleep 0.1
    done
    if pgrep -x EdgeControl >/dev/null; then
        echo "Published; EdgeControl did not exit. Local installation was not changed." >&2
        exit 1
    fi
fi
staged_app="/Applications/EdgeControl-update-$run_id.app"
[[ ! -e "$staged_app" ]] || { echo "Existing staged app: $staged_app" >&2; exit 1; }
ditto "$app" "$staged_app"
codesign --verify --deep --strict "$staged_app"
cmp "$app/Contents/MacOS/EdgeControl" "$staged_app/Contents/MacOS/EdgeControl"
if [[ -d /Applications/EdgeControl.app ]]; then
    mv /Applications/EdgeControl.app "$release_dir/EdgeControl-previous.app"
fi
if ! mv "$staged_app" /Applications/EdgeControl.app; then
    if [[ -d "$release_dir/EdgeControl-previous.app" ]]; then
        mv "$release_dir/EdgeControl-previous.app" /Applications/EdgeControl.app
    fi
    exit 1
fi
open /Applications/EdgeControl.app
sleep 2
pgrep -x EdgeControl >/dev/null
echo "Published $tag and installed $version ($build). Backup and verified packages: $release_dir"
