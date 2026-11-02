# EdgeControl 1.8.4 validation

## Update-check failure and immediate repair

The published v1.8.3 feed was valid XML but contained a second namespace, `http://www.andymatusiak.com/sparkle`, inherited from v1.7.2–1.7.4. ElementTree serialized those fields under `ns1`, so Sparkle did not recognize the historical version elements. Sparkle 2.9.6 rejected the entire feed with error 1000: `Feed item lacks sparkle:version element, and version couldn't be deduced.` The same failure was reproduced by linking the pinned Sparkle framework and parsing the downloaded production feed.

The live v1.8.3 appcast was normalized to `http://www.andymatuschak.org/xml-namespaces/sparkle`. All record values, archive URLs, byte lengths and Ed25519 signatures were compared and preserved. No release archive was replaced or re-signed. All ten entries then parsed with Sparkle. The repaired asset SHA-256 is `a35020b347b6d19d420e0aa3687c3e0c239a5001f98725566095ebad8cfc763b`, matching GitHub's uploaded-asset digest. Ordinary XML parsing and archive-signature checks alone had missed this failure.

## Prevention and scope

`appcast.py` normalizes the known legacy URI and validates canonical version fields, ordering, duplicate builds, archive URL/version binding, positive lengths and signature encoding. Publication also runs the parser from the Sparkle framework accompanying the signing tools, before creating a tag or draft. CI uses the project's pinned Sparkle version to prove that the original fixture fails for the expected reason, that all repaired historical records parse, and that a newly generated record parses. This parser probe uses Sparkle's exposed internal initializer only in release tooling; it is not linked into EdgeControl's application code.

Six Python regressions cover the namespace failure, preservation, idempotence, duplicate builds, invalid archive/signature metadata and conflicting namespace attributes. Existing 151 native tests and universal Release packaging remain required. Signature syntax validation complements, and never replaces, the existing cryptographic archive-signature checks.

The app's UpdateController correctly delegates manual and automatic checks to Sparkle; no preference reset or alternate update implementation was introduced. A full interactive install still needs confirmation through the running application's update dialog.

## Icon

The master artwork was generated specifically for EdgeControl. `build_icons.sh` derives all ten RGBA AppIcon catalog representations and the legacy ICNS container from `assets/icon-1024.png`, preserving transparent margins. Artwork uses a pearl-glass tile with blue/orange trackpad-edge controls; no Apple logo. The original generated source is retained outside the repository; the approved 1024 px master is committed. Native UI snapshots and macOS asset compilation verify integration; Dock cache refresh is left to normal installation.
