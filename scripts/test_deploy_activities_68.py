import importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('deployment',Path(__file__).with_name('deploy-unified-activities.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class DeploymentTests(unittest.TestCase):
 def test_only_reachable_modern_module_is_selected_and_old_unused_copy_is_preserved(self):
  active=b'async function lifeAction( scheduled_time section_status activityEvents'
  parts=[('entry.mjs','application/javascript',b'import app from "./runtime.mjs";'),('runtime.mjs','application/javascript',active),('old.mjs','application/javascript',b'async function lifeAction('),('copy.mjs','application/javascript',active)]
  self.assertEqual(m.active_module('entry.mjs',parts),'runtime.mjs')
 def test_ambiguous_graph_is_rejected(self):
  data=b'async function lifeAction( scheduled_time section_status activityEvents'
  parts=[('entry.mjs','application/javascript',b'import a from "./a.mjs"; import b from "./b.mjs";'),('a.mjs','application/javascript',data),('b.mjs','application/javascript',data)]
  with self.assertRaises(RuntimeError):m.active_module('entry.mjs',parts)
 def test_patch_is_additive_and_idempotent_on_recovered_worker(self):
  original=Path('manual/build-67/worker.js').read_text();patched=m.transform(original)
  self.assertEqual(m.transform(patched),patched)
  self.assertIn('return saveActivity(env.DB, x)',patched)
  self.assertIn('return enrichActivities(env.DB, await lifeRead(env, x))',patched)
if __name__=='__main__':unittest.main()
