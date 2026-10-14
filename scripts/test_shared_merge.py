import importlib.util
from pathlib import Path
import sqlite3
import unittest
spec=importlib.util.spec_from_file_location('merge',Path(__file__).with_name('shared-merge.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


class MergeTests(unittest.TestCase):
    def db(self):
        db=sqlite3.connect(':memory:');db.row_factory=sqlite3.Row
        db.executescript("CREATE TABLE os_tasks(id INTEGER PRIMARY KEY,title TEXT,created_at TEXT,updated_at TEXT); CREATE TABLE finance_write_requests(id TEXT PRIMARY KEY,fingerprint TEXT);")
        self.addCleanup(db.close);return db
    def apply(self,db,sql):
        try: db.executescript('BEGIN;'+sql+'COMMIT;')
        except Exception: db.rollback();raise
    def test_local_additions_and_deletion_preserve_new_web_data(self):
        a,b=self.db(),self.db()
        a.executescript("INSERT INTO os_tasks VALUES(1,'old','2026-09-01','2026-09-01'); INSERT INTO os_tasks VALUES(2,'new web','2026-10-14T10:00:00Z','2026-10-14T10:00:00Z');")
        b.execute("INSERT INTO finance_write_requests VALUES('stable-id','original fingerprint')");b.commit()
        sql,counts=m.plan_merge(a,b,'2026-10-14T09:00:00Z');self.apply(a,sql)
        self.assertEqual(a.execute('SELECT id FROM os_tasks').fetchall()[0][0],2)
        self.assertEqual(a.execute('SELECT COUNT(*) FROM finance_write_requests').fetchone()[0],1)
        self.assertEqual(counts['deleted'],1)
        self.apply(a,sql)
        self.assertEqual(a.execute('SELECT COUNT(*) FROM finance_write_requests').fetchone()[0],1)
    def test_racing_web_update_aborts_without_losing_data(self):
        a,b=self.db(),self.db()
        a.execute("INSERT INTO os_tasks VALUES(1,'old','2026-09-01','2026-09-01')");a.commit()
        sql,_=m.plan_merge(a,b,'2026-10-14T09:00:00Z')
        a.execute("UPDATE os_tasks SET title='concurrent web change'");a.commit()
        with self.assertRaises(sqlite3.IntegrityError):self.apply(a,sql)
        self.assertEqual(a.execute('SELECT title FROM os_tasks').fetchone()[0],'concurrent web change')
    def test_two_sided_conflict_is_not_silently_overwritten(self):
        a,b=self.db(),self.db()
        a.execute("INSERT INTO os_tasks VALUES(1,'web','2026-09-01','2026-10-14T10:00:00Z')")
        b.execute("INSERT INTO os_tasks VALUES(1,'app','2026-09-01','2026-10-14T10:01:00Z')")
        with self.assertRaises(m.MergeConflict):m.plan_merge(a,b,'2026-10-14T09:00:00Z')
    def test_existing_financial_request_conflict_is_rejected(self):
        a,b=self.db(),self.db()
        a.execute("INSERT INTO finance_write_requests VALUES('same-id','first')")
        b.execute("INSERT INTO finance_write_requests VALUES('same-id','different')")
        with self.assertRaises(m.MergeConflict):m.plan_merge(a,b,'2026-10-14T09:00:00Z')


if __name__=='__main__':unittest.main()
