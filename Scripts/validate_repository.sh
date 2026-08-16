#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

required=(
  "EdgeControl.xcodeproj/project.pbxproj"
  "EdgeControl/App/EdgeControlApp.swift"
  "EdgeControl/Input/TrackpadManager.swift"
  "EdgeControl/Gesture/GestureEngine.swift"
  "EdgeControl/Actions/VolumeController.swift"
  "EdgeControl/Display/BuiltInDisplayBackend.swift"
  "EdgeControl/Display/ExternalDDCBackend.swift"
  "EdgeControl/Feedback/HapticEngine.swift"
  "EdgeControl/UI/HUDController.swift"
  "EdgeControlTests/GestureEngineTests.swift"
  "README.md"
  "LICENSE"
  "THIRD_PARTY_NOTICES.md"
  "HANDOFF_TO_OPENCLAW.md"
  "Docs/LOCAL_VALIDATION_REQUIRED.md"
)

for relative_path in "${required[@]}"; do
  if [[ ! -e "$project_root/$relative_path" ]]; then
    echo "Missing: $relative_path" >&2
    exit 1
  fi
done

if grep -R -n -E 'URLSession|Network\.framework|import Network|telemetry|analytics SDK' \
  "$project_root/EdgeControl" --include='*.swift' --include='*.c'; then
  echo "Potential network or telemetry reference found." >&2
  exit 1
fi

local_validation_count="$(grep -R -h 'LOCAL_VALIDATION_REQUIRED' "$project_root/EdgeControl" "$project_root/Docs" | wc -l | tr -d ' ')"
if [[ "$local_validation_count" -lt 8 ]]; then
  echo "Expected explicit LOCAL_VALIDATION_REQUIRED markers." >&2
  exit 1
fi

echo "Repository structure and offline-runtime guard checks passed."
echo "LOCAL_VALIDATION_REQUIRED markers: $local_validation_count"
echo "A real macOS xcodebuild is still required."

