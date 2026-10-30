from pathlib import Path
import importlib.util,unittest
spec=importlib.util.spec_from_file_location('movement70',Path(__file__).with_name('deploy-movement-creation-70.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class MovementCreationTests(unittest.TestCase):
 def test_transform_preserves_activity_and_financial_columns(self):
  original=Path('manual/build-68/worker.js').read_text();changed=m.transform(original)
  self.assertEqual(m.transform(changed),changed)
  for header in ['async function lifeAction(', 'async function saveTransaction(']:
   a=original.index(header);b=original.index('\n}',a)+2
   self.assertIn(original[a:b],changed)
  self.assertIn('created_at: row[23] || null',changed)
  self.assertIn('sortMovementCreation(selectedTransactions)',changed)
 def test_changed_context_is_rejected(self):
  original=Path('manual/build-68/worker.js').read_text().replace('r.financial_category_id\n  ];','r.other_field\n  ];')
  with self.assertRaises(RuntimeError):m.transform(original)
 def test_unknown_generic_update_trigger_is_rejected_without_writes(self):
  from unittest.mock import patch
  calls=[]
  def query(sql):
   calls.append(sql)
   return [{'name':'other','sql':'CREATE TRIGGER other AFTER UPDATE ON movements BEGIN SELECT 1; END'}]
  with patch.object(m,'metadata_query',side_effect=query):
   with self.assertRaises(RuntimeError):m.audit_triggers()
  self.assertTrue(all(sql.startswith('SELECT') for sql in calls))
if __name__=='__main__':unittest.main()
