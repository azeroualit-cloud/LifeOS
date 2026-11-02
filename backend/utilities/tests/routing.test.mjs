import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { utilityCompetenceContext } from '../competence.mjs';

const dir = await mkdtemp(join(tmpdir(), 'utility-routing-'));
const source = await readFile('manual/build-75/worker.js', 'utf8');
await writeFile(join(dir, 'worker.mjs'), source + '\nexport {expenseRouting,D1PlanRepository,PlanService,initialState,balance,withFinancePlans};');
const core = await import(pathToFileURL(join(dir, 'worker.mjs')));
test.after(() => rm(dir, { recursive: true, force: true }));
async function fixture() {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(`CREATE TABLE movements(source_row INTEGER PRIMARY KEY,amount REAL,actual_date TEXT,category TEXT,account TEXT,movement_type TEXT,status TEXT,description TEXT,notes TEXT,import_id TEXT);
    CREATE TABLE movement_budget_policies(movement_source_row INTEGER PRIMARY KEY,treatment TEXT,recovery_json TEXT);
    CREATE TABLE extraordinary_movement_links(movement_source_row INTEGER,cycle_id INTEGER);
    CREATE TABLE finance_write_requests(id TEXT PRIMARY KEY,fingerprint TEXT);`);
  const db = { prepare(sql) { let args = []; return {
    bind(...values) { args = values; return this; }, async first() { return sqlite.prepare(sql).get(...args) ?? null; },
    async all() { return { results: sqlite.prepare(sql).all(...args) }; }, async run() { return { meta: { changes: Number(sqlite.prepare(sql).run(...args).changes) } }; }
  }; }, async batch(statements) { sqlite.exec('BEGIN'); try { const result = []; for (const s of statements) result.push(await s.run()); sqlite.exec('COMMIT'); return result; } catch (e) { sqlite.exec('ROLLBACK'); throw e; } } };
  const repository = new core.D1PlanRepository(db); await repository.initialize();
  const state = core.initialState();
  state.plans.water = { id: 'water', name: 'Acqua', category: 'Acqua', kind: 'estimated', status: 'active', startMonth: '2026-10', amountCents: 5000, rateChanges: [] };
  await repository.compareAndSet(0, state);
  let failAfterCash = false;
  const recordTransaction = async (_, input) => {
    const old = sqlite.prepare('SELECT source_row FROM movements WHERE import_id=?').get('APP-' + input.requestId);
    if (old) return true;
    const id = 2 + sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n;
    sqlite.prepare('INSERT INTO movements VALUES(?,?,?,?,?,?,?,?,?,?)').run(id, -input.amount, input.date, input.category, 'Trade Republic', 'Spesa', 'Eseguito', input.name, input.note || '', 'APP-' + input.requestId);
    sqlite.prepare('INSERT INTO movement_budget_policies VALUES(?,?,?)').run(id, input.budgetTreatment, '[]');
    sqlite.prepare('INSERT INTO finance_write_requests VALUES(?,?)').run(input.requestId, 'synthetic');
    if (failAfterCash) { failAfterCash = false; throw Error('Response lost after bank commit'); }
    return true;
  };
  const cash = { async record(p) { await recordTransaction({}, { requestId: p.requestId, amount: p.amountCents / 100, date: p.date, category: p.category, name: p.name, budgetTreatment: 'savings' }); return sqlite.prepare('SELECT source_row FROM movements WHERE import_id=?').get('APP-' + p.requestId).source_row; } };
  const service = new core.PlanService(repository, cash, '2026-11-02');
  const ctx = { repository, service, db, today: '2026-11-02', recordTransaction, env: {} };
  const payload = { requestId: 'utility-original-0001', utilityCompetenceVersion: 1, expenseRoutingVersion: 1,
    expenseDestination: 'ordinary', type: 'Spesa', account: 'Trade Republic', category: 'Acqua', amount: 221.79, name: 'Bolletta sintetica',
    date: '2026-11-02', competenceStartMonth: '2026-08', competenceEndMonth: '2026-10' };
  const rows = () => sqlite.prepare('SELECT * FROM movements').all();
  return { ctx, payload, sqlite, rows, fail() { failAfterCash = true; } };
}

test('ordinary bill retry and period edit keep one cash row; old replay cannot restore old allocation', async () => {
  const { ctx, payload, rows } = await fixture();
  await core.expenseRouting.save({ ...ctx, input: payload }); await core.expenseRouting.save({ ...ctx, input: payload });
  assert.equal(rows().length, 1); const original = structuredClone(rows()[0]);
  const edit = { requestId: 'utility-edit-0001', movementId: original.source_row, expectedAmountCents: 22179, expectedDate: original.actual_date,
    expectedCategory: 'Acqua', expectedPaymentId: '', expenseDestination: 'ordinary', competenceStartMonth: '2026-09', competenceEndMonth: '2026-10' };
  await core.expenseRouting.change({ ...ctx, input: edit }); await core.expenseRouting.change({ ...ctx, input: edit });
  await core.expenseRouting.save({ ...ctx, input: payload });
  const { state } = await ctx.repository.read(), context = utilityCompetenceContext(state, rows());
  assert.equal(context.bills.length, 1); assert.equal(context.bills[0].period.start, '2026-09');
  assert.deepEqual({ ...rows()[0] }, original);
  assert.equal((await core.expenseRouting.status({ ...ctx, input: payload })).complete, true);
});

