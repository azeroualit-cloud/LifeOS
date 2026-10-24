const healthSchemaJobs = new WeakMap();
async function ensureHealth(env) {
  if (!healthSchemaJobs.has(env.DB)) healthSchemaJobs.set(env.DB, env.DB.prepare("CREATE TABLE IF NOT EXISTS os_health_daily(day TEXT PRIMARY KEY,weight_kg REAL,calories INTEGER,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)").run());
  try { await healthSchemaJobs.get(env.DB); }
  catch (error) { healthSchemaJobs.delete(env.DB); throw error; }
}
async function healthData(env) {
  await ensureHealth(env);
  const end = nowDay();
  const start = new Date(Date.parse(end + "T12:00:00Z") - 89 * 86400000).toISOString().slice(0,10);
  return (await env.DB.prepare("SELECT day,weight_kg,calories FROM os_health_daily WHERE day>=? AND day<=? ORDER BY day").bind(start,end).all()).results;
}
async function saveHealthEntry(env, input) {
  const day = validDate(input?.day);
  if (day > nowDay()) throw Error("Scegli oggi o una data precedente.");
  const numeric = (value, low, high, integer = false) => {
    if (value === undefined || value === null || value === "") return null;
    if (!["string", "number"].includes(typeof value)) throw Error("Misura non valida.");
    const n = Number(value);
    if (!Number.isFinite(n) || n < low || n > high || (integer && !Number.isInteger(n))) throw Error("Misura non valida.");
    return n;
  };
  const weight = numeric(input.weightKg,20,500), calories = numeric(input.calories,0,15000,true);
  if (weight === null && calories === null) throw Error("Inserisci il peso o le calorie.");
  await ensureHealth(env);
  // One entry per civil day; retrying or correcting a measurement never adds duplicates.
  await env.DB.prepare("INSERT INTO os_health_daily(day,weight_kg,calories) VALUES(?,?,?) ON CONFLICT(day) DO UPDATE SET weight_kg=COALESCE(excluded.weight_kg,os_health_daily.weight_kg),calories=COALESCE(excluded.calories,os_health_daily.calories),updated_at=CURRENT_TIMESTAMP").bind(day,weight,calories).run();
  return true;
}
// Published shifts are separate from drafts. This schema never seeds or reads finance.
const shiftCalendarSchemaJobs = new WeakMap();
async function ensureShiftCalendar(env) {
  if (!shiftCalendarSchemaJobs.has(env.DB)) shiftCalendarSchemaJobs.set(env.DB, env.DB.batch([
    env.DB.prepare("CREATE TABLE IF NOT EXISTS os_shift_calendar (id INTEGER PRIMARY KEY CHECK(id=1),token TEXT NOT NULL,calendar_id TEXT NOT NULL,published_at TEXT)"),
    env.DB.prepare("CREATE TABLE IF NOT EXISTS os_published_shifts (day TEXT PRIMARY KEY,kind TEXT NOT NULL,sequence INTEGER NOT NULL DEFAULT 0,cancelled INTEGER NOT NULL DEFAULT 0,modified_at TEXT NOT NULL)"),
    env.DB.prepare("CREATE TABLE IF NOT EXISTS os_shift_publications (month TEXT PRIMARY KEY,published_at TEXT NOT NULL)")
  ]));
  try { await shiftCalendarSchemaJobs.get(env.DB); }
  catch (error) { shiftCalendarSchemaJobs.delete(env.DB); throw error; }
}
function shiftCalendarToken() {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)), n => n.toString(16).padStart(2, "0")).join("");
}
async function shiftCalendarStatus(env, month) {
  await ensureShiftCalendar(env);
  const config = await env.DB.prepare("SELECT token,published_at FROM os_shift_calendar WHERE id=1").first();
  const publication = await env.DB.prepare("SELECT published_at FROM os_shift_publications WHERE month=?").bind(month).first();
  return { path: config ? `/calendar/turni/${config.token}.ics` : null, publishedAt: publication?.published_at || null };
}
async function shiftCalendarAction(env, method, input) {
  const month = String(input?.month || "");
  if (!validMonthKey(month)) throw Error("Mese non valido.");
  await ensureShiftCalendar(env);
  if (method === "publishShiftCalendar") {
    await ensureLife(env);
    // D1 batch is transactional: readers see the previous or the complete new month.
    // SQL compares snapshots inside the transaction, so concurrent retries keep UIDs/revisions.
    await env.DB.batch([
      env.DB.prepare("INSERT OR IGNORE INTO os_shift_calendar(id,token,calendar_id) VALUES(1,?,?)").bind(shiftCalendarToken(), crypto.randomUUID()),
      env.DB.prepare("INSERT INTO os_published_shifts(day,kind,modified_at) SELECT day,kind,strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM os_shifts WHERE substr(day,1,7)=? ON CONFLICT(day) DO UPDATE SET kind=excluded.kind,cancelled=0,sequence=os_published_shifts.sequence+1,modified_at=excluded.modified_at WHERE os_published_shifts.kind<>excluded.kind OR os_published_shifts.cancelled<>0").bind(month),
      env.DB.prepare("UPDATE os_published_shifts SET cancelled=1,sequence=sequence+1,modified_at=strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE substr(day,1,7)=? AND cancelled=0 AND NOT EXISTS(SELECT 1 FROM os_shifts WHERE os_shifts.day=os_published_shifts.day)").bind(month),
      env.DB.prepare("INSERT INTO os_shift_publications(month,published_at) VALUES(?,strftime('%Y-%m-%dT%H:%M:%SZ','now')) ON CONFLICT(month) DO UPDATE SET published_at=excluded.published_at").bind(month),
      env.DB.prepare("UPDATE os_shift_calendar SET published_at=strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id=1")
    ]);
  } else if (method === "rotateShiftCalendarLink") {
    await env.DB.prepare("UPDATE os_shift_calendar SET token=? WHERE id=1").bind(shiftCalendarToken()).run();
  }
  return shiftCalendarStatus(env, month);
}
function publishedShiftsICS(rows, calendarId) {
  const lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Life OS//Turni//IT", "CALSCALE:GREGORIAN", "X-WR-CALNAME:Turni Life OS", "X-WR-TIMEZONE:Europe/Rome",
    "BEGIN:VTIMEZONE", "TZID:Europe/Rome", "BEGIN:DAYLIGHT", "DTSTART:19960331T020000", "TZOFFSETFROM:+0100", "TZOFFSETTO:+0200", "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU", "END:DAYLIGHT", "BEGIN:STANDARD", "DTSTART:19961027T030000", "TZOFFSETFROM:+0200", "TZOFFSETTO:+0100", "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU", "END:STANDARD", "END:VTIMEZONE"];
  const kinds = {morning:["Mattina", "060000", "140000"], afternoon:["Pomeriggio", "140000", "220000"], night:["Notte", "220000", "060000"], holiday:["Ferie"], rest:["Riposo"]};
  for (const row of rows) {
    const kind = kinds[row.kind];
    if (!kind || !/^\d{4}-\d{2}-\d{2}$/.test(row.day)) continue;
    const day = row.day.replaceAll("-", ""), next = new Date(Date.parse(row.day + "T12:00:00Z") + 86400000).toISOString().slice(0,10).replaceAll("-", "");
    const stamp = row.modified_at.replaceAll(/[-:]/g, "");
    lines.push("BEGIN:VEVENT", `UID:${calendarId}-${day}@lifeos`, `DTSTAMP:${stamp}`, `LAST-MODIFIED:${stamp}`, `SEQUENCE:${row.sequence}`, `SUMMARY:${kind[0]}`);
    if (kind.length === 1) lines.push(`DTSTART;VALUE=DATE:${day}`, `DTEND;VALUE=DATE:${next}`, "TRANSP:TRANSPARENT");
    else lines.push(`DTSTART;TZID=Europe/Rome:${day}T${kind[1]}`, `DTEND;TZID=Europe/Rome:${row.kind === "night" ? next : day}T${kind[2]}`, "TRANSP:OPAQUE");
    lines.push(`STATUS:${row.cancelled ? "CANCELLED" : "CONFIRMED"}`, "END:VEVENT");
  }
  return [...lines, "END:VCALENDAR", ""].join("\r\n");
}
async function serveShiftCalendar(request, env, token) {
  const headers = {"cache-control":"no-store", "referrer-policy":"no-referrer", "x-robots-tag":"noindex, nofollow", "x-content-type-options":"nosniff"};
  if (!["GET", "HEAD"].includes(request.method)) return new Response("Metodo non disponibile.", {status:405, headers:{...headers, Allow:"GET, HEAD"}});
  try {
    // Deliberately no ensureLife: public subscriptions must never run legacy seed/migrations.
    const config = await env.DB.prepare("SELECT calendar_id FROM os_shift_calendar WHERE id=1 AND token=? AND published_at IS NOT NULL").bind(token).first();
    if (!config) return new Response("Non trovato.", {status:404, headers});
    const rows = await env.DB.prepare("SELECT * FROM os_published_shifts ORDER BY day").all();
    return new Response(request.method === "HEAD" ? null : publishedShiftsICS(rows.results, config.calendar_id), {headers:{...headers, "content-type":"text/calendar; charset=utf-8"}});
  } catch {
    return new Response("Calendario non disponibile. Riprova più tardi.", {status:503, headers:{...headers, "retry-after":"300"}});
  }
}

