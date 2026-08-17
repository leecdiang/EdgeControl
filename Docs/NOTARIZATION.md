# Notarization

This document is prepared so that only credentials need to be supplied to produce a production-notarized DMG. Nothing here requires code changes.

## Current state (2026-08-17)

- **Signing:** ad-hoc (`codesign --force --deep --sign -`). The validation machine has no Apple Developer ID certificate (`security find-identity -v -p codesigning` returns none).
- **Notarization:** NOT PERFORMED.
- **Distribution artifact:** `dist/EdgeControl-1.1.0-macOS.dmg`, signed ad-hoc, verified drag-to-Applications install for the 1.1.0 baseline.

## Prerequisites (user-supplied, via local keychain only)

1. An Apple Developer Program membership.
2. A **Developer ID Application** certificate installed in the local keychain (name e.g. `Developer ID Application: Your Name (TEAMID)`).
3. An App Store Connect API key or an app-specific password stored as a notarytool keychain profile, e.g.:

```bash
xcrun notarytool store-credentials "EdgeControl-Notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

Credentials must never be typed into chat, files, or scripts by anyone else. Use only the local keychain.

## Steps

```bash
cd <repo>
APP=build/DerivedData/Build/Products/Release/EdgeControl.app
IDENTITY="Developer ID Application: Your Name (TEAMID)"
NOTARY_PROFILE="EdgeControl-Notary"
VERSION=1.1.0

# 1. Build Release
./Scripts/build_release.sh build

# 2. Sign the app with hardened runtime + timestamp (the project already sets
#    ENABLE_HARDENED_RUNTIME = YES in Release).
codesign --force --timestamp \
  --options runtime \
  --sign "$IDENTITY" \
  --entitlements EdgeControl/EdgeControl.entitlements \
  "$APP"

# 3. Verify
codesign --verify --deep --strict --verbose=2 "$APP"

# 4. Package the DMG (signs the DMG with the same identity)
CODESIGN_IDENTITY="$IDENTITY" ./Scripts/package_dmg.sh "$APP" "dist/EdgeControl-$VERSION-macOS.dmg"

# 5. Notarize + staple
xcrun notarytool submit "dist/EdgeControl-$VERSION-macOS.dmg" \
  --keychain-profile "$NOTARY_PROFILE" --wait

xcrun stapler staple "dist/EdgeControl-$VERSION-macOS.dmg"

# 6. Validate
spctl --assess --type open --context context:primary-signature -vv "dist/EdgeControl-$VERSION-macOS.dmg"
```

`package_dmg.sh` already runs the notarize/staple steps when `CODESIGN_IDENTITY` and `NOTARY_PROFILE` are set (steps 4–5 can be done in one command; the manual sequence above is the same thing with more visibility).

## Hardened runtime and private APIs

Hardened Runtime is enabled in Release. The private interfaces used here (MultitouchSupport contacts, DisplayServices) do not require entitlements to load via `dlopen`/`dlsym` on the validation machine — verified working in the ad-hoc build. If notarization-time validation (or a future macOS) blocks any of them:

- Check the specific error with `xcrun stapler validate` / Console.
- If a private interface fails under Hardened Runtime, the app already fails closed: the backend reports unavailable and the rest of the app keeps working (verified pattern).
- Do not disable Hardened Runtime globally; record the precise reason and scope instead.

## Gatekeeper verification after install

```bash
spctl --assess --type execute -vv /Applications/EdgeControl.app
codesign --verify --deep --strict --verbose=2 /Applications/EdgeControl.app
```

## If no credentials are ever supplied

The ad-hoc `dist/EdgeControl-1.1.0-macOS.dmg` remains the current baseline deliverable. Gatekeeper will show "unidentified developer" for the ad-hoc build on other machines — that is expected and acceptable for local distribution.
