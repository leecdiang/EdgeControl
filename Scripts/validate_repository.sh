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
  "EdgeControl/System/RecentKeyboardActivityGuard.swift"
  "EdgeControl/Feedback/HapticEngine.swift"
  "EdgeControl/UI/HUDController.swift"
  "EdgeControlTests/GestureEngineTests.swift"
  ".github/workflows/ci.yml"
  "README.md"
  "LICENSE"
  "THIRD_PARTY_NOTICES.md"
  "HANDOFF_TO_OPENCLAW.md"
  "OPENCLAW_VALIDATE_1.6.0.md"
  "OPENCLAW_VALIDATE_1.7.0.md"
  "RELEASE_NOTES_1.6.0.md"
  "RELEASE_NOTES_1.7.0.md"
  "Docs/LOCAL_VALIDATION_REQUIRED.md"
  "Docs/RELEASE_NOTES_1.6.0.md"
  "Docs/RELEASE_NOTES_1.6.0.zh.md"
  "Docs/RELEASE_NOTES_1.7.0.md"
  "Docs/RELEASE_NOTES_1.7.0.zh.md"
  "Docs/STATIC_BUG_AUDIT_1.3.1.md"
  "Docs/STATIC_BUG_AUDIT_1.4.0.md"
)

for relative_path in "${required[@]}"; do
  if [[ ! -e "$project_root/$relative_path" ]]; then
    echo "Missing: $relative_path" >&2
    exit 1
  fi
done

project_file="$project_root/EdgeControl.xcodeproj/project.pbxproj"
version_count="$(grep -F 'MARKETING_VERSION = 1.7.0;' "$project_file" | wc -l | tr -d ' ')"
if [[ "$version_count" -ne 2 ]]; then
  echo "Expected Debug and Release MARKETING_VERSION 1.7.0, found $version_count." >&2
  exit 1
fi

build_count="$(grep -F 'CURRENT_PROJECT_VERSION = 5;' "$project_file" | wc -l | tr -d ' ')"
if [[ "$build_count" -ne 2 ]] || ! grep -Fq '<string>$(CURRENT_PROJECT_VERSION)</string>' "$project_root/EdgeControl/Info.plist"; then
  echo "Expected build number 5 to be sourced from CURRENT_PROJECT_VERSION." >&2
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
if [[ "$test_method_count" -lt 68 ]]; then
  echo "Expected at least 68 XCTest methods, found $test_method_count." >&2
  exit 1
fi

typing_guard="$project_root/EdgeControl/System/RecentKeyboardActivityGuard.swift"
required_typing_guard_markers=(
  "CGEventSource.secondsSinceLastEventType"
  "suppressionInterval.isFinite"
  "elapsed.isFinite"
)

for expected_marker in "${required_typing_guard_markers[@]}"; do
  if ! grep -Fq "$expected_marker" "$typing_guard"; then
    echo "Recent-typing guard drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

settings_file="$project_root/EdgeControl/Settings/AppSettings.swift"
required_independent_profile_markers=(
  "case .precise: return 0.50"
  "case .standard: return 0.70"
  "case .fast: return 0.95"
  "case .strong: return 0.600"
  "case .standard: return 0.350"
  "case .light: return 0.200"
  "case .strong: return 0.007"
  "case .light: return 0.021"
  "migrated(fromLegacySensitivity"
  "enum HapticStrength"
  "case .light: return 0.04"
  "case .standard, .strong: return 0.02"
  "enum HUDColorStyle"
  "case aurora"
  "case morandi"
  "legacyColorfulHUD ? .classic : .system"
)

for expected_marker in "${required_independent_profile_markers[@]}"; do
  if ! grep -Fq "$expected_marker" "$settings_file"; then
    echo "Independent speed/protection preset drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

menu_view="$project_root/EdgeControl/UI/MenuBarMenuView.swift"
settings_view="$project_root/EdgeControl/UI/SettingsView.swift"
required_ui_markers=(
  '.menuBarExtraStyle(.window)'
  'EdgeActionCard'
  'QuickToggle'
  'HUDPalettePreview'
  'selection: $settings.hudColorStyle'
  'EdgeSettingsGlass'
  '.fullSizeContentView'
  'testLegacyColorfulHUDMigratesToThreeLevelPalette'
  'testMorandiPaletteIsSelectableAndPersists'
)

