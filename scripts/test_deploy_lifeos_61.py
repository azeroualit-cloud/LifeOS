import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('deploy',Path(__file__).with_name('deploy-lifeos-61.py'));module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class DeployPatchTests(unittest.TestCase):
    def testGuardIdempotenceAndUnrelatedCodePreserved(self):
        patches=[{'before':'old routine','after':'new routine'}]
        source='finance preserved\nold routine\nauth preserved'
        changed=module.transform(source,patches)
        self.assertEqual(changed,'finance preserved\nnew routine\nauth preserved')
        self.assertEqual(module.transform(changed,patches),changed)
        with self.assertRaises(RuntimeError):module.transform('unexpected routine',patches)
        with self.assertRaises(RuntimeError):module.transform(source+'\nold routine',patches)
    def testMultipartKeepsModuleBytes(self):
        parts=[('worker.js','application/javascript+module',b'export default {}')]
        data,kind=module.multipart(parts)
        entry,result=module.modules(data,{'Content-Type':kind,'cf-entrypoint':'worker.js'})
        self.assertEqual(entry,'worker.js');self.assertEqual(result,parts)
if __name__=='__main__':unittest.main()
