## Update: supplied device report identifies the failing call

The missing-evidence sections below are retained as investigation history. The report has since been received and matched to the delivered build 75. Disassembly identifies a null weak Foundation Date comparison in saved-session restoration. [Build 76 analysis, replacement IPA and completed verification](REVISIONE-76.md). No certificate replacement, logout, uninstall or archive reset is indicated by this evidence.

# Build 75 — immediate launch exit investigation

Status: the reported physical-device failure is **unresolved**. No application-code fix or replacement IPA is claimed. The user specified iPhone 15 Pro, iOS 27.2 and immediate return to the Home Screen; do not ask for the OS version again.

## Confirmed verification gap

The delivery tests used Debug builds with `--visual-test`. The delivered app was a separately archived Release build. Its package integrity was checked, but its ordinary startup path had not been launched before delivery. Demo tests substitute Health data and temporary storage, so they do not establish successful real-service startup or successful launch after Signulous re-signing.

Added read-only Release startup probes in `scripts/verify-release-launch75.py`, `.github/workflows/lifeos-launch75.yml` and `.github/workflows/lifeos-launch27.yml`. These build configuration Release, install it without Debug/demo arguments, capture console output and screenshots, and observe the process for 25 seconds per scenario. Fixtures are synthetic. They never query the user's server or use the phone's archive.

## Executed checks

- [41597566713](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41597566713): iPhone 15 Pro simulator, available iOS 27.0 runtime; fresh and empty synthetic-upgrade cases reached the Dashboard and remained running.
- [41598435738](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41598435738): downloaded and used actual iOS 27.2 runtime; supported simulated model was iPhone 18 Pro. Fresh and empty synthetic-upgrade cases reached the Dashboard and remained running. This is an OS-version check, not a claim of testing the user's iPhone 15 Pro.
- [41600421038](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41600421038): iPhone 15 Pro / iOS 27.0, Release; fresh, empty synthetic-upgrade and populated synthetic-upgrade cases all reached the Dashboard. The populated fixture includes an appointment, task, shift and 31 daily weight/calorie records; the displayed chart and values were inspected.
- [41600421112](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41600421112): attempted exact iPhone 15 Pro / iOS 27.2. Apple's downloadable image selected on that runner was iOS 27.2 build `24B91016s`, whose supported phone list contained only `iPhone Duo`. The probe correctly stopped before compiling/running instead of mislabelling another model. No app failure was observed in this skipped scenario.

## Package and startup review

Reviewed `App.init`, shared service initialization, archive decoding/migration and rollover, notification/widget initialization, Health store startup, nutrition-store initialization, initial Dashboard calculations, legacy Health conversion and framework linkage.

The published IPA SHA-256 is `94e64ccf0cc5a139208a05cb094a67241d6436305a9b4cd4e93b4737b05bf39d`. Its device binary has image UUID `48EEE488-2BB3-3BCA-BC66-0F81C2D815C7`, minimum OS 17.0 and SDK 27.2. AlarmKit is weak-linked. Health read/write and AlarmKit purpose strings exist. App/widget identifiers remain unchanged. These checks do not validate the entitlements and provisioning profile that a signing service applies later.

Both original distributed IPA 74 and IPA 75 have no Mach-O signature section, consistent with the existing unsigned-for-Signulous packaging. This fact alone is not evidence that the installed signature is invalid.

The reviewed archive-loading paths catch decoding/storage errors; App Group access already handles an unavailable container. HealthKit authorization checks run automatically at startup and are bypassed by the old demo test path. That remains a relevant boundary to inspect in a device stack, but the new probes did not reproduce an exception there. No confirmed crashing application line was identified, and neither HealthKit nor Signulous has been established as the cause.

## Missing evidence and next action

The latest physical-device `LifeOSProbe… .ips` crash report was requested through Settings → Privacy & Security → Analytics & Improvements → Analytics Data. No report has been received. It supplies the exception type, termination namespace/reason, loaded image UUID and failing stack without asking the user to repeat version information.

Analyze that report privately; do not upload it or phone identifiers to public GitHub logs. Compare its image UUID/version to the released artifact before symbolication. Distinguish a Swift/Objective-C exception from a dyld failure, OS code-signing rejection, watchdog or memory termination before changing code. Preserve bundle IDs, entitlements, user archives and existing Health/Bloom data. Do not delete or reinstall the app to clear data as a diagnostic shortcut.

No production application sources have changed during this investigation. No Cloudflare code has been deployed and no financial data queried. The reported device crash remains open pending the actual termination evidence.
