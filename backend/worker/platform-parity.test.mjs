import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {pathToFileURL} from 'node:url';
import {mkdir} from 'node:fs/promises';
import worker from '../../worker.js';
import {platformContract} from './platform-contract.mjs';
const {chromium}=await import(pathToFileURL(process.env.LIFEOS_PLAYWRIGHT_MODULE));
const password='synthetic-parity-password';
const response=await worker.fetch(new Request('https://fixture.test/',{headers:{Authorization:'Basic '+btoa('nas:'+password)}}),{APP_PASSWORD:password,DB:{}},{});
assert.equal(response.status,200);const html=await response.text();
const today=new Date().toLocaleDateString('sv-SE',{timeZone:'Europe/Rome'}),month=today.slice(0,7),calls=[];
const life={today,month,categories:[{key:'action',label:'Attività',position:0},{key:'reading',label:'Letture',position:1}],tasks:[],events:[],upcomingEvents:[],routines:[],shifts:[{day:today,kind:'morning'}]};
const planning={goal:6000,savingsTarget:15000,monthlySaving:300};
let oldServer=false,failMonth=null,failOverview=false,quickUnavailable=false;
const ledger=new Map();
const server=createServer(async(req,res)=>{
 res.setHeader('Content-Type',req.url.startsWith('/api/')?'application/json':'text/html');
 if(!req.url.startsWith('/api/')){res.end(html);return;}
 let raw='';for await(const part of req)raw+=part;
 const args=JSON.parse(raw),method=req.url.slice(5);calls.push({method,args});
 const key=typeof args[0]==='string'?args[0]:`${args[0]}-${String(args[1]).padStart(2,'0')}`;
 if(method==='getLifeData'){res.end(JSON.stringify(life));return;}
 if(method==='getFinanceCategoryOptions'){res.end(JSON.stringify([...platformContract.expenseCategories,...platformContract.incomeCategories]));return;}
 if(method==='getFinanceData'&&key===failMonth){failMonth=null;res.statusCode=503;res.end('Mese temporaneamente non disponibile');return;}
 if(method==='getFinanceOverview'&&failOverview){failOverview=false;res.statusCode=503;res.end('Mese non disponibile');return;}
 if(method==='savePlanningSettings'){[planning.goal,planning.monthlySaving,planning.savingsTarget]=args;res.end('true');return;}
 if(method==='saveTransaction'){
  ledger.set(args[0].requestId,args[0]);
  if(quickUnavailable){res.statusCode=503;res.end('Risposta non ricevuta');return;}
  res.end('true');return;
 }
 if(method==='saveEstimate'){res.end('true');return;}
 const d={key,year:Number(key.slice(0,4)),month:Number(key.slice(-2)),updatedAt:'test',summary:{budget:7000,monthlyRemaining:1000,monthlySalary:1800,monthlySpent:200,monthlyCommitted:600,recurringCommitments:[],monthlyBudgetBreakdown:[]},transactions:[],recurring:[{name:'Gas',estimate:40,nextEstimate:45}],averages:[],planning,categories:[{name:'Casa',amount:100},{name:'Auto',amount:-10}],extraPlan:{allocations:[],links:[]},forecastHistory:[],wealthHistory:[{month:key,measured:7000}],lifetime:{series:[],salaryHistory:[{month:key,base:1700,additional:100}]} };
 if(!oldServer)d.plansV2={version:2,month:key,plans:[],payments:[]};
 res.end(JSON.stringify(d));
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const browser=await chromium.launch({headless:true,...(process.env.LIFEOS_CHROMIUM?{executablePath:process.env.LIFEOS_CHROMIUM}:{}),args:['--no-sandbox']});
try{
 const page=await browser.newPage({viewport:{width:390,height:844}}),errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.route('https://api.open-meteo.com/**',r=>r.fulfill({status:503,body:'No weather in synthetic fixture'}));
 await page.addInitScript(()=>localStorage.setItem('life-theme','dark'));
 await page.goto('http://127.0.0.1:'+server.address().port);await page.waitForFunction(()=>!!life.data);
 await page.locator('.home-week-grid [data-home-day]').first().waitFor();
 await page.getByRole('button',{name:'Impostazioni',exact:true}).click();
 await page.locator('[data-settings-theme]').selectOption('system');assert.equal(await page.evaluate(()=>localStorage.getItem('life-theme')),null);
 await page.locator('[data-settings-theme]').selectOption('dark');await page.locator('#dialog [data-close]').first().click();
 assert.equal(await page.locator('.home-week-grid [data-home-day]').count(),7);
 if(process.env.LIFEOS_WEB_SCREENSHOTS){await mkdir(process.env.LIFEOS_WEB_SCREENSHOTS,{recursive:true});await page.screenshot({path:process.env.LIFEOS_WEB_SCREENSHOTS+'/home-parity-mobile.png',fullPage:true});}
 assert.ok(await page.locator('.home-summary').textContent());
 await page.locator('[data-home-times-sheet]').click();
 assert.equal(await page.locator('#life-dialog .kv').count(),6);await page.locator('#life-dialog [data-life-close]').click();
 await page.evaluate(()=>setView('tasks'));
 assert.deepEqual(await page.locator('.os-category-tabs button').allTextContents(),['Attività','Letture']);
 await page.getByRole('button',{name:'Gestisci categorie',exact:true}).click();
 await page.locator('#life-dialog input[name=label]').waitFor();await page.locator('#life-dialog [data-life-close]').click();
 await page.evaluate(()=>setView('overview'));await page.locator('.finance-actions').waitFor();
 assert.deepEqual((await page.locator('.finance-actions button').allTextContents()).map(t=>t.replace(/[◷⋯＋]/g,'').trim()),['Budget','Piani','Spesa']);
 await page.locator('.finance-actions [data-new-transaction]').click();
 assert.deepEqual(await page.locator('#entry-form [name=category] option').allTextContents(),platformContract.expenseCategories);
 assert.equal(await page.locator('#entry-form [name=months]').count(),1);
 assert.equal(await page.locator('#entry-form [name=note]').count(),1);
 assert.deepEqual(await page.locator('#entry-form [name=budgetTreatment] option').allTextContents(),['Automatico','Da risparmi']);
 await page.locator('#entry-form [name=type]').selectOption('Entrata');
 assert.deepEqual(await page.locator('#entry-form [name=category] option').allTextContents(),platformContract.incomeCategories);
 await page.locator('#dialog [data-close]').first().click();
 await page.locator('.finance-actions [data-view=budget]').click();await page.locator('[data-edit-planning]').waitFor();
 await page.locator('[data-edit-planning]').click();
 await page.locator('#platform-planning-form [name=goal]').fill('5000');await page.locator('#platform-planning-form [name=target]').fill('14000');
 await page.locator('#platform-planning-form [type=submit]').click();await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
 const saved=calls.find(c=>c.method==='savePlanningSettings');assert.equal(saved.args[0],5000);assert.equal(saved.args[2],14000);assert.equal(saved.args[1],7000/(13-Number(month.slice(-2))));
 await page.locator('[data-budget-recurring]').click();await page.locator('#platform-recurring-form [name=amount]').fill('160');await page.locator('#platform-recurring-form [name=months]').fill('2');await page.locator('#platform-recurring-form [type=submit]').click();await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
 const bill=calls.find(c=>c.method==='saveTransaction');assert.equal(bill.args[0].category,'Gas');assert.equal(bill.args[0].months,2);assert.ok(bill.args[0].requestId);
 // The bank commits, but the browser never receives its response. Reload and
 // replay must retain the original identity and exact persisted payload.
 quickUnavailable=true;
 const queued={requestId:'synthetic-response-lost-1',type:'Spesa',category:'Casa',name:'Spesa senza risposta',date:today,amount:23.45,months:1,account:'Trade Republic'};
 await page.evaluate(p=>workerRequest('saveTransaction',[p]),queued);
 assert.equal(await page.evaluate(()=>lifeOSDeviceBackup().pending.length),1);
 assert.match(await page.locator('#platform-sync-status').textContent(),/salvati sul dispositivo/);
 await page.reload();await page.waitForFunction(()=>!!life.data);assert.equal(await page.evaluate(()=>lifeOSDeviceBackup().pending.length),1);
 quickUnavailable=false;await page.evaluate(()=>workerRequest('getFinanceOverview',[state.year,state.month]));
 assert.equal(await page.evaluate(()=>lifeOSDeviceBackup().pending.length),0);
 assert.equal([...ledger.keys()].filter(id=>id===queued.requestId).length,1);
 const replays=calls.filter(c=>c.method==='saveTransaction'&&c.args[0].requestId===queued.requestId);assert.ok(replays.length>=2);assert.deepEqual(replays[0].args,replays.at(-1).args);
 await page.evaluate(()=>setView('overview'));await page.locator('.finance-value').waitFor();failOverview=true;
 await page.locator('#next-month').click();await page.locator('[data-finance-retry]').waitFor();
 assert.equal(await page.locator('.finance-value').count(),0);
 await page.locator('[data-finance-retry]').click();await page.locator('.finance-value').waitFor();
 await page.locator('#prev-month').click();await page.locator('.finance-value').waitFor();
 await page.evaluate(()=>setView('analysis'));await page.locator('[data-refresh-categories]:enabled').waitFor();
 assert.deepEqual(await page.locator('#analysis h2').allTextContents(),['Spese per categoria','Previsione patrimonio','Patrimonio','Stipendi per competenza']);
 assert.match(await page.locator('[data-period-categories]').textContent(),/300,00/);
 if(process.env.LIFEOS_WEB_SCREENSHOTS)await page.screenshot({path:process.env.LIFEOS_WEB_SCREENSHOTS+'/analysis-parity-mobile.png',fullPage:true});
 await page.locator('[data-category-period="6"]').click();await page.locator('[data-refresh-categories]:enabled').waitFor();assert.match(await page.locator('[data-period-categories]').textContent(),/600,00/);
 const reads=calls.filter(c=>c.method==='getFinanceData').length;
 await page.locator('[data-category-period="3"]').click();await page.locator('[data-refresh-categories]:enabled').waitFor();assert.equal(calls.filter(c=>c.method==='getFinanceData').length,reads);
 // An interrupted category period is never displayed as a complete total.
 const older=new Date(month+'-01T12:00:00Z');older.setUTCMonth(older.getUTCMonth()-8);failMonth=older.toISOString().slice(0,7);
 await page.locator('[data-category-period="12"]').click();await page.getByRole('button',{name:'Riprova',exact:true}).waitFor();assert.match(await page.locator('[data-period-categories]').textContent(),/Caricati/);
 await page.getByRole('button',{name:'Riprova',exact:true}).click();await page.locator('[data-refresh-categories]:enabled').waitFor();assert.match(await page.locator('[data-period-categories]').textContent(),/1\.200,00/);
 for(const [width,height] of [[320,568],[390,844],[1280,900]]){
  await page.setViewportSize({width,height});
  for(const view of ['today','tasks','calendar','overview','budget','analysis','extras']){
   await page.evaluate(v=>setView(v),view);await page.waitForTimeout(30);
   assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),view+' overflow at '+width);
  }
 }
 oldServer=true;await page.evaluate(()=>{state.data=null;setView('extras');});await page.locator('#extras [role=alert]').waitFor();assert.equal(await page.locator('#extras [role=alert]').textContent(),platformContract.plansUnavailable);
 assert.equal(await page.locator('#extras').getByText('Caricamento Piani…').count(),0);
 await page.emulateMedia({reducedMotion:'reduce'});assert.equal(await page.locator('.theme-toggle').evaluate(e=>getComputedStyle(e).transitionDuration),'0s');
 assert.deepEqual(errors,[]);
 const broken=await browser.newPage();await broken.addInitScript(()=>localStorage.setItem('lifeos-web-device-v2','corrupted'));
 await broken.goto('http://127.0.0.1:'+server.address().port);await broken.waitForFunction(()=>!!life.data);
 const before=calls.filter(c=>c.method==='saveTransaction').length;
 await assert.rejects(()=>broken.evaluate(p=>workerRequest('saveTransaction',[p]),queued),/Archivio locale non leggibile/);
 assert.equal(calls.filter(c=>c.method==='saveTransaction').length,before);
 assert.equal(await broken.evaluate(()=>localStorage.getItem('lifeos-web-device-v2')),'corrupted');await broken.close();
 console.log('PASS: shared categories, dashboard week, neutral times, tasks, movement fields, savings read-back, recurring payment, four analysis charts, 3/6/12 month cache/error/retry, outdated server recovery, seven views at three widths.');
}finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
