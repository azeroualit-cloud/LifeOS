// LIFEOS_BLOOM_FOODS_93
/** Nutrizione (alimenti personali) e Bloom (libreria di link e note) sul sito. Tabelle create se mancanti, nessuna modifica a quelle esistenti. */
const NB_FAMILIES = ["bakery", "grain", "egg", "dairy", "cheese", "fat", "legume", "fruit", "nut", "poultry", "meat", "fish", "meal", "pantry", "drink", "sweet", "vegetable", "supplement"];
let nbReady = null;
export function resetBloomFoodsForTests() { nbReady = null; }
async function nbTables(env) {
  if (!nbReady) {
    nbReady = env.DB.batch([
      env.DB.prepare("CREATE TABLE IF NOT EXISTS web_foods (id TEXT PRIMARY KEY, name TEXT NOT NULL, brand TEXT NOT NULL DEFAULT '', family TEXT NOT NULL DEFAULT 'meal', basis TEXT NOT NULL DEFAULT 'g', kcal REAL, protein REAL, carbs REAL, fat REAL, fibre REAL, not_declared INTEGER NOT NULL DEFAULT 0, micro TEXT NOT NULL DEFAULT '{}', aliases TEXT NOT NULL DEFAULT '[]', note TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL)"),
      env.DB.prepare("CREATE TABLE IF NOT EXISTS web_bloom_collections (id TEXT PRIMARY KEY, name TEXT NOT NULL, doc TEXT NOT NULL DEFAULT '{}', updated_at TEXT NOT NULL)"),
      env.DB.prepare("CREATE TABLE IF NOT EXISTS web_bloom_items (id TEXT PRIMARY KEY, kind TEXT NOT NULL DEFAULT 'note', title TEXT NOT NULL DEFAULT '', url TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', tags TEXT NOT NULL DEFAULT '[]', place TEXT NOT NULL DEFAULT '', archived INTEGER NOT NULL DEFAULT 0, trashed_at REAL, modified_at REAL NOT NULL DEFAULT 0, files TEXT NOT NULL DEFAULT '[]', doc TEXT NOT NULL DEFAULT '{}')"),
      // Riparazione idempotente: cestinati importati con la data di riferimento Apple (2001).
      env.DB.prepare("UPDATE web_bloom_items SET trashed_at = trashed_at + 978307200 WHERE trashed_at > 0 AND trashed_at < 1500000000"),
    ]).catch((error) => { nbReady = null; throw error; });
  }
  await nbReady;
}
let nbLenient = false;
const nbText = (v, max, required) => {
  const t = String(v ?? "").trim();
  if (required && !t) throw Error(required);
  if (t.length > max) { if (nbLenient) return t.slice(0, max); throw Error("Testo troppo lungo (massimo " + max + " caratteri)."); }
  return t;
};
const nbNum = (v, max) => {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(String(v).replace(",", "."));
  if (!Number.isFinite(n) || n < 0 || n > max) throw Error("Valore numerico non valido.");
  return Math.round(n * 1000) / 1000;
};
const nbId = (v, prefix) => {
  const id = v ? String(v) : prefix + crypto.randomUUID();
  if (!/^[A-Za-z0-9_.:-]{1,80}$/.test(id)) throw Error("Identificativo non valido.");
  return id;
};
/** Secondi unix; i valori sotto 1,5e9 arrivano dall'app come data di riferimento Apple (2001). */
const nbAppleTime = (v) => {
  if (v === null || v === undefined || v === "") return null;
  let n = Number(v);
  if (!Number.isFinite(n) || n <= 0) return null;
  if (n < 1.5e9) n += 978307200;
  return Math.floor(n);
};
const nbJson = (text, fallback) => { try { const v = JSON.parse(text); return v ?? fallback; } catch { return fallback; } };

