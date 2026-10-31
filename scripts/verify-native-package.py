"""Check the unsigned iPhone IPA and its informative widget before publication.

This validates package contents, not the entitlements applied by a later signing service.
"""
import argparse
import hashlib
import plistlib
import struct
import zipfile
from pathlib import Path


def verify(path: Path, version: str, build: str):
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None, 'Corrupt IPA archive'
        app = 'Payload/LifeOSProbe.app/'
        extension = app + 'PlugIns/LifeOSWidget.appex/'
        for prefix, identifier in [(app, 'com.nas.lifeos.probe'), (extension, 'com.nas.lifeos.probe.quickactions')]:
            info = plistlib.loads(archive.read(prefix + 'Info.plist'))
            assert info['CFBundleIdentifier'] == identifier
            assert info['CFBundleShortVersionString'] == version
            assert info['CFBundleVersion'] == build
            assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS']
            binary = archive.read(prefix + info['CFBundleExecutable'])
            assert binary[:4] == b'\xcf\xfa\xed\xfe', 'Expected a thin Mach-O executable'
            assert struct.unpack_from('<I', binary, 4)[0] == 0x0100000c, 'Expected arm64'
            ncmds = struct.unpack_from('<I', binary, 16)[0]
            position = 32
            platforms = []
            for _ in range(ncmds):
                command, size = struct.unpack_from('<II', binary, position)
                if command == 0x32:
                    platforms.append(struct.unpack_from('<I', binary, position + 8)[0])
                position += size
            assert platforms == [2], 'Expected iOS device, never a Simulator binary'
            if prefix == app:
                assert info.get('NSAlarmKitUsageDescription'), 'Missing alarm authorization purpose'
                assert any('lifeos' in item.get('CFBundleURLSchemes', []) for item in info.get('CFBundleURLTypes', []))
            else:
                # Swift may inline a short String into instructions. The runtime
                # type name is longer and remains in widget reflection metadata.
                assert b'LifeOSOverviewWidget' in binary, 'Missing informative widget implementation'
                assert info['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.widgetkit-extension'
        print('VERIFIED_IPHONE_APP_AND_INFORMATIVE_WIDGET', version, build, hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--version', required=True)
    parser.add_argument('--build', required=True)
    args = parser.parse_args()
    verify(args.ipa, args.version, args.build)
