import test from 'node:test';
import assert from 'node:assert/strict';
import {budgetFlow} from './budget-flow.mjs';
const month='2026-10';
const plans=[
 {id:'rent',name:'Casa sintetica',status:'active',startMonth:month,contributionCents:55000},
 {id:'advance',name:'Anticipo sintetico',status:'active',startMonth:'2026-11',contributionCents:-10001},
 {id:'stopped',name:'Interrotto sintetico',status:'stopped',startMonth:'2026-01',contributionCents:2000},
 {id:'zero',name:'Scadenza futura',status:'active',startMonth:month,contributionCents:0},
 {id:'future',name:'Futuro',status:'active',startMonth:'2026-11',contributionCents:0},
 {id:'closed',name:'Concluso',status:'settled',startMonth:'2026-01',endMonth:'2026-09',contributionCents:0},
];
test('salary waterfall includes all applicable plans, credits advances and never duplicates adopted legacy rows',()=>{
 const s={monthlySalary:1800,monthlySpent:123.45,monthlyRemaining:1206.56,monthlyBudgetBreakdown:[{name:'Casa sintetica',planId:'rent',amount:550},{name:'Anticipo sintetico',planId:'advance',amount:-100.01},{name:'Interrotto sintetico',planId:'stopped',amount:20}]};
 const f=budgetFlow(s,plans,month);
 assert.deepEqual(f.rows.map(r=>r.planId),['rent','advance','stopped','zero']);
 assert.deepEqual(f.rows.map(r=>r.remainingCents),[125000,135001,133001,133001]);
 assert.equal(f.rows.at(-1).remainingCents-f.spentCents,f.remainingCents);
 assert.equal(f.remainingCents,120656);
});
test('legacy obligations and refunds reconcile with the confirmed budget in cents, including negative budgets',()=>{
 const s={monthlySalary:100,monthlySpent:-10.01,monthlyRemaining:-9.99,monthlyBudgetBreakdown:[{name:'Impegno precedente',amount:120}]};
 const f=budgetFlow(s,[],month);
 assert.equal(f.rows.length,1);assert.equal(f.rows[0].remainingCents,-2000);
 assert.equal(f.rows.at(-1).remainingCents-f.spentCents,-999);
});
test('empty month and historical obligations stay explainable',()=>{
 assert.deepEqual(budgetFlow({monthlySalary:100,monthlyRemaining:100},[],month).rows,[]);
 const f=budgetFlow({monthlySalary:100,monthlySpent:10,monthlyRemaining:70},[],month);
 assert.equal(f.rows[0].name,'Altri impegni del mese');assert.equal(f.rows[0].amountCents,2000);
});
