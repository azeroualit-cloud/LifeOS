import importlib.util, pathlib, subprocess, tempfile, unittest
root = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('d', root / 'scripts/deploy-bloom-foods-93.py')
d = importlib.util.module_from_spec(spec)
import os; os.chdir(root); spec.loader.exec_module(d)

class T(unittest.TestCase):
    def test_patches_web_worker_once_and_checks(self):
        src = (root / 'web/worker.mjs').read_text()
        out = d.transform(src)
        self.assertEqual(d.transform(out), out)
        self.assertEqual(out.count('await bloomFoodsAction(env, method, args)'), 1)
        with tempfile.TemporaryDirectory() as t:
            p = pathlib.Path(t) / 'w.mjs'; p.write_text(out)
            subprocess.run(['node', '--check', str(p)], check=True)
    def test_refuses_unknown_context(self):
        with self.assertRaises(RuntimeError): d.transform('export default {}')
if __name__ == '__main__': unittest.main()
