import {chromium} from 'playwright';
import fs from 'node:fs';
const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const html=fs.readFileSync(new URL('../app.html',import.meta.url),'utf8');
const errors=[];
// Fixture: 14 mesi di movimenti sintetici (importi con segno, in euro).
const movements=[];let id=1;
for(let m=0;m<14;m++){const d=new Date(Date.UTC(2025,8+m,1));const ym=d.toISOString().slice(0,7);
 movements.push({source_row:id++,actual_date:ym+'-02',actual_month:ym,description:'Stipendio',amount:1740.25,category:'Stipendio',movement_type:'Entrata',account:'Trade Republic'});
 for(const [c,a] of [['Alimentari',-(220+m*7)],['Trasporti',-(90+m%3*20)],['Svago',-(60+m*5)],['Casa',-400]])movements.push({source_row:id++,actual_date:ym+'-1'+(id%9),actual_month:ym,description:c+' test',amount:a,category:c,movement_type:'Spesa',account:'Revolut',merchant:'Negozio'});
 movements.push({source_row:id++,actual_date:ym+'-20',actual_month:ym,description:'Giroconto',amount:-300,category:'',movement_type:'Trasferimento',account:'Revolut'});}
const tables=[{name:'movements',rows:movements.length},{name:'os_tasks',rows:42},{name:'os_events',rows:17},{name:'financial_categories',rows:9}];
const page=await browser.newPage({acceptDownloads:true});page.on('pageerror',e=>errors.push(e.message));
await page.route('**/*',async r=>{const q=r.request();
 if(q.isNavigationRequest())return r.fulfill({body:html,contentType:'text/html'});
 const u=new URL(q.url());
 if(u.pathname==='/api/getAdminStatus')return r.fulfill({json:{tables,bytes:3.2*1048576,lastMovement:'2026-11-18',limits:{storageBytes:500*1048576,dailyWrites:100000,dailyReads:5000000},auth:'Password',time:new Date().toISOString()}});
 if(u.pathname==='/api/getAdminExport'){const [t,off]=JSON.parse(q.postData());const all=t==='movements'?movements:[{id:1}];const rows=all.slice(off,off+200);return r.fulfill({json:{table:t,offset:off,rows,done:rows.length<200}});}
 return r.fulfill({status:503,body:'Offline test'});});
await page.goto('http://lifeos.local');await page.waitForTimeout(250);
await page.evaluate(()=>{document.documentElement.dataset.theme='dark';document.getElementById('error').classList.add('hidden');
 const d={year:2026,month:10,key:'2026-10',updatedAt:'test',summary:{monthlyRemaining:72.19,budget:7553.59,monthlySalary:1740.25,monthlySpent:728.29,recurringCommitments:[],monthlyBudgetBreakdown:[]},transactions:[{row:1,name:'Amazon',date:'2026-10-16',category:'Shopping',type:'Spesa',amount:-15.04}],recurring:[],averages:[],planning:{year:2026,goal:null,monthlySaving:100,now:7553.59,monthsRemaining:2},monthlyBreakdowns:{},lifetime:{series:[]}};
 state.year=2026;state.month=10;state.data=d;state.loadedDetail=true;
 life.data={today:'2026-11-18',shifts:[],events:[],tasks:[],categories:[],routines:[]};document.getElementById('loading').classList.add('hidden');});
// Admin
await page.setViewportSize({width:1280,height:900});
await page.locator('#admin-link').click();
await page.locator('.adm-grid .adm-row').first().waitFor();
if(await page.locator('#page-title').textContent()!=='Admin')throw Error('title');
if((await page.locator('.adm-row').count())!==4)throw Error('tables');
if(!(await page.locator('.adm-big').textContent()).includes('3.2'))throw Error('size');
await page.screenshot({path:'/home/claude/shots/admin.png',fullPage:true});
const [dl1]=await Promise.all([page.waitForEvent('download'),page.locator('[data-adm=csv]').click()]);
const csv=fs.readFileSync(await dl1.path(),'utf8');
if(!csv.includes('actual_date;description;amount')||!csv.includes('1740,25'))throw Error('csv content');
if(csv.split('\r\n').length!==movements.length+1)throw Error('csv rows '+csv.split('\r\n').length);
await page.locator('.adm-progress').filter({hasText:'esportati'}).waitFor();
const [dl2]=await Promise.all([page.waitForEvent('download'),page.locator('[data-adm=backup]').click()]);
const bk=JSON.parse(fs.readFileSync(await dl2.path(),'utf8'));
if(Object.keys(bk.tables).length!==4||bk.tables.movements.length!==movements.length)throw Error('backup');
// Analisi
await page.evaluate(()=>setView('analysis'));
await page.locator('.apl-kpis').waitFor();
const kpi=await page.locator('.apl-kpis strong').allTextContents();
if(kpi.length!==4||!kpi[1].includes('10.442'))throw Error('kpi '+kpi);
if(!(await page.locator('.apl .bar-row').count()))throw Error('categories');
await page.locator('[data-apl-range="3"]').click();
await page.locator('[data-apl-range="3"].active').waitFor();
await page.fill('#apl-search','Alimentari');await page.waitForTimeout(400);
const rowsShown=await page.locator('.apl tbody tr').count();
if(rowsShown!==3)throw Error('search rows '+rowsShown);
await page.screenshot({path:'/home/claude/shots/analysis.png',fullPage:true});
for(const w of [320,375,768,1280,1600]){await page.setViewportSize({width:w,height:900});
 for(const v of ['analysis','admin']){await page.evaluate(x=>setView(x),v);await page.waitForTimeout(150);
  if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('overflow '+v+' '+w);}}
await page.setViewportSize({width:375,height:812});await page.evaluate(()=>setView('admin'));await page.waitForTimeout(150);await page.screenshot({path:'/home/claude/shots/admin-mobile.png',fullPage:true});
console.log(JSON.stringify({ok:true,errors}));await browser.close();if(errors.length)process.exitCode=1;
