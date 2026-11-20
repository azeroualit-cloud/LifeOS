/** Impostazioni della previsione patrimonio (tredicesima, quattordicesima, scenario, mese di inizio statistica). Un solo record JSON in os_meta. */
const FORECAST_KEY = "web_forecast_settings_v1";
async function forecastTable(env) {
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS os_meta (key TEXT PRIMARY KEY,value TEXT NOT NULL)").run();
}
function cleanForecast(input) {
  const o = input && typeof input === "object" ? input : {};
  const money = (v, lo, hi) => (v === null || v === undefined ? null : Number.isFinite(Number(v)) && Number(v) >= lo && Number(v) <= hi ? Math.round(Number(v)) : (() => { throw Error("Importo non valido."); })());
  const from = o.from === null || o.from === undefined || o.from === "" ? null : String(o.from);
  if (from !== null && !/^20\d\d-(0[1-9]|1[0-2])$/.test(from)) throw Error("Mese non valido.");
  const horizon = [6, 12, 24].includes(Number(o.horizon)) ? Number(o.horizon) : 12;
  return { saving: money(o.saving, -100000, 100000), horizon, b13: o.b13 !== false, b14: o.b14 !== false, a13: money(o.a13, 0, 100000), a14: money(o.a14, 0, 100000), from };
}
async function getForecastSettings(env) {
  await forecastTable(env);
  const row = await env.DB.prepare("SELECT value FROM os_meta WHERE key=?").bind(FORECAST_KEY).first();
  if (!row) return null;
  try { return cleanForecast(JSON.parse(row.value)); } catch { return null; }
}
async function saveForecastSettings(env, input) {
  const clean = cleanForecast(input);
  await forecastTable(env);
  await env.DB.prepare("INSERT INTO os_meta(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value").bind(FORECAST_KEY, JSON.stringify(clean)).run();
  return clean;
}
