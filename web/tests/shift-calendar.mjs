import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';

// Execute the production SQL against SQLite, including transactional rollback.
class D1 {
  sql = new DatabaseSync(':memory:');
  prepare(sql) {
    const statement = this.sql.prepare(sql);
    const bound = (args = []) => ({
      bind: (...values) => bound(values),
      first: async () => statement.get(...args) || null,
      all: async () => ({results:statement.all(...args)}),
      run: async () => ({meta:statement.run(...args)})
    });
    return bound();
  }
  async batch(statements) {
    this.sql.exec('BEGIN');
    try { const results=[]; for (const statement of statements) results.push(await statement.run()); this.sql.exec('COMMIT'); return results; }
    catch (error) { this.sql.exec('ROLLBACK'); throw error; }
  }
}
const folder = await mkdtemp(tmpdir() + '/lifeos-calendar-');
try {
  const source = await readFile(new URL('../dist/worker.mjs', import.meta.url),'utf8');
  await writeFile(folder+'/worker.mjs',source+'\nexport {shiftCalendarAction,lifeSchemaJobs,ensureShiftCalendar,nowDay};');
  const {default:worker,shiftCalendarAction,lifeSchemaJobs,ensureShiftCalendar,nowDay} = await import(pathToFileURL(folder+'/worker.mjs'));
  const DB = new D1(), env = {DB, ACCESS_EMAIL:'test@example.com'};
  DB.sql.exec('CREATE TABLE os_shifts(day TEXT PRIMARY KEY,kind TEXT NOT NULL); CREATE TABLE finance_secret(value TEXT); INSERT INTO finance_secret VALUES (\'never expose\');');
  lifeSchemaJobs.set(DB,Promise.resolve()); // Only existing legacy seed is outside this feature's fixture.
  const action = (method, month='2026-10') => shiftCalendarAction(env,method,{month});
  const draft = (day,kind) => DB.sql.prepare('INSERT OR REPLACE INTO os_shifts VALUES (?,?)').run(day,kind);
  const feed = async (path, method='GET') => worker.fetch(new Request('https://lifeos.test'+path,{method}),env,{});
  const rpc = async (method,args,identity='test@example.com') => worker.fetch(new Request('https://lifeos.test/api/'+method,{method:'POST',headers:{origin:'https://lifeos.test','content-type':'application/json'},body:JSON.stringify(args)}),env,{access:{getIdentity:async()=>({email:identity})}});
  assert.equal((await action('getShiftCalendar')).path,null);
  assert.equal((await rpc('publishShiftCalendar',[{month:'2026-10'}],'intruder@example.com')).status,403);
  assert.equal((await rpc('publishShiftCalendar',[{month:'bad'}])).status,400);
  const day = nowDay();
  assert.equal((await rpc('saveHealthEntry',[{day,weightKg:78.4,calories:2100}],'intruder@example.com')).status,403);
  assert.equal((await rpc('saveHealthEntry',[{day,weightKg:78.4,calories:2100}])).status,200);
  await rpc('saveHealthEntry',[{day,weightKg:78.1}]);
  await rpc('saveHealthEntry',[{day,weightKg:78.1}]);
  let health = await (await rpc('getHealthData',[])).json();
  assert.equal(health.length,1); assert.equal(health[0].weight_kg,78.1); assert.equal(health[0].calories,2100);
  await rpc('saveHealthEntry',[{day,calories:0}]);
  health = await (await rpc('getHealthData',[])).json(); assert.equal(health[0].calories,0);
  for (const input of [{day,weightKg:NaN},{day,weightKg:19},{day,calories:1.5},{day,weightKg:true},{day},{day:'2099-01-01',weightKg:70}]) {
    assert.equal((await rpc('saveHealthEntry',[input])).status,400);
  }
  for (const [day,kind] of [['2026-10-17','morning'],['2026-10-18','afternoon'],['2026-10-24','night'],['2026-10-25','holiday'],['2026-10-26','rest']]) draft(day,kind);
  const published = await (await rpc('publishShiftCalendar',[{month:'2026-10'}])).json();
  assert.match(published.path,/^\/calendar\/turni\/[a-f0-9]{64}\.ics$/);
  let response = await feed(published.path), text = await response.text();
  assert.equal(response.status,200);
  assert.match(response.headers.get('content-type'),/text\/calendar/);
  assert.equal(response.headers.get('cache-control'),'no-store');
  assert.equal(text.split('BEGIN:VEVENT').length-1,5);
  assert.match(text,/DTSTART;TZID=Europe\/Rome:20261024T220000\r\nDTEND;TZID=Europe\/Rome:20261025T060000/);
  assert.match(text,/DTSTART;VALUE=DATE:20261025\r\nDTEND;VALUE=DATE:20261026/);
  assert(!text.includes('never expose'));
  assert(!text.includes('78.1'), 'health measurements must never enter the shift feed');
  assert(!/(?<!\r)\n/.test(text));
  assert(text.split('\r\n').every(line=>Buffer.byteLength(line)<=75));
  const before = DB.sql.prepare('SELECT * FROM os_published_shifts ORDER BY day').all();
  draft('2026-10-17','night');
  DB.sql.exec("DELETE FROM os_shifts WHERE day='2026-10-18'");
  assert.equal(await (await feed(published.path)).text(),text,'drafts must stay unpublished');
  await action('publishShiftCalendar');
  text = await (await feed(published.path)).text();
  const after = DB.sql.prepare('SELECT * FROM os_published_shifts ORDER BY day').all();
  assert.equal(after[0].sequence,1); assert.equal(after[1].cancelled,1); assert.equal(after[1].sequence,1);
  assert.deepEqual(after[2],before[2],'unchanged shifts preserve revision');
  assert.match(text,/STATUS:CANCELLED/);
  const uid = text.match(/UID:[^\r]+/)[0];
  await action('publishShiftCalendar');
  assert.deepEqual(DB.sql.prepare('SELECT * FROM os_published_shifts ORDER BY day').all(),after,'retry must be idempotent');
  draft('2026-11-01','morning'); await action('publishShiftCalendar','2026-11');
  assert.equal(DB.sql.prepare('SELECT COUNT(*) n FROM os_published_shifts').get().n,6);
  const rotated = await action('rotateShiftCalendarLink');
  assert.notEqual(rotated.path,published.path);
  assert.equal((await feed(published.path)).status,404);
  assert.equal((await feed(rotated.path.replace(/[a-f0-9](?=\.ics)/,'z'))).status,403);
  const wrongToken = '/calendar/turni/'+'0'.repeat(64)+'.ics';
  assert.equal((await feed(wrongToken)).status,404);
  text = await (await feed(rotated.path)).text(); assert(text.includes(uid),'rotation must preserve event UIDs');
  assert.equal((await feed(rotated.path,'POST')).status,405);
  assert.equal(await (await feed(rotated.path,'HEAD')).text(),'');
  DB.sql.exec("DELETE FROM os_shifts WHERE substr(day,1,7)='2026-10'");
  await action('publishShiftCalendar');
  assert.equal(DB.sql.prepare("SELECT COUNT(*) n FROM os_published_shifts WHERE substr(day,1,7)='2026-10' AND cancelled=0").get().n,0);
  assert.equal(DB.sql.prepare("SELECT cancelled FROM os_published_shifts WHERE day='2026-11-01'").get().cancelled,0);
  draft('2026-10-17','morning'); await action('publishShiftCalendar');
  assert.equal(DB.sql.prepare("SELECT sequence FROM os_published_shifts WHERE day='2026-10-17'").get().sequence,3);
  // An SQL failure must roll back all snapshot changes, not partially publish the month.
  draft('2026-10-17','night');
  DB.sql.exec("CREATE TRIGGER reject_publication BEFORE UPDATE ON os_shift_publications BEGIN SELECT RAISE(ABORT,'test failure'); END;");
  await assert.rejects(()=>action('publishShiftCalendar'),/test failure/);
  assert.equal(DB.sql.prepare("SELECT kind FROM os_published_shifts WHERE day='2026-10-17'").get().kind,'morning');
  // Public reads must not create tables, seed legacy data, or leak a database error.
  const emptyEnv = {DB:new D1()};
  const unavailable = await worker.fetch(new Request('https://lifeos.test'+wrongToken),emptyEnv,{});
  assert.equal(unavailable.status,503); assert(!(await unavailable.text()).includes('SQLITE'));
  assert.equal(emptyEnv.DB.sql.prepare("SELECT COUNT(*) n FROM sqlite_master WHERE type='table'").get().n,0);
  await ensureShiftCalendar(emptyEnv); await ensureShiftCalendar(emptyEnv);
  console.log('Shift calendar: publication, auth, drafts, updates, cancellations, retries, rotation, month isolation and rollback passed.');
} finally { await rm(folder,{recursive:true,force:true}); }
