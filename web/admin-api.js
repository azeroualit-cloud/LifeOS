
/** Stato diagnostico in sola lettura: nessuna scrittura, nessun nuovo binding. */
async function getAdminStatus(env) {
  const tables = (
    await env.DB.prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '\\_cf\\_%' ESCAPE '\\' ORDER BY name",
    ).all()
  ).results.map((r) => r.name);
  const counts = [];
  for (const name of tables) {
    const row = await env.DB.prepare(
      'SELECT COUNT(*) AS n FROM "' + name.replaceAll('"', '""') + '"',
    ).first();
    counts.push({ name, rows: Number(row?.n || 0) });
  }
  let bytes = null;
  try {
    const pages = await env.DB.prepare("PRAGMA page_count").first();
    const size = await env.DB.prepare("PRAGMA page_size").first();
    bytes = Number(Object.values(pages)[0]) * Number(Object.values(size)[0]);
  } catch {}
  let lastMovement = null;
  try {
    lastMovement =
      (await env.DB.prepare("SELECT MAX(actual_date) AS d FROM movements").first())
        ?.d || null;
  } catch {}
  return {
    tables: counts,
    bytes,
    lastMovement,
    limits: { storageBytes: 500 * 1024 * 1024, dailyWrites: 100000, dailyReads: 5000000 },
    auth: String(env.ACCESS_EMAIL || "").trim() ? "Cloudflare Access" : "Password",
    time: new Date().toISOString(),
  };
}

/** Esporta una tabella D1 a pagine da 200 righe; il nome è validato su sqlite_master. */
async function getAdminExport(env, table, offset) {
  const n = Number(offset);
  if (!Number.isInteger(n) || n < 0 || n > 1000000 || n % 200 !== 0)
    throw Error("Pagina non valida.");
  const found = await env.DB.prepare(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=? AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '\\_cf\\_%' ESCAPE '\\'",
  )
    .bind(String(table))
    .first();
  if (!found) throw Error("Tabella non disponibile.");
  const rows = (
    await env.DB.prepare(
      'SELECT * FROM "' + found.name.replaceAll('"', '""') + '" LIMIT 200 OFFSET ?',
    )
      .bind(n)
      .all()
  ).results;
  return { table: found.name, offset: n, rows, done: rows.length < 200 };
}