for expected_marker in "${required_ui_markers[@]}"; do
  if ! grep -R -Fq "$expected_marker" \
    "$project_root/EdgeControl/App/EdgeControlApp.swift" \
    "$project_root/EdgeControl/App/EdgeControlAppModel.swift" \
    "$menu_view" "$settings_view" \
    "$project_root/EdgeControlTests/SettingsTests.swift"; then
    echo "1.6.0 menu/settings invariant drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

required_session_pinning_markers=(
  "speedMultiplier: settings.adjustmentSpeed.gainMultiplier"
  "settings.falseTouchProtection.typingSuppressionInterval"
  "discardTouchFramesUntilLift = discardTouchFramesUntilLift || hasLiveTouchContacts"
)

for expected_marker in "${required_session_pinning_markers[@]}"; do
  if ! grep -Fq "$expected_marker" "$app_model"; then
    echo "Speed/protection lifecycle guard drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

required_typing_latch_markers=(
  "recentKeyboardActivity"
  "blockNewGestureForRecentTyping"
  "case .idle, .entryCandidate, .entryConfirmed"
)

for expected_marker in "${required_typing_latch_markers[@]}"; do
  if ! grep -Fq "$expected_marker" "$project_root/EdgeControl/Gesture/GestureEngine.swift"; then
    echo "Recent-typing lifecycle guard drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

required_zero_cross_markers=(
  "committedDirection"
  "direction != active.committedDirection"
  "testGradualZeroCrossingCannotEscapeThroughDeadband"
)

for expected_marker in "${required_zero_cross_markers[@]}"; do
  if ! grep -R -Fq "$expected_marker" \
    "$project_root/EdgeControl/Gesture/GestureEngine.swift" \
    "$project_root/EdgeControlTests/GestureEngineTests.swift"; then
    echo "Committed zero-cross guard drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

if grep -R -n -E 'CGEventTap|addGlobalMonitorForEvents|IOHIDManager' \
  "$project_root/EdgeControl" --include='*.swift' --include='*.c'; then
  echo "Keyboard capture/monitor API found; elapsed-time-only policy violated." >&2
  exit 1
fi

brightness_controller="$project_root/EdgeControl/Display/DisplayBrightnessController.swift"
required_brightness_routing_markers=(
  "external.enabled && external.isAvailable"
  "guard external.enabled else"
  "func beginSession() throws -> BrightnessControlSession"
  "builtIn.refresh()"
)

for expected_marker in "${required_brightness_routing_markers[@]}"; do
  if ! grep -Fq "$expected_marker" "$brightness_controller"; then
    echo "Brightness routing guard drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

ddc_backend="$project_root/EdgeControl/Display/ExternalDDCBackend.swift"
required_ddc_session_markers=(
  "selectedConnectionIndex = index"
  "lastResponsiveIndex: selectedConnectionIndex"
  "testExternalDDCWritesBackToTheResponsiveConnection"
)

for expected_marker in "${required_ddc_session_markers[@]}"; do
  if ! grep -R -Fq "$expected_marker" \
    "$ddc_backend" "$project_root/EdgeControlTests/SettingsTests.swift"; then
    echo "DDC responsive-connection pinning drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

if ! grep -Fq "guard let activeDisplays = activeDisplayProvider() else { return }" \
  "$project_root/EdgeControl/Display/BuiltInDisplayBackend.swift"; then
  echo "Built-in display refresh must preserve its last ID on query failure." >&2
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
  "static let compactWidth: CGFloat = 144"
  "static let errorWidth: CGFloat = 212"
  "static let height: CGFloat = 40"
  "CapsuleVisualEffect"
  "view.material = .hudWindow"
  "Color(nsColor: .windowBackgroundColor).opacity(0.52)"
  ".clipShape(Capsule())"
  "case (.morandi, .volume)"
)

for expected_marker in "${required_hud_markers[@]}"; do
  if ! grep -Fq "$expected_marker" "$hud_controller"; then
    echo "Compact HUD invariant drifted or is missing: $expected_marker" >&2
    exit 1
  fi
done

haptic_engine="$project_root/EdgeControl/Feedback/HapticEngine.swift"
required_haptic_lifecycle_markers=(
  "secondaryPulseTask?.cancel()"
  "pulseGeneration == generation"
  "testEndingGestureCancelsPendingStrongSecondaryPulse"
  "testWakeResetCancelsPendingStrongSecondaryPulse"
)

for expected_marker in "${required_haptic_lifecycle_markers[@]}"; do
  if ! grep -R -Fq "$expected_marker" \
    "$haptic_engine" "$project_root/EdgeControlTests/HapticEngineTests.swift"; then
    echo "Strong haptic lifecycle guard drifted or is missing: $expected_marker" >&2
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
