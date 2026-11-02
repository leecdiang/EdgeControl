# EdgeControl 1.8.0 (build 14)

- Organize settings into Gestures, Feedback, and General, with a visual trackpad guide and fewer competing switches. Preserve previously disabled actions during migration.
- Choose Capsule, Notch, or Off / External HUD modes. Notch uses screen geometry; displays without a usable camera cutout use a top capsule.
- Keep brightness feedback on the controlled display and volume feedback on the gesture-start display. Value bars update directly without repeated easing.
- Preview the HUD without changing system values, and try haptic feedback from settings.
- Show an Alcove coexistence explanation when installed; no automatic integration or simulated brightness/volume keys.

Geometry and lifecycle coverage does not certify every physical display, macOS fullscreen configuration, or Alcove notification path. Existing users retain their visible/hidden HUD preference and the default capsule style.
