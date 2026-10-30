const movementCreationJobs = new WeakMap();
export async function ensureMovementCreation(db) {
  if (!movementCreationJobs.has(db)) movementCreationJobs.set(db, (async () => {
    const hasColumn = async () => (await db.prepare('PRAGMA table_info(movements)').all()).results.some(row => row.name === 'created_at');
    if (!await hasColumn()) {
      try { await db.prepare('ALTER TABLE movements ADD COLUMN created_at TEXT').run(); }
      catch (error) { if (!await hasColumn()) throw error; }
    }
    await db.batch([
      db.prepare("CREATE TRIGGER IF NOT EXISTS lifeos_movement_created_v1 AFTER INSERT ON movements WHEN NEW.created_at IS NULL BEGIN UPDATE movements SET created_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE source_row=NEW.source_row; END"),
      db.prepare("CREATE TRIGGER IF NOT EXISTS lifeos_movement_created_immutable_v1 BEFORE UPDATE OF created_at ON movements WHEN OLD.created_at IS NOT NULL AND NEW.created_at IS NOT OLD.created_at BEGIN SELECT RAISE(ABORT,'Creation timestamp is immutable'); END")
    ]);
  })());
  try { await movementCreationJobs.get(db); }
  catch (error) { movementCreationJobs.delete(db); throw error; }
}
export function sortMovementCreation(rows) {
  return rows.sort((a,b) => (a.created_at || '').localeCompare(b.created_at || '') * -1 || Number(b.row) - Number(a.row));
}
