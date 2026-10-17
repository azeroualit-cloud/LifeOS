// Usage: node backend/plans/build-worker.mjs /private/worker.mjs /private/worker-plans.mjs
// Copies no private source into the public repository. npm supplies the pinned bundler.
import {readFile,mkdir,writeFile,mkdtemp,rm} from 'node:fs/promises';
import {resolve,dirname,join} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const [input,output]=process.argv.slice(2);
if(!input||!output)throw Error('Specificare percorso del Worker privato e destinazione privata.');
const source=resolve(input), target=resolve(output), module=fileURLToPath(new URL('./worker-adapter.mjs',import.meta.url));
const publicRoot=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
if(target===publicRoot||target.startsWith(publicRoot+'/'))throw Error('Il Worker completo deve restare fuori dal repository pubblico.');
const text=await readFile(source,'utf8');
if(!text.includes('export default')||!text.includes('async function saveTransaction'))throw Error('Sorgente Worker non compatibile.');
await mkdir(dirname(target),{recursive:true});
const temp=await mkdtemp(join(tmpdir(),'lifeos-plans-'));
try {
  const entry=join(temp,'entry.mjs');
  await writeFile(entry,`import original from ${JSON.stringify(source)};\nimport {withFinancePlans} from ${JSON.stringify(module)};\nexport default withFinancePlans(original);\n`,{mode:0o600});
  const build=spawnSync('npx',['--yes','esbuild@0.25.12',entry,'--bundle','--format=esm','--target=es2022','--log-level=warning','--outfile='+target],{stdio:'inherit',env:{...process.env,npm_config_cache:process.env.npm_config_cache??join(tmpdir(),'lifeos-npm-cache')}});
  if(build.status!==0)throw Error('Packaging Worker non riuscito.');
} finally {await rm(temp,{recursive:true,force:true});}
