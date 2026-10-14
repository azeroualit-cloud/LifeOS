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
  patched=m.transform(source)
  m.check(patched)
  self.assertEqual(m.transform(patched),patched)
  with tempfile.TemporaryDirectory() as folder:
   worker=Path(folder)/'worker.mjs';worker.write_text(patched+'\nexport {forecastCashHistory, writeAction, attachSavingsPlanning};')
   test=Path(folder)/'test.mjs';test.write_text('''import assert from 'node:assert/strict';
import {forecastCashHistory,writeAction,attachSavingsPlanning} from './worker.mjs';
const rows=[{source_row:1,actual_date:'2026-09-01',amount:2000,account:'Trade Republic',status:'Eseguito'}, {source_row:2,actual_date:'2026-09-03',amount:-600,account:'Trade Republic',status:'Eseguito'}, {source_row:3,actual_date:'2026-10-01',amount:9000,account:'Trade Republic',status:'Eseguito'}];
const history=forecastCashHistory(rows,{links:[{role:'payment',movement_source_row:2,attributed_cents:60000}]},'2026-10-14');
assert.equal(history.length,6);assert.equal(history.at(-1).ordinaryNet,2000);assert.equal(history.at(-1).extraPaid,600);assert.equal(history[0].observed,false);
let calls=[];const DB={prepare(sql){return {bind(...args){this.args=args;return this},async all(){return {results:[]}},sql}},async batch(statements){calls.push(statements)}};
await writeAction({DB},'savePlanningSettings',[6000,400,15000]);assert.equal(calls.length,1);assert.equal(calls[0].length,3);assert.match(calls[0][2].sql,/LifeOS Settings/);assert.equal(calls[0][2].args[0],'[15000]');
calls=[];await writeAction({DB},'savePlanningSettings',[6000,400]);assert.equal(calls[0].length,2);
calls=[];await assert.rejects(writeAction({DB},'savePlanningSettings',[6000,400,-1]));assert.equal(calls.length,0);
const budgetRow=(n,value)=>({sheet:'Budget',row_number:n,values_json:JSON.stringify([...Array(14).fill(''),value])});
const config=[budgetRow(13,6000),budgetRow(14,400),{sheet:'LifeOS Settings',row_number:1,values_json:'[15000]'}];
const lightweight=attachSavingsPlanning({summary:{budget:7000}},config,'2026-10-14');assert.equal(lightweight.planning.goal,6000);assert.equal(lightweight.planning.savingsTarget,15000);assert.equal(lightweight.planning.monthlySaving,400);
const full=attachSavingsPlanning({summary:{budget:7000},planning:{goal:6000,projection:9999,monthsRemaining:2}},config,'2026-10-14');assert.equal(full.planning.projection,9999);assert.equal(full.planning.monthsRemaining,2);assert.equal(full.planning.savingsTarget,15000);
const legacy=attachSavingsPlanning({summary:{budget:7000}},config.slice(0,2),'2026-10-14');assert.equal(legacy.planning.goal,6000);assert.equal(legacy.planning.savingsTarget,undefined);
console.log('Atomic settings, old-client compatibility and lightweight/full planning read-back: OK');''')
   subprocess.run(['node',str(test)],check=True)
 def test_refuses_unreviewed_worker(self):
  with self.assertRaises(RuntimeError):m.transform('changed source')
if __name__=='__main__':unittest.main()
