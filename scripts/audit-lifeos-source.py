"""Read the two owned Worker sources and export only an authenticated ciphertext.

The private RSA key stays in the review session. No database API is called.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ACCOUNT = '1728c3b1b852eb6285646842db7256de'
WORKERS = ('lifeos', 'lifeos-native-test')
AAD = b'lifeos-live-audit-v1'
MAX_SOURCE_BYTES = 16 * 1024 * 1024


def seal(payload, public_pem):
    public = serialization.load_pem_public_key(public_pem)
    if not isinstance(public, rsa.RSAPublicKey) or public.key_size < 3072:
        raise ValueError('Audit requires an RSA key of at least 3072 bits.')
    key = AESGCM.generate_key(bit_length=256)
    nonce = os.urandom(12)
    wrapped = public.encrypt(key, padding.OAEP(mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(), label=AAD))
    encrypted = AESGCM(key).encrypt(nonce, payload, AAD)
    encode = lambda value: base64.b64encode(value).decode('ascii')
    return json.dumps({'version': 1, 'algorithm': 'RSA-OAEP-SHA256+AES-256-GCM', 'wrapped_key': encode(wrapped), 'nonce': encode(nonce), 'ciphertext': encode(encrypted)}, separators=(',', ':')).encode()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, newurl):
        raise RuntimeError('Unexpected Cloudflare redirect; audit stopped.')


def collect(token):
    client = urllib.request.build_opener(NoRedirect())
    sources = []
    for name in WORKERS:
        url = f'https://api.cloudflare.com/client/v4/accounts/{ACCOUNT}/workers/scripts/{name}/content/v2'
        request = urllib.request.Request(url, method='GET', headers={'Authorization': 'Bearer ' + token})
        with client.open(request, timeout=90) as response:
            data = response.read(MAX_SOURCE_BYTES + 1)
            if response.status != 200 or not data or len(data) > MAX_SOURCE_BYTES:
                raise RuntimeError('Unexpected Worker source response.')
            headers = {key: response.headers[key] for key in ('Content-Type', 'cf-entrypoint', 'cf-entrypoint-name') if key in response.headers}
        if 'json' in headers.get('Content-Type', ''):
            raise RuntimeError('Cloudflare returned JSON instead of a Worker module.')
        sources.append({'name': name, 'headers': headers, 'sha256': hashlib.sha256(data).hexdigest(), 'content_base64': base64.b64encode(data).decode('ascii')})
    return json.dumps({'version': 1, 'sources': sources}, separators=(',', ':')).encode()


def main():
    token = os.environ.get('CLOUDFLARE_API_TOKEN')
    if not token:
        raise RuntimeError('Cloudflare token unavailable.')
    public = Path(__file__).with_name('lifeos-audit-public.pem').read_bytes()
    # Validate encryption before retrieving any private source.
    seal(b'preflight', public)
    encrypted = seal(collect(token), public)
    target = Path('audit-encrypted')
    target.mkdir(mode=0o700, exist_ok=True)
    (target / 'lifeos-live.enc.json').write_bytes(encrypted)
    print('ENCRYPTED_SOURCE_AUDIT_READY; two read-only source GETs; no deployment or database calls.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Never print response bodies, headers, credentials, or source excerpts.
        print('::error::Source audit stopped (' + type(error).__name__ + '); private details omitted.')
        raise SystemExit(1)
