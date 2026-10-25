import {chromium} from 'playwright';
import fs from 'node:fs';
const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const html=fs.readFileSync(new URL('../app.html',import.meta.url),'utf8');
const errors=[];
const page=await browser.newPage();page.on('pageerror',e=>errors.push(e.message));
await page.route('**/*',r=>r.request().isNavigationRequest()?r.fulfill({body:html,contentType:'text/html'}):r.fulfill({status:503,body:'Offline test'}));
await page.goto('http://lifeos.local');
await page.waitForTimeout(250);
await page.evaluate(()=>{document.documentElement.dataset.theme='dark';document.getElementById('error').classList.add('hidden');});
await page.evaluate(()=>{
const d={year:2026,month:10,key:'2026-10',updatedAt:'test',summary:{monthlyRemaining:72.19,budget:7553.59,monthlySalary:1740.25,monthlySpent:728.29,recurringCommitments:[],monthlyBudgetBreakdown:[]},transactions:[{row:1,name:'Amazon',date:'2026-10-16',category:'Shopping',type:'Spesa',amount:-15.04}],recurring:[],averages:[],planning:{year:2026,goal:null,monthlySaving:100,now:7553.59,monthsRemaining:2},monthlyBreakdowns:{},lifetime:{series:[]}};
state.year=2026;state.month=10;state.data=d;state.loadedDetail=true;
life.data={today:'2026-10-17',shifts:[{day:'2026-10-17',kind:'morning'}],events:[],tasks:[],categories:[],routines:[]};life.month='2026-10';life.selected='2026-10-17';
setView('overview');document.getElementById('loading').classList.add('hidden');
});
for(const [width,height] of [[375,812],[320,568],[1280,900]]) {
 await page.setViewportSize({width,height});
 await page.evaluate(()=>setView('overview'));
 const actions=await page.locator('.finance-actions button').allTextContents();
 if(!actions[2].includes('Spesa'))throw Error('Spesa order');
 if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Overflow '+width);

 await page.locator('.finance-actions [data-view=budget]').click();await page.locator('#budget .planning-card').waitFor();
 await page.evaluate(()=>setView('analysis'));await page.locator('#analysis .tr-category-card').waitFor();
 await page.evaluate(()=>setView('calendar'));await page.locator('.os-calendar-week').first().waitFor();

 if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Calendar overflow '+width);
}
// Completion remains in its section, follows open tasks, and can be reopened.
await page.evaluate(()=>{
 life.data.categories=[{key:'action',label:'Attività'}]; life.category='action';
 life.data.tasks=[
  {id:1,title:'Pasta',list_kind:'action',status:'done',sort_order:0},
  {id:2,title:'Kiwi',list_kind:'action',status:'todo',sort_order:1},
  {id:3,title:'Riso',list_kind:'action',status:'done',section_status:'waiting',sort_order:2},
  {id:4,title:'Banane',list_kind:'action',status:'waiting',sort_order:3}
 ]; setView('tasks'); renderLifeOS();
});
const sections=page.locator('#tasks .os-task-section');
if(await sections.count()!==2)throw Error('Only Active and Waiting sections expected');
if(await sections.nth(0).locator('.os-task-title').allTextContents().then(t=>t.join(','))!=='Kiwi,Pasta')throw Error('Active ordering');
if(await sections.nth(1).locator('.os-task-title').allTextContents().then(t=>t.join(','))!=='Banane,Riso')throw Error('Waiting ordering');
if(await page.locator('.os-completed').count())throw Error('Completed must not be a separate section');
if(await page.locator('[data-life-status="3:waiting"]').count()!==1)throw Error('Reopening must restore Waiting');
if(await page.locator('#tasks .done .os-task-title').first().evaluate(e=>getComputedStyle(e).textDecorationLine)!=='none')throw Error('Completed text must not be struck through');
for(const width of [320,375,1280]) {
 await page.setViewportSize({width,height:812});
 if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Tasks overflow '+width);
}
await page.setViewportSize({width:375,height:812});
await page.screenshot({path:new URL('../previews/attivita.png',import.meta.url).pathname,fullPage:true});
await page.emulateMedia({reducedMotion:'reduce'});
if(await page.locator('.theme-toggle').evaluate(e=>getComputedStyle(e).transitionDuration)!=='0s')throw Error('Reduced motion');
console.log(JSON.stringify({viewports:3,errors}));await browser.close();if(errors.length)process.exitCode=1;
