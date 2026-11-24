// BILL-PAST-MONTHS-2026-11-24: the estimated quota follows the 12-month average, with no hidden recovery.
import test from 'node:test';
import assert from 'node:assert/strict';
import { lifeosLevelEstimate95, wrapLevelling } from '../levelling.mjs';

const plan = (extra = {}) => ({ id: 'p', kind: 'estimated', status: 'active', startMonth: '2026-10', amountCents: 4365, rateChanges: [], ...extra });
const pay = (id, amountCents, date, extra = {}) => ({ id, planId: 'p', status: 'posted', amountCents, date, cycleMonth: date.slice(0, 7), competenceMonths: 1, ...extra });
const rateAt = (p, m) => { let r = p.amountCents; for (const c of p.rateChanges) if (c.fromMonth <= m) r = c.amountCents; return r; };

test('after a bill the quota from next month is the average of the bills over their months', () => {
  const p = plan({ rateChanges: [{ fromMonth: '2026-11', amountCents: 4957 }] });
  const state = { plans: { p }, payments: { a: pay('a', 4957, '2026-10-13'), b: pay('b', 8540, '2026-11-14', { utilityPeriod: { start: '2026-10', end: '2026-10', count: 1 } }) } };
  const out = lifeosLevelEstimate95(state, p, '2026-11-24');
  assert.equal(out.averageCents, 6749);
  assert.equal(out.quotaCents, 6749);
  assert.deepEqual(['2026-11', '2026-12', '2027-03'].map(m => rateAt(p, m)), [4957, 6749, 6749]);
});

test('a quarterly bill counts over its three months', () => {
  const p = plan({ amountCents: 2000 });
  const state = { plans: { p }, payments: { b: pay('b', 22179, '2026-10-28', { competenceMonths: 3, utilityPeriod: { start: '2026-07', end: '2026-09', count: 3 } }) } };
  assert.equal(lifeosLevelEstimate95(state, p, '2026-11-24').quotaCents, 7393);
});

test('the current month is aligned with what its budget carries (Acqua, November)', () => {
  const p = plan({ amountCents: 2000, budgetEstimates: { '2026-11': 7393 }, rateChanges: [{ fromMonth: '2026-11', amountCents: 22179 }, { fromMonth: '2026-12', amountCents: 7393 }] });
  const state = { plans: { p }, payments: { b: pay('b', 22179, '2026-10-28', { competenceMonths: 3, utilityPeriod: { start: '2026-07', end: '2026-09', count: 3 } }) } };
  lifeosLevelEstimate95(state, p, '2026-11-24');
  assert.deepEqual(['2026-10', '2026-11', '2026-12'].map(m => rateAt(p, m)), [2000, 7393, 7393]);
});

test('levelling is idempotent, removes older recovery steps and keeps a manual future change', () => {
  const p = plan({ rateChanges: [{ fromMonth: '2027-02', amountCents: 9000, levelled: true }, { fromMonth: '2027-06', amountCents: 9999 }] });
  const state = { plans: { p }, payments: { b: pay('b', 8540, '2026-11-14') } };
  lifeosLevelEstimate95(state, p, '2026-11-24');
  const once = JSON.stringify(p.rateChanges);
  lifeosLevelEstimate95(state, p, '2026-11-24');
  assert.equal(JSON.stringify(p.rateChanges), once);
  assert.deepEqual(['2027-02', '2027-06'].map(m => rateAt(p, m)), [8540, 9999]);
});

test('plans of other kinds are not levelled', () => {
  const fixed = plan({ kind: 'fixed' });
  assert.equal(lifeosLevelEstimate95({ plans: { p: fixed }, payments: { b: pay('b', 100, '2026-11-14') } }, fixed, '2026-11-24'), null);
});

test('the wrappers run the original behaviour first', () => {
  const p = plan();
  const base = { plans: { p }, payments: { b: { ...pay('b', 8540, '2026-11-14'), status: 'pending' } } };
  const calls = [];
  const w = wrapLevelling({
    completePaymentBase(state, id) { calls.push('pay'); const n = structuredClone(state); n.payments[id].status = 'posted'; n.plans.p.rateChanges.push({ fromMonth: '2026-12', amountCents: 1 }); return n; },
    completePaymentDeletionBase(state) { return structuredClone(state); },
    refreshUtilityEstimateBase() { calls.push('refresh'); }
  });
  const next = w.completePayment(base, 'b', 7, '2026-11-24');
  assert.deepEqual(calls, ['pay']);
  assert.equal(rateAt(next.plans.p, '2026-12'), 8540);
  assert.equal(next.plans.p.rateChanges.filter(c => c.fromMonth === '2026-12').length, 1);
});
