import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('../../../manual/build-70/worker.js',import.meta.url),'utf8');
const core=await import('data:text/javascript;base64,'+Buffer.from(source+'\nexport {ensureMovementCreation,sortMovementCreation,recordToMovement};').toString('base64'));
function fixture() {
 const sql=new DatabaseSync(':memory:');sql.exec('CREATE TABLE movements(source_row INTEGER PRIMARY KEY,actual_date TEXT,description TEXT,amount REAL)');
 const db={prepare(text){let args=[];return {bind(...values){args=values;return this},async all(){return {results:sql.prepare(text).all(...args)}},async run(){return {meta:{changes:sql.prepare(text).run(...args).changes}}}}},async batch(items){sql.exec('BEGIN');try{const result=[];for(const item of items)result.push(await item.run());sql.exec('COMMIT');return result}catch(e){sql.exec('ROLLBACK');throw e}}};
 return {sql,db};
}
test('historical movements keep unknown creation time, order by append id',async()=>{
 const {sql,db}=fixture();sql.exec("INSERT INTO movements VALUES(7,'2026-10-30','Old',-1),(8,'2026-09-01','Backdated',-2)");
 await core.ensureMovementCreation(db);
 const rows=sql.prepare('SELECT source_row row,created_at FROM movements').all();
 assert.ok(rows.every(r=>r.created_at===null));assert.deepEqual(core.sortMovementCreation(rows).map(r=>r.row),[8,7]);
});
test('new backdated entries have real immutable UTC timestamps and sort first',async()=>{
 const {sql,db}=fixture();sql.exec("INSERT INTO movements VALUES(7,'2026-10-30','Old',-1)");await core.ensureMovementCreation(db);
 sql.prepare('INSERT INTO movements(source_row,actual_date,description,amount) VALUES(?,?,?,?)').run(8,'2026-09-01','New',-2);
 const before=sql.prepare('SELECT * FROM movements WHERE source_row=8').get();assert.match(before.created_at,/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
 sql.prepare('UPDATE movements SET actual_date=?,amount=? WHERE source_row=8').run('2026-08-01',-10);
 assert.equal(sql.prepare('SELECT created_at FROM movements WHERE source_row=8').get().created_at,before.created_at);
 assert.throws(()=>sql.exec("UPDATE movements SET created_at='2000-01-01' WHERE source_row=8"),/immutable/);
 assert.deepEqual(core.sortMovementCreation(sql.prepare('SELECT source_row row,created_at FROM movements').all()).map(r=>r.row),[8,7]);
});
test('timestamp ties retain deterministic append order and deletion/reinsertion stamps anew',async()=>{
 const {sql,db}=fixture();await core.ensureMovementCreation(db);
 sql.exec("INSERT INTO movements(source_row,created_at) VALUES(1,'2026-10-01T10:00:00.000Z'),(2,'2026-10-01T10:00:00.000Z')");
 assert.deepEqual(core.sortMovementCreation(sql.prepare('SELECT source_row row,created_at FROM movements').all()).map(r=>r.row),[2,1]);
 sql.exec('DELETE FROM movements WHERE source_row=2');sql.exec('INSERT INTO movements(source_row) VALUES(2)');
 assert.notEqual(sql.prepare('SELECT created_at FROM movements WHERE source_row=2').get().created_at,'2026-10-01T10:00:00.000Z');
});
test('migration is idempotent and concurrent callers preserve amounts and dates',async()=>{
 const {sql,db}=fixture();sql.exec("INSERT INTO movements VALUES(1,'2026-10-30','Preserve',-125.50)");
 await Promise.all([core.ensureMovementCreation(db),core.ensureMovementCreation(db)]);await core.ensureMovementCreation(db);
 assert.deepEqual({...sql.prepare('SELECT * FROM movements').get()},{source_row:1,actual_date:'2026-10-30',description:'Preserve',amount:-125.5,created_at:null});
 assert.equal(sql.prepare("SELECT COUNT(*) n FROM sqlite_master WHERE type='trigger'").get().n,2);
});
test('Worker projection preserves financial-category indexes and appends creation field',()=>{
 const row=core.recordToMovement({source_row:8,created_at:'2026-10-30T10:00:00.000Z',resolved_category:'Acqua',financial_category_id:3});
 assert.equal(row[19],8);assert.equal(row[21],'Acqua');assert.equal(row[22],3);assert.equal(row[23],'2026-10-30T10:00:00.000Z');
});
