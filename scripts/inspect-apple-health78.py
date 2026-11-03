"""Inspect the simulator's shipped Health resources with pinned REA, without registration.

Retains REA's complete response and simulator identity. No Apple binaries are copied
or published. Resource evidence does not establish rendered geometry; UI captures
are produced by NativeAppleHealthReferenceUITests in the same validation run.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import selectors
import subprocess
import time

root = Path.cwd()
output = root / 'app/build/apple-health-reference'
output.mkdir(parents=True, exist_ok=True)
device = os.environ['MAIN_DEVICE']
bundle = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', device, 'com.apple.Health', 'app'], text=True).strip())
info = plistlib.loads((bundle / 'Info.plist').read_bytes())
executable = bundle / info['CFBundleExecutable']
identity = {
    'bundle_id': info['CFBundleIdentifier'], 'bundle_version': info.get('CFBundleVersion'),
    'runtime': os.environ['COMPAT_RUNTIME'], 'device': 'iPhone 15 Pro',
    'executable_sha256': hashlib.sha256(executable.read_bytes()).hexdigest(),
    'rea_version': '6.8.0', 'scope': 'bundle resources; rendered geometry requires UI evidence',
}
(output / 'identity.json').write_text(json.dumps(identity, indent=2))
print('APPLE_HEALTH_REFERENCE_IDENTITY', json.dumps(identity))
command = ['node', str(root / '.rea78/node_modules/rea-agents/scripts/rea.mjs'), '--mcp']
with (output / 'rea-stderr.log').open('w') as error_log:
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=error_log, text=True, bufsize=1)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)

    def send(message):
        process.stdin.write(json.dumps({'jsonrpc': '2.0', **message}) + '\n')
        process.stdin.flush()

    def receive(request_id):
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if not selector.select(timeout=1):
                if process.poll() is not None:
                    raise RuntimeError('REA exited before answering; see retained stderr')
                continue
            line = process.stdout.readline()
            if not line:
                raise RuntimeError('REA closed its output')
            message = json.loads(line)
            if message.get('id') == request_id:
                return message
        raise TimeoutError('REA response deadline; child will be terminated and failure retained')

    try:
        send({'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2025-03-26', 'capabilities': {}, 'clientInfo': {'name': 'LifeOS-reference-inspection', 'version': '78'}}})
        initialization = receive(1)
        (output / 'initialization.json').write_text(json.dumps(initialization, indent=2))
        send({'method': 'notifications/initialized'})
        for request_id, name, arguments in [(2, 'open_bundle_resources', {'path': str(bundle)}), (3, 'inspect_plist', {})]:
            send({'id': request_id, 'method': 'tools/call', 'params': {'name': name, 'arguments': arguments}})
            result = receive(request_id)
            (output / (name + '.json')).write_text(json.dumps(result, indent=2))
            failed = 'error' in result or result.get('result', {}).get('isError', False)
            print('REA_REFERENCE_TOOL', name, 'error' if failed else 'response retained')
            if failed:
                raise RuntimeError(f'REA {name} failed; complete evidence retained')
    finally:
        selector.close()
        process.stdin.close()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.wait(timeout=10)
