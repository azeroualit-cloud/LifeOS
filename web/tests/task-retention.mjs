import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import assert from 'node:assert/strict';

// Execute the actual Worker functions against an isolated SQLite-backed D1 adapter.
const source = readFileSync(new URL('../worker.mjs', import.meta.url), 'utf8');
const worker = await import('data:text/javascript;base64,' + Buffer.from(source + '\nexport {initializeLife,lifeAction,lifeRead};').toString('base64'));
const sqlite = new DatabaseSync(':memory:');
class Statement {
  constructor(sql, values = []) { this.sql = sql; this.values = values; }
  bind(...values) { return new Statement(this.sql, values); }
  async run() { const result = sqlite.prepare(this.sql).run(...this.values); return {meta: {changes: Number(result.changes)}}; }
  async all() { return {results: sqlite.prepare(this.sql).all(...this.values)}; }
  async first() { return sqlite.prepare(this.sql).get(...this.values) ?? null; }
}
const env = {DB: {prepare: sql => new Statement(sql), async batch(statements) {
  sqlite.exec('BEGIN');
  try { const results = []; for (const s of statements) results.push(await s.run()); sqlite.exec('COMMIT'); return results; }
  catch (error) { sqlite.exec('ROLLBACK'); throw error; }
}}};
await worker.initializeLife(env);
await worker.initializeLife(env); // Additive migration is safe to run again.
sqlite.exec("DELETE FROM os_tasks; INSERT INTO os_tasks(id,title,status,sort_order,completed_at) VALUES(1,'Pasta','done',1,'2020-01-01T00:00:00Z'),(2,'Riso','waiting',2,NULL),(3,'Kiwi','todo',3,NULL)");
let data = await worker.lifeRead(env, '2026-10');
assert(data.tasks.some(t => t.id === 1), 'Reading must retain old completed tasks');
await worker.lifeAction(env, 'setTaskStatus', [{id:2, status:'done'}]);
data = await worker.lifeRead(env, '2026-10');
assert.equal(data.tasks.find(t => t.id === 2).section_status, 'waiting');
assert(data.tasks.find(t => t.id === 2).completed_at);
await worker.lifeAction(env, 'saveTask', [{id:2,title:'Riso integrale',list_kind:'action',notes:'Riutilizzabile'}]);
data = await worker.lifeRead(env, '2026-10');
assert.equal(data.tasks.find(t => t.id === 2).section_status, 'waiting');
assert.equal(data.tasks.find(t => t.id === 2).status, 'done');
await worker.lifeAction(env, 'setTaskStatus', [{id:2,status:'waiting'}]);
data = await worker.lifeRead(env, '2026-10');
assert.equal(data.tasks.find(t => t.id === 2).completed_at, null);
assert.equal(data.tasks.find(t => t.id === 2).status, 'waiting');
await worker.lifeAction(env, 'setTaskStatus', [{id:3,status:'done'}]);
await worker.lifeAction(env, 'setTaskStatus', [{id:3,status:'done'}]);
assert.equal((await worker.lifeRead(env, '2026-10')).tasks.find(t => t.id === 3).section_status, 'todo');
await assert.rejects(worker.lifeAction(env, 'setTaskStatus', [{id:3,status:'bad'}]));
assert.equal((await worker.lifeRead(env, '2026-10')).tasks.length, 3);
// Explicit deletion is still possible, never a side effect of reading or completion.
await worker.lifeAction(env, 'deleteTask', [1]);
assert.equal((await worker.lifeRead(env, '2026-10')).tasks.length, 2);
sqlite.close();
console.log('TASK_RETENTION_OK: real Worker migrations, old completion retention, section restoration, edit preservation, validation and explicit deletion');
