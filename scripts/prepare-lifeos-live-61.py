"""Surgical task patches for the audited live bundle; no network or deployment.

Routine scheduling, finance, authentication, HTML and other modules stay intact.
"""
import hashlib

AUDITED_SHA256 = '373384c74fe55aa66f2d1a6b8c12e778b4f33dbcf699e28696c5f12aa632f73f'
PATCHED_SHA256 = '2fffe32f48461693444363457451c4787b25feb9196a1dda71e1d6175779a1e6'


def patches():
    migration_anchor = '  if (!columns.some((column) => column.name === "sort_order")) {'
    migration = '''  for (const [name, definition] of [["section_status", "TEXT NOT NULL DEFAULT 'todo'"], ["scheduled_time", "TEXT"]]) {
    if (!columns.some((column) => column.name === name)) {
      try { await env.DB.prepare("ALTER TABLE os_tasks ADD COLUMN " + name + " " + definition).run(); }
      catch (error) {
        const fresh = (await env.DB.prepare("PRAGMA table_info(os_tasks)").all()).results;
        if (!fresh.some((column) => column.name === name)) throw error;
      }
    }
  }
  await env.DB.prepare("UPDATE os_tasks SET section_status='waiting' WHERE status='waiting' AND section_status!='waiting'").run();
'''
    retention = '''  await env.DB.prepare(
    "DELETE FROM os_tasks WHERE status='done' AND completed_at IS NOT NULL AND strftime('%s',completed_at)<=strftime('%s','now','-5 days')"
  ).run();'''
    dates = '    const due = x.due_date ? validDate(x.due_date) : null, scheduled = x.scheduled_date ? validDate(x.scheduled_date) : null;'
    time = '''
    const timeProvided = Object.prototype.hasOwnProperty.call(x, "scheduled_time");
    const scheduledTime = x.scheduled_time === null || x.scheduled_time === void 0 || x.scheduled_time === "" ? null : x.scheduled_time;
    if (!validClock(scheduledTime)) throw Error("Orario promemoria non valido.");'''
    update = '"UPDATE os_tasks SET title=?,list_kind=?,sort_order=CASE WHEN list_kind=? THEN sort_order ELSE (SELECT COALESCE(MAX(sort_order),0)+1 FROM os_tasks WHERE list_kind=?) END,notes=?,due_date=?,scheduled_date=?,updated_at=CURRENT_TIMESTAMP WHERE id=?"'
    insert = '"INSERT INTO os_tasks(title,list_kind,notes,due_date,scheduled_date,sort_order) VALUES (?,?,?,?,?,(SELECT COALESCE(MAX(sort_order),0)+1 FROM os_tasks WHERE list_kind=?))"'
    status = '"UPDATE os_tasks SET status=?,completed_at=CASE WHEN ?=\'done\' THEN COALESCE(completed_at,strftime(\'%Y-%m-%dT%H:%M:%SZ\',\'now\')) ELSE NULL END,updated_at=CURRENT_TIMESTAMP WHERE id=?"'
    return [
        (migration_anchor, migration + migration_anchor),
        (retention, '  // Completed tasks are retained until the user explicitly deletes them.'),
        (dates, dates + time),
        (update, update.replace('scheduled_date=?,updated_at', 'scheduled_date=?,scheduled_time=CASE WHEN ? THEN ? ELSE scheduled_time END,updated_at')),
        ('.bind(title, kind, kind, kind, notes, due, scheduled, id).run();', '.bind(title, kind, kind, kind, notes, due, scheduled, timeProvided ? 1 : 0, scheduledTime, id).run();'),
        (insert, insert.replace('scheduled_date,sort_order) VALUES (?,?,?,?,?,', 'scheduled_date,scheduled_time,sort_order) VALUES (?,?,?,?,?,?,')),
        ('.bind(title, kind, notes, due, scheduled, kind).run();', '.bind(title, kind, notes, due, scheduled, scheduledTime, kind).run();'),
        (status, status.replace('SET status=?,', "SET section_status=CASE WHEN ?='done' THEN CASE WHEN status IN ('todo','waiting') THEN status ELSE section_status END ELSE ? END,status=?,")),
        ('.bind(status, status, id).run();', '.bind(status, status, status, status, id).run();'),
        ('    routineScheduleVersion: 1,', '    routineScheduleVersion: 1,\n    capabilities: { routineSchedules: true, taskNotificationTimes: true },'),
        (').slice(0, 3),\n    routines: routines.results.map(', ').slice(0, 48),\n    routines: routines.results.map('),
    ]


def transform(source):
    for index, (before, after) in enumerate(patches()):
        # Inspect the full replacement first: some insertions contain the anchor.
        if source.count(after) == 1:
            continue
        if source.count(before) != 1:
            raise ValueError('Live source context mismatch at patch %d; no writes.' % index)
        source = source.replace(before, after, 1)
    return source


def validate_preservation(original, changed):
    restored = changed
    for before, after in reversed(patches()):
        if restored.count(after) != 1:
            raise ValueError('Patched source is ambiguous.')
        restored = restored.replace(after, before, 1)
    if restored != original:
        raise ValueError('Unrelated source changed.')


if __name__ == '__main__':
    import argparse
    from pathlib import Path
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise SystemExit('Output must be a new file.')
    original = args.source.read_text()
    changed = transform(original)
    validate_preservation(original, changed)
    args.output.write_text(changed)
    args.output.chmod(0o600)
    print('LIVE_SOURCE_PATCH_PREPARED; unrelated code preserved; sha256=' + hashlib.sha256(changed.encode()).hexdigest())
