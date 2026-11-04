import importlib.util,re,unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
s=importlib.util.spec_from_file_location('selection',R/'scripts/select-development-tests.py')
m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class SelectionTests(unittest.TestCase):
 def test_unknown_shared_and_missing_base_expand(self):
  for paths in [[],['native-next/Sources/Theme.swift'],['native-next/project.yml'],['native-next/Sources/BloomView.swift','native-next/Shared/Model.swift']]:
   self.assertEqual(m.select('preview','auto',paths)[0],sorted(m.AREAS))
 def test_feature_diff_selects_feature(self):
  self.assertEqual(m.select('preview','auto',['native-next/Sources/BloomView.swift'])[0],['bloom'])
 def test_multiple_features_form_union(self):
  self.assertEqual(m.select('preview','auto',['native-next/Sources/BloomView.swift','native-next/Sources/HealthView.swift'])[0],['bloom','health'])
 def test_focused_adds_units_and_bloom_recovery(self):
  a=m.select('preview','bloom',[])[1];b=m.select('focused','bloom',[])[1]
  self.assertNotIn('LifeOSProbeTests',a);self.assertIn('LifeOSProbeTests',b)
  self.assertTrue(any('AllowsRetry' in t for t in b));self.assertGreater(len(b),len(a))
 def test_all_selectors_exist(self):
  for selector in m.select('focused','all',[])[1]:
   parts=selector.split('/')
   if len(parts)<2: continue
   source=(R/('native-next/Tests' if parts[0] == 'LifeOSProbeTests' else 'native-next/UITests')/f'{parts[1]}.swift').read_text()
   self.assertIn('class '+parts[1],source)
   if len(parts)>2:self.assertRegex(source,r'func\s+'+re.escape(parts[2])+r'\s*\(')
unittest.main()
