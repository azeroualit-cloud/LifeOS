import test from 'node:test';
import assert from 'node:assert/strict';
import {romeInput,romeTimestamp,weightLink} from './weight-transfer.mjs';
test('weight handoff uses exact Rome time and a stable ID without any HTTP destination',()=>{
 const id='646EF0F9-DB18-4082-AF8C-E6CC20CE9958',now=new Date('2026-10-17T12:00:00Z');
 assert.equal(romeInput(now),'2026-10-17T14:00');assert.equal(romeTimestamp('2026-10-17T14:00'),now.getTime());
 const link=new URL(weightLink('80.235','2026-10-17T13:00',id,now));assert.equal(link.protocol,'lifeos:');assert.equal(link.hostname,'weight');assert.equal(link.searchParams.get('kg'),'80.235');assert.equal(link.searchParams.get('id'),id);assert.equal(Number(link.searchParams.get('at')),Date.parse('2026-10-17T11:00:00Z'));
});
test('invalid, future and nonexistent DST times cannot prepare a weight transfer',()=>{
 const id='646EF0F9-DB18-4082-AF8C-E6CC20CE9958',now=new Date('2026-10-17T12:00:00Z');
 for(const kg of [0,-1,501,NaN,Infinity])assert.throws(()=>weightLink(kg,'2026-10-17T13:00',id,now));
 assert.throws(()=>weightLink(80,'2027-10-17T13:00',id,now));assert.throws(()=>romeTimestamp('2026-03-29T02:30'));assert.throws(()=>romeTimestamp('2026-02-30T12:00'));
});
