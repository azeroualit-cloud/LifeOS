import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {wealthForecast,aggregateCategories,addMonth} from './finance-model.mjs';

test('category periods retain refunds, exact cents and incomplete-month errors',()=>{
 const cache=new Map([['2026-09',[{name:'Casa',amount:20.01},{name:'Auto',amount:30}]],['2026-10',[{name:'Casa',amount:-10.01},{name:'Auto',amount:-35}]]]);
 assert.deepEqual(aggregateCategories(cache,['2026-09','2026-10']),[{name:'Casa',amount:10}]);
 assert.throws(()=>aggregateCategories(cache,['2026-08','2026-09']),/incompleti/);
 assert.throws(()=>aggregateCategories(new Map([['2026-10',[{name:'',amount:1}]]]),['2026-10']),/non validi/);
 assert.equal(addMonth('2026-12',1),'2027-01');assert.equal(addMonth('2028-01-31',1),'2028-02-29');
});

test('web and Swift forecasts agree on actuals, planned cash, bootstrap bands and year boundaries',async()=>{
 const folder=await mkdtemp(join(tmpdir(),'lifeos-parity-'));
 try{
  // Compile the real native model, not a second JavaScript implementation.
  await writeFile(join(folder,'main.swift'),`import Foundation
let input = try JSONDecoder().decode([Record].self, from: FileHandle.standardInput.readDataToEndOfFile())
let output: [Record] = input.map { row in
 let model = NativeWealthForecast(finance: row.record("finance"), plan: row.record("plan"), day: row.text("day"))
 func point(_ p: NativeForecastPoint) -> JSONValue { .object(["day": .string(p.day), "value": .number(p.value), "lower": .number(p.lower), "upper": .number(p.upper)]) }
 return ["samples": .int(model.samples), "normalizedNet": .number(model.normalizedNet), "knownExtra": .number(model.knownExtra), "history": .array(model.history.map(point)), "prediction": .array(model.prediction.map(point))]
}
FileHandle.standardOutput.write(try JSONEncoder().encode(output))
`);
  const files=['Models','NativeModels','NativeFinanceModel','NativePlanModel','NativePlatformContract'].map(n=>'work/native/Sources/'+n+'.swift');
  const build=spawnSync(process.env.LIFEOS_SWIFTC||'swiftc',[...files,join(folder,'main.swift'),'-module-cache-path',join(folder,'cache'),'-o',join(folder,'model')],{encoding:'utf8'});
  assert.equal(build.status,0,build.stderr);
  const samples=[100,120,90,140,110,10000],day='2027-01-31';
  const finance={summary:{budget:5000},forecastHistory:samples.map((ordinaryNet,i)=>({month:addMonth('2027-01',i-6),ordinaryNet,extraPaid:0,observed:true})),lifetime:{series:[{month:'2026-12',wealth:4800}]},wealthHistory:[{month:'2026-12',measured:4900,estimated:4700}],plansV2:{plans:[{id:'goal',kind:'goal',status:'active',amountCents:60000,outstandingCents:55000,endMonth:'2027-03'},{id:'fixed',kind:'fixed',status:'active',startMonth:'2026-11',intervalMonths:3,amountCents:9000,rateChanges:[{fromMonth:'2027-02',amountCents:12000}]}],payments:[{planId:'fixed',status:'posted',date:'2026-12-10',amountCents:9000,settlementKey:'2026-11'}]}};
  const plan={allocations:[{cycle_id:1,kind:'expense',status:'Programmato',total_cents:30000,end_month:'2027-02',payment_account:'Trade Republic'}],links:[{cycle_id:1,role:'payment',movement_source_row:8,attributed_cents:10000,account:'Trade Republic',actual_date:'2026-12-10',amount:-100}],settlements:[]};
  const fixtures=[{finance,plan,day},{finance:{...finance,forecastHistory:finance.forecastHistory.slice(0,3)},plan,day},{finance:{...finance,plansV2:{plans:[],payments:[]}},plan:{},day:'2027-02-28'}];
  const native=spawnSync(join(folder,'model'),[],{input:JSON.stringify(fixtures),encoding:'utf8'});assert.equal(native.status,0,native.stderr);
  const output=JSON.parse(native.stdout);
  for(let i=0;i<fixtures.length;i++){
   const f=fixtures[i],web=wealthForecast(f.finance,f.plan,f.day),swift=output[i];
   assert.equal(web.samples,swift.samples);assert.equal(web.normalizedNet,swift.normalizedNet);assert.equal(web.knownExtra,swift.knownExtra);
   assert.deepEqual(web.history.map(p=>[p.day,p.value]),swift.history.map(p=>[p.day,p.value]));
   assert.deepEqual(web.prediction,swift.prediction);
  }
 }finally{await rm(folder,{recursive:true,force:true});}
});
