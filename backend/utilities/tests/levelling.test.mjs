import test from 'node:test';
import assert from 'node:assert/strict';
import { lifeosLevelEstimate95, wrapLevelling } from '../levelling.mjs';

const plan = (extra = {}) => ({ id: 'p', kind: 'estimated', status: 'active', startMonth: '2026-10', amountCents: 4365, rateChanges: [], ...extra });
const pay = (id, amountCents, date, extra = {}) => ({ id, planId: 'p', status: 'posted', amountCents, date, cycleMonth: date.slice(0, 7), competenceMonths: 1, ...extra });
const rateAt = (p, m) => { let r = p.amountCents; for (const c of p.rateChanges) if (c.fromMonth <= m) r = c.amountCents; return r; };

test('a bill higher than the set-aside quota raises the next three months, then the average returns', () => {
  const p = plan({ rateChanges: [{ fromMonth: '2026-11', amountCents: 4957 }, { fromMonth: '2026-12', amountCents: 6749 }] });
  const state = { plans: { p }, payments: {
    a: pay('a', 4957, '2026-10-13'),                                                        // covers September: before the plan
    b: pay('b', 8540, '2026-11-14', { utilityPeriod: { start: '2026-10', end: '2026-10', count: 1 } }) } };
  const out = lifeosLevelEstimate95(state, p, '2026-11-24');
  assert.equal(out.averageCents, 6749);
  assert.equal(out.gapCents, 4365 - 8540);
  assert.equal(out.quotaCents, 6749 + 1392);
  assert.deepEqual(['2026-12', '2027-01', '2027-02', '2027-03'].map(m => rateAt(p, m)), [8141, 8141, 8141, 6749]);
  assert.equal(out.untilMonth, '2027-02');
});

test('a smaller bill lowers the quota and a surplus never makes it negative', () => {
  const p = plan({ amountCents: 3000 });
  const state = { plans: { p }, payments: { b: pay('b', 2436, '2026-11-19', { utilityPeriod: { start: '2026-10', end: '2026-10', count: 1 } }) } };
  assert.equal(lifeosLevelEstimate95(state, p, '2026-11-24').quotaCents, 2436 - 188);
  const q = plan({ amountCents: 50000 });
  const big = { plans: { p: q }, payments: { b: pay('b', 1000, '2026-11-19', { utilityPeriod: { start: '2026-10', end: '2026-10', count: 1 } }) } };
  assert.equal(lifeosLevelEstimate95(big, q, '2026-11-24').quotaCents, 0);
});

test('a quarterly bill spreads the gap over its own length and uses what the budget carried', () => {
  const p = plan({ amountCents: 5000, budgetEstimates: { '2026-11': 4000 } });
  const state = { plans: { p }, payments: { b: pay('b', 18000, '2027-01-10', { competenceMonths: 3, utilityPeriod: { start: '2026-10', end: '2026-12', count: 3 } }) } };
  const out = lifeosLevelEstimate95(state, p, '2027-01-12');
  assert.equal(out.gapCents, 5000 + 4000 + 5000 - 18000);
  assert.equal(out.averageCents, 6000);
  assert.equal(out.quotaCents, 6000 + 1333);
  assert.equal(rateAt(p, '2027-05'), 6000);
});

test('levelling is idempotent and keeps a manual future change', () => {
  const p = plan({ rateChanges: [{ fromMonth: '2027-06', amountCents: 9999 }] });
  const state = { plans: { p }, payments: { b: pay('b', 8540, '2026-11-14', { utilityPeriod: { start: '2026-10', end: '2026-10', count: 1 } }) } };
  lifeosLevelEstimate95(state, p, '2026-11-24');
  const once = JSON.stringify(p.rateChanges);
  lifeosLevelEstimate95(state, p, '2026-11-24');
  assert.equal(JSON.stringify(p.rateChanges), once);
  assert.equal(rateAt(p, '2027-06'), 9999);
});

test('bills before the plan start and plans of other kinds are not levelled', () => {
  const p = plan({ amountCents: 2000 });
  const state = { plans: { p }, payments: { b: pay('b', 22179, '2026-10-28', { competenceMonths: 3, utilityPeriod: { start: '2026-07', end: '2026-09', count: 3 } }) } };
  const out = lifeosLevelEstimate95(state, p, '2026-11-24');
  assert.equal(out.gapCents, 0);
  assert.equal(out.quotaCents, 7393);
  const fixed = plan({ kind: 'fixed' });
  assert.equal(lifeosLevelEstimate95({ plans: { p: fixed }, payments: state.payments }, fixed, '2026-11-24'), null);
});

test('the wrappers run the original behaviour first', () => {
  const p = plan();
  const base = { plans: { p }, payments: { b: { ...pay('b', 8540, '2026-11-14', { utilityPeriod: { start: '2026-10', end: '2026-10', count: 1 } }), status: 'pending' } } };
  const calls = [];
  const w = wrapLevelling({
    completePaymentBase(state, id) { calls.push('pay'); const n = structuredClone(state); n.payments[id].status = 'posted'; n.plans.p.rateChanges.push({ fromMonth: '2026-12', amountCents: 8540 }); return n; },
    completePaymentDeletionBase(state) { return structuredClone(state); },
    refreshUtilityEstimateBase() { calls.push('refresh'); }
  });
  const next = w.completePayment(base, 'b', 7, '2026-11-24');
  assert.deepEqual(calls, ['pay']);
  assert.equal(rateAt(next.plans.p, '2026-12'), 8540 + 1392);
  assert.equal(next.plans.p.rateChanges.filter(c => c.fromMonth === '2026-12').length, 1);
});
