import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { utilityCompetenceContext, utilityPeriod } from '../competence.mjs';

const folder = await mkdtemp(join(tmpdir(), 'lifeos-utility-budget-'));
const source = await readFile(process.env.LIFEOS_UTILITY_WORKER || 'manual/build-70/worker.js', 'utf8');
await writeFile(join(folder, 'worker.mjs'), source + '\nexport {monthlyBudgetAmounts, project, balance, augmentFinance, computeFinance, sheetBook};');
const core = await import(pathToFileURL(join(folder, 'worker.mjs')));
test.after(() => rm(folder, { recursive: true, force: true }));
const period = utilityPeriod({ competenceStartMonth: '2026-08', competenceEndMonth: '2026-10' });
const row = { source_row: 2, description: 'Bolletta sintetica', amount: -221.79, actual_date: '2026-11-02', category: 'Acqua', account: 'Trade Republic', movement_type: 'Spesa', status: 'Eseguito' };
const movement = [new Date('2026-11-02T12:00:00Z'), new Date('2026-11-02T12:00:00Z'), 'Bolletta sintetica', -221.79, 'Trade Republic', 'Acqua', 'Spesa', 'Eseguito', 3];
movement[19] = 2;
const state = { plans: {}, payments: {}, commands: {}, expenseRoutingCommands: { bill: { kind: 'ordinary', pending: false, movementId: 2, utilityPeriod: period } } };
function budget(month, current = state) {
  return core.monthlyBudgetAmounts({ salary: 1800, rent: 500, recurring: [{ name: 'Acqua', treatment: 'Vincolata', estimate: 50 }],
    movements: [movement], month, todayDay: '2026-11-02', extras: [],
    extraPlan: { allocations: [], links: [], budgetPolicies: [{ movement_source_row: 2, treatment: 'ordinary' }], utilityCompetence: utilityCompetenceContext(current, [row]) } });
}
test('real monthly budget replaces past estimates with actual bill shares and excludes the single cash debit', () => {
  for (const month of ['2026-08', '2026-09', '2026-10']) {
    const b = budget(month);
    assert.equal(b.monthlyCommitted, 573.93);
    assert.equal(b.monthlySpent, 0);
    assert.equal(b.monthlyRemaining, 1226.07);
  }
  const november = budget('2026-11');
  assert.equal(november.monthlyCommitted, 550);
  assert.equal(november.monthlySpent, 0);
  assert.equal(november.monthlyRemaining, 1250);
});

test('plan fund and bill cost are independent in the native overview, including months before adoption', () => {
  const current = structuredClone(state);
  delete current.expenseRoutingCommands;
  current.plans.water = { id: 'water', name: 'Acqua', category: 'Acqua', kind: 'estimated', status: 'active', startMonth: '2026-10', amountCents: 5000,
    legacy: { type: 'recurring', name: 'Acqua', fromMonth: '2026-10' } };
  current.payments.bill = { id: 'bill', planId: 'water', status: 'posted', movementId: 2, date: '2026-11-02', amountCents: 22179, utilityPeriod: period };
  for (const month of ['2026-08', '2026-09', '2026-10', '2026-11']) {
    const baseBudget = budget(month, current), view = core.project(current, month);
    if (month === '2026-10') {
      const costRow = baseBudget.monthlyBudgetBreakdown.find(r => r.name === 'Acqua');
      assert.equal(costRow.planId, 'water'); assert.equal(costRow.budgetRole, 'utilityCost');
    }
    const base = { summary: { ...baseBudget, recurringCommitments: [], budget: 1000, committedCurrent: 0 }, transactions: [] };
    const updated = core.augmentFinance(base, view, view);
    assert.equal(updated.summary.monthlyRemaining, month === '2026-11' ? 1250 : 1226.07);
    const fund = view.plans.find(p => p.id === 'water');
    assert.equal(fund.contributionCents, month < '2026-10' ? 0 : 5000);
  }
  assert.equal(core.balance(current, current.plans.water, '2026-10').fundCents, 5000);
  assert.equal(core.balance(current, current.plans.water, '2026-11').paidCents, 22179);
});

test('a utility bill funded by a continuous or fixed fund is charged once, regardless of fund kind', () => {
  for (const kind of ['fund', 'fixed', 'goal']) {
    const current = structuredClone(state); delete current.expenseRoutingCommands;
    current.plans.water = { id: 'water', name: 'Fondo acqua', category: 'Acqua', kind, status: 'active', startMonth: '2026-08', endMonth: kind === 'goal' ? '2026-12' : null, intervalMonths: 1, amountCents: 5000 };
    current.payments.bill = { id: 'bill', planId: 'water', status: 'posted', movementId: 2, date: '2026-11-02', amountCents: 22179, utilityPeriod: period };
    const b = budget('2026-10', current), view = core.project(current, '2026-10');
    const updated = core.augmentFinance({ summary: { ...b, recurringCommitments: [], budget: 1000, committedCurrent: 0 }, transactions: [] }, view, view);
    assert.equal(updated.summary.monthlyRemaining, 1226.07, kind + ' must not charge cost and fund contribution together');
  }
});

