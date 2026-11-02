import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('utilities75', 'scripts/deploy-utilities-75.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class UtilityDeploymentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = Path('manual/build-70/worker.js').read_text()

    def test_transform_is_idempotent_and_keeps_unrelated_embedded_data(self):
        changed = module.transform(self.original)
        self.assertEqual(module.transform(changed), changed)
        for prefix in ['var APP_HTML = ', 'var PRIVATE_RULES_BLOB = ']:
            before = next(line for line in self.original.splitlines() if line.startswith(prefix))
            after = next(line for line in changed.splitlines() if line.startswith(prefix))
            self.assertTrue(before == after, 'Unrelated embedded data must remain byte-identical')

    def test_unknown_live_context_is_rejected(self):
        altered = self.original.replace('  const latestMonth = today < key ? today : key;', '  const latestMonth = differentSalaryPolicy();')
        with self.assertRaises(RuntimeError):
            module.transform(altered)

    def test_different_already_deployed_version_is_not_overwritten(self):
        changed = module.transform(self.original)
        with self.assertRaises(RuntimeError):
            module.transform(changed + '\n// unknown later change')

if __name__ == '__main__':
    unittest.main()
