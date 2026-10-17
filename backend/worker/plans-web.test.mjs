// Browser regression against HTML actually served by the single-file Worker.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile,mkdir} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import worker from '../../worker.js';
const {chromium}=await import(pathToFileURL(process.env.LIFEOS_PLAYWRIGHT_MODULE));
const password='synthetic-browser-fixture-password';
const response=await worker.fetch(new Request('https://fixture.test/',{headers:{Authorization:'Basic '+btoa('nas:'+password)}}),{APP_PASSWORD:password,DB:{}},{});
assert.equal(response.status,200);const html=await response.text();
assert.ok(html.includes('X-LifeOS-Plans-Version'));assert.ok(html.includes('Nuovo piano'));
const today=new Date().toLocaleDateString('sv-SE',{timeZone:'Europe/Rome'}),month=today.slice(0,7);
const plan={id:'synthetic-goal',name:'Obiettivo sintetico',kind:'goal',status:'active',amountCents:30000,contributionCents:10000,fundCents:10000,paidCents:0,outstandingCents:30000,startMonth:month,endMonth:month};
const finance={year:Number(month.slice(0,4)),month:Number(month.slice(-2)),key:month,updatedAt:'test',transactions:[],recurring:[],extraPlan:{allocations:[],links:[]},summary:{budget:4000,monthlyRemaining:1000,monthlyCommitted:500},plansV2:{version:2,month,plans:[plan],payments:[]}};
const life={today,month,categories:[],tasks:[],shifts:[],events:[],upcomingEvents:[],routines:[]};
const calls=[];let failWrite=false;
const server=createServer(async(req,res)=>{
 res.setHeader('Content-Type',req.url.startsWith('/api/')?'application/json':'text/html');
 if(!req.url.startsWith('/api/')){res.end(html);return;}
 let raw='';for await(const chunk of req)raw+=chunk;
 const args=JSON.parse(raw),method=req.url.slice(5);calls.push({method,args,version:req.headers['x-lifeos-plans-version']});
 if(method==='getLifeData')res.end(JSON.stringify(life));
 else if(method==='getFinancePlanMovements')res.end(JSON.stringify({movements:[{row:9,name:'Spesa sintetica',date:today,amountCents:12000}]}));
 else if(method.startsWith('get'))res.end(JSON.stringify(finance));
 else if(failWrite){failWrite=false;res.statusCode=503;res.end('Risposta non ricevuta');}
 else res.end(JSON.stringify({ok:true}));
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const browser=await chromium.launch({headless:true,...(process.env.LIFEOS_CHROMIUM?{executablePath:process.env.LIFEOS_CHROMIUM}:{}),args:['--no-sandbox']});
try{
 const page=await browser.newPage({viewport:{width:1280,height:900}}),errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.route('https://api.open-meteo.com/**',r=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify({current:{temperature_2m:20,weather_code:0},hourly:{time:[],rain:[],precipitation_probability:[]}})}));
 await page.addInitScript(()=>localStorage.setItem('life-theme','dark'));
 await page.goto('http://127.0.0.1:'+server.address().port);
 await page.waitForFunction(()=>!!life.data);
 await page.evaluate(()=>setView('extras'));
 await page.getByRole('button',{name:'Nuovo piano',exact:true}).last().waitFor();
 assert.equal(await page.locator('#page-title').textContent(),'Piani');
 const shot=process.env.LIFEOS_WEB_SCREENSHOTS;if(shot)await mkdir(shot,{recursive:true});
 for(const kind of ['goal','fund','fixed','estimated','advance','recovery']){
  await page.locator('#extras [data-new-extra]').click();
  await page.locator('#plans-web-form [name=kind]').selectOption(kind);
  await page.locator('#plans-web-form [name=name]').fill('Piano '+kind);
  await page.locator('#plans-web-form [name=amount]').fill('250');
  if(kind==='recovery')await page.locator('#plans-web-form [name=movementId] option[value="9"]').waitFor({state:'attached'});
  if(kind==='advance'&&shot)await page.screenshot({path:shot+'/new-advance-desktop.png'});
  await page.locator('#plans-web-form [type=submit]').click();
  await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
  const call=calls.filter(x=>x.method==='saveFinancePlan').at(-1);
  assert.equal(call.args[0].kind,kind);assert.equal(call.args[0].amountCents,25000);assert.equal(call.version,'2');
  await page.locator('#extras [data-new-extra]').waitFor();
 }
 // Retry after an ambiguous response keeps both operation ID and exact payload.
 await page.locator('#extras [data-new-extra]').click();
 await page.locator('#plans-web-form [name=name]').fill('Riprova');
 await page.locator('#plans-web-form [name=amount]').fill('80');failWrite=true;
 await page.locator('#plans-web-form [type=submit]').click();
 await page.getByRole('button',{name:'Riprova',exact:true}).click();
 await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
 const retries=calls.filter(c=>c.method==='saveFinancePlan').slice(-2);assert.deepEqual(retries[0].args,retries[1].args);
 // Linking an existing movement uses the v2 payment endpoint, never saveTransaction.
 await page.locator('[data-plans-pay]').click();
 await page.locator('#plans-web-form [name=movementId] option[value="9"]').waitFor({state:'attached'});
 await page.locator('#plans-web-form [name=movementId]').selectOption('9');
 await page.locator('#plans-web-form [type=submit]').click();
 await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
 const payment=calls.find(c=>c.method==='recordFinancePlanPayment');assert.equal(payment.args[0].movementId,9);assert.equal(payment.args[0].amountCents,12000);
 await page.locator('[data-plans-edit]').click();await page.locator('#plans-web-form [type=submit]').click();
 await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
 assert.ok(calls.some(c=>c.method==='editFinancePlan'));
 await page.locator('[data-plans-stop]').click();await page.locator('#plans-web-form [type=submit]').click();
 await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
 assert.ok(calls.some(c=>c.method==='stopFinancePlan'));
 finance.plansV2.plans.push({...plan,id:'synthetic-fund',kind:'fund',name:'Fondo sintetico',endMonth:null});
 finance.plansV2.payments.push({id:'fund-paid',planId:'synthetic-fund',status:'posted',cycleMonth:month,settlementKey:'fund-paid'});
 await page.evaluate(()=>load());await page.locator('[data-plans-pay="synthetic-fund"]').waitFor();
 finance.plansV2.payments.push({id:'payment-pending',planId:plan.id,status:'pending',cycleMonth:month});
 await page.evaluate(()=>load());await page.locator('[data-plans-resume]').click();
 await page.locator('#plans-web-form [type=submit]').click();
 await page.waitForFunction(()=>document.getElementById('dialog').classList.contains('hidden'));
 assert.ok(calls.some(c=>c.method==='resumeFinancePlanPayment'&&c.args[0].paymentId==='payment-pending'));
 await page.setViewportSize({width:390,height:844});
 await page.locator('#extras [data-new-extra]').click();
 assert.equal(await page.getByRole('heading',{name:'Nuova straordinaria'}).count(),0);
 assert.equal(await page.locator('#plans-web-form [name=kind] option').count(),6);
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 if(shot)await page.screenshot({path:shot+'/new-plan-mobile.png'});
 assert.ok(!calls.some(c=>['saveExtra','getFinanceExtras','recordExtraPayment'].includes(c.method)));
 assert.ok(calls.every(c=>c.version==='2'));assert.deepEqual(errors,[]);
 console.log('PASS: six plan types, legacy dialog replaced, same-ID retry, movement link, future edit, stop, repeated fund payments, resume pending payment, mobile layout; no JavaScript errors.');
}finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
