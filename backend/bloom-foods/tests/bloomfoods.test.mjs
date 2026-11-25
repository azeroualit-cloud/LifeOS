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

test('app-only fields survive the round trip and site edits keep them', async () => {
  const e = env();
  await bloomFoodsAction(e, 'saveFood', [{ id: 'personal-2', name: 'Uova', family: 'egg', calories: 143, protein: 12.6, carbohydrate: 0.7, fat: 9.9, pieces: [{ name: 'Uovo', grams: 50 }], supplementUnit: null }]);
  e.sqlite.prepare("UPDATE web_foods SET name='Uova bio' WHERE id='personal-2'").run();
  const food = (await bloomFoodsAction(e, 'listFoods', [])).foods[0];
  assert.equal(food.name, 'Uova bio'); assert.deepEqual(food.app.pieces, [{ name: 'Uovo', grams: 50 }]);
  await bloomFoodsAction(e, 'saveBloomItem', [{ id: 'n4', kind: 'image', title: 'Foto', pinnedCategoryIDs: ['tag-a'], noteFiles: [{ name: 'a.jpg', type: 'public.jpeg', data: 'AAAA', lifeosFileSHA256: 'x' }] }]);
  const item = await bloomFoodsAction(e, 'getBloomItem', ['n4']);
  assert.deepEqual(item.app.pinnedCategoryIDs, ['tag-a']); assert.equal(item.app.noteFiles[0].data, undefined); assert.equal(item.kind, 'image');
  await bloomFoodsAction(e, 'deleteFood', ['personal-2']);
  assert.equal(e.sqlite.prepare('SELECT COUNT(*) n FROM web_foods_app').get().n, 0);
});

test('food diary: last change wins, deletions travel, day follows Rome time', async () => {
  const e = env();
  const base = { id: 'A1B2C3D4-0000-0000-0000-000000000001', at: '2026-11-21T23:30:00Z', name: 'Skyr', grams: 150, kcal: 95, protein: 16.5, carbs: 5.9, fat: 0.3, fibre: 0, revision: 1, modified: 1000, app: { protein: 16.5, nutrientValues: { calcium: { amount: 180 } } } };
  let r = await bloomFoodsAction(e, 'saveFoodDiaryEntry', [base]);
  assert.equal(r.saved, true); assert.equal(r.entry.day, '2026-11-22', 'after midnight in Rome'); assert.equal(r.entry.app.nutrientValues.calcium.amount, 180);
  r = await bloomFoodsAction(e, 'saveFoodDiaryEntry', [{ ...base, grams: 200, modified: 900 }]);
  assert.equal(r.saved, false, 'an older edit never overwrites'); assert.equal(r.entry.grams, 150);
  r = await bloomFoodsAction(e, 'saveFoodDiaryEntry', [{ ...base, grams: 200, kcal: 127, modified: 2000, revision: 1 }]);
  assert.equal(r.saved, true); assert.equal(r.entry.revision, 2, 'revision always grows');
  const changes = await bloomFoodsAction(e, 'listFoodDiary', [1500]);
  assert.equal(changes.entries.length, 1); assert.equal(changes.version, 1);
  const days = await bloomFoodsAction(e, 'listFoodDiaryDays', ['2026-11-22', '2026-11-22']);
  assert.equal(days.entries.length, 1);
  assert.deepEqual(await bloomFoodsAction(e, 'deleteFoodDiaryEntry', [base.id, 1500]), { deleted: false, entry: changes.entries[0] });
  assert.equal((await bloomFoodsAction(e, 'deleteFoodDiaryEntry', [base.id, 3000])).deleted, true);
  const after = await bloomFoodsAction(e, 'listFoodDiary', [2500]);
  assert.equal(after.entries[0].deleted, true, 'the deletion reaches the other side');
  assert.equal((await bloomFoodsAction(e, 'listFoodDiaryDays', ['2026-11-22', '2026-11-22'])).entries.length, 0);
  const imp = await bloomFoodsAction(e, 'importFoodDiary', [[{ ...base, id: 'B1', modified: 10 }, { ...base, id: 'B1', modified: 10 }]]);
  assert.deepEqual(imp, { saved: 2, skipped: 0 });
  assert.equal((await bloomFoodsAction(e, 'listFoodDiary', [0])).entries.filter((x) => x.id === 'B1').length, 1, 'repeatable without duplicates');
  await assert.rejects(() => bloomFoodsAction(e, 'saveFoodDiaryEntry', [{ ...base, at: 'ieri' }]), /Data del pasto/);
});

