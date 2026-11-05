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
 def test_full_unit_selection_does_not_retain_narrower_filters(self):
  focused=m.select('focused','nutrition',[])[1]
  self.assertEqual(focused.count('LifeOSProbeTests'),1)
  self.assertFalse(any(t.startswith('LifeOSProbeTests/') for t in focused))
  self.assertTrue(any(t.startswith('LifeOSProbeTests/') for t in m.select('preview','nutrition',[])[1]))
 def test_new_areas_and_paths_are_selected(self):
  for area, name in [('activities','NativeActivityEditor.swift'),('calendar','CalendarScreen.swift'),('shifts','NativeShiftProgress.swift')]:
   self.assertIn(area,m.select('preview','auto',['native-next/Sources/'+name])[0])
   self.assertEqual(m.select('preview',area,[])[0],[area])
 def test_safe_area_checks_are_focused_cross_area_only(self):
  checks = ["LifeOSProbeUITests/NativeRevision78UITests/testSafeAreaLastContentStandard", "LifeOSProbeUITests/NativeRevision78UITests/testSafeAreaLastContentLargeText"]
  for area in ["all", "dashboard"]:
   focused=m.select("focused",area,[])[1]
   for test in checks: self.assertEqual(focused.count(test),1)
  for mode,area in [("preview","all"),("focused","nutrition")]:
   for test in checks: self.assertNotIn(test,m.select(mode,area,[])[1])
 def test_all_selectors_exist(self):
  for selector in set(m.select('focused','all',[])[1] + m.select('preview','all',[])[1]):
   parts=selector.split('/')
   if len(parts)<2: continue
   source=(R/('native-next/Tests' if parts[0] == 'LifeOSProbeTests' else 'native-next/UITests')/f'{parts[1]}.swift').read_text(encoding='utf-8')
   self.assertIn('class '+parts[1],source)
   if len(parts)>2:self.assertRegex(source,r'func\s+'+re.escape(parts[2])+r'\s*\(')
unittest.main()
