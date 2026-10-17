// Public, sanitized runtime only. Never use the private bank-fixture source here.
import {readFile,writeFile,rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const root=fileURLToPath(new URL('../../',import.meta.url));
const check=process.argv.includes('--check');
const target=check?'worker.generated.mjs':'worker.js';
try {
  const runtime=await readFile(root+'backend/worker/runtime.mjs','utf8');
  const marker='const APP_HTML =',start=runtime.indexOf(marker)+marker.length;
  const literal=runtime.slice(start).match(/^\s*("(?:[^"\\]|\\.)*")/);
  if(!literal)throw Error('Embedded frontend missing.');
  let html=JSON.parse(literal[1]);
  if(!html.includes('headers: { "content-type": "application/json" },')||!html.includes('? "getFinanceExtras"')||!html.includes('</body>'))throw Error('Web integration contract changed.');
  html=html.replace('headers: { "content-type": "application/json" },','headers: { "content-type": "application/json", "X-LifeOS-Plans-Version": "2" },');
  html=html.replace('? "getFinanceExtras"','? "getFinanceOverview"');
  const web=await readFile(root+'backend/worker/plans-web.js','utf8');
  html=html.replace('</body>','<script>'+web+'</script></body>');
  const generated=runtime.slice(0,start)+runtime.slice(start).replace(literal[1],()=>JSON.stringify(html));
  await writeFile(root+'backend/worker/runtime.generated.mjs',generated);
  const result=spawnSync('npx',[...(process.env.LIFEOS_ESBUILD_OFFLINE?['--offline']:[]),'--yes','esbuild@0.25.12','backend/worker/entry.mjs','--bundle','--format=esm','--target=es2022','--log-level=warning','--outfile='+target],{cwd:root,stdio:'inherit'});
  if(result.status!==0)throw Error('Worker build failed.');
  const built=await readFile(root+target,'utf8');
  if(/IT\d{2}[A-Z]\d{22}/i.test(built)||built.includes('ANASS.md')||built.includes('TR-0001'))throw Error('Private fixture detected in public Worker.');
  if(check&&built!==await readFile(root+'worker.js','utf8'))throw Error('worker.js is stale. Run node backend/worker/build.mjs and commit worker.js with the source changes.');
  console.log(check?'Worker matches current sources.':'worker.js regenerated.');
} finally {await rm(root+'backend/worker/runtime.generated.mjs',{force:true});if(check)await rm(root+target,{force:true});}
