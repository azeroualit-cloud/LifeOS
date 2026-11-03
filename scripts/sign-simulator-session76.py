#!/usr/bin/env python3
"""Configure Keychain identity only for the CI simulator host.
Xcode signs the app and nested code normally; device entitlements stay unchanged.
"""
import plistlib
from pathlib import Path
project=Path("project.yml")
source=Path("LifeOS.entitlements")
assert project.exists() and source.exists()
identity="LIFEOSCI00.com.nas.lifeos.probe"
values=plistlib.loads(source.read_bytes())
values.update({"application-identifier":identity,"keychain-access-groups":[identity]})
target=Path("/tmp/lifeos76-simulator.entitlements")
target.write_bytes(plistlib.dumps(values))
text=project.read_text()
old="        CODE_SIGN_ENTITLEMENTS: LifeOS.entitlements"
assert text.count(old)==1
text=text.replace(old,old+'\n        "CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]": '+str(target))
project.write_text(text)
print("SIMULATOR_XCODE_MANAGED_KEYCHAIN_IDENTITY_CONFIGURED")
