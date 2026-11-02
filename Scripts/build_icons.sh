#!/bin/bash
# Package the approved 1024 px artwork without changing its design or transparency.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
master="$root/assets/icon-1024.png"
catalog="$root/EdgeControl/Assets.xcassets/AppIcon.appiconset"
work="$(mktemp -d "${TMPDIR:-/tmp}/EdgeControl-icons.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir "$work/AppIcon.iconset"
for size in 16 32 128 256 512; do
    for scale in 1 2; do
        pixels=$((size * scale))
        suffix=""; [[ "$scale" == 1 ]] || suffix="@2x"
        name="${size}x${size}${suffix}.png"
        sips -z "$pixels" "$pixels" "$master" --out "$catalog/AppIcon_$name" >/dev/null
        cp "$catalog/AppIcon_$name" "$work/AppIcon.iconset/icon_$name"
    done
done
cp "$catalog/AppIcon_512x512.png" "$root/assets/icon-512.png"
# Package the PNG representations directly. This only writes the ICNS container;
# image pixels and their alpha channels are unchanged by this step.
python3 - "$work/AppIcon.iconset" "$root/EdgeControl/Resources/AppIcon.icns" <<'PY'
import pathlib, struct, sys
root = pathlib.Path(sys.argv[1])
entries = [('icp4', '16x16'), ('ic11', '16x16@2x'), ('icp5', '32x32'),
           ('ic12', '32x32@2x'), ('ic07', '128x128'), ('ic13', '128x128@2x'),
           ('ic08', '256x256'), ('ic14', '256x256@2x'), ('ic09', '512x512'), ('ic10', '512x512@2x')]
chunks = []
for kind, name in entries:
    png = (root / ('icon_' + name + '.png')).read_bytes()
    assert png.startswith(b'\x89PNG\r\n\x1a\n')
    chunks.append(kind.encode('ascii') + struct.pack('>I', len(png) + 8) + png)
payload = b''.join(chunks)
pathlib.Path(sys.argv[2]).write_bytes(b'icns' + struct.pack('>I', len(payload) + 8) + payload)
PY