test('cash-confirmed pending bill is recoverable after restart without transient double cost or another debit', async () => {
  const { ctx, payload, rows, fail } = await fixture(); fail();
  await assert.rejects(core.expenseRouting.save({ ...ctx, input: payload }), /Response lost/);
  assert.equal((await core.expenseRouting.status({ ...ctx, input: payload })).complete, false);
  const pending = await ctx.repository.read();
  assert.equal(utilityCompetenceContext(pending.state, rows()).bills.length, 1);
  const restarted = new core.D1PlanRepository(ctx.db); await restarted.initialize();
  await core.expenseRouting.save({ ...ctx, repository: restarted, input: payload });
  assert.equal(rows().length, 1); assert.equal((await core.expenseRouting.status({ ...ctx, input: payload })).complete, true);
});

test('plan payment uses actual November cash and October/November fund contributions; a second document is allowed', async () => {
  const { ctx, payload, rows } = await fixture();
  const input = { ...payload, expenseDestination: 'plan', planId: 'water', expectedAvailableCents: 10000 };
  await core.expenseRouting.save({ ...ctx, input }); await core.expenseRouting.save({ ...ctx, input });
  const { state } = await ctx.repository.read();
  assert.equal(state.payments[input.requestId].utilityPeriod.start, '2026-08');
  assert.equal(core.balance(state, state.plans.water, '2026-10').fundCents, 5000);
  assert.equal(core.balance(state, state.plans.water, '2026-11').paidCents, 22179);
  await core.expenseRouting.save({ ...ctx, input: { ...input, requestId: 'utility-second-0001', expectedAvailableCents: 0, amount: 30 } });
  assert.equal(rows().length, 2);
});

test('period update and policy share the same rollback; malformed period writes nothing', async () => {
  const { ctx, payload, rows, sqlite } = await fixture();
  await assert.rejects(core.expenseRouting.save({ ...ctx, input: { ...payload, competenceEndMonth: '2026-07' } }));
  assert.equal(rows().length, 0);
  await core.expenseRouting.save({ ...ctx, input: payload }); const before = await ctx.repository.read();
  sqlite.exec("CREATE TRIGGER fail_policy BEFORE UPDATE ON movement_budget_policies BEGIN SELECT RAISE(ABORT,'injected policy failure'); END");
  await assert.rejects(core.expenseRouting.change({ ...ctx, input: { requestId: 'utility-rollback-0001', movementId: 2, expectedAmountCents: 22179,
    expectedDate: '2026-11-02', expectedCategory: 'Acqua', expectedPaymentId: '', expenseDestination: 'ordinary', competenceStartMonth: '2026-09', competenceEndMonth: '2026-10' } }), /injected policy/);
  assert.deepEqual(await ctx.repository.read(), before); assert.equal(rows().length, 1);
});

test('dedicated bill endpoints preserve POST, origin and authentication checks', async () => {
  const worker = core.withFinancePlans({ async fetch() { return new Response('{}', { status: 401, headers: { 'Content-Type': 'application/json' } }); } });
  for (const method of ['saveUtilityBill', 'changeUtilityBill', 'recordUtilityPlanPayment']) {
    const url = 'https://example.test/api/' + method;
    assert.equal((await worker.fetch(new Request(url), {}, {})).status, 405);
    assert.equal((await worker.fetch(new Request(url, { method: 'POST', headers: { Origin: 'https://wrong.test' }, body: '[]' }), {}, {})).status, 403);
    assert.equal((await worker.fetch(new Request(url, { method: 'POST', headers: { Origin: 'https://example.test' }, body: '[]' }), {}, {})).status, 401);
  }
});

test('editing competence on a stopped fund preserves payment identity, fund status and bank row', async () => {
  const { ctx, payload, rows } = await fixture();
  const input = { ...payload, expenseDestination: 'plan', planId: 'water', expectedAvailableCents: 10000 };
  await core.expenseRouting.save({ ...ctx, input });
  await ctx.service.change(state => { const next = structuredClone(state); next.plans.water.status = 'stopped'; next.plans.water.stopAfter = '2026-11'; return { state: next, result: {} }; });
  const before = { ...rows()[0] };
  const edit = { requestId: 'utility-stopped-edit', movementId: 2, expenseDestination: 'plan', planId: 'water', expectedPaymentId: input.requestId,
    expectedAmountCents: 22179, expectedDate: '2026-11-02', expectedCategory: 'Acqua', competenceStartMonth: '2026-09', competenceEndMonth: '2026-10',
    expectedCompetenceStartMonth: '2026-08', expectedCompetenceEndMonth: '2026-10' };
  await core.expenseRouting.change({ ...ctx, input: edit });
  const { state } = await ctx.repository.read();
  assert.equal(state.payments[input.requestId].utilityPeriod.start, '2026-09');
  assert.equal(state.plans.water.status, 'stopped'); assert.equal(Object.values(state.payments).filter(p => p.status === 'posted').length, 1);
  assert.deepEqual({ ...rows()[0] }, before);
  await assert.rejects(core.expenseRouting.change({ ...ctx, input: { ...edit, requestId: 'utility-stale-edit', competenceStartMonth: '2026-07' } }), /periodo.*cambiato/i);
});
