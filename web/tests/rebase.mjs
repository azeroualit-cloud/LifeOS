import {chromium} from 'playwright';
import fs from 'node:fs';
const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const html=fs.readFileSync(new URL('../app.html',import.meta.url),'utf8');
const errors=[],calls=[];
const fixture=fs.readFileSync(new URL('./interface.mjs',import.meta.url),'utf8').match(/const d=(\{.*?\});\r?\nstate\.year/s)[1];
const fx=eval('('+fixture+')');
const plans=[{id:'p2',name:'Dentista',category:'Dentista',kind:'goal',amountCents:90000,startMonth:'2026-10',endMonth:'2027-03',status:'active',contributionCents:15000,fundCents:30000,outstandingCents:90000}];
const page=await browser.newPage();page.on('pageerror',e=>errors.push(e.message));
await page.route('**/*',async r=>{const q=r.request();
 if(q.isNavigationRequest())return r.fulfill({body:html,contentType:'text/html'});
 const u=new URL(q.url());if(!u.pathname.startsWith('/api/'))return r.fulfill({status:503,body:'x'});
 const m=u.pathname.slice(5),args=q.postData()?JSON.parse(q.postData()):[];calls.push({m,args});
 if(m==='getFinancePlans')return r.fulfill({json:{version:2,month:args[0],plans,payments:[]}});
 if(m==='getExpenseRouting')return r.fulfill({json:{version:1,plans:args[0].category==='Dentista'?[{id:'p2',name:'Dentista',kind:'goal',availableCents:30000}]:[]}});
 if(['getFinanceData','getFinanceOverview','getFinanceExtras'].includes(m))return r.fulfill({json:{...fx,year:args[0],month:args[1],key:args[0]+'-'+String(args[1]).padStart(2,'0')}});
 if(m==='getLifeData')return r.fulfill({json:{today:'2026-10-17',shifts:[],events:[],tasks:[],categories:[],routines:[],activityEvents:[],upcomingEvents:[]}});
 if(m==='getFinanceCategoryOptions')return r.fulfill({json:['Altro','Dentista','Alimentari']});
 if(m==='getAdminStatus')return r.fulfill({json:{tables:[{name:'finance_transactions',rows:12}],generatedAt:'2026-10-17T10:00:00Z'}});
 return r.fulfill({json:true});});
await page.goto('http://lifeos.local');await page.waitForTimeout(300);
await page.evaluate(f=>{document.getElementById('error').classList.add('hidden');
 const d=eval('('+f+')');state.year=2026;state.month=10;state.data=d;state.loadedDetail=true;
 life.data={today:'2026-10-17',shifts:[],events:[],tasks:[],categories:[],routines:[]};life.month='2026-10';document.getElementById('loading').classList.add('hidden');},fixture);
for(const [w,h] of [[320,568],[375,812],[768,1024],[1024,768],[1280,900],[1600,900]]){
 await page.setViewportSize({width:w,height:h});
 for(const v of ['overview','budget','analysis','extras','admin']){
  await page.evaluate(v=>setView(v),v);await page.waitForTimeout(200);
  if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error(`overflow ${v} ${w}`);
 }
}
if(!(await page.locator('#admin').textContent()).trim())throw Error('admin vuoto');
if(!calls.some(c=>c.m==='getAdminStatus'))throw Error('getAdminStatus non chiamato');
// selettore mese
await page.setViewportSize({width:1280,height:900});await page.evaluate(()=>setView('overview'));
await page.fill('#period-pick','2026-07').catch(()=>{});await page.evaluate(()=>{const i=document.getElementById('period-pick');i.value='2026-07';i.dispatchEvent(new Event('change',{bubbles:true}));});
await page.waitForTimeout(300);
if(await page.evaluate(()=>state.year+'-'+state.month)!=='2026-7')throw Error('mese '+await page.evaluate(()=>state.year+'-'+state.month));
await page.evaluate(()=>{state.year=2026;state.month=10;});
// destinazione spesa
await page.evaluate(()=>openTransaction('Spesa'));await page.waitForTimeout(200);
await page.selectOption('#entry-form [name=category]','Dentista');await page.fill('#entry-form [name=amount]','50');
await page.locator('#routing-box select').waitFor({timeout:3000});
await page.selectOption('#routing-box select','p2');
await page.fill('#entry-form [name=name]','Pulizia');
await page.locator('#entry-form [type=submit]').click();await page.waitForTimeout(400);
const c=calls.filter(x=>x.m==='saveTransaction').at(-1);
if(!c||c.args[0].expenseRoutingVersion!==1||c.args[0].expenseDestination!=='plan'||c.args[0].planId!=='p2')throw Error('routing '+JSON.stringify(c));
if(errors.length)throw Error('pageerror '+errors.join(' | '));
console.log('rebase ok');await browser.close();
