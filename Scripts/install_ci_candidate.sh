#!/bin/bash
# Install exactly one validated PR commit; this never creates a tag or release.
set -euo pipefail
[[ $# == 2 || ( $# == 3 && "$3" == --verify-only ) ]] || {
    echo "Usage: $0 successful-run-id expected-commit-sha [--verify-only]" >&2; exit 2;
}
run_id="$1"
expected_commit="$2"
[[ "$run_id" =~ ^[0-9]+$ && "$expected_commit" =~ ^[0-9a-f]{40}$ ]] || exit 2
repo="leecdiang/EdgeControl"
version="1.8.4"
build="18"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$project_root/build"
evidence="$(mktemp -d "$project_root/build/pr-install-$version.XXXXXX")"
work="$(mktemp -d "${TMPDIR:-/tmp}/EdgeControl-ci-install.XXXXXX")"
trap 'rm -rf "$work"' EXIT
echo "Installation evidence and backup: $evidence"
gh api "repos/$repo/actions/runs/$run_id" > "$evidence/run.json"
python3 - "$evidence/run.json" "$expected_commit" "$repo" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r['head_sha']==sys.argv[2], 'Run is not for the expected commit'
assert r['conclusion']=='success' and r['status']=='completed', 'CI has not passed'
assert r['path']=='.github/workflows/ci.yml', 'Unexpected workflow'
assert r['head_repository']['full_name']==sys.argv[3], 'Unexpected source repository'
assert r['event']=='push', 'Select the branch push run, not the PR merge preview'
PY
gh run download "$run_id" --repo "$repo" --name "EdgeControl-candidate-$expected_commit" --dir "$evidence/candidate"
[[ "$(cat "$evidence/candidate/SOURCE_COMMIT")" == "$expected_commit" ]]
mkdir "$work/hashcheck"
ln -s "$evidence/candidate" "$work/hashcheck/build"
(cd "$work/hashcheck" && shasum -a 256 -c "$evidence/candidate/SHA256SUMS")
unzip -t "$evidence/candidate/EdgeControl-macOS.zip" > "$evidence/zip-verification.txt"
hdiutil verify "$evidence/candidate/EdgeControl-macOS.dmg" > "$evidence/dmg-verification.txt"
ditto -x -k "$evidence/candidate/EdgeControl-macOS.zip" "$work/unpacked"
app="$work/unpacked/EdgeControl.app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "$build" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == "org.edgecontrol.EdgeControl" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")" == "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' /Applications/EdgeControl.app/Contents/Info.plist)" ]]
codesign --verify --deep --strict "$app"
architectures="$(lipo -archs "$app/Contents/MacOS/EdgeControl")"
[[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]]
if [[ "${3:-}" == --verify-only ]]; then
    echo "Verified PR candidate $version ($build) at $expected_commit; installation unchanged."
    exit 0
fi
stage_dir="$(mktemp -d /Applications/EdgeControl-install.XXXXXX)"
staged="$stage_dir/EdgeControl.app"
ditto --norsrc --noextattr --qtn --acl "$app" "$staged"
codesign --verify --deep --strict "$staged"
python3 - "$app" "$staged" <<'PY'
import hashlib,os,pathlib,stat,sys
def manifest(root):
    root=pathlib.Path(root); result={}
    for directory,dirs,files in os.walk(root,followlinks=False):
        for name in dirs+files:
            p=pathlib.Path(directory)/name; mode=p.lstat().st_mode
            item=(stat.S_IFMT(mode),stat.S_IMODE(mode))
            if p.is_symlink(): item+=(os.readlink(p),)
            elif p.is_file(): item+=(hashlib.sha256(p.read_bytes()).hexdigest(),)
            result[str(p.relative_to(root))]=item
    return result
assert manifest(sys.argv[1])==manifest(sys.argv[2]), 'Staged bundle differs'
PY
if pgrep -x EdgeControl >/dev/null; then
    killall -TERM EdgeControl
    for _ in {1..50}; do
        pgrep -x EdgeControl >/dev/null || break
        sleep 0.1
    done
    if pgrep -x EdgeControl >/dev/null; then
        echo "EdgeControl did not exit; installed app is unchanged." >&2; exit 1
    fi
fi
mv /Applications/EdgeControl.app "$evidence/EdgeControl-previous.app"
if ! mv "$staged" /Applications/EdgeControl.app; then
    mv "$evidence/EdgeControl-previous.app" /Applications/EdgeControl.app
    open /Applications/EdgeControl.app
    exit 1
fi
rmdir "$stage_dir"
if ! codesign --verify --deep --strict /Applications/EdgeControl.app; then
    mv /Applications/EdgeControl.app "$evidence/EdgeControl-failed.app"
    mv "$evidence/EdgeControl-previous.app" /Applications/EdgeControl.app
    open /Applications/EdgeControl.app
    exit 1
fi
open /Applications/EdgeControl.app
sleep 2
pgrep -x EdgeControl >/dev/null
echo "Installed PR candidate $version ($build), commit $expected_commit. Backup: $evidence/EdgeControl-previous.app"