test('shared settings keep the newest copy and the alert log keeps the latest entries', async () => {
  const e = env();
  await assert.rejects(bloomFoodsAction(e, 'getSettings', ['other']));
  let r = await bloomFoodsAction(e, 'saveSettings', ['nutrition-goals', { kcal: 2400, fibre: 30 }, 2000]);
  assert.equal(r.saved, true); assert.equal(r.doc.kcal, 2400);
  r = await bloomFoodsAction(e, 'saveSettings', ['nutrition-goals', { kcal: 1800 }, 1000]);
  assert.equal(r.saved, false, 'an older copy never overwrites'); assert.equal(r.doc.kcal, 2400);
  assert.equal((await bloomFoodsAction(e, 'getSettings', ['nutrition-goals'])).modified, 2000);
  assert.equal((await bloomFoodsAction(e, 'getSettings', ['alerts'])).modified, 0);
  assert.equal((await bloomFoodsAction(e, 'getSettings', ['supplement-stacks'])).modified, 0);
  assert.equal((await bloomFoodsAction(e, 'getSettings', ['finance-categories'])).modified, 0); // CATEGORY-ADMIN-2026-11-24
  await bloomFoodsAction(e, 'addAlertLog', [[{ id: 'a1', rule: 'r1', at: '2026-11-23T08:00:00Z', title: 'Budget', body: 'Sotto 50 €' }, { id: 'a1', rule: 'r1', at: '2026-11-23T08:00:00Z' }]]);
  const log = await bloomFoodsAction(e, 'listAlertLog', [10]);
  assert.equal(log.entries.length, 1); assert.equal(log.entries[0].title, 'Budget');
});

test('food changes: only rows changed since the stamp, deletions from any worker included', async () => {
  const e = env();
  await bloomFoodsAction(e, 'importFoods', [[{ id: 'a', name: 'Skyr', calories: 63, protein: 11, carbohydrate: 4, fat: 0.2 }, { id: 'b', name: 'Avena', calories: 372, protein: 13, carbohydrate: 59, fat: 7 }]]);
  const first = await bloomFoodsAction(e, 'listFoodChanges', [null]);
  assert.equal(first.full, true); assert.equal(first.foods.length, 2);
  const quiet = await bloomFoodsAction(e, 'listFoodChanges', [first.stamp]);
  assert.equal(quiet.foods.length, 0); assert.equal(quiet.deleted.length, 0); assert.equal(quiet.stamp, first.stamp);
  await new Promise((r) => setTimeout(r, 5));
  e.sqlite.prepare("DELETE FROM web_foods WHERE id = 'b'").run(); // as the site Worker does
  await bloomFoodsAction(e, 'saveFood', [{ id: 'c', name: 'Riso', calories: 351, protein: 7, carbohydrate: 78, fat: 0.6, pieces: [{ name: 'tazza', grams: 90 }] }]);
  const delta = await bloomFoodsAction(e, 'listFoodChanges', [quiet.stamp]);
  assert.deepEqual(delta.deleted, ['b']); assert.deepEqual(delta.foods.map((f) => f.id), ['c']);
  assert.equal(delta.foods[0].app.pieces[0].name, 'tazza');
  assert.ok(delta.stamp > quiet.stamp);
  const after = await bloomFoodsAction(e, 'listFoodChanges', [delta.stamp]);
  assert.equal(after.foods.length + after.deleted.length, 0);
});

test('app-layout setting is accepted by the app gateway', async () => {
  const e = env();
  const r = await bloomFoodsAction(e, 'saveSettings', ['app-layout', { tabSlot: 'bloom' }, Date.now()]);
  assert.equal(r.doc.tabSlot, 'bloom');
});
