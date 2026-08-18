#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
derived_data="$project_root/build/DerivedData"
archive_path="$project_root/build/EdgeControl.xcarchive"
action="${1:-all}"

common_args=(
  -project "$project_root/EdgeControl.xcodeproj"
  -scheme EdgeControl
  -destination "platform=macOS"
  -derivedDataPath "$derived_data"
)

signing_args=()
if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  signing_args+=(CODE_SIGNING_ALLOWED=NO)
else
  signing_args+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
  if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    signing_args+=(CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY")
  fi
fi

run_tests() {
  xcodebuild "${common_args[@]}" -configuration Debug test "${signing_args[@]}"
}

run_build() {
  xcodebuild "${common_args[@]}" -configuration Release clean build "${signing_args[@]}"
  local app_path="$derived_data/Build/Products/Release/EdgeControl.app"
  if [[ -z "${DEVELOPMENT_TEAM:-}" && -d "$app_path" ]]; then
    # Full ad-hoc re-sign: without this, the bundle only carries a linker
    # signature on arm64 (no _CodeSignature/CodeResources, x86_64 slice
    # unsigned). A complete ad-hoc signature is free and makes the app
    # verifiable on any Mac.
    codesign --force --sign - "$app_path"
  fi
  echo "Built app: $app_path"
}

run_archive() {
  mkdir -p "$project_root/build"
  xcodebuild \
    -project "$project_root/EdgeControl.xcodeproj" \
    -scheme EdgeControl \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$archive_path" \
    archive \
    "${signing_args[@]}"
  echo "Archive: $archive_path"
}

case "$action" in
  test) run_tests ;;
  build) run_build ;;
  archive) run_archive ;;
  all)
    run_tests
    run_build
    ;;
  *)
    echo "Usage: $0 [test|build|archive|all]" >&2
    exit 2
    ;;
esac
