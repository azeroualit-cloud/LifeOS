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
  start=patched.index('async function lifeAction(');end=patched.index('async function saveTransaction',start)
  self.assertNotIn('.slice(0, 140)',patched[start:end])
 def test_lost_upload_acknowledgement_restores_original_worker(self):
  import json,os,io,contextlib
  from unittest.mock import patch
  original=Path('manual/build-67/worker.js').read_bytes()
  current=[original];uploads=[]
  class Response:
   def __init__(self,data,headers):self.data=data;self.headers=headers
   def __enter__(self):return self
   def __exit__(self,*args):pass
   def read(self):return self.data
  def request(req,timeout=90):
   if req.full_url.endswith('/settings'):
    return Response(json.dumps({'success':True,'result':{'bindings':[{'name':'DB','type':'d1','id':m.helpers.DATABASE}]}}).encode(),{'Content-Type':'application/json'})
   if req.get_method()=='GET':return Response(current[0],{'Content-Type':'application/javascript','cf-entrypoint':'worker.js'})
   _,parts=m.helpers.modules(req.data,{'Content-Type':req.headers['Content-type']})
   current[0]=parts[0][2];uploads.append(current[0])
   if len(uploads)==1:raise OSError('simulated lost upload response')
   return Response(b'{"success":true,"result":{}}',{'Content-Type':'application/json'})
  with patch.dict(os.environ,{'CLOUDFLARE_API_TOKEN':'fixture-only','LIFEOS_BACKEND_AUDIT_ONLY':'0'}),patch.object(m.helpers,'WORKERS',['fixture']),patch.object(m.urllib.request,'urlopen',side_effect=request),contextlib.redirect_stdout(io.StringIO()):
   with self.assertRaises(RuntimeError):m.main()
  self.assertEqual(len(uploads),2)
  self.assertEqual(current[0],original)
if __name__=='__main__':unittest.main()
