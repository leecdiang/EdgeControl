#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/EdgeControl-feed-tests.XXXXXX")"
trap 'rm -rf "$work"' EXIT
python3 -m unittest discover -s "$script_dir/Tests" -p 'test_appcast.py'
fixture="$script_dir/Tests/Fixtures/appcast-legacy-namespace.xml"
# A negative test must fail for the parser reason, not a missing compiler/file.
if bash "$script_dir/validate_appcast.sh" "$fixture" 17 > "$work/negative.log" 2>&1; then
    echo 'Regression fixture unexpectedly accepted by Sparkle' >&2; exit 1
fi
grep -F 'Feed item lacks sparkle:version' "$work/negative.log"
python3 "$script_dir/appcast.py" "$fixture" "$work/appcast.xml" --build 17
bash "$script_dir/validate_appcast.sh" "$work/appcast.xml" 17
# Exercise generation of a new entry using public-format test signature bytes.
printf 'fixture archive' > "$work/archive.zip"
signature="$(python3 -c 'import base64; print(base64.b64encode(bytes(64)).decode())')"
python3 "$script_dir/appcast.py" "$work/appcast.xml" "$work/new.xml" --build 18 \
    --version 1.8.4 --archive "$work/archive.zip" --signature "$signature" --description 'Feed regression fixture'
bash "$script_dir/validate_appcast.sh" "$work/new.xml" 18
python3 - "$script_dir" "$work/new.xml" "$signature" <<'PY'
import sys, xml.etree.ElementTree as ET
sys.path.insert(0, sys.argv[1])
from appcast import signature_for
assert signature_for(ET.parse(sys.argv[2]).getroot(), '1.8.4', 18) == sys.argv[3]
print('Generated feed is compatible with local installer signature selection')
PY
