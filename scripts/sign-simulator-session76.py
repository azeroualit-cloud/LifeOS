#!/usr/bin/env python3
"""Give the unsigned CI simulator host an explicit, synthetic Keychain identity.
Never used for a device archive or the delivered IPA.
"""
import plistlib, subprocess, sys, tempfile
from pathlib import Path
app = Path(sys.argv[1]).resolve()
info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["CFBundleSupportedPlatforms"] == ["iPhoneSimulator"]
assert info["CFBundleIdentifier"] == "com.nas.lifeos.probe"
identity = "LIFEOSCI.com.nas.lifeos.probe"
with tempfile.TemporaryDirectory() as directory:
    entitlements = Path(directory) / "keychain.plist"
    entitlements.write_bytes(plistlib.dumps({"application-identifier": identity,
        "keychain-access-groups": [identity], "get-task-allow": True}))
    subprocess.run(["codesign", "--force", "--sign", "-", "--entitlements", str(entitlements), str(app)], check=True)
    subprocess.run(["codesign", "--verify", str(app)], check=True)
print("SIMULATOR_SYNTHETIC_KEYCHAIN_IDENTITY_READY")
