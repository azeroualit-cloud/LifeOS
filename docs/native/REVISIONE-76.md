# LifeOS 0.10.15 / build 76 — startup compatibility

## Cause confirmed from the supplied report

The report matches the exact public build 75 executable. At main-thread return offset `0x2CA6CC`, the preceding instruction calls the weak Foundation `Date <= Date` import `_$s10Foundation4DateV2leoiySbAC_ACtFZ`. The recorded destination is zero. The containing function reads and decodes saved Keychain cookies: `SessionVault.load` with its inlined expiry comparison. Startup reaches it when restoring a saved server session.

The generated availability check selects this new entry point on iOS 27.2. On the supplied early beta, the weak function resolved to zero. Build 75 also imports a weak `Date >= Date` entry point. The `CODESIGNING / Invalid Page` termination label alone does not establish a bad certificate: this execution attempted to fetch instructions at address zero. No certificate replacement or logout is prescribed.

Earlier fresh/demo and synthetic upgrades had no saved server endpoint, so they missed this path. Their successful launches did not disprove the user's crash. Raw reports, device identifiers and signing-team identifiers have not been published.

## Fix

Compile with Xcode 27.0 / SDK 27.0 rather than the 27.2 Foundation overlay. Keep the deployment target, application behavior, bundle IDs, App Group, Health permissions, icon and local archives unchanged. Do not delete saved login or user data.

The toolchain selector accepts an installed 26.x fallback but refuses to silently use 27.2. A Mach-O regression gate rejects weak Foundation Date comparison imports in both app and widget. It rejects the exact delivered build 75 and accepts the replacement build.

Version: 0.10.15 / 76. Production code is unchanged; the compatible compilation removes the new ABI dependency globally.

## Verification harness

Two new tests exercise actual Keychain cookie persistence, future/expired expiry and a reserved-domain saved-session fixture. Simulator hosts require a synthetic Keychain identity: the first unsigned harness could not save its fixture, and manual host-only signing prevented simulator launch. Xcode now signs the simulator host and nested code, with simulator-only entitlement overrides. Device archives retain their established unsigned-for-Signulous packaging.

The actual Release app is launched without Debug/demo flags in four synthetic cases: fresh storage, empty upgrade, populated upgrade and saved-session upgrade. The fixture contains no real credentials or financial data.

## Results

Source: `d4efcc45b9bb07e9b588f0901a638414b519ff7b`. [Compatibility build and delivery](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41612277726).

- Xcode 27.0.0, device SDK 27.0.
- iPhone 15 Pro simulator / iOS 27.0: 247 unit tests and seven UI tests, zero failures. Both real Keychain tests passed; the saved-session fixture was reseeded and verified after UI installations.
- iPhone SE 3 simulator / iOS 27.0: six UI tests, zero failures.
- Actual Release startup without demo flags: all four cases remained running for the 25-second observation. The screenshots show the native Health authorization sheet, not a completed post-authorization Dashboard flow. These are bounded startup checks, not physical-device validation.
- Device archive and app/widget import gate passed. The exact public build 75 fails the same regression gate.
- [Independent public-download and screenshot review](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41612623334) passed. The public IPA was downloaded afresh, checksum checked, and package/import checks rerun. All four synthetic screenshots were inspected.
- Physical launch after Signulous re-signing on the user's iPhone 15 Pro / iOS 27.2 remains to be confirmed.

## Delivery

[Download LifeOS-76.ipa](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.15-build76/LifeOS-76.ipa) — direct IPA, no outer ZIP.

SHA-256: `b0827a1104f84dcd97426f17b7e8e129036fd52d8871647fadb4072931fc9cab`.

The earlier candidate archive hashes are superseded by this independently verified public asset. Device dSYMs are retained in the build artifact.

Re-sign using Signulous and install as an update without uninstalling. Physical-device launch and provisioning remain distinct from simulator and binary validation. No Cloudflare deployment or financial-data query is included.
