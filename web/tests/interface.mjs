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
await page.emulateMedia({reducedMotion:'reduce'});
if(await page.locator('.theme-toggle').evaluate(e=>getComputedStyle(e).transitionDuration)!=='0s')throw Error('Reduced motion');
console.log(JSON.stringify({viewports:3,errors}));await browser.close();if(errors.length)process.exitCode=1;
