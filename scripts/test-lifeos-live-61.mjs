// Exercise the actual recovered/patched Worker locally, with an isolated D1 adapter.
// No Cloudflare requests, production data, or private source are printed.
import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import assert from 'node:assert/strict';

if (!process.argv[2]) throw Error('Pass a local Worker module to test.');
const source = readFileSync(process.argv[2], 'utf8');
const worker = await import('data:text/javascript;base64,' + Buffer.from(source + '\nexport {initializeLife,lifeRead,lifeAction};').toString('base64'));
const db = new DatabaseSync(':memory:');
const statements = [];
class Statement {
  constructor(sql, values = []) { this.sql = sql; this.values = values; }
  bind(...values) { return new Statement(this.sql, values); }
  async run() { statements.push(this.sql); const result = db.prepare(this.sql).run(...this.values); return {meta: {changes: Number(result.changes)}}; }
  async all() { return {results: db.prepare(this.sql).all(...this.values)}; }
  async first() { return db.prepare(this.sql).get(...this.values) ?? null; }
}
const env = {DB: {prepare: sql => new Statement(sql), async batch(items) {
  db.exec('BEGIN');
  try { const values = []; for (const item of items) values.push(await item.run()); db.exec('COMMIT'); return values; }
  catch (error) { db.exec('ROLLBACK'); throw error; }
}}};
const read = () => worker.lifeRead(env, '2026-10');
const act = (method, value) => worker.lifeAction(env, method, [value]);

try {
  // Existing schema and old completed records must survive the additive migration.
  db.exec("CREATE TABLE os_tasks (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,list_kind TEXT NOT NULL DEFAULT 'action',status TEXT NOT NULL DEFAULT 'todo',due_date TEXT,scheduled_date TEXT,notes TEXT NOT NULL DEFAULT '',import_key TEXT UNIQUE,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,completed_at TEXT)");
  db.exec("INSERT INTO os_tasks(id,title,status,completed_at) VALUES(1,'Pasta','done','2020-01-01T00:00:00Z'),(2,'Riso','waiting',NULL),(3,'Kiwi','todo',NULL)");
  db.exec("CREATE TABLE finance_canary(id INTEGER PRIMARY KEY, value TEXT); INSERT INTO finance_canary VALUES(1,'fixture-unchanged')");
  await worker.initializeLife(env);
  await worker.initializeLife(env);
  let data = await read();
  assert(data.tasks.some(t => t.id === 1), 'Old completion must not be deleted on read');
  assert.equal(data.tasks.find(t => t.id === 2).section_status, 'waiting');
  assert.deepEqual(data.capabilities, {routineSchedules: true, taskNotificationTimes: true});
  assert.equal(db.prepare("PRAGMA table_info(os_tasks)").all().filter(x => x.name === 'scheduled_time').length, 1);

  await act('setTaskStatus', {id: 2, status: 'done'});
  const completion = (await read()).tasks.find(t => t.id === 2);
  assert.equal(completion.section_status, 'waiting');
  assert(completion.completed_at);
  await act('setTaskStatus', {id: 2, status: 'done'});
  assert.equal((await read()).tasks.find(t => t.id === 2).completed_at, completion.completed_at);
  await act('saveTask', {id: 2, title: 'Riso integrale', list_kind: 'action', notes: 'Reusable'});
  assert.equal((await read()).tasks.find(t => t.id === 2).section_status, 'waiting');
  assert.equal((await read()).tasks.find(t => t.id === 2).status, 'done');
  await act('setTaskStatus', {id: 2, status: 'waiting'});
  assert.equal((await read()).tasks.find(t => t.id === 2).completed_at, null);
  await act('setTaskStatus', {id: 2, status: 'todo'});
  await act('setTaskStatus', {id: 2, status: 'done'});
  assert.equal((await read()).tasks.find(t => t.id === 2).section_status, 'todo');
  await assert.rejects(act('setTaskStatus', {id: 3, status: 'invalid'}));

  await act('saveTask', {id: 2, title: 'Riso', list_kind: 'action', due_date: '2026-10-29', scheduled_date: '2026-10-26', scheduled_time: '16:30'});
  let task = (await read()).tasks.find(t => t.id === 2);
  assert.equal(task.scheduled_time, '16:30');
  assert.equal(task.due_date, '2026-10-29');
  assert.equal(task.scheduled_date, '2026-10-26');
  await act('saveTask', {id: 2, title: 'Riso rinominato', list_kind: 'action', scheduled_date: '2026-10-27'});
  assert.equal((await read()).tasks.find(t => t.id === 2).scheduled_time, '16:30');
  for (const value of ['25:99', '9:00', 900, false, {}]) {
    await assert.rejects(act('saveTask', {id: 2, title: 'Invalid', list_kind: 'action', scheduled_time: value}));
  }
  await act('saveTask', {id: 2, title: 'Riso', list_kind: 'action', scheduled_time: null});
  assert.equal((await read()).tasks.find(t => t.id === 2).scheduled_time, null);
  await act('saveTask', {title: 'Pane', list_kind: 'action', due_date: '2026-10-29', scheduled_time: '07:45'});
  assert.equal((await read()).tasks.find(t => t.title === 'Pane').scheduled_time, '07:45');

  // Preserve the existing schedule_json representation, including during rename.
  const schedule = {mode: 'weekdays', startDate: '2099-01-01', weekdays: [1, 5], intervalDays: 1};
  await act('saveRoutine', {title: 'Lettura', schedule});
  let routine = (await read()).routines.find(r => r.title === 'Lettura');
  assert.deepEqual(routine.schedule, schedule);
  await act('saveRoutine', {id: routine.id, title: 'Lettura rinominata'});
  assert.deepEqual((await read()).routines.find(r => r.id === routine.id).schedule, schedule);
  await assert.rejects(act('setRoutineCheck', {id: routine.id, day: (await read()).today, checked: true}));
  const storedSchedule = db.prepare('SELECT schedule_json FROM os_routines WHERE id=?').get(routine.id).schedule_json;
  await worker.initializeLife(env);
  assert.equal(db.prepare('SELECT schedule_json FROM os_routines WHERE id=?').get(routine.id).schedule_json, storedSchedule);
  assert.equal(db.prepare("SELECT COUNT(*) AS n FROM sqlite_master WHERE name='os_routine_schedules'").get().n, 0);

  // Event identity and occurrence state remain the existing event records.
  const today = (await read()).today;
  for (let n = 0; n < 5; n++) await act('saveEvent', {title: 'Fixture event ' + n, day: today});
  data = await read();
  assert.equal(data.upcomingEvents.length, 5, 'Reminders must not stop at the three-item home preview');
  const event = data.upcomingEvents[0];
  const taskCount = data.tasks.length;
  await act('setEventOccurrence', {id: event.id, day: today, status: 'done'});
  data = await read();
  assert(!data.upcomingEvents.some(e => e.id === event.id && e.day === today));
  assert.equal(data.tasks.length, taskCount, 'Events must not create duplicate tasks');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM os_events').get().n, 5);

  await act('deleteTask', 1);
  assert(!(await read()).tasks.some(t => t.id === 1));
  assert.equal(db.prepare('SELECT value FROM finance_canary WHERE id=1').get().value, 'fixture-unchanged');
  assert(!statements.some(sql => /DELETE FROM os_tasks WHERE status/.test(sql)));
  console.log('LIVE_61_SQLITE_OK: retention, additive migration, section restoration, reminder times, unchanged schedules, event identity and unrelated data');
} finally {
  db.close();
}
