// BILL-PAST-MONTHS-2026-11-24: past months never change; the excess lands on the chosen months.
import test from 'node:test';
import assert from 'node:assert/strict';
import { utilityCompetenceContext, utilityMonthlyCost, utilityPeriod } from '../competence.mjs';

const period = utilityPeriod({ competenceStartMonth: '2026-09', competenceEndMonth: '2026-11' });
const row = (date, amount = -221.79) => ({ source_row: 2, amount, actual_date: date, category: 'Acqua', account: 'Trade Republic', movement_type: 'Spesa', status: 'Eseguito' });
const quota = (p, m) => { let r = p.amountCents; for (const c of p.rateChanges || []) if (c.fromMonth <= m) r = c.amountCents; return r; };
const cost = (ctx, month) => utilityMonthlyCost(ctx, 'Acqua', month, 5000, quota).amountCents;

test('a bill without a plan, paid from today, goes on its payment month and leaves the competence months alone', () => {
  const state = { plans: {}, payments: {}, expenseRoutingCommands: { b: { kind: 'ordinary', movementId: 2, utilityPeriod: period } } };
  const ctx = utilityCompetenceContext(state, [row('2026-11-26')]);
  assert.deepEqual(['2026-09', '2026-10', '2026-11', '2026-12'].map(m => cost(ctx, m)), [5000, 5000, 22179, 5000]);
});

test('the user can spread the excess on the next months or keep part on savings', () => {
  const state = { plans: {}, payments: {}, expenseRoutingCommands: { b: { kind: 'ordinary', movementId: 2, utilityPeriod: period, billRule: 2,
    utilitySavingsCents: 2179, billBudgetMonths: ['2026-11', '2026-12'] } } };
  const ctx = utilityCompetenceContext(state, [row('2026-11-26')]);
  assert.deepEqual(['2026-10', '2026-11', '2026-12', '2027-01'].map(m => cost(ctx, m)), [5000, 10000, 10000, 5000]);
  const all = structuredClone(state); all.expenseRoutingCommands.b.utilitySavingsCents = 22179;
  assert.equal(cost(utilityCompetenceContext(all, [row('2026-11-26')]), '2026-11'), 5000, 'all on savings: the month keeps its estimate');
});

test('with a plan the month keeps its quota, the plan pays what it set aside and only the excess is added', () => {
  const plan = { id: 'w', name: 'Acqua', category: 'Acqua', kind: 'estimated', status: 'active', startMonth: '2026-09', amountCents: 6000, rateChanges: [] };
  const payment = { id: 'p', planId: 'w', status: 'posted', movementId: 2, date: '2026-11-26', amountCents: 22179, utilityPeriod: period, competenceMonths: 3 };
  const ctx = utilityCompetenceContext({ plans: { w: plan }, payments: { p: payment } }, [row('2026-11-26')]);
  // Set aside Sep–Nov: 3 × 60 = 180 €; bill 221,79 €: 41,79 € on November.
  assert.equal(ctx.bills[0].fromPlanCents, 18000);
  assert.deepEqual(['2026-09', '2026-10', '2026-11', '2026-12'].map(m => cost(ctx, m)), [6000, 6000, 6000 + 4179, 6000]);
  const stored = utilityCompetenceContext({ plans: { w: plan }, payments: { p: { ...payment, coveredCents: 20000, billBudgetMonths: ['2026-12'] } } }, [row('2026-11-26')]);
  assert.deepEqual(['2026-11', '2026-12'].map(m => cost(stored, m)), [6000, 6000 + 2179]);
});

test('a cheaper bill adds nothing: the rest stays in the plan', () => {
  const plan = { id: 'w', name: 'Acqua', category: 'Acqua', kind: 'estimated', status: 'active', startMonth: '2026-09', amountCents: 8000, rateChanges: [] };
  const payment = { id: 'p', planId: 'w', status: 'posted', movementId: 2, date: '2026-11-26', amountCents: 22179, utilityPeriod: period, competenceMonths: 3 };
  const ctx = utilityCompetenceContext({ plans: { w: plan }, payments: { p: payment } }, [row('2026-11-26')]);
  assert.deepEqual(ctx.bills[0].shares, []);
  assert.equal(cost(ctx, '2026-11'), 8000);
});

test('bills recorded before the rule keep their competence shares (past months unchanged)', () => {
  const state = { plans: {}, payments: {}, expenseRoutingCommands: { b: { kind: 'ordinary', movementId: 2, utilityPeriod: period } } };
  const ctx = utilityCompetenceContext(state, [row('2026-11-02')]);
  assert.deepEqual(['2026-09', '2026-10', '2026-11'].map(m => cost(ctx, m)), [7393, 7393, 7393]);
});
