import {chromium} from 'playwright';
import fs from 'node:fs';
const out=process.env.SHOTS||'/tmp/shots';fs.mkdirSync(out,{recursive:true});
const file=process.env.HTML||new URL('../app.html',import.meta.url);
const html=fs.readFileSync(file,'utf8');
const fixture=fs.readFileSync(new URL('./interface.mjs',import.meta.url),'utf8').match(/const d=(\{.*?\});\r?\nstate\.year/s)[1];
const fx=eval('('+fixture+')');
const plans=[
 {id:'p1',name:'Assicurazione auto',category:'Assicurazione',kind:'fixed',amountCents:62000,startMonth:'2026-01',intervalMonths:12,status:'active',contributionCents:5167,fundCents:41300,outstandingCents:0},
 {id:'p2',name:'Dentista',category:'Dentista',kind:'goal',amountCents:90000,startMonth:'2026-10',endMonth:'2027-03',status:'active',contributionCents:15000,fundCents:30000,outstandingCents:90000}];
const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const errors=[];
for(const theme of ['dark','light']) for(const [w,h,tag] of [[390,844,'m'],[1280,900,'d']]){
 const ctx=await browser.newContext({viewport:{width:w,height:h},colorScheme:theme,deviceScaleFactor:1});
 const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',async r=>{const q=r.request();
  if(q.isNavigationRequest())return r.fulfill({body:html,contentType:'text/html'});
  const u=new URL(q.url());if(!u.pathname.startsWith('/api/'))return r.fulfill({status:503,body:'x'});
  const m=u.pathname.slice(5),args=q.postData()?JSON.parse(q.postData()):[];
  if(m==='getFinancePlans')return r.fulfill({json:{version:2,month:args[0],plans,payments:[]}});
  if(['getFinanceData','getFinanceOverview','getFinanceExtras'].includes(m))return r.fulfill({json:{...fx,year:args[0],month:args[1],key:args[0]+'-'+String(args[1]).padStart(2,'0')}});
  if(m==='getLifeData')return r.fulfill({json:{today:'2026-10-17',shifts:[{day:'2026-10-17',kind:'morning'}],events:[],tasks:[{id:1,title:'Chiamare assicurazione',list_kind:'action',status:'todo',sort_order:0},{id:2,title:'Pagare bolletta',list_kind:'action',status:'done',sort_order:1}],categories:[{key:'action',label:'Attività'}],routines:[],activityEvents:[],upcomingEvents:[]}});
  if(m==='getFinanceCategoryOptions')return r.fulfill({json:['Altro','Dentista','Alimentari']});
  if(m==='getAdminStatus')return r.fulfill({json:{tables:[{name:'finance_transactions',rows:1240},{name:'os_tasks',rows:310}],generatedAt:'2026-10-17T10:00:00Z'}});
  return r.fulfill({json:true});});
 await page.goto('http://lifeos.local');await page.waitForTimeout(300);
 await page.evaluate(([f,t])=>{document.documentElement.dataset.theme=t;document.getElementById('error')?.classList.add('hidden');
  const d=eval('('+f+')');d.plansV2={version:2,month:'2026-10',plans:[{id:'p1',name:'Assicurazione auto',category:'Assicurazione',kind:'fixed',amountCents:62000,startMonth:'2026-01',intervalMonths:12,status:'active',contributionCents:5167,fundCents:41300,outstandingCents:0},{id:'p2',name:'Dentista',category:'Dentista',kind:'goal',amountCents:90000,startMonth:'2026-10',endMonth:'2027-03',status:'active',contributionCents:15000,fundCents:30000,outstandingCents:90000}],payments:[]};state.year=2026;state.month=10;state.data=d;state.loadedDetail=true;
  life.data={today:'2026-10-17',shifts:[{day:'2026-10-17',kind:'morning'}],events:[],tasks:[{id:1,title:'Chiamare assicurazione',list_kind:'action',status:'todo',sort_order:0},{id:2,title:'Pagare bolletta',list_kind:'action',status:'done',sort_order:1}],categories:[{key:'action',label:'Attività'}],routines:[]};life.category='action';life.month='2026-10';life.selected='2026-10-17';
  document.getElementById('loading')?.classList.add('hidden');},[fixture,theme]);
 for(const v of ['today','overview','movements','budget','analysis','extras','tasks','calendar','admin']){
  await page.evaluate(v=>{try{setView(v);renderLifeOS?.()}catch(e){}},v);await page.waitForTimeout(350);
  await page.screenshot({path:`${out}/${theme}-${tag}-${v}.png`,fullPage:false});
 }
 await page.evaluate(()=>openTransaction('Spesa'));await page.waitForTimeout(300);
 await page.screenshot({path:`${out}/${theme}-${tag}-modal.png`});
 await ctx.close();
}
await browser.close();console.log('errors',errors.slice(0,5));
