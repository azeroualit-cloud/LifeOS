import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { bloomFoodsAction, resetBloomFoodsForTests } from '../bloomfoods.mjs';

function env() {
  resetBloomFoodsForTests();
  const sqlite = new DatabaseSync(':memory:');
  const stmt = (sql) => { let p = []; return {
    bind(...v) { p = v; return this; },
    async first() { return sqlite.prepare(sql).get(...p) ?? null; },
    async all() { return { results: sqlite.prepare(sql).all(...p) }; },
    async run() { return sqlite.prepare(sql).run(...p); },
  }; };
  return { sqlite, DB: { prepare: stmt, async batch(list) { sqlite.exec('BEGIN'); try { const r = []; for (const s of list) r.push(await s.run()); sqlite.exec('COMMIT'); return r; } catch (e) { sqlite.exec('ROLLBACK'); throw e; } } } };
}

test('unknown methods are left to the existing worker', async () => {
  assert.equal(await bloomFoodsAction(env(), 'getFinanceData', []), undefined);
  assert.equal(await bloomFoodsAction(env(), 'constructor', []), undefined);
});

test('app food list round-trips through the shared table', async () => {
  const e = env();
  const r = await bloomFoodsAction(e, 'importFoods', [[{ id: 'personal-1', name: 'Skyr', brand: 'Milbona', family: 'dairy', measurementBasis: 'g', calories: 63, protein: 11, carbohydrate: 3.9, fat: 0.2, fibre: 0, nutrientValues: { calcium: { amount: 120 } } }]]);
  assert.equal(r.imported, 1);
  const { foods } = await bloomFoodsAction(e, 'listFoods', []);
  assert.equal(foods[0].name, 'Skyr'); assert.equal(foods[0].protein, 11); assert.equal(foods[0].micro.calcium, 120);
  await bloomFoodsAction(e, 'importFoods', [[{ id: 'personal-1', name: 'Skyr', calories: 64, protein: 11, carbohydrate: 4, fat: 0.2 }]]);
  assert.equal((await bloomFoodsAction(e, 'listFoods', [])).foods.length, 1, 'the one-time transfer can be repeated without duplicates');
});

test('Bloom import converts Apple reference dates and never overwrites newer site edits', async () => {
  const e = env();
  const apple = 785000000; // 2025 in Apple reference seconds
  await bloomFoodsAction(e, 'importBloom', [{ collections: [{ id: 'tag-a', name: 'Ristoranti' }], items: [{ id: 'n1', title: 'Ramen', urlString: 'https://example.com', tagIDs: ['tag-a'], modifiedAt: apple, trashedAt: apple }] }]);
  let item = await bloomFoodsAction(e, 'getBloomItem', ['n1']);
  assert.equal(item.modifiedAt, apple + 978307200); assert.equal(item.trashedAt, apple + 978307200);
  const again = await bloomFoodsAction(e, 'importBloom', [{ items: [{ id: 'n1', title: 'Vecchio', modifiedAt: apple - 10 }] }]);
  assert.equal(again.skipped, 1);
  assert.equal((await bloomFoodsAction(e, 'getBloomItem', ['n1'])).title, 'Ramen');
});

test('existing rows with Apple trashedAt are repaired once', async () => {
  const e = env();
  await bloomFoodsAction(e, 'getBloom', []);
  e.sqlite.prepare("INSERT INTO web_bloom_items(id,trashed_at,modified_at) VALUES ('old',785000000,1700000000)").run();
  resetBloomFoodsForTests();
  await bloomFoodsAction(e, 'getBloom', []);
  resetBloomFoodsForTests();
  const { items } = await bloomFoodsAction(e, 'getBloom', []);
  assert.equal(items.find((i) => i.id === 'old').trashedAt, 785000000 + 978307200);
});

test('save with a stale expectModifiedAt reports a conflict instead of overwriting', async () => {
  const e = env();
  const saved = await bloomFoodsAction(e, 'saveBloomItem', [{ id: 'n2', title: 'Dal sito' }]);
  e.sqlite.prepare('UPDATE web_bloom_items SET modified_at=? WHERE id=?').run(saved.modifiedAt + 100, 'n2');
  const r = await bloomFoodsAction(e, 'saveBloomItem', [{ id: 'n2', title: "Dall'app", expectModifiedAt: saved.modifiedAt }]);
  assert.equal(r.conflict, true); assert.equal(r.current.title, 'Dal sito');
  const ok = await bloomFoodsAction(e, 'saveBloomItem', [{ id: 'n2', title: "Dall'app", expectModifiedAt: saved.modifiedAt + 100 }]);
  assert.ok(!ok.conflict); assert.equal((await bloomFoodsAction(e, 'getBloomItem', ['n2'])).title, "Dall'app");
});

test('trash and delete only remove trashed notes', async () => {
  const e = env();
  await bloomFoodsAction(e, 'saveBloomItem', [{ id: 'n3', title: 'x' }]);
  await bloomFoodsAction(e, 'deleteBloomItem', ['n3']);
  assert.ok(await bloomFoodsAction(e, 'getBloomItem', ['n3']));
  await bloomFoodsAction(e, 'trashBloomItem', ['n3']);
  await bloomFoodsAction(e, 'deleteBloomItem', ['n3']);
  await assert.rejects(bloomFoodsAction(e, 'getBloomItem', ['n3']));
});
