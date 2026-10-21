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
 if(method==='getFinanceCategoryPeriod'){
  const last=args[0],count=args[1],[y,m]=last.split('-').map(Number),months=Array.from({length:count},(_,i)=>new Date(Date.UTC(y,m-count+i,1)).toISOString().slice(0,7));
  if(failMonth&&months.includes(failMonth)){failMonth=null;res.statusCode=500;res.setHeader('Content-Type','text/html');res.end('<!DOCTYPE html><html><head><title>Worker exceeded resource limits</title></head></html>');return;}
  res.end(JSON.stringify({version:1,months:months.map(month=>({month,categories:[{name:'Casa',amount:100},{name:'Auto',amount:-10}]}))}));return;
 }
 if(method==='getFinanceOverview'&&failOverview){failOverview=false;res.statusCode=503;res.end('Mese non disponibile');return;}
 if(method==='savePlanningSettings'){[planning.goal,planning.monthlySaving,planning.savingsTarget]=args;res.end('true');return;}
 if(method==='saveTransaction'){
  ledger.set(args[0].requestId,args[0]);
  if(quickUnavailable){res.statusCode=503;res.end('Risposta non ricevuta');return;}
  res.end('true');return;
 }
 if(method==='saveEstimate'){res.end('true');return;}
 const d={key,year:Number(key.slice(0,4)),month:Number(key.slice(-2)),updatedAt:'test',summary:{budget:7000,committedCurrent:200,remainingFree:6800,monthlyRemaining:1000,monthlySalary:1800,monthlySpent:200,monthlyCommitted:600,recurringCommitments:[],monthlyBudgetBreakdown:[]},transactions:[],recurring:[{name:'Gas',estimate:40,nextEstimate:45}],averages:[],planning,categories:[{name:'Casa',amount:100},{name:'Auto',amount:-10}],extraPlan:{allocations:[],links:[]},forecastHistory:[],wealthHistory:[{month:key,measured:7000}],lifetime:{series:[],salaryHistory:[{month:key,base:1700,additional:100}]} };
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
 assert.equal(await page.locator('#entry-form [name=months]').count(),0);
 assert.equal(await page.locator('#entry-form [name=note]').count(),1);
 assert.equal(await page.locator('#entry-form [name=budgetTreatment]').count(),0);
 await page.locator('#entry-form [name=type]').selectOption('Entrata');
 assert.deepEqual(await page.locator('#entry-form [name=category] option').allTextContents(),platformContract.incomeCategories);
 await page.locator('#dialog [data-close]').first().click();
 await page.locator('.finance-actions [data-view=budget]').click();await page.locator('[data-edit-planning]').waitFor();
 await page.locator('[data-edit-planning]').click();
 await page.locator('#platform-planning-form [name=goal]').fill('5000');await page.locator('#platform-planning-form [name=target]').fill('14000');
 await page.locator('#platform-planning-form [type=submit]').click();await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
 const saved=calls.find(c=>c.method==='savePlanningSettings');assert.equal(saved.args[0],5000);assert.equal(saved.args[2],14000);assert.equal(saved.args[1],7000/(13-Number(month.slice(-2))));
 await page.locator('[data-budget-recurring]').click();
 assert.equal(await page.locator('#platform-recurring-form').count(),0);
 assert.equal(await page.locator('#page-title').textContent(),'Piani');
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
 await page.locator('.finance-actions [data-new-transaction]').click();assert.equal(await page.locator('#entry-form [name=date]').inputValue(),today);await page.locator('#dialog [data-close]').first().click();
 await page.locator('#prev-month').click();await page.locator('.finance-value').waitFor();
 await page.evaluate(()=>setView('analysis'));await page.locator('[data-refresh-categories]:enabled').waitFor();
 assert.deepEqual(await page.locator('#analysis h2').allTextContents(),['Spese per categoria','Previsione patrimonio','Patrimonio','Stipendi per competenza']);
 assert.match(await page.locator('[data-period-categories]').textContent(),/300,00/);
 if(process.env.LIFEOS_WEB_SCREENSHOTS)await page.screenshot({path:process.env.LIFEOS_WEB_SCREENSHOTS+'/analysis-parity-mobile.png',fullPage:true});
 await page.locator('[data-category-period="6"]').click();await page.locator('[data-refresh-categories]:enabled').waitFor();assert.match(await page.locator('[data-period-categories]').textContent(),/600,00/);
 const reads=calls.filter(c=>c.method==='getFinanceCategoryPeriod').length;
 await page.locator('[data-category-period="3"]').click();await page.locator('[data-refresh-categories]:enabled').waitFor();assert.equal(calls.filter(c=>c.method==='getFinanceCategoryPeriod').length,reads);
 // An interrupted category period is never displayed as a complete total.
 const older=new Date(month+'-01T12:00:00Z');older.setUTCMonth(older.getUTCMonth()-8);failMonth=older.toISOString().slice(0,7);
 await page.locator('[data-category-period="12"]').click();await page.getByRole('button',{name:'Riprova',exact:true}).waitFor();assert.match(await page.locator('[data-period-categories]').textContent(),/server è momentaneamente occupato/);assert.ok(!(await page.locator('[data-period-categories]').textContent()).includes('<!DOCTYPE'));
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
 oldServer=false;
 // Local tools use the native demo fixture and never fall through to remote writes.
 quickUnavailable=true;await page.evaluate(p=>workerRequest('saveTransaction',[p]),{...queued,requestId:'synthetic-before-demo-1'});
 await page.evaluate(()=>setView('today'));await page.getByRole('button',{name:'Impostazioni',exact:true}).click();
 page.once('dialog',d=>d.accept());await page.locator('[data-settings-demo]').click();
 await page.waitForFunction(()=>lifeOSLocalMode.mode==='demo'&&!!life.data);
 assert.deepEqual(await page.evaluate(()=>life.data.categories.map(c=>c.label)),['Attività','Desideri','Giochi','Letture']);
 const remoteBefore=calls.length;
 quickUnavailable=false;await page.evaluate(()=>{window.dispatchEvent(new Event('online'));document.dispatchEvent(new Event('visibilitychange'));});
 assert.equal(await page.evaluate(()=>lifeOSDeviceBackup().pending.length),1);assert.equal(calls.length,remoteBefore);
 assert.equal(await page.evaluate(()=>lifeOSLocalMode.previousArchive.pending.length),1);
 await page.setViewportSize({width:390,height:844});await page.evaluate(()=>setView('today'));await page.locator('[data-life-routine-manage]').click();
 await page.locator('#os-routine-form [name=title]').fill('Allenamento programmato');await page.locator('#os-routine-form [name=mode]').selectOption('interval');await page.locator('#os-routine-form [name=intervalDays]').fill('2');await page.locator('#os-routine-form [name=startDate]').fill(today);await page.locator('#os-routine-form [type=submit]').click();
 await page.waitForFunction(()=>life.data.routines.some(r=>r.title==='Allenamento programmato'));const habitID=await page.evaluate(()=>life.data.routines.find(r=>r.title==='Allenamento programmato').id);
 await page.locator('#life-dialog [data-life-close]').click();await page.locator(`[data-life-routine="${habitID}"]`).click();await page.waitForFunction(id=>!!life.data.routines.find(r=>r.id===id)?.checked,habitID);
 await page.locator('[data-life-routine-manage]').click();await page.getByRole('button',{name:'Modifica Allenamento programmato',exact:true}).click();assert.equal(await page.locator('#os-routine-form [name=intervalDays]').inputValue(),'2');
 await page.locator('#os-routine-form [name=mode]').selectOption('weekdays');if(process.env.LIFEOS_WEB_SCREENSHOTS)await page.screenshot({path:process.env.LIFEOS_WEB_SCREENSHOTS+'/habits-management-mobile.png',fullPage:true});await page.locator('#os-routine-form [type=submit]').click();assert.match(await page.locator('[data-habit-error]').textContent(),/almeno un giorno/);
 const offDay=(new Date(today+'T12:00:00Z').getUTCDay()+6)%7+1===7?1:(new Date(today+'T12:00:00Z').getUTCDay()+6)%7+2;
 await page.locator(`#os-routine-form [name=weekday][value="${offDay}"]`).check();await page.locator('#os-routine-form [type=submit]').click();await page.waitForFunction(id=>life.data.routines.find(r=>r.id===id)?.schedule?.mode==='weekdays',habitID);
 await page.locator('#life-dialog [data-life-close]').click();assert.equal(await page.locator(`[data-life-routine="${habitID}"]`).count(),0);
 await page.reload();await page.waitForFunction(()=>lifeOSLocalMode.mode==='demo'&&!!life.data);await page.evaluate(()=>setView('today'));assert.equal(await page.locator(`[data-life-routine="${habitID}"]`).count(),0);
 await page.locator('[data-life-routine-manage]').click();assert.equal(await page.getByRole('button',{name:'Modifica Allenamento programmato',exact:true}).count(),1);await page.locator('#life-dialog [data-life-close]').click();
 await page.evaluate(()=>setView('extras'));await page.locator('#extras [data-new-extra]').click();
 await page.locator('#plans-web-form [name=kind]').selectOption('fund');await page.locator('#plans-web-form [name=name]').fill('Fondo demo');await page.locator('#plans-web-form [name=amount]').fill('50');await page.locator('#plans-web-form [type=submit]').click();
 await page.locator('[data-plans-detail]').click();await page.locator('[data-plans-pay]').click();await page.locator('#plans-web-form [name=amount]').fill('40');await page.locator('#plans-web-form [type=submit]').click();
 await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
 assert.equal(await page.evaluate(()=>state.data.summary.budget),960);assert.equal(calls.length,remoteBefore);
 await page.reload();await page.waitForFunction(()=>lifeOSLocalMode.mode==='demo'&&!!life.data);assert.equal(calls.length,remoteBefore);
 await page.evaluate(()=>setView('overview'));await page.locator('.finance-value').waitFor();assert.equal(await page.evaluate(()=>state.data.summary.budget),960);
 await page.getByRole('button',{name:'Impostazioni',exact:true}).click();await page.locator('[data-settings-restore]').click();await page.waitForFunction(()=>lifeOSLocalMode.mode==='server'&&!!life.data);
 await page.evaluate(()=>setView('overview'));await page.locator('.finance-value').waitFor();
 await page.getByRole('button',{name:'Impostazioni',exact:true}).click();await page.locator('[data-settings-disconnect]').click();await page.waitForFunction(()=>lifeOSLocalMode.mode==='snapshot'&&!!life.data);
 await page.getByRole('button',{name:'Impostazioni',exact:true}).click();await page.locator('[data-settings-paste]').click();
 const imported={key:month,summary:{budget:1234,committedCurrent:100,remainingFree:1134,monthlyRemaining:500},transactions:[]};
 await page.locator('[name=snapshot]').fill(JSON.stringify(imported));await page.locator('[data-settings-import-text]').click();
 await page.waitForFunction(()=>lifeOSLocalMode.mode==='snapshot'&&!!life.data);await page.evaluate(()=>setView('overview'));await page.locator('.finance-value').waitFor();assert.equal(await page.evaluate(()=>state.data.summary.budget),1234);
 const snapshotCalls=calls.length;await assert.rejects(()=>page.evaluate(()=>workerRequest('saveTask',[{title:'Do not write'}])),/consultabile/);assert.equal(calls.length,snapshotCalls);
 await page.evaluate(()=>setView('today'));await page.getByRole('button',{name:'Aggiungi peso',exact:true}).click();
 await page.locator('#web-weight-form [name=weight]').fill('80.235');await page.locator('#web-weight-form [type=submit]').click();
 const weightURL=await page.locator('[data-weight-link]').getAttribute('href');assert.ok(weightURL.startsWith('lifeos://weight?'));assert.equal(new URL(weightURL).searchParams.get('kg'),'80.235');
 await page.locator('#web-weight-form [type=submit]').click();assert.equal(await page.locator('[data-weight-link]').getAttribute('href'),weightURL);assert.equal(calls.length,snapshotCalls);
 await page.locator('#life-dialog [data-life-close]').first().click();
 await page.emulateMedia({reducedMotion:'reduce'});assert.equal(await page.locator('.theme-toggle').evaluate(e=>getComputedStyle(e).transitionDuration),'0s');
 assert.deepEqual(errors,[]);
 const broken=await browser.newPage();await broken.addInitScript(()=>localStorage.setItem('lifeos-web-device-v2','corrupted'));
 await broken.goto('http://127.0.0.1:'+server.address().port);await broken.waitForFunction(()=>!!life.data);
 const before=calls.filter(c=>c.method==='saveTransaction').length;
 await assert.rejects(()=>broken.evaluate(p=>workerRequest('saveTransaction',[p]),queued),/Archivio locale non leggibile/);
 assert.equal(calls.filter(c=>c.method==='saveTransaction').length,before);
 assert.equal(await broken.evaluate(()=>localStorage.getItem('lifeos-web-device-v2')),'corrupted');await broken.close();
 console.log('PASS: shared categories, dashboard week, neutral times, tasks, movement fields, savings read-back, recurring payment, four analysis charts, 3/6/12 month cache/error/retry, outdated server recovery, seven views at three widths, isolated persistent demo, interval/weekday habit scheduling and reload, snapshot import and confirmed-app weight handoff.');
}finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
