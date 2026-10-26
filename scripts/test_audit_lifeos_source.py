import base64
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

spec = importlib.util.spec_from_file_location('audit', Path(__file__).with_name('audit-lifeos-source.py'))
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class SourceAuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.private = rsa.generate_private_key(public_exponent=65537, key_size=3072)
        cls.public = cls.private.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)

    def testAuthenticatedEncryptionRoundTripAndTamper(self):
        source = b'private fixture source must never be visible in artifact'
        encrypted = audit.seal(source, self.public)
        self.assertNotIn(source, encrypted)
        data = json.loads(encrypted)
        decode = lambda key: base64.b64decode(data[key])
        key = self.private.decrypt(decode('wrapped_key'), padding.OAEP(mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(), label=audit.AAD))
        self.assertEqual(AESGCM(key).decrypt(decode('nonce'), decode('ciphertext'), audit.AAD), source)
        damaged = bytearray(decode('ciphertext')); damaged[-1] ^= 1
        with self.assertRaises(InvalidTag):
            AESGCM(key).decrypt(decode('nonce'), bytes(damaged), audit.AAD)

    def testCollectorOnlyReadsTheTwoOwnedWorkerSources(self):
        requests = []
        class Response:
            status = 200
            headers = {'Content-Type': 'application/javascript', 'cf-entrypoint': 'worker.js'}
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self, limit): return b'fixture source'
        class Client:
            def open(self, request, timeout):
                requests.append(request)
                return Response()
        with patch.object(audit.urllib.request, 'build_opener', return_value=Client()):
            result = json.loads(audit.collect('fixture-token'))
        self.assertEqual(len(requests), 2)
        self.assertEqual([r.get_method() for r in requests], ['GET', 'GET'])
        self.assertEqual([s['name'] for s in result['sources']], list(audit.WORKERS))
        for request in requests:
            self.assertTrue(request.full_url.startswith('https://api.cloudflare.com/client/v4/accounts/' + audit.ACCOUNT + '/workers/scripts/'))
            self.assertTrue(request.full_url.endswith('/content/v2'))


if __name__ == '__main__':
    unittest.main()
