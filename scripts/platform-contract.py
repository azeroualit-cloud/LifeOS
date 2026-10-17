"""Generate the shared web/server/iOS vocabulary; fail on drift with --check."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
contract = json.loads((root / 'shared/platform-contract.json').read_text())
native = Path(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] != '--check' else root / 'work/native'
swift = 'import Foundation\n\n// Generated from shared/platform-contract.json.\nenum NativePlatformContract {\n'
for key, value in contract.items():
    if isinstance(value, (list, dict, str)):
        literal = json.dumps(value, ensure_ascii=False)
        if isinstance(value, dict):
            literal = '[' + literal[1:-1] + ']'
        swift += f'    static let {key} = {literal}\n'
swift += '}\n'
outputs = {
    root / 'backend/worker/platform-contract.mjs': '// Generated from shared/platform-contract.json.\nexport const platformContract = ' + json.dumps(contract, ensure_ascii=False, indent=2) + ';\n',
    native / 'Sources/NativePlatformContract.swift': swift,
}
for path, content in outputs.items():
    if '--check' in sys.argv:
        if not path.exists() or path.read_text() != content:
            raise SystemExit(f'Shared platform contract is stale: {path}')
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
print('PLATFORM_CONTRACT_OK')
