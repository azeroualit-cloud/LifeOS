import copy
import contextlib
import hashlib
import io
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('live_deploy', Path(__file__).with_name('deploy-lifeos-live-61.py'))
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)
BEFORE = b'export default { value: 1 };'
AFTER = b'export default { value: 2 };'
HELPER = ('helper.js', 'application/javascript+module', b'export const preserved = true;')


class FakeAPI:
    def __init__(self):
        self.parts = {name: [('worker.js', 'application/javascript+module', BEFORE), HELPER] for name in deploy.WORKERS}
        self.settings = {name: {'bindings': [{'type': 'd1', 'name': 'DB', 'id': deploy.DATABASE}, {'type': 'secret_text', 'name': 'FIXTURE_SECRET'}, {'type': 'plain_text', 'name': 'MODE', 'text': 'fixture'}], 'compatibility_date': '2026-01-01', 'compatibility_flags': [], 'observability': {'enabled': True}, 'usage_model': 'standard'} for name in deploy.WORKERS}
        self.puts = []
        self.fail_after_write = False
        self.fail_second_worker = False
        self.fail_read_after_write = False
        self.pending_read_error = False

    def __call__(self, path, method='GET', data=None, kind=None):
        name = path.split('/')[3]
        if method == 'GET' and path.endswith('/settings'):
            return copy.deepcopy(self.settings[name])
        if method == 'GET' and path.endswith('/content/v2'):
            if self.pending_read_error:
                self.pending_read_error = False
                raise OSError('fixture read timeout')
            raw, content_type = deploy.codec.multipart(self.parts[name])
            return raw, {'Content-Type': content_type, 'cf-entrypoint': 'worker.js'}
        if method != 'PUT': raise AssertionError('Unexpected request')
        if self.fail_second_worker and name == deploy.WORKERS[1]:
            self.fail_second_worker = False
            raise OSError('fixture write failure')
        entry, parts = deploy.codec.modules(data, {'Content-Type': kind})
        self.assert_entry(entry)
        self.puts.append(name)
        self.parts[name] = parts
        if self.fail_after_write:
            self.fail_after_write = False
            raise OSError('fixture response lost after successful write')
        if self.fail_read_after_write:
            self.fail_read_after_write = False
            self.pending_read_error = True
        return {}

    @staticmethod
    def assert_entry(entry):
        assert entry == 'worker.js'


class LiveDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))
        self.fake_patcher = SimpleNamespace(
            AUDITED_SHA256=hashlib.sha256(BEFORE).hexdigest(),
            PATCHED_SHA256=hashlib.sha256(AFTER).hexdigest(),
            transform=lambda source: AFTER.decode(),
            validate_preservation=lambda original, changed: None,
        )
        self.patcher = patch.object(deploy, 'patcher', self.fake_patcher)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def testDefaultModeNeverWrites(self):
        api = FakeAPI()
        deploy.execute(api)
        self.assertEqual(api.puts, [])

    def testBothWorkersAndUnrelatedModulesPreserved(self):
        api = FakeAPI()
        settings = copy.deepcopy(api.settings)
        deploy.execute(api, apply=True)
        self.assertEqual(api.puts, list(deploy.WORKERS))
        self.assertEqual(api.settings, settings)
        for parts in api.parts.values():
            self.assertEqual(parts[0][2], AFTER)
            self.assertEqual(parts[1], HELPER)
        api.puts.clear()
        deploy.execute(api, apply=True)
        self.assertEqual(api.puts, [], 'Re-running the reviewed update must be idempotent')

    def testSecondWorkerMismatchStopsBeforeAnyWrite(self):
        api = FakeAPI()
        api.parts[deploy.WORKERS[1]][0] = ('worker.js', 'application/javascript+module', b'changed concurrently')
        with self.assertRaisesRegex(RuntimeError, 'changed since source review'):
            deploy.execute(api, apply=True)
        self.assertEqual(api.puts, [])

    def testLostPutResponseStillRollsBack(self):
        api = FakeAPI()
        original = copy.deepcopy(api.parts)
        api.fail_after_write = True
        with self.assertRaisesRegex(RuntimeError, 'restored and verified'):
            deploy.execute(api, apply=True)
        self.assertEqual(api.parts, original)

    def testVerificationFailureRollsBack(self):
        api = FakeAPI()
        original = copy.deepcopy(api.parts)
        api.fail_read_after_write = True
        with self.assertRaisesRegex(RuntimeError, 'restored and verified'):
            deploy.execute(api, apply=True)
        self.assertEqual(api.parts, original)

    def testSecondWorkerWriteFailureRestoresFirst(self):
        api = FakeAPI()
        original = copy.deepcopy(api.parts)
        api.fail_second_worker = True
        with self.assertRaisesRegex(RuntimeError, 'restored and verified'):
            deploy.execute(api, apply=True)
        self.assertEqual(api.parts, original)

    def testMetadataRetainsSecretsByTypeAndPreservesOtherBindings(self):
        settings = FakeAPI().settings[deploy.WORKERS[0]]
        original = copy.deepcopy(settings)
        result = deploy.metadata(settings, 'worker.js')
        self.assertEqual(settings, original)
        self.assertEqual(result['keep_bindings'], ['secret_text'])
        self.assertEqual(len(result['bindings']), 2)
        self.assertEqual(result['usage_model'], settings['usage_model'])
        with self.assertRaisesRegex(RuntimeError, 'Unrecognized configuration'):
            deploy.metadata({**settings, 'new_unknown_configuration': True}, 'worker.js')
        wrong = copy.deepcopy(settings); wrong['bindings'][0]['id'] = 'wrong-fixture-database'
        with self.assertRaisesRegex(RuntimeError, 'Unexpected shared database'):
            deploy.metadata(wrong, 'worker.js')

    def testRealPatchGuardIdempotenceAndFullPreservation(self):
        patcher = deploy.load('tested_live_patch', 'prepare-lifeos-live-61.py')
        source = '\n'.join(before for before, after in patcher.patches())
        changed = patcher.transform(source)
        self.assertEqual(patcher.transform(changed), changed)
        patcher.validate_preservation(source, changed)
        with self.assertRaises(ValueError): patcher.transform(source + '\n' + patcher.patches()[0][0])
        with self.assertRaises(ValueError): patcher.validate_preservation(source, changed + '\nunrelated change')

    def testMissingSecretBindingIsDetectedWithoutReadingItsValue(self):
        api = FakeAPI()
        settings, entry, parts = deploy.snapshot(api, deploy.WORKERS[0])
        item = deploy.prepare(deploy.WORKERS[0], settings, entry, parts)
        api.settings[deploy.WORKERS[0]]['bindings'].append({'type': 'secret_text', 'name': 'UNEXPECTED_FIXTURE_SECRET'})
        with self.assertRaisesRegex(RuntimeError, 'configuration changed'):
            deploy.assert_snapshot(api, item, parts)


if __name__ == '__main__':
    unittest.main()
