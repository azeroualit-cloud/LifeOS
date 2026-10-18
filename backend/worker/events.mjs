/** Espande ricorrenze in [low, high); 29/30/31 slittano all’ultimo giorno valido. */
export function expandEvents(rows, low, high) {
  const out = [];
  for (const ev of rows) {
    const start = ev.day,
      base = new Date(start + "T12:00:00Z");
    for (let n = 0; n < 12000; n++) {
      let day = start;
      if (n) {
        if (!ev.frequency || ev.frequency === "none") break;
        if (ev.frequency === "weekly")
          day = new Date(+base + n * 7 * 86400000).toISOString().slice(0, 10);
        else {
          const months = n * (ev.frequency === "yearly" ? 12 : 1),
            y = base.getUTCFullYear(),
            m = base.getUTCMonth() + months,
            last = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
          day = new Date(Date.UTC(y, m, Math.min(base.getUTCDate(), last), 12))
            .toISOString()
            .slice(0, 10);
        }
      }
      if (day >= high || (ev.until_day && day > ev.until_day)) break;
      if (day >= low) out.push({ ...ev, day, series_day: start });
    }
  }
  return out.sort(
    (a, b) =>
      a.day.localeCompare(b.day) ||
      (a.start_time || "").localeCompare(b.start_time || "") ||
      a.id - b.id,
  );
}

