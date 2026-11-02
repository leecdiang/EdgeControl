#!/bin/bash
set -euo pipefail
[[ $# == 2 || $# == 3 ]] || { echo "Usage: $0 feed.xml newest-build [Sparkle-framework-directory]" >&2; exit 2; }
script_dir="$(cd "$(dirname "$0")" && pwd)"
framework_dir="${3:-$script_dir/../build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64}"
[[ -d "$framework_dir/Sparkle.framework" ]] || { echo "Sparkle framework unavailable: $framework_dir" >&2; exit 1; }
framework_dir="$(cd "$framework_dir" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/EdgeControl-feed-check.XXXXXX")"
trap 'rm -rf "$work"' EXIT
xcrun clang "$script_dir/validate_appcast.m" -fobjc-arc -fmodules \
  -fmodules-cache-path="$work/module-cache" -framework Foundation -framework Sparkle \
  -F "$framework_dir" -Wl,-rpath,"$framework_dir" -o "$work/validate_appcast"
"$work/validate_appcast" "$1" "$2"
