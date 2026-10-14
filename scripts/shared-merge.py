"""Build a guarded, repeatable merge. No financial values are written to logs."""
import datetime
import sqlite3


class MergeConflict(Exception):
    pass


def quote(name): return '"' + name.replace('"', '""') + '"'
def literal(value):
    if value is None: return 'NULL'
    if isinstance(value, bytes): return "X'" + value.hex() + "'"
    if isinstance(value, (float, int)): return repr(value)
    return "'" + str(value).replace("'", "''") + "'"
def moment(value):
    value = datetime.datetime.fromisoformat(str(value).replace('Z', '+00:00'))
    return value.replace(tzinfo=datetime.timezone.utc) if value.tzinfo is None else value
def where(row): return ' AND '.join(quote(k) + ' IS ' + literal(v) for k, v in row.items())


def plan_merge(primary, copy, copied_at):
    cutoff = moment(copied_at) - datetime.timedelta(minutes=2)
    sql = ['CREATE TABLE IF NOT EXISTS _lifeos_merge_guard (ok INTEGER NOT NULL CHECK(ok=1));']
    counts = {'inserted': 0, 'updated': 0, 'deleted': 0, 'timestamp_only': 0, 'web_additions_kept': 0}
    tables = [r[0] for r in primary.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' AND name NOT LIKE '_lifeos_%'")]
    allowed_new = {'os_tasks','os_routine_checks','os_shifts','os_events','os_event_repeat','os_event_occurrences','os_routines','os_categories', 'finance_write_requests','finance_extra_requests','account_balance_events','movements','movement_budget_policies','movement_financial_categories','extraordinary','extraordinary_cycles','extraordinary_allocations','extraordinary_links','extraordinary_settlements'}
    for table in tables:
        info = primary.execute(f'PRAGMA table_info({quote(table)})').fetchall()
        other = copy.execute(f'PRAGMA table_info({quote(table)})').fetchall()
        if [tuple(x) for x in info] != [tuple(x) for x in other]: raise MergeConflict('Schema diverso: ' + table)
        keys = [r['name'] for r in sorted(info, key=lambda r:r['pk']) if r['pk']]
        if not keys: raise MergeConflict('Chiave non identificata: ' + table)
        def rows(db): return {tuple(r[k] for k in keys): dict(r) for r in db.execute('SELECT * FROM '+quote(table))}
        a,b = rows(primary), rows(copy)
        for key in b.keys()-a.keys():
            if table not in allowed_new: raise MergeConflict('Nuovi dati da verificare: '+table)
            row=b[key]; pk={k:row[k] for k in keys}
            sql.append(f'INSERT INTO _lifeos_merge_guard SELECT 0 WHERE EXISTS(SELECT 1 FROM {quote(table)} WHERE {where(pk)}) AND NOT EXISTS(SELECT 1 FROM {quote(table)} WHERE {where(row)});')
            sql.append(f'INSERT INTO {quote(table)} ({",".join(map(quote,row))}) SELECT {",".join(map(literal,row.values()))} WHERE NOT EXISTS(SELECT 1 FROM {quote(table)} WHERE {where(pk)});')
            counts['inserted']+=1
        for key in a.keys() & b.keys():
            old,new=a[key],b[key]
            if old==new: continue
            fields=[k for k in old if old[k]!=new[k]]
            if set(fields)<= {'updated_at'}: counts['timestamp_only']+=1; continue
            if table!='os_tasks' or moment(old['updated_at'])>cutoff: raise MergeConflict('Modifiche concorrenti da verificare: '+table)
            pk={k:old[k] for k in keys}
            sql.append(f'INSERT INTO _lifeos_merge_guard SELECT 0 WHERE NOT EXISTS(SELECT 1 FROM {quote(table)} WHERE {where(old)}) AND NOT EXISTS(SELECT 1 FROM {quote(table)} WHERE {where(new)});')
            sql.append(f'UPDATE {quote(table)} SET '+','.join(quote(k)+'='+literal(v) for k,v in new.items())+f' WHERE {where(old)};')
            counts['updated']+=1
        for key in a.keys()-b.keys():
            row=a[key]
            # Only explicit task deletions can be inferred safely from the snapshot.
            # Rows created on the web after the copy are always preserved.
            if table!='os_tasks' or moment(row['created_at'])>cutoff:
                counts['web_additions_kept']+=1; continue
            if moment(row['updated_at'])>cutoff: raise MergeConflict('Attività modificata sul web dopo la copia.')
            pk={k:row[k] for k in keys}
            sql.append(f'INSERT INTO _lifeos_merge_guard SELECT 0 WHERE EXISTS(SELECT 1 FROM {quote(table)} WHERE {where(pk)}) AND NOT EXISTS(SELECT 1 FROM {quote(table)} WHERE {where(row)});')
            sql.append(f'DELETE FROM {quote(table)} WHERE {where(row)};')
            counts['deleted']+=1
    sql.append('DROP TABLE _lifeos_merge_guard;')
    return '\n'.join(sql), counts
