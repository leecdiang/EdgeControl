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
  ".github/workflows/ci.yml"
  "README.md"
  "LICENSE"
  "THIRD_PARTY_NOTICES.md"
  "HANDOFF_TO_OPENCLAW.md"
  "OPENCLAW_VALIDATE_1.3.0.md"
  "Docs/LOCAL_VALIDATION_REQUIRED.md"
  "Docs/RELEASE_NOTES_1.3.0.md"
)

for relative_path in "${required[@]}"; do
  if [[ ! -e "$project_root/$relative_path" ]]; then
    echo "Missing: $relative_path" >&2
    exit 1
  fi
done

project_file="$project_root/EdgeControl.xcodeproj/project.pbxproj"
version_count="$(grep -F 'MARKETING_VERSION = 1.3.0;' "$project_file" | wc -l | tr -d ' ')"
if [[ "$version_count" -ne 2 ]]; then
  echo "Expected Debug and Release MARKETING_VERSION 1.3.0, found $version_count." >&2
  exit 1
fi

gesture_types="$project_root/EdgeControl/Gesture/EdgeGestureTypes.swift"
required_gesture_defaults=(
  "var entryCorridor: Double = 0.03"
  "var controlCorridor: Double = 0.08"
  "var directionalityRatio: Double = 0.80"
  "var entryTimeout: TimeInterval = 0.450"
)

for expected_default in "${required_gesture_defaults[@]}"; do
  if ! grep -Fq "$expected_default" "$gesture_types"; then
    echo "Gesture default drifted or is missing: $expected_default" >&2
    exit 1
  fi
done

app_model="$project_root/EdgeControl/App/EdgeControlAppModel.swift"
required_disconnect_guards=(
  "hasLiveTouchContacts"
  "discardTouchFramesUntilLift"
  "silence >= 0.750"
  "live touch reset after callback silence"
)

for expected_marker in "${required_disconnect_guards[@]}"; do
  if ! grep -Fq "$expected_marker" "$app_model"; then
    echo "External-trackpad disconnect guard drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

test_method_count="$(grep -R -h -E '^[[:space:]]+func test' "$project_root/EdgeControlTests" | wc -l | tr -d ' ')"
if [[ "$test_method_count" -lt 35 ]]; then
  echo "Expected at least 35 XCTest methods, found $test_method_count." >&2
  exit 1
fi

bridge="$project_root/EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.c"
required_external_trackpad_markers=(
  'dlsym(framework, "MTDeviceCreateList")'
  'dlsym(framework, "MTDeviceIsBuiltIn")'
  '"MTDeviceGetSensorSurfaceDimensions"'
  'EC_TRACKPAD_SELECTION_EXTERNAL'
)

for expected_marker in "${required_external_trackpad_markers[@]}"; do
  if ! grep -Fq "$expected_marker" "$bridge"; then
    echo "External-trackpad guard drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

if ! grep -Fq '#if defined(EDGE_DEBUG_LOGGING) && EDGE_DEBUG_LOGGING' \
  "$project_root/EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.c"; then
  echo "The C raw-touch probe must remain compile-gated to Debug builds." >&2
  exit 1
fi

hud_controller="$project_root/EdgeControl/UI/HUDController.swift"
required_hud_markers=(
  "static let compactWidth: CGFloat = 148"
  "static let errorWidth: CGFloat = 220"
  "static let height: CGFloat = 42"
  ".glassEffect(.regular.tint(tint), in: Capsule())"
  ".background(.ultraThinMaterial, in: Capsule())"
)

for expected_marker in "${required_hud_markers[@]}"; do
  if ! grep -Fq "$expected_marker" "$hud_controller"; then
    echo "Compact HUD invariant drifted or is missing: $expected_marker" >&2
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
echo "XCTest methods: $test_method_count"
echo "Run xcodebuild on macOS to compile and execute the tests."
