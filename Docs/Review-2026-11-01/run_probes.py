#!/usr/bin/env python3
"""Review probes for the 1.7.5 snapshot. No real device writes or network requests.
Bug assertions intentionally describe the reviewed behavior, not desired behavior.
Generated/instrumented sources live under build/full-review-repro.
"""
from pathlib import Path
import subprocess
import shutil
import hashlib
import json

fixtures = Path(__file__).resolve().parent
root = fixtures.parents[1]
manifest = json.loads((fixtures / "coverage.json").read_text())
for entry in manifest["files"]:
    if hashlib.sha256((root / entry["path"]).read_bytes()).hexdigest() != entry["sha256"]:
        raise SystemExit("Historical probes require audited tree " + manifest["reviewed_tree"] + "; use the current XCTest regressions after fixes.")
work = root / "build/full-review-repro"
work.mkdir(parents=True, exist_ok=True)
log = []
def run(args):
    result = subprocess.run([str(a) for a in args], cwd=root, capture_output=True, text=True)
    output = result.stdout + result.stderr
    log.append(output)
    print(output, end="", flush=True)
    (work / "results.txt").write_text("".join(log))
    if result.returncode:
        raise SystemExit(result.returncode)
sdk = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()
common = ["xcrun", "swiftc", "-swift-version", "5", "-enable-upcoming-feature", "StrictConcurrency",
          "-sdk", sdk, "-module-cache-path", work / "ModuleCache"]
source = (root / "EdgeControl/App/EdgeControlAppModel.swift").read_text()
source = source.replace("private func consume(", "func consume(")
source = source.replace("    private func beginSession(edge: Edge) {",
    "    var reviewHasSession: Bool { session != nil }\n"
    "    var reviewCursorFrozen: Bool { cursorController.isFrozen }\n"
    "    private func beginSession(edge: Edge) {")
(work / "AppModel.swift").write_text(source)
shutil.copyfile(fixtures / "AppModelProbe.swift", work / "main.swift")
run(common + [root / p for p in [
    "EdgeControl/Settings/AppSettings.swift", "EdgeControl/Settings/EdgeAction.swift",
    "EdgeControl/Input/TouchModels.swift", "EdgeControl/Gesture/EdgeGestureTypes.swift",
    "EdgeControl/Gesture/GestureEngine.swift", "EdgeControl/Actions/ContinuousValueMapper.swift",
    "EdgeControl/Actions/ControlErrors.swift", "EdgeControl/System/RecentKeyboardActivityGuard.swift"
]] + [fixtures / "AppModelStubs.swift", work / "AppModel.swift", work / "main.swift", "-o", work / "appmodel"])
run([work / "appmodel"])
source = (root / "EdgeControl/Actions/VolumeController.swift").read_text()
for name in ["AudioObjectGetPropertyData", "AudioObjectSetPropertyData", "AudioObjectHasProperty", "AudioObjectIsPropertySettable"]:
    source = source.replace(name, "Review" + name)
(work / "VolumeController.swift").write_text(source)
run(common + [root / "EdgeControl/Actions/ControlErrors.swift", root / "EdgeControl/Actions/ContinuousValueMapper.swift",
    work / "VolumeController.swift", fixtures / "VolumeProbe.swift", "-o", work / "volume"])
run([work / "volume"])
run(["xcrun", "clang", "-isysroot", sdk, "-I", root / "EdgeControl/PrivateFrameworks", fixtures / "DDCProbe.c",
    root / "EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.c", "-framework", "CoreFoundation",
    "-framework", "CoreGraphics", "-framework", "IOKit", "-o", work / "ddc"])
run([work / "ddc"])
settings = (root / "EdgeControl/Settings/AppSettings.swift").read_text()
strength = settings.split("enum HapticStrength",1)[1].split("enum HUDColorStyle",1)[0]
(work / "Strength.swift").write_text("import Foundation\nenum HapticStrength" + strength)
shutil.copyfile(fixtures / "HapticProbe.swift", work / "main.swift")
run(common + [root / "EdgeControl/Feedback/HapticEngine.swift", root / "EdgeControl/Feedback/DetentTracker.swift",
    work / "Strength.swift", work / "main.swift", "-o", work / "haptic"])
run([work / "haptic"])
print("All review probes completed. Results:", work / "results.txt")
