// Public, sanitized runtime only. Never use the private bank-fixture source here.
import {readFile,writeFile,rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const root=fileURLToPath(new URL('../../',import.meta.url));
const check=process.argv.includes('--check');
const target=check?'worker.generated.mjs':'worker.js';
try {
  const result=spawnSync('npx',[...(process.env.LIFEOS_ESBUILD_OFFLINE?['--offline']:[]),'--yes','esbuild@0.25.12','backend/worker/entry.mjs','--bundle','--format=esm','--target=es2022','--log-level=warning','--outfile='+target],{cwd:root,stdio:'inherit'});
  if(result.status!==0)throw Error('Worker build failed.');
  const built=await readFile(root+target,'utf8');
  if(/IT\d{2}[A-Z]\d{22}/i.test(built)||built.includes('ANASS.md')||built.includes('TR-0001'))throw Error('Private fixture detected in public Worker.');
  if(check&&built!==await readFile(root+'worker.js','utf8'))throw Error('worker.js is stale. Run node backend/worker/build.mjs and commit worker.js with the source changes.');
  console.log(check?'Worker matches current sources.':'worker.js regenerated.');
} finally {if(check)await rm(root+target,{force:true});}