test('unpaid November retains the last complete paid salary window; a real history gap uses configured fallback', () => {
  const RealDate = globalThis.Date;
  globalThis.Date = class extends RealDate {
    constructor(...args) { super(...(args.length ? args : ['2026-11-02T12:00:00Z'])); }
    static now() { return RealDate.parse('2026-11-02T12:00:00Z'); }
  };
  try {
    const grid = Array.from({ length: 24 }, () => Array(15).fill(''));
    grid[1][14] = 0; grid[2][14] = 500;
    const config = () => grid.map((values, index) => ({ sheet: 'Budget', row_number: index + 1, values_json: JSON.stringify(values) }));
    const salaries = Array.from({ length: 12 }, (_, i) => {
      const month = new RealDate(Date.UTC(2025, 10 + i, 1)).toISOString().slice(0, 7);
      return { source_row: i + 2, budget_date: month + '-28', actual_date: month + '-28', description: 'Stipendio sintetico', amount: 1800,
        account: 'Trade Republic', category: 'Stipendio', movement_type: 'Entrata', status: 'Eseguito', budget_month: month };
    });
    for (const month of [10, 11]) {
      const result = core.computeFinance(core.sheetBook(config(), salaries, []), 2026, month, null, [], [], false, {});
      assert.equal(result.summary.monthlySalary, 1800);
      assert.equal(result.summary.monthlyRemaining, 1300);
      assert.equal(result.summary.salaryWindow.to, '2026-10');
    }
    grid[1][14] = 1400;
    const incomplete = core.computeFinance(core.sheetBook(config(), salaries.filter((_, i) => i !== 5), []), 2026, 11, null, [], [], false, {});
    assert.equal(incomplete.summary.monthlySalary, 1400); assert.equal(incomplete.summary.salaryWindow, null);
    grid[1][14] = 0;
    const realDeficit = core.computeFinance(core.sheetBook(config(), [], []), 2026, 11, null, [], [], true, {});
    assert.equal(realDeficit.summary.monthlyRemaining, -500, 'A real deficit is never hidden with a clamp');
    const stale = salaries.map(r => ({ ...r, actual_date: new RealDate(Date.UTC(Number(r.actual_date.slice(0, 4)), Number(r.actual_date.slice(5, 7)) - 3, 28)).toISOString().slice(0, 10) }));
    const staleHistory = core.computeFinance(core.sheetBook(config(), stale, []), 2026, 11, null, [], [], true, {});
    assert.equal(staleHistory.summary.monthlyRemaining, -500, 'Stale salaries must not create current spending money');
  } finally { globalThis.Date = RealDate; }
});

test('full finance response updates every past month while cashflow stays on the actual payment date', () => {
  const RealDate = globalThis.Date;
  globalThis.Date = class extends RealDate { constructor(...args) { super(...(args.length ? args : ['2026-11-02T12:00:00Z'])); } };
  try {
    const grid = Array.from({ length: 24 }, () => Array(15).fill(''));
    grid[1][14] = 1800; grid[2][14] = 500;
    grid[4][0] = 'Acqua'; grid[4][1] = 50; grid[4][2] = 'Vincolata';
    const config = grid.map((values, index) => ({ sheet: 'Budget', row_number: index + 1, values_json: JSON.stringify(values) }));
    config.push({ sheet: 'Categorie finanziarie', row_number: 1, values_json: JSON.stringify([[{ id: 10, name: 'Altro', members: [] }]]) });
    for (const paidDay of ['2026-10-31', '2026-11-02']) {
      const bankRow = { ...row, actual_date: paidDay, competence_months: 3 };
      const plan = { allocations: [], links: [], budgetPolicies: [{ movement_source_row: 2, treatment: 'ordinary' }], utilityCompetence: utilityCompetenceContext(state, [bankRow]) };
      const result = core.computeFinance(core.sheetBook(config, [bankRow], []), 2026, 11, plan, [], [], false, {});
      for (const month of ['2026-08', '2026-09', '2026-10']) {
        const value = result.yearly.find(item => item.month === month);
        assert.equal(value.monthlyRemaining, 1226.07);
        assert.equal(value.spent, month === paidDay.slice(0, 7) ? 221.79 : 0);
      }
      assert.equal(result.summary.monthlyRemaining, paidDay.startsWith('2026-11') ? 1250 : 1226.07);
      assert.equal(result.summary.monthlyBudgetBreakdown.find(r => r.name === 'Acqua').competenceSource, 'estimate');
      assert.equal(result.yearly.find(item => item.month === '2026-11').spent, paidDay.startsWith('2026-11') ? 221.79 : 0);
      assert.equal(result.transactions.length, paidDay.startsWith('2026-11') ? 1 : 0);
      if (result.transactions.length) { assert.equal(result.transactions[0].date, paidDay); assert.equal(result.transactions[0].amount, -221.79); }
      assert.equal(result.lifetime.expenses.find(r => r.name === 'Acqua').amount, 221.79);
    }
  } finally { globalThis.Date = RealDate; }
});