/* ---------- Alimenti ---------- */
function nbCleanFood(input) {
  const o = input && typeof input === "object" ? input : {};
  const notDeclared = o.notDeclared === true;
  const micro = {};
  for (const [key, value] of Object.entries(o.micro && typeof o.micro === "object" ? o.micro : {}).slice(0, 60)) {
    if (!/^[A-Za-z0-9]{1,24}$/.test(key)) continue;
    const n = nbNum(value, 1e6);
    if (n !== null) micro[key] = n;
  }
  const aliases = (Array.isArray(o.aliases) ? o.aliases : []).map((a) => nbText(a, 60)).filter(Boolean).slice(0, 12);
  return {
    id: nbId(o.id, "personal-"),
    name: nbText(o.name, 120, "Il nome è obbligatorio."),
    brand: nbText(o.brand, 80),
    family: NB_FAMILIES.includes(o.family) ? o.family : "meal",
    basis: o.basis === "ml" ? "ml" : "g",
    kcal: notDeclared ? null : nbNum(o.kcal, 2000),
    protein: notDeclared ? null : nbNum(o.protein, 100),
    carbs: notDeclared ? null : nbNum(o.carbs, 100),
    fat: notDeclared ? null : nbNum(o.fat, 100),
    fibre: notDeclared ? null : nbNum(o.fibre, 100),
    notDeclared,
    micro,
    aliases,
    note: nbText(o.note, 500),
  };
}
function nbFoodRow(r) {
  return { id: r.id, name: r.name, brand: r.brand, family: r.family, basis: r.basis, kcal: r.kcal, protein: r.protein, carbs: r.carbs, fat: r.fat, fibre: r.fibre, notDeclared: !!r.not_declared, micro: nbJson(r.micro, {}), aliases: nbJson(r.aliases, []), note: r.note, updatedAt: r.updated_at };
}
function nbFoodStatement(env, f) {
  return env.DB.prepare("INSERT INTO web_foods(id,name,brand,family,basis,kcal,protein,carbs,fat,fibre,not_declared,micro,aliases,note,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,brand=excluded.brand,family=excluded.family,basis=excluded.basis,kcal=excluded.kcal,protein=excluded.protein,carbs=excluded.carbs,fat=excluded.fat,fibre=excluded.fibre,not_declared=excluded.not_declared,micro=excluded.micro,aliases=excluded.aliases,note=excluded.note,updated_at=excluded.updated_at")
    .bind(f.id, f.name, f.brand, f.family, f.basis, f.kcal, f.protein, f.carbs, f.fat, f.fibre, f.notDeclared ? 1 : 0, JSON.stringify(f.micro), JSON.stringify(f.aliases), f.note, new Date().toISOString());
}
async function listFoods(env) {
  await nbTables(env);
  const { results } = await env.DB.prepare("SELECT * FROM web_foods ORDER BY name COLLATE NOCASE LIMIT 5000").all();
  return { foods: results.map(nbFoodRow) };
}
async function saveFood(env, input) {
  await nbTables(env);
  const food = nbCleanFood(input);
  await nbFoodStatement(env, food).run();
  return food;
}
async function deleteFood(env, id) {
  await nbTables(env);
  await env.DB.prepare("DELETE FROM web_foods WHERE id=?").bind(nbId(id, "x")).run();
  return { ok: true };
}
/** Accetta l'elenco degli alimenti personali dell'app (stesso formato JSON) e lo converte. */
function nbFoodFromApp(a) {
  const nv = a?.nutrientValues && typeof a.nutrientValues === "object" ? a.nutrientValues : {};
  const micro = {};
  for (const [key, v] of Object.entries(nv)) {
    const amount = Number(v?.amount);
    if (Number.isFinite(amount) && /^[A-Za-z0-9]{1,24}$/.test(key)) micro[key === "folateMass" ? "folate" : key] = amount;
  }
  return { id: a?.id, name: a?.name, brand: a?.brand, family: a?.family, basis: a?.measurementBasis === "ml" ? "ml" : "g", kcal: Number(a?.calories), protein: Number(a?.protein), carbs: Number(a?.carbohydrate), fat: Number(a?.fat), fibre: a?.fibre == null ? null : Number(a.fibre), notDeclared: a?.nutritionNotDeclared === true, micro, aliases: a?.aliases || [], note: a?.dataNote || "" };
}
async function importFoods(env, list) {
  await nbTables(env);
  if (!Array.isArray(list) || !list.length || list.length > 200) throw Error("Invia da 1 a 200 alimenti per volta.");
  const foods = list.map((item) => nbCleanFood(item && item.calories !== undefined ? nbFoodFromApp(item) : item));
  await env.DB.batch(foods.map((f) => nbFoodStatement(env, f)));
  return { imported: foods.length };
}

