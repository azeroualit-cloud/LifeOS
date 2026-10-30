const movementCreationJobs = new WeakMap();
export async function ensureMovementCreation(db) {
  if (!movementCreationJobs.has(db)) movementCreationJobs.set(db, db.batch([
    db.prepare('CREATE TABLE IF NOT EXISTS movement_creation_metadata(movement_source_row INTEGER PRIMARY KEY REFERENCES movements(source_row) ON DELETE CASCADE ON UPDATE CASCADE,created_at TEXT NOT NULL)'),
    db.prepare("CREATE TRIGGER IF NOT EXISTS lifeos_movement_created_v1 AFTER INSERT ON movements BEGIN INSERT OR IGNORE INTO movement_creation_metadata(movement_source_row,created_at) VALUES(NEW.source_row,strftime('%Y-%m-%dT%H:%M:%fZ','now')); END"),
    db.prepare("CREATE TRIGGER IF NOT EXISTS lifeos_movement_created_immutable_v1 BEFORE UPDATE OF created_at ON movement_creation_metadata WHEN NEW.created_at IS NOT OLD.created_at BEGIN SELECT RAISE(ABORT,'Creation timestamp is immutable'); END")
  ]));
  try { await movementCreationJobs.get(db); }
  catch (error) { movementCreationJobs.delete(db); throw error; }
}
export function sortMovementCreation(rows) {
  return rows.sort((a,b) => (a.created_at || '').localeCompare(b.created_at || '') * -1 || Number(b.row) - Number(a.row));
}
