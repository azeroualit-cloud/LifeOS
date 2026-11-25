/** Nutrizione (alimenti personali) e Bloom (libreria di link e note) sul sito. Tabelle create se mancanti, nessuna modifica a quelle esistenti. */
const NB_FAMILIES = ["bakery", "grain", "egg", "dairy", "cheese", "fat", "legume", "fruit", "nut", "poultry", "meat", "fish", "meal", "pantry", "drink", "sweet", "vegetable", "supplement"];
let nbReady = null;
async function nbTables(env) {
  if (!nbReady) {
    nbReady = env.DB.batch([
      env.DB.prepare("CREATE TABLE IF NOT EXISTS web_foods (id TEXT PRIMARY KEY, name TEXT NOT NULL, brand TEXT NOT NULL DEFAULT '', family TEXT NOT NULL DEFAULT 'meal', basis TEXT NOT NULL DEFAULT 'g', kcal REAL, protein REAL, carbs REAL, fat REAL, fibre REAL, not_declared INTEGER NOT NULL DEFAULT 0, micro TEXT NOT NULL DEFAULT '{}', aliases TEXT NOT NULL DEFAULT '[]', note TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL)"),
      env.DB.prepare("CREATE TABLE IF NOT EXISTS web_bloom_collections (id TEXT PRIMARY KEY, name TEXT NOT NULL, doc TEXT NOT NULL DEFAULT '{}', updated_at TEXT NOT NULL)"),
      env.DB.prepare("CREATE TABLE IF NOT EXISTS web_bloom_items (id TEXT PRIMARY KEY, kind TEXT NOT NULL DEFAULT 'note', title TEXT NOT NULL DEFAULT '', url TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', tags TEXT NOT NULL DEFAULT '[]', place TEXT NOT NULL DEFAULT '', archived INTEGER NOT NULL DEFAULT 0, trashed_at REAL, modified_at REAL NOT NULL DEFAULT 0, files TEXT NOT NULL DEFAULT '[]', doc TEXT NOT NULL DEFAULT '{}')"),
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
  let modified = Number(o.modifiedAt);
  if (modified > 0 && modified < 1.5e9) modified += 978307200; // date di riferimento Apple (2001) in secondi unix
  return {
    id: nbId(o.id, ""),
    kind: /^[a-z]{2,20}$/.test(String(o.kind || "")) ? String(o.kind) : url ? "link" : "note",
    title: nbText(o.title, 300), url,
    body: nbText(o.text ?? o.body, 200000), notes: nbText([linkNote, o.notes].filter(Boolean).join("\n"), 200000),
    tags, place, archived: o.archived ? 1 : 0,
    trashedAt: o.trashedAt == null || o.trashedAt === "" ? null : Number(o.trashedAt) || null,
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
  await nbItemStatement(env, item, false).run();
  return { id: item.id };
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

let ndReady = null;
/** Tabella del diario, identica a quella del Worker dell'app (stesso D1). */
async function ndTables(env) {
  if (!ndReady) {
    ndReady = env.DB.batch([
      env.DB.prepare("CREATE TABLE IF NOT EXISTS web_food_diary (id TEXT PRIMARY KEY, day TEXT NOT NULL, at TEXT NOT NULL, name TEXT NOT NULL DEFAULT '', grams REAL, ml REAL, kcal REAL, protein REAL, carbs REAL, fat REAL, fibre REAL, revision INTEGER NOT NULL DEFAULT 0, modified REAL NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, app TEXT NOT NULL DEFAULT '{}')"),
      env.DB.prepare("CREATE INDEX IF NOT EXISTS web_food_diary_modified ON web_food_diary(modified)"),
      env.DB.prepare("CREATE INDEX IF NOT EXISTS web_food_diary_day ON web_food_diary(day)"),
    ]).catch((error) => { ndReady = null; throw error; });
  }
  await ndReady;
}
/* ---- Diario alimentare (FOOD-DIARY-SERVER-2026-11-22) ----
   Una riga per pasto. Campi leggibili dal sito (data, nome, quantità, macro) + `app`, la voce
   completa dell'app (micronutrienti, alcol, porzioni...). Vince la modifica più recente (`modified`,
   millisecondi). Le eliminazioni restano come righe `deleted` perché telefono e sito le ricevano. */
const ndDay = (iso) => {
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) throw Error("Data del pasto non valida.");
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Rome", year: "numeric", month: "2-digit", day: "2-digit" }).format(d);
};
const ndRow = (r) => ({ id: r.id, day: r.day, at: r.at, name: r.name, grams: r.grams, ml: r.ml, kcal: r.kcal, protein: r.protein, carbs: r.carbs, fat: r.fat, fibre: r.fibre, revision: r.revision, modified: r.modified, deleted: r.deleted === 1, app: (() => { try { return JSON.parse(r.app || "{}"); } catch { return {}; } })() });
function ndClean(input) {
  const v = input && typeof input === "object" ? input : {};
  const id = nbId(v.id, "diary-");
  const at = new Date(v.at || "");
  if (!Number.isFinite(at.getTime())) throw Error("Data del pasto non valida.");
  const modified = Number(v.modified);
  if (!Number.isFinite(modified) || modified <= 0) throw Error("Data di modifica non valida.");
  const app = v.app && typeof v.app === "object" ? JSON.stringify(v.app) : "{}";
  if (app.length > 24000) throw Error("Voce del diario troppo grande.");
  return { id, at: at.toISOString(), day: ndDay(at.toISOString()), name: nbText(v.name, 160, ""), grams: nbNum(v.grams, 100000), ml: nbNum(v.ml, 100000), kcal: nbNum(v.kcal, 100000), protein: nbNum(v.protein, 10000), carbs: nbNum(v.carbs, 10000), fat: nbNum(v.fat, 10000), fibre: nbNum(v.fibre, 10000), revision: Math.max(0, Math.floor(Number(v.revision) || 0)), modified, app };
}
/** Modifiche dal momento `since` (millisecondi, 0 = tutto), eliminazioni comprese. */
async function listFoodDiary(env, since) {
  await ndTables(env);
  const from = Number(since) > 0 ? Number(since) : 0;
  const { results } = await env.DB.prepare("SELECT * FROM web_food_diary WHERE modified > ? ORDER BY modified LIMIT 5000").bind(from).all();
  return { version: 1, now: Date.now(), entries: results.map(ndRow) };
}
async function listFoodDiaryDays(env, fromDay, toDay) {
  await ndTables(env);
  const re = /^\d{4}-\d{2}-\d{2}$/;
  if (!re.test(String(fromDay)) || !re.test(String(toDay))) throw Error("Intervallo di giorni non valido.");
  const { results } = await env.DB.prepare("SELECT * FROM web_food_diary WHERE deleted = 0 AND day >= ? AND day <= ? ORDER BY at LIMIT 5000").bind(fromDay, toDay).all();
  return { version: 1, entries: results.map(ndRow) };
}
/** Salva se è più recente della copia sul server; restituisce sempre la copia valida. */
async function saveFoodDiaryEntry(env, input) {
  await ndTables(env);
  const e = ndClean(input);
  const old = await env.DB.prepare("SELECT * FROM web_food_diary WHERE id = ?").bind(e.id).first();
  if (old && Number(old.modified) > e.modified) return { saved: false, entry: ndRow(old) };
  const revision = Math.max(e.revision, old ? Number(old.revision) + 1 : 0);
  await env.DB.prepare("INSERT INTO web_food_diary(id,day,at,name,grams,ml,kcal,protein,carbs,fat,fibre,revision,modified,deleted,app) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,0,?) ON CONFLICT(id) DO UPDATE SET day=excluded.day,at=excluded.at,name=excluded.name,grams=excluded.grams,ml=excluded.ml,kcal=excluded.kcal,protein=excluded.protein,carbs=excluded.carbs,fat=excluded.fat,fibre=excluded.fibre,revision=excluded.revision,modified=excluded.modified,deleted=0,app=excluded.app")
    .bind(e.id, e.day, e.at, e.name, e.grams, e.ml, e.kcal, e.protein, e.carbs, e.fat, e.fibre, revision, e.modified, e.app).run();
  return { saved: true, entry: ndRow(await env.DB.prepare("SELECT * FROM web_food_diary WHERE id = ?").bind(e.id).first()) };
}
async function deleteFoodDiaryEntry(env, id, modified) {
  await ndTables(env);
  const key = nbId(id, "diary-"), when = Number(modified);
  if (!Number.isFinite(when) || when <= 0) throw Error("Data di modifica non valida.");
  const old = await env.DB.prepare("SELECT * FROM web_food_diary WHERE id = ?").bind(key).first();
  if (!old) return { deleted: false };
  if (Number(old.modified) > when) return { deleted: false, entry: ndRow(old) };
  await env.DB.prepare("UPDATE web_food_diary SET deleted = 1, modified = ?, revision = revision + 1 WHERE id = ?").bind(when, key).run();
  return { deleted: true };
}
/** Trasferimento una tantum dello storico dell'app, ripetibile senza doppioni. */
async function importFoodDiary(env, list) {
  await ndTables(env);
  if (!Array.isArray(list) || list.length > 500) throw Error("Elenco del diario non valido.");
  let saved = 0, skipped = 0;
  for (const item of list) { const r = await saveFoodDiaryEntry(env, item); if (r.saved) saved++; else skipped++; }
  return { saved, skipped };
}
// LIFEOS_HUB_95 (SITE-ADMIN-HUB-2026-11-23): impostazioni condivise fra sito e app (obiettivi di
// nutrizione, regole degli avvisi, notifiche degli orari) e registro degli avvisi scattati.
// Tabelle create se mancanti; vale la modifica più recente.
let hubReady = null;
async function hubTables(env) {
  if (!hubReady) {
    hubReady = env.DB.batch([
      env.DB.prepare("CREATE TABLE IF NOT EXISTS web_settings (key TEXT PRIMARY KEY, doc TEXT NOT NULL DEFAULT '{}', modified REAL NOT NULL DEFAULT 0)"),
      env.DB.prepare("CREATE TABLE IF NOT EXISTS web_alert_log (id TEXT PRIMARY KEY, rule TEXT NOT NULL DEFAULT '', at TEXT NOT NULL, title TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '')"),
      env.DB.prepare("CREATE INDEX IF NOT EXISTS web_alert_log_at ON web_alert_log(at)"),
    ]).catch((error) => { hubReady = null; throw error; });
  }
  await hubReady;
}
const HUB_KEYS = ["nutrition-goals", "nutrition-targets", "alerts", "supplement-stacks", "finance-categories", "private-log", "app-layout"]; // CATEGORY-ADMIN-2026-11-24, CALENDAR-PRIVATE-ENTRY-2026-11-24, NAV-E-SLOT-2026-11-25
function hubKey(key) {
  const k = String(key || "");
  if (!HUB_KEYS.includes(k)) throw Error("Impostazione sconosciuta.");
  return k;
}
async function getSettings(env, key) {
  await hubTables(env);
  const k = hubKey(key);
  const row = await env.DB.prepare("SELECT doc, modified FROM web_settings WHERE key = ?").bind(k).first();
  let doc = {};
  try { doc = row ? JSON.parse(row.doc || "{}") : {}; } catch { doc = {}; }
  return { key: k, doc, modified: row ? Number(row.modified) : 0 };
}
/** Salva se più recente della copia sul server; restituisce sempre la copia valida. */
async function saveSettings(env, key, doc, modified) {
  await hubTables(env);
  const k = hubKey(key), when = Number(modified);
  if (!Number.isFinite(when) || when <= 0) throw Error("Data di modifica non valida.");
  if (!doc || typeof doc !== "object" || Array.isArray(doc)) throw Error("Impostazioni non valide.");
  const text = JSON.stringify(doc);
  if (text.length > 64000) throw Error("Impostazioni troppo grandi.");
  const old = await env.DB.prepare("SELECT modified FROM web_settings WHERE key = ?").bind(k).first();
  if (old && Number(old.modified) > when) return { saved: false, ...(await getSettings(env, k)) };
  await env.DB.prepare("INSERT INTO web_settings(key, doc, modified) VALUES (?,?,?) ON CONFLICT(key) DO UPDATE SET doc = excluded.doc, modified = excluded.modified").bind(k, text, when).run();
  return { saved: true, ...(await getSettings(env, k)) };
}
/** Avvisi mostrati dall'iPhone, per vederli sul sito; ne restano gli ultimi 500. */
async function addAlertLog(env, list) {
  await hubTables(env);
  if (!Array.isArray(list) || list.length > 100) throw Error("Elenco degli avvisi non valido.");
  let saved = 0;
  for (const item of list) {
    const v = item && typeof item === "object" ? item : {};
    const at = new Date(v.at || "");
    if (!Number.isFinite(at.getTime())) continue;
    const id = String(v.id || "").slice(0, 80) || "log-" + at.getTime();
    await env.DB.prepare("INSERT OR IGNORE INTO web_alert_log(id, rule, at, title, body) VALUES (?,?,?,?,?)")
      .bind(id, String(v.rule || "").slice(0, 80), at.toISOString(), String(v.title || "").slice(0, 160), String(v.body || "").slice(0, 600)).run();
    saved++;
  }
  await env.DB.prepare("DELETE FROM web_alert_log WHERE id NOT IN (SELECT id FROM web_alert_log ORDER BY at DESC LIMIT 500)").run();
  return { saved };
}
async function listAlertLog(env, limit) {
  await hubTables(env);
  const n = Math.max(1, Math.min(500, Math.floor(Number(limit) || 100)));
  const { results } = await env.DB.prepare("SELECT * FROM web_alert_log ORDER BY at DESC LIMIT ?").bind(n).all();
  return { entries: results };
}
