"""Reject weak Date comparison ABI imports absent from early iOS 27.2 betas."""
import argparse
import plistlib
import struct
import zipfile
from pathlib import Path

PREFIX = '_$s10Foundation4DateV'
COMPARISONS = ('1loiy', '1goiy', '2leoiy', '2geoiy', '2eeoiy', '2neoiy')


def weak_date_imports(binary):
    if len(binary) < 32 or binary[:4] != b'\xcf\xfa\xed\xfe':
        raise ValueError('Expected a thin 64-bit Mach-O')
    count, command_bytes = struct.unpack_from('<II', binary, 16)
    if 32 + command_bytes > len(binary):
        raise ValueError('Truncated Mach-O commands')
    offset = 32
    for _ in range(count):
        if offset + 8 > 32 + command_bytes:
            raise ValueError('Truncated load command')
        command, size = struct.unpack_from('<II', binary, offset)
        if size < 8 or offset + size > 32 + command_bytes:
            raise ValueError('Invalid load command size')
        if command == 2:
            if size < 24:
                raise ValueError('Truncated symbol command')
            symbols, number, strings, string_size = struct.unpack_from('<IIII', binary, offset + 8)
            if symbols + number * 16 > len(binary) or strings + string_size > len(binary):
                raise ValueError('Truncated symbol table')
            result = []
            for index in range(number):
                name_index, kind, _, description, _ = struct.unpack_from('<IBBHQ', binary, symbols + index * 16)
                if kind & 0x0e or not description & 0x40:
                    continue
                if name_index >= string_size:
                    raise ValueError('Invalid symbol name')
                name = binary[strings + name_index:strings + string_size].split(b'\0')[0].decode('utf-8')
                if name.startswith(PREFIX) and name[len(PREFIX):].startswith(COMPARISONS):
                    result.append(name)
            return result
        offset += size
    raise ValueError('Missing symbol table')


def verify_ipa(path):
    with zipfile.ZipFile(path) as archive:
        for prefix in ['Payload/LifeOSProbe.app/', 'Payload/LifeOSProbe.app/PlugIns/LifeOSWidget.appex/']:
            info = plistlib.loads(archive.read(prefix + 'Info.plist'))
            missing = weak_date_imports(archive.read(prefix + info['CFBundleExecutable']))
            if missing:
                raise ValueError('Early iOS 27.2 startup-incompatible weak Date import: ' + ', '.join(missing))
    print('STARTUP_IMPORT_COMPATIBILITY_VERIFIED: app and widget have no weak Date-comparison entry points')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    verify_ipa(parser.parse_args().ipa)
