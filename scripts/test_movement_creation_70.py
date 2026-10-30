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
 def test_legacy_triggers_are_fingerprinted_read_only_and_preserved(self):
  from unittest.mock import patch
  calls=[]
  def query(sql):
   calls.append(sql)
   return [{'name':'legacy','tbl_name':'movements','sql':'CREATE TRIGGER legacy AFTER UPDATE ON movements BEGIN SELECT 1; END'}] if "name NOT IN" in sql else []
  with patch.object(m,'metadata_query',side_effect=query):result=m.audit_triggers()
  self.assertEqual(set(result),{'legacy'})
  self.assertTrue(all(sql.startswith(('SELECT','PRAGMA')) for sql in calls))
 def test_unknown_sidecar_triggers_are_rejected(self):
  from unittest.mock import patch
  def query(sql):return [{'name':'foreign','tbl_name':'movement_creation_metadata','sql':'fixture'}]
  with patch.object(m,'metadata_query',side_effect=query):
   with self.assertRaises(RuntimeError):m.audit_triggers()
 def test_owned_trigger_fingerprints_match_actual_sqlite_schema(self):
  import sqlite3,json,re
  db=sqlite3.connect(':memory:')
  db.execute('CREATE TABLE movements(source_row INTEGER PRIMARY KEY)')
  db.execute('CREATE TABLE movement_creation_metadata(movement_source_row INTEGER PRIMARY KEY,created_at TEXT NOT NULL)')
  for value in re.findall(r'db\.prepare\(("CREATE TRIGGER[^\n]+")\)',m.payload):db.execute(json.loads(value))
  actual=dict(db.execute("SELECT name,sql FROM sqlite_master WHERE type='trigger'").fetchall())
  self.assertEqual({name:m.canonical_trigger(sql) for name,sql in actual.items()},m.expected_triggers())
if __name__=='__main__':unittest.main()
