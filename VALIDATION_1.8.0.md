# Adaptive HUD and settings validation

Baseline: 1.7.7, main 9bd0d6f0ed23e91c2e51730051ae5e95cdbc2722.

The settings hierarchy is Gestures / Feedback / General. Legacy global action disablement is migrated once to explicit disabled edge assignments. Existing hidden HUDs remain hidden; new notch mode is opt-in. Quick HUD toggles remember the last visible mode.

Placement uses NSScreen frame, visibleFrame, safeAreaInsets and auxiliary areas in points. Geometry coverage includes different scaled notch sizes, external/notchless monitors, negative and vertically stacked origins, portrait displays, malformed cutout metadata, menu-bar visibility, error width, pinned display identity and disconnection fallback. Brightness sessions expose the selected backend display ID only for HUD placement. Hardware control routing is unchanged.

Alcove 1.7.9 is installed on the user's machine. Detection is informational only. Off / External does not guarantee Alcove receives programmatic adjustments, does not launch/configure it, and never synthesizes media-key events. User-assisted physical validation remains necessary: check actual gestures for volume and built-in brightness, fullscreen, output-device changes, and external DDC where available; restore Capsule if external feedback is missing.

The software test matrix is not a claim of physical cross-model certification. Check notch positioning on actual MacBook screens, menu bar overlap, fullscreen/Spaces, Reduce Motion/Transparency, large settings window, and external-display hotplug. CI results and native UI attachments are recorded in the PR.

Native CI snapshots were visually inspected in light and dark appearances. The settings background was made explicit so text remains legible without a backdrop, and preview captures wait for the entrance animation. Three settings pages and both HUD styles are included in the CI artifact.
