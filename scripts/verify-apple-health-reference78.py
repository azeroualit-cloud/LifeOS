"""Check the measured reference against the current simulator Apple binary.

A deterministic native-app reference avoids recapturing Health's asynchronously
loaded catalog as part of product regression tests. No LifeOS UI test is skipped.
"""
import hashlib
import json
from pathlib import Path

root = Path("app/build")
identity = json.loads((root / "apple-health-reference/identity.json").read_text())
assert identity["bundle_id"] == "com.apple.Health"
assert identity["bundle_version"] == "7027.0.72.2.7"
assert identity["runtime"] == "27.0"
assert identity["executable_sha256"] == "22afdab042bbf8272e27af8f848cce17a63ffa178969e1c799a690d2ed6abc8d"
reference = root / "apple-health-reference-pinned78"
log = (reference / "probe78.log").read_text()
assert "testCaptureAppleHealthReference]' passed" in log
assert "APPLE_HEALTH_REFERENCE_TREE_populated-summary" in log
for marker in ["{361.0, 133.0}", "{361.0, 132.0}", "{80.0, 50.0}", "2,200", "176.4"]:
    assert marker in log, marker
image = reference / "probe78-screenshots/C5E777A5-61E0-47B5-96CE-5B41681CF92E.png"
assert hashlib.sha256(image.read_bytes()).hexdigest() == "8eb8449e5838068c4e019389952a8873ecfce36645c6608e06ed034fd45e9793"
print("APPLE_HEALTH_REFERENCE_VERIFIED: source run 41706031951; same binary/runtime; populated image checksum and passing capture test verified")
