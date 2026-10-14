import importlib.util
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('upgrade',Path(__file__).with_name('upgrade-finance.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class UpgradeTests(unittest.TestCase):
 def test_backend_patch_and_atomic_compatibility(self):
  local=Path('/workspace/Life-OS-Codex/web/worker.js')
  if local.exists():source=local.read_text()
  else:
   spec=importlib.util.spec_from_file_location('setup',Path(__file__).with_name('provision-lifeos-test.py'))
   p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
   _,parts=p.downloaded_modules(*p.api(f'/workers/scripts/{p.SOURCE_WORKER}/content/v2'))
   source=next(data.decode() for _,_,data in parts if b'async function loadFinance(' in data)
  patched=source if m.MARKER in source else m.transform(source)
  m.check(patched)
  self.assertEqual(m.transform(patched),patched)
  with tempfile.TemporaryDirectory() as folder:
   worker=Path(folder)/'worker.mjs';worker.write_text(patched+'\nexport {forecastCashHistory, writeAction};')
   test=Path(folder)/'test.mjs';test.write_text('''import assert from 'node:assert/strict';
import {forecastCashHistory,writeAction} from './worker.mjs';
const rows=[{source_row:1,actual_date:'2026-09-01',amount:2000,account:'Trade Republic',status:'Eseguito'}, {source_row:2,actual_date:'2026-09-03',amount:-600,account:'Trade Republic',status:'Eseguito'}, {source_row:3,actual_date:'2026-10-01',amount:9000,account:'Trade Republic',status:'Eseguito'}];
const history=forecastCashHistory(rows,{links:[{role:'payment',movement_source_row:2,attributed_cents:60000}]},'2026-10-14');
assert.equal(history.length,6);assert.equal(history.at(-1).ordinaryNet,2000);assert.equal(history.at(-1).extraPaid,600);assert.equal(history[0].observed,false);
let calls=[];const DB={prepare(sql){return {bind(...args){this.args=args;return this},async all(){return {results:[]}},sql}},async batch(statements){calls.push(statements)}};
await writeAction({DB},'savePlanningSettings',[6000,400,15000]);assert.equal(calls.length,1);assert.equal(calls[0].length,3);assert.match(calls[0][2].sql,/LifeOS Settings/);assert.equal(calls[0][2].args[0],'[15000]');
calls=[];await writeAction({DB},'savePlanningSettings',[6000,400]);assert.equal(calls[0].length,2);
calls=[];await assert.rejects(writeAction({DB},'savePlanningSettings',[6000,400,-1]));assert.equal(calls.length,0);
console.log('Backend forecast, backward compatibility, atomic settings and invalid target: OK');''')
   subprocess.run(['node',str(test)],check=True)
 def test_refuses_unreviewed_worker(self):
  with self.assertRaises(RuntimeError):m.transform('changed source')
if __name__=='__main__':unittest.main()
