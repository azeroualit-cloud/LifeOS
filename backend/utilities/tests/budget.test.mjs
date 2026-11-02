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
const row = { source_row: 2, amount: -221.79, actual_date: '2026-11-02', category: 'Acqua', account: 'Trade Republic', movement_type: 'Spesa', status: 'Eseguito' };
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
    const base = { summary: { ...baseBudget, recurringCommitments: [], budget: 1000, committedCurrent: 0 }, transactions: [] };
    const updated = core.augmentFinance(base, view, view);
    assert.equal(updated.summary.monthlyRemaining, month === '2026-11' ? 1250 : 1226.07);
    const fund = view.plans.find(p => p.id === 'water');
    assert.equal(fund.contributionCents, month < '2026-10' ? 0 : 5000);
  }
  assert.equal(core.balance(current, current.plans.water, '2026-10').fundCents, 5000);
  assert.equal(core.balance(current, current.plans.water, '2026-11').paidCents, 22179);
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
  } finally { globalThis.Date = RealDate; }
});
