#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$(mktemp -d "${TMPDIR:-/tmp}/edgecontrol-display-test.XXXXXX")"
trap 'rm -rf "$output"' EXIT
xcrun clang -Wall -Wextra "$root/Scripts/Tests/display_services_cache_test.c" \
  -framework CoreFoundation -framework CoreGraphics -framework IOKit \
  -o "$output/display-services-test"
"$output/display-services-test"
