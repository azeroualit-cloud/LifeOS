"""Guarded deployment plan for the audited live LifeOS modules.

Default mode is read-only. --apply requires separate owner authorization.
Configuration and credentials stay in runner memory and are never exported.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import urllib.request


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


codec = load('lifeos_multipart', 'deploy-lifeos-61.py')
patcher = load('lifeos_live_patch', 'prepare-lifeos-live-61.py')
ACCOUNT = codec.ACCOUNT
DATABASE = codec.DATABASE
WORKERS = ('lifeos-native-test', 'lifeos')
CONFIG_KEYS = {'bindings', 'compatibility_date', 'compatibility_flags', 'usage_model', 'logpush', 'tail_consumers', 'placement', 'tags', 'observability', 'limits', 'assets', 'annotations'}
READ_ONLY_KEYS = {'created_on', 'modified_on', 'last_deployed_from', 'named_handlers', 'id', 'etag'}


def metadata(settings, entry):
    unknown = set(settings) - CONFIG_KEYS - READ_ONLY_KEYS
    if unknown:
        raise RuntimeError('Unrecognized configuration field; no settings are discarded.')
    if settings.get('assets'):
        raise RuntimeError('Asset-backed Worker requires a separate deployment plan.')
    result = {key: copy.deepcopy(value) for key, value in settings.items() if key in CONFIG_KEYS}
    bindings = result.get('bindings', [])
    database = [item for item in bindings if item.get('name') == 'DB']
    if len(database) != 1 or database[0].get('type') != 'd1' or database[0].get('id') != DATABASE:
        raise RuntimeError('Unexpected shared database binding; no writes.')
    secret_types = {item['type'] for item in bindings if item.get('type', '').startswith('secret_')}
    result['bindings'] = [item for item in bindings if item.get('type') not in secret_types]
    result.update(main_module=entry, keep_bindings=sorted(secret_types))
    return result


def signature(parts):
    return sorted((name, kind, hashlib.sha256(data).hexdigest()) for name, kind, data in parts)


def secrets_signature(settings):
    return sorted((item.get('name'), item.get('type')) for item in settings.get('bindings', []) if item.get('type', '').startswith('secret_'))


def prepare(name, settings, entry, original):
    meta = metadata(settings, entry)
    changed = []
    found = False
    for filename, kind, data in original:
        if filename == entry:
            found = True
            digest = hashlib.sha256(data).hexdigest()
            if digest not in (patcher.AUDITED_SHA256, patcher.PATCHED_SHA256):
                raise RuntimeError('Live entry changed since source review; no writes.')
            if digest == patcher.AUDITED_SHA256:
                text = data.decode('utf-8')
                new = patcher.transform(text)
                patcher.validate_preservation(text, new)
                data = new.encode('utf-8')
                if hashlib.sha256(data).hexdigest() != patcher.PATCHED_SHA256:
                    raise RuntimeError('Prepared source differs from the tested patch.')
                with tempfile.TemporaryDirectory(prefix='lifeos-syntax-') as folder:
                    path = Path(folder) / 'worker.mjs'
                    path.write_bytes(data)
                    path.chmod(0o600)
                    result = subprocess.run(['node', '--check', str(path)], capture_output=True)
                    if result.returncode:
                        raise RuntimeError('Patched Worker syntax verification failed.')
        changed.append((filename, kind, data))
    if not found:
        raise RuntimeError('Entrypoint missing.')
    return {'name': name, 'entry': entry, 'original': original, 'changed': changed, 'metadata': meta, 'secret_bindings': secrets_signature(settings)}


def snapshot(api, name):
    settings = api('/workers/scripts/' + name + '/settings')
    entry, parts = codec.modules(*api('/workers/scripts/' + name + '/content/v2'))
    return settings, entry, parts


def assert_snapshot(api, item, parts):
    settings, entry, actual = snapshot(api, item['name'])
    if entry != item['entry'] or signature(actual) != signature(parts) or metadata(settings, entry) != item['metadata'] or secrets_signature(settings) != item['secret_bindings']:
        raise RuntimeError('Worker source or configuration changed; verification stopped.')


def upload(api, item, parts):
    data, kind = codec.multipart([('metadata', 'application/json', json.dumps(item['metadata']).encode()), *parts])
    api('/workers/scripts/' + item['name'], method='PUT', data=data, kind=kind)


def execute(api, apply=False):
    prepared = []
    # Validate BOTH Workers before any possible write, even in apply mode.
    for name in WORKERS:
        settings, entry, original = snapshot(api, name)
        prepared.append(prepare(name, settings, entry, original))
    if not apply:
        print('LIVE_61_PREFLIGHT_OK; both entries match audited source; no writes or configuration export.')
        return
    # Check the complete snapshots once more before starting the update.
    for item in prepared:
        assert_snapshot(api, item, item['original'])
    attempted = []
    try:
        for item in prepared:
            if signature(item['original']) == signature(item['changed']):
                continue
            assert_snapshot(api, item, item['original'])
            # Include uncertain network outcomes in rollback: a lost response may
            # still follow a successful remote PUT.
            attempted.append(item)
            upload(api, item, item['changed'])
            assert_snapshot(api, item, item['changed'])
        for item in prepared:
            assert_snapshot(api, item, item['changed'])
        print('LIVE_61_DEPLOYED_AND_VERIFIED; task patch only; other modules, configuration and secrets preserved.')
    except Exception:
        rollback_failed = False
        for item in reversed(attempted):
            try:
                # Do not overwrite an unrelated deployment made concurrently.
                settings, entry, actual = snapshot(api, item['name'])
                if entry != item['entry'] or metadata(settings, entry) != item['metadata'] or secrets_signature(settings) != item['secret_bindings'] or signature(actual) not in (signature(item['original']), signature(item['changed'])):
                    raise RuntimeError('Concurrent change prevents automatic rollback.')
                if signature(actual) == signature(item['changed']):
                    upload(api, item, item['original'])
                assert_snapshot(api, item, item['original'])
            except Exception:
                rollback_failed = True
        if rollback_failed:
            raise RuntimeError('Update stopped; at least one rollback requires review.') from None
        raise RuntimeError('Update stopped; attempted Workers restored and verified.') from None


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, newurl):
        raise RuntimeError('Unexpected Cloudflare redirect.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    token = os.environ.get('CLOUDFLARE_API_TOKEN')
    if not token:
        raise RuntimeError('Cloudflare token unavailable.')
    client = urllib.request.build_opener(NoRedirect())
    def api(path, method='GET', data=None, kind=None):
        if not path.startswith('/workers/scripts/') or method not in ('GET', 'PUT'):
            raise RuntimeError('Unsupported API request.')
        if method != 'GET' and not args.apply:
            raise RuntimeError('Read-only mode forbids writes.')
        request = urllib.request.Request('https://api.cloudflare.com/client/v4/accounts/' + ACCOUNT + path, data=data, method=method, headers={'Authorization': 'Bearer ' + token, **({'Content-Type': kind} if kind else {})})
        with client.open(request, timeout=90) as response:
            raw = response.read()
            if 'json' in response.headers.get('Content-Type', ''):
                value = json.loads(raw)
                if value.get('success') is not True:
                    raise RuntimeError('Cloudflare rejected the request.')
                return value.get('result')
            return raw, response.headers
    execute(api, args.apply)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('::error::' + (str(error) if isinstance(error, RuntimeError) else 'Deployment stopped (' + type(error).__name__ + '); private response omitted.'))
        raise SystemExit(1)
