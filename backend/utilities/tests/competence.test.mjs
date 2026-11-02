import assert from 'node:assert/strict';
import { test } from 'node:test';
import { utilityPeriod, utilityShares, utilityCompetenceContext, utilityMonthlyCost, hasUtilityBill, salaryReferenceMonth } from '../competence.mjs';

const period = utilityPeriod({ competenceStartMonth: '2026-08', competenceEndMonth: '2026-10' });
const movement = (id = 2) => ({ source_row: id, actual_date: '2026-11-02', amount: -221.79, category: 'Acqua',
  account: 'Trade Republic', movement_type: 'Spesa', status: 'Eseguito' });
const plan = { id: 'water', category: 'Acqua', kind: 'estimated', status: 'active', startMonth: '2026-10', amountCents: 5000 };
const contribution = (p, month) => month >= p.startMonth ? p.amountCents : 0;

test('221.79 August–October allocates exactly 73.93 each, independent of payment in November', () => {
  assert.deepEqual(utilityShares(22179, period), ['08', '09', '10'].map(m => ({ month: '2026-' + m, amountCents: 7393 })));
  const bank = movement(), before = structuredClone(bank);
  const state = { plans: { water: plan }, payments: { bill: { status: 'posted', movementId: 2, utilityPeriod: period } } };
  const context = utilityCompetenceContext(state, [bank]);
  for (const month of ['2026-08', '2026-09', '2026-10'])
    assert.deepEqual(utilityMonthlyCost(context, 'Acqua', month, 4000, contribution), { amountCents: 7393, source: 'actual' });
  assert.deepEqual(utilityMonthlyCost(context, 'Acqua', '2026-11', 4000, contribution), { amountCents: 5000, source: 'estimate' });
  assert.deepEqual(bank, before); assert.equal(context.bills.length, 1);
  assert.equal(contribution(plan, '2026-10'), 5000, 'The fund contribution is not replaced by the cost');
  assert.equal(hasUtilityBill(context, 2), true);
});

test('ordinary bill without a fund has the same cost; edits replace the period and use current bank amount', () => {
  const command = { kind: 'ordinary', movementId: 2, utilityPeriod: period, pending: false };
  const state = { expenseRoutingCommands: { first: command } };
  let context = utilityCompetenceContext(state, [movement()]);
  assert.equal(utilityMonthlyCost(context, 'Acqua', '2026-09', 4000, contribution).amountCents, 7393);
  state.expenseRoutingCommands.first.active = false;
  state.expenseRoutingCommands.edited = { ...command, active: true,
    utilityPeriod: utilityPeriod({ competenceStartMonth: '2026-09', competenceEndMonth: '2026-10' }) };
  context = utilityCompetenceContext(state, [{ ...movement(), amount: -100 }]);
  assert.equal(utilityMonthlyCost(context, 'Acqua', '2026-08', 4000, contribution).amountCents, 4000);
  assert.equal(utilityMonthlyCost(context, 'Acqua', '2026-09', 4000, contribution).amountCents, 5000);
});

test('cent remainders are deterministic, preserve total and span year boundaries', () => {
  const p = utilityPeriod({ competenceStartMonth: '2026-12', competenceEndMonth: '2027-02' });
  assert.deepEqual(utilityShares(10000, p), [{ month: '2026-12', amountCents: 3334 },
    { month: '2027-01', amountCents: 3333 }, { month: '2027-02', amountCents: 3333 }]);
  for (let n = 1; n < 500; n++) assert.equal(utilityShares(n, p).reduce((s, q) => s + q.amountCents, 0), n);
});

test('distinct overlapping documents sum costs while a duplicate movement fails closed', () => {
  const commands = { a: { kind: 'ordinary', movementId: 2, utilityPeriod: period },
    b: { kind: 'ordinary', movementId: 3, utilityPeriod: period } };
  const context = utilityCompetenceContext({ expenseRoutingCommands: commands }, [movement(), movement(3)]);
  assert.equal(utilityMonthlyCost(context, 'Acqua', '2026-09', 4000, contribution).amountCents, 14786);
  commands.b.movementId = 2;
  assert.throws(() => utilityCompetenceContext({ expenseRoutingCommands: commands }, [movement()]));
});

test('pending saves do not masquerade as documents; deleting retains cost until the bank confirms removal', () => {
  const state = { payments: { p: { status: 'pending', movementId: 2, utilityPeriod: period } } };
  assert.equal(utilityCompetenceContext(state, [movement()]).bills.length, 0);
  state.payments.p.status = 'deleting';
  assert.equal(utilityCompetenceContext(state, [movement()]).bills.length, 1);
  assert.equal(utilityCompetenceContext(state, []).bills.length, 0);
  state.payments.p.status = 'deleted';
  assert.equal(utilityCompetenceContext(state, [movement()]).bills.length, 0);
});

test('malformed, reversed, partial and overlong periods fail; legacy missing period is never inferred', () => {
  assert.equal(utilityPeriod({ competenceMonths: 3, name: 'Ago Set Ott' }), null);
  for (const [a, b] of [['2026-13', '2026-14'], ['2026-10', '2026-08'], ['2025-08', '2026-10'], ['2026-08', undefined]])
    assert.throws(() => utilityPeriod({ competenceStartMonth: a, competenceEndMonth: b }));
  assert.throws(() => utilityShares(-1, period));
});

test('salary reference ignores unpaid November without looking into future or skipping a gap', () => {
  const credited = new Map([['2026-09', 1800], ['2026-10', 1800], ['2026-12', 1800]]);
  assert.equal(salaryReferenceMonth(credited, '2026-11'), '2026-10');
  assert.equal(salaryReferenceMonth(credited, '2026-09'), '2026-09');
  assert.equal(salaryReferenceMonth(new Map(), '2026-11'), '2026-11');
  assert.equal(salaryReferenceMonth(new Map([['2026-09', 1800]]), '2026-11'), '2026-11', 'An older unpaid gap must keep the configured fallback');
});
