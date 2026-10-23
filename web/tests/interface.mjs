import {chromium} from 'playwright';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const html=fs.readFileSync(new URL('../app.html',import.meta.url),'utf8');
const errors=[];
const page=await browser.newPage();page.on('pageerror',e=>errors.push(e.message));
await page.route('**/*',r=>r.request().isNavigationRequest()?r.fulfill({body:html,contentType:'text/html'}):r.fulfill({status:503,body:'Offline test'}));
await page.goto('http://lifeos.local');
await page.waitForTimeout(250);
await page.evaluate(()=>{document.documentElement.dataset.theme='dark';document.getElementById('error').classList.add('hidden');});
await page.evaluate(()=>{
// Synthetic UI fixture: invented amounts and description, no bank import or user data.
const d={year:2026,month:10,key:'2026-10',updatedAt:'test',summary:{monthlyRemaining:100,budget:3000,monthlySalary:2000,monthlySpent:500,recurringCommitments:[],monthlyBudgetBreakdown:[]},transactions:[{row:1,name:'Acquisto demo',date:'2026-10-16',category:'Shopping',type:'Spesa',amount:-10}],recurring:[],averages:[],planning:{year:2026,goal:null,monthlySaving:100,now:3000,monthsRemaining:2},monthlyBreakdowns:{},lifetime:{series:[]}};
state.year=2026;state.month=10;state.data=d;state.loadedDetail=true;
life.data={today:'2026-10-17',shifts:[{day:'2026-10-17',kind:'morning'}],events:[],tasks:[],categories:[],routines:[]};life.month='2026-10';life.selected='2026-10-17';
setView('overview');document.getElementById('loading').classList.add('hidden');
});
assert.deepEqual((await page.locator('.nav button').allTextContents()).map(t=>t.trim()),['Dashboard','Finanza']);
assert.equal(await page.locator('#tasks').count(),0);
await page.evaluate(()=>{
 life.data.tasks=[{id:4,title:'Attività precedente',status:'todo',list_kind:'action'}];
 life.data.routines=[{id:3,title:'Abitudine precedente',checked:0}];
 setView('today');
});
assert.equal(await page.locator('#today .os-calendar-week .os-day').count(),7);
assert(!/Attività precedente|Abitudine precedente|In evidenza|Routine/.test(await page.locator('#today').textContent()));
assert.equal(await page.locator('#today .dashboard-actions button').count(),2);
await page.route('**/api/getLifeData',async route=>route.fulfill({contentType:'application/json',body:JSON.stringify(await page.evaluate(()=>life.data))}));
let healthAttempts=0;
await page.route('**/api/saveHealthEntry',async route=>{
 const [entry]=route.request().postDataJSON();
 assert.equal(entry.weightKg,'78.4');assert.equal(entry.calories,'2100');
 healthAttempts++;
 await route.fulfill(healthAttempts===1?{status:503,body:'Connessione non disponibile'}:{contentType:'application/json',body:'true'});
});
await page.route('**/api/getHealthData',route=>route.fulfill({contentType:'application/json',body:JSON.stringify([{day:'2026-10-17',weight_kg:78.4,calories:2100}])}));
await page.locator('[data-add-weight]').click();
await page.locator('#health-form [name=weightKg]').fill('78.4');
await page.locator('#health-form [name=calories]').fill('2100');
await page.locator('#health-form [type=submit]').click();
await page.waitForFunction(()=>document.getElementById('health-error')?.textContent.includes('Connessione'));
assert.equal(await page.locator('#health-form [name=weightKg]').inputValue(),'78.4');
await page.locator('#health-form [type=submit]').click();
await page.waitForFunction(()=>document.getElementById('life-dialog').classList.contains('hidden'));
assert.match(await page.locator('.health-latest').textContent(),/78,4 kg/);
await page.locator('[data-health-metric=calories]').click();
assert.match(await page.locator('.health-latest').textContent(),/2[.\s]?100 kcal/);
await page.setViewportSize({width:375,height:812});
await page.screenshot({path:new URL('../previews/dashboard-salute.png',import.meta.url).pathname,fullPage:true});
await page.locator('[data-dashboard-calendar]').click();
await page.locator('.shift-publication').waitFor();
await page.locator('#calendar [data-view=today]').click();
assert.equal(await page.locator('#today.active').count(),1);
for(const [width,height] of [[375,812],[320,568],[1280,900]]) {
 await page.setViewportSize({width,height});
 await page.evaluate(()=>setView('today'));
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'Dashboard overflow '+width);
 await page.evaluate(()=>setView('overview'));
 const actions=await page.locator('#overview .finance-actions button').allTextContents();
 if(!actions[2].includes('Spesa'))throw Error('Spesa order');
 if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Overflow '+width);

 await page.locator('#overview .finance-actions [data-view=budget]').click();await page.locator('#budget .planning-card').waitFor();
 await page.evaluate(()=>setView('analysis'));await page.locator('#analysis .tr-category-card').waitFor();
 await page.evaluate(()=>setView('calendar'));await page.locator('#calendar .os-calendar-week').first().waitFor();
 assert.equal(await page.locator('#calendar [data-life-tool=event], #calendar [data-life-event], #page-fab button').count(),0);

 if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Calendar overflow '+width);
}
// The month is published only after queued brush writes finish. Failures stay retryable.
// Legacy events remain editable from Dashboard while the planner has no event creation tools.
await page.evaluate(()=>{
 life.data.events=[{id:9,title:'Evento precedente',day:'2026-10-17'}];
 osOpenEvent(9);
});
await page.locator('#os-event-editor').waitFor();
assert.equal(await page.locator('#os-event-editor [name=title]').inputValue(),'Evento precedente');
await page.locator('#os-event-editor [data-life-close]').click();
assert.equal(await page.locator('#os-event-editor').count(),0);
let attempts=0;
const calendar={path:'/calendar/turni/'+'a'.repeat(64)+'.ics',publishedAt:'2026-10-23T12:00:00Z'};
await page.route('**/api/publishShiftCalendar',async route=>{
 assert.deepEqual(route.request().postDataJSON(),[{month:'2026-10'}]);
 attempts++;
 await route.fulfill(attempts===1?{status:503,body:'Server non disponibile'}:{contentType:'application/json',body:JSON.stringify(calendar)});
});
await page.locator('[data-shift-publish]').click();
await page.locator('.shift-publication [role=alert]').waitFor();
assert.match(await page.locator('.shift-publication [role=alert]').textContent(),/Puoi riprovare/);
assert.equal(await page.locator('[data-shift-publish]').isEnabled(),true);
await page.evaluate(()=>{life.paintQueue=new Promise(resolve=>window.finishPaint=resolve);});
await page.locator('[data-shift-publish]').click();
assert.equal(await page.locator('[data-shift-publish]').isDisabled(),true);
assert.equal(await page.locator('[data-life-month="1"]').isDisabled(),true);
assert.equal(attempts,1,'publishing must wait for the brush queue');
await page.evaluate(()=>window.finishPaint());
await page.locator('.shift-subscription input').waitFor();
assert.equal(attempts,2);
assert.equal(await page.locator('.shift-subscription a').getAttribute('href'),'webcal://lifeos.local'+calendar.path);
assert.equal(await page.locator('.shift-subscription input').inputValue(),'http://lifeos.local'+calendar.path);
// Saving failures cannot silently publish an incomplete month.
await page.evaluate(()=>life.paintFailures.add('2026-10-23'));
await page.locator('[data-shift-publish]').click();
await page.locator('.shift-publication [role=alert]').waitFor();
assert.equal(attempts,2);
assert.match(await page.locator('.shift-publication [role=alert]').textContent(),/non sono stati salvati/);
await page.evaluate(()=>{life.paintFailures.clear();life.publishError='';renderLifeOS();});
for (const width of [320,375,1280]) {
 await page.setViewportSize({width,height:812});
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'Subscription overflow '+width);
}
await page.setViewportSize({width:375,height:1000});
await page.screenshot({path:new URL('../previews/turni-apple.png',import.meta.url).pathname,fullPage:true});
await page.emulateMedia({reducedMotion:'reduce'});
if(await page.locator('.theme-toggle').evaluate(e=>getComputedStyle(e).transitionDuration)!=='0s')throw Error('Reduced motion');
console.log(JSON.stringify({viewports:3,errors}));await browser.close();if(errors.length)process.exitCode=1;