/* ---------- Bloom ---------- */
function nbCleanItem(input) {
  const o = input && typeof input === "object" ? input : {};
  let url = nbText(o.urlString ?? o.url, 2000);
  let linkNote = "";
  if (url && !/^https?:\/\/[^\s]+$/i.test(url)) {
    if (!nbLenient) throw Error("Il link deve iniziare con http:// o https://");
    linkNote = url.slice(0, 500); url = "";
  }
  const tags = [...new Set((Array.isArray(o.tagIDs ?? o.tags) ? (o.tagIDs ?? o.tags) : o.collectionID ? [o.collectionID] : []).map((t) => nbText(t, 64)).filter(Boolean))].slice(0, 40);
  const files = (Array.isArray(o.noteFiles) ? o.noteFiles : []).slice(0, 40).map((f) => ({ name: nbText(f?.name ?? f?.fileName, 160), type: nbText(f?.type, 80) })).filter((f) => f.name);
  if (o.fileName && !files.length) files.push({ name: nbText(o.fileName, 160), type: nbText(o.type, 80) });
  const rest = {};
  for (const key of ["noteLinks", "imageFraming", "framing", "pinned", "createdAt", "importance"]) if (o[key] !== undefined) rest[key] = o[key];
  let doc = JSON.stringify(rest);
  if (doc.length > 8000) doc = "{}";
  let place = "";
  if (o.place && typeof o.place === "object") { place = JSON.stringify(o.place); if (place.length > 4000) place = ""; }
  const modified = nbAppleTime(o.modifiedAt) ?? 0;
  return {
    id: nbId(o.id, ""),
    kind: /^[a-z]{2,20}$/.test(String(o.kind || "")) ? String(o.kind) : url ? "link" : "note",
    title: nbText(o.title, 300), url,
    body: nbText(o.text ?? o.body, 200000), notes: nbText([linkNote, o.notes].filter(Boolean).join("\n"), 200000),
    tags, place, archived: o.archived ? 1 : 0,
    trashedAt: nbAppleTime(o.trashedAt),
    modifiedAt: Number.isFinite(modified) && modified > 0 ? modified : Math.floor(Date.now() / 1000),
    files, doc,
  };
}
const nbItemRow = (r, full) => ({ id: r.id, kind: r.kind, title: r.title, url: r.url, body: full ? r.body : r.body.slice(0, 300), bodyLength: r.body.length, notes: full ? r.notes : r.notes.slice(0, 300), tags: nbJson(r.tags, []), place: r.place ? nbJson(r.place, null) : null, archived: !!r.archived, trashedAt: r.trashed_at, modifiedAt: r.modified_at, files: nbJson(r.files, []), doc: full ? nbJson(r.doc, {}) : undefined });
function nbItemStatement(env, i, onlyNewer) {
  const base = "INSERT INTO web_bloom_items(id,kind,title,url,body,notes,tags,place,archived,trashed_at,modified_at,files,doc) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET kind=excluded.kind,title=excluded.title,url=excluded.url,body=excluded.body,notes=excluded.notes,tags=excluded.tags,place=excluded.place,archived=excluded.archived,trashed_at=excluded.trashed_at,modified_at=excluded.modified_at,files=excluded.files,doc=excluded.doc";
  return env.DB.prepare(base + (onlyNewer ? " WHERE excluded.modified_at > web_bloom_items.modified_at" : ""))
    .bind(i.id, i.kind, i.title, i.url, i.body, i.notes, JSON.stringify(i.tags), i.place, i.archived, i.trashedAt, i.modifiedAt, JSON.stringify(i.files), i.doc);
}
function nbCleanCollection(input) {
  const o = input && typeof input === "object" ? input : {};
  const rest = {};
  for (const key of ["color", "icon", "pinned", "order", "createdAt", "kind"]) if (o[key] !== undefined && String(JSON.stringify(o[key])).length < 200) rest[key] = o[key];
  return { id: nbId(o.id, "tag-"), name: nbText(o.name, 80, "Il nome è obbligatorio."), doc: JSON.stringify(rest) };
}
async function getBloom(env) {
  await nbTables(env);
  const [c, i] = await Promise.all([
    env.DB.prepare("SELECT * FROM web_bloom_collections ORDER BY name COLLATE NOCASE LIMIT 500").all(),
    env.DB.prepare("SELECT * FROM web_bloom_items ORDER BY modified_at DESC LIMIT 5000").all(),
  ]);
  return { collections: c.results.map((r) => ({ id: r.id, name: r.name, doc: nbJson(r.doc, {}) })), items: i.results.map((r) => nbItemRow(r, false)) };
}
async function getBloomItem(env, id) {
  await nbTables(env);
  const row = await env.DB.prepare("SELECT * FROM web_bloom_items WHERE id=?").bind(nbId(id, "x")).first();
  if (!row) throw Error("Elemento non trovato.");
  return nbItemRow(row, true);
}
async function saveBloomItem(env, input) {
  await nbTables(env);
  const item = nbCleanItem({ ...input, modifiedAt: Math.floor(Date.now() / 1000) });
  const expected = nbAppleTime(input?.expectModifiedAt);
  if (expected !== null && input?.id) {
    const row = await env.DB.prepare("SELECT modified_at FROM web_bloom_items WHERE id=?").bind(item.id).first();
    if (row && row.modified_at > expected) return { id: item.id, conflict: true, current: await getBloomItem(env, item.id) };
  }
  await nbItemStatement(env, item, false).run();
  return { id: item.id, modifiedAt: item.modifiedAt };
}
async function trashBloomItem(env, id, trashed) {
  await nbTables(env);
  await env.DB.prepare("UPDATE web_bloom_items SET trashed_at=?, modified_at=? WHERE id=?").bind(trashed ? Math.floor(Date.now() / 1000) : null, Math.floor(Date.now() / 1000), nbId(id, "x")).run();
  return { ok: true };
}
async function deleteBloomItem(env, id) {
  await nbTables(env);
  await env.DB.prepare("DELETE FROM web_bloom_items WHERE id=? AND trashed_at IS NOT NULL").bind(nbId(id, "x")).run();
  return { ok: true };
}
async function saveBloomCollection(env, input) {
  await nbTables(env);
  const c = nbCleanCollection(input);
  await env.DB.prepare("INSERT INTO web_bloom_collections(id,name,doc,updated_at) VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,doc=excluded.doc,updated_at=excluded.updated_at").bind(c.id, c.name, c.doc, new Date().toISOString()).run();
  return { id: c.id };
}
async function deleteBloomCollection(env, id) {
  await nbTables(env);
  const key = nbId(id, "x");
  const { results } = await env.DB.prepare("SELECT id,tags FROM web_bloom_items WHERE tags LIKE ?").bind('%"' + key.replace(/[%_"\\]/g, "") + '"%').all();
  const stmts = results.filter((r) => nbJson(r.tags, []).includes(key)).map((r) => env.DB.prepare("UPDATE web_bloom_items SET tags=? WHERE id=?").bind(JSON.stringify(nbJson(r.tags, []).filter((t) => t !== key)), r.id));
  stmts.push(env.DB.prepare("DELETE FROM web_bloom_collections WHERE id=?").bind(key));
  await env.DB.batch(stmts);
  return { ok: true };
}
/** Importa un blocco della copia di Bloom dell'app. Non sovrascrive mai elementi modificati più di recente sul sito. */
async function importBloom(env, payload) {
  await nbTables(env);
  const collections = Array.isArray(payload?.collections) ? payload.collections : [];
  const items = Array.isArray(payload?.items) ? payload.items : [];
  if (collections.length > 300 || items.length > 60 || !(collections.length + items.length)) throw Error("Invia al massimo 60 elementi e 300 categorie per volta.");
  const cleanC = [], cleanI = [], rejected = [];
  nbLenient = true;
  try {
    for (const c of collections) { try { cleanC.push(nbCleanCollection(c)); } catch (e) { rejected.push({ id: String(c?.id ?? ""), reason: String(e.message || e) }); } }
    for (const i of items) { try { cleanI.push(nbCleanItem(i)); } catch (e) { rejected.push({ id: String(i?.id ?? ""), reason: String(e.message || e) }); } }
  } finally { nbLenient = false; }
  const existing = new Map();
  if (cleanI.length) {
    const { results } = await env.DB.prepare("SELECT id,modified_at FROM web_bloom_items WHERE id IN (" + cleanI.map(() => "?").join(",") + ")").bind(...cleanI.map((i) => i.id)).all();
    for (const r of results) existing.set(r.id, r.modified_at);
  }
  const stmts = [
    ...cleanC.map((c) => env.DB.prepare("INSERT INTO web_bloom_collections(id,name,doc,updated_at) VALUES (?,?,?,?) ON CONFLICT(id) DO NOTHING").bind(c.id, c.name, c.doc, new Date().toISOString())),
    ...cleanI.map((i) => nbItemStatement(env, i, true)),
  ];
  if (stmts.length) await env.DB.batch(stmts);
  const added = cleanI.filter((i) => !existing.has(i.id)).length;
  const updated = cleanI.filter((i) => existing.has(i.id) && i.modifiedAt > existing.get(i.id)).length;
  return { added, updated, skipped: cleanI.length - added - updated, collections: cleanC.length, rejected: rejected.slice(0, 20), rejectedCount: rejected.length };
}

/** Gateway dell'app: stesse tabelle del sito, nessun metodo arbitrario. Restituisce undefined se il metodo non è suo. */
const BLOOM_FOODS_METHODS = {
  listFoods: (env) => listFoods(env),
  saveFood: (env, a) => saveFood(env, a[0]),
  deleteFood: (env, a) => deleteFood(env, a[0]),
  importFoods: (env, a) => importFoods(env, a[0]),
  getBloom: (env) => getBloom(env),
  getBloomItem: (env, a) => getBloomItem(env, a[0]),
  saveBloomItem: (env, a) => saveBloomItem(env, a[0]),
  trashBloomItem: (env, a) => trashBloomItem(env, a[0], a[1] !== false),
  deleteBloomItem: (env, a) => deleteBloomItem(env, a[0]),
  saveBloomCollection: (env, a) => saveBloomCollection(env, a[0]),
  deleteBloomCollection: (env, a) => deleteBloomCollection(env, a[0]),
  importBloom: (env, a) => importBloom(env, a[0]),
};
export async function bloomFoodsAction(env, method, args) {
  if (!Object.prototype.hasOwnProperty.call(BLOOM_FOODS_METHODS, method)) return undefined;
  return BLOOM_FOODS_METHODS[method](env, Array.isArray(args) ? args : []);
}
