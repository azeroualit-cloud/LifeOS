// backend/worker/habits.mjs
function validHabitDay(day2) {
  return typeof day2 === "string" && /^\d{4}-\d{2}-\d{2}$/.test(day2) && Number.isFinite(Date.parse(day2 + "T12:00:00Z")) && (/* @__PURE__ */ new Date(day2 + "T12:00:00Z")).toISOString().slice(0, 10) === day2;
}
function habitSchedule(value) {
  if (value === void 0) return { mode: "daily", intervalDays: 1, weekdays: [], startDate: "" };
  if (!value || typeof value !== "object" || Array.isArray(value) || !["daily", "interval", "weekdays"].includes(value.mode)) throw Error("Ripetizione non valida.");
  const { mode } = value, startDate = value.startDate ?? "", intervalDays = value.intervalDays ?? 1, days = value.weekdays ?? [];
  if (startDate !== "" && !validHabitDay(startDate) || mode !== "daily" && !validHabitDay(startDate)) throw Error("Scegli una data di inizio valida.");
  if (mode === "interval" && (!Number.isInteger(intervalDays) || intervalDays < 1 || intervalDays > 365)) throw Error("Scegli un intervallo da 1 a 365 giorni.");
  if (mode === "weekdays" && (!Array.isArray(days) || !days.length || days.some((d) => !Number.isInteger(d) || d < 1 || d > 7))) throw Error("Scegli almeno un giorno della settimana.");
  return { mode, intervalDays: mode === "interval" ? intervalDays : 1, weekdays: mode === "weekdays" ? [...new Set(days)].sort((a, b) => a - b) : [], startDate };
}
function habitDue(routine, day2) {
  const s = habitSchedule(routine.schedule);
  if (!validHabitDay(day2) || s.startDate && day2 < s.startDate) return false;
  if (s.mode === "daily") return true;
  if (s.mode === "weekdays") return s.weekdays.includes(((/* @__PURE__ */ new Date(day2 + "T12:00:00Z")).getUTCDay() + 6) % 7 + 1);
  return Math.round((Date.parse(day2 + "T12:00:00Z") - Date.parse(s.startDate + "T12:00:00Z")) / 864e5) % s.intervalDays === 0;
}

// backend/worker/events.mjs
function expandEvents(rows, low, high) {
  const out = [];
  for (const ev of rows) {
    const start = ev.day, base = /* @__PURE__ */ new Date(start + "T12:00:00Z");
    for (let n = 0; n < 12e3; n++) {
      let day2 = start;
      if (n) {
        if (!ev.frequency || ev.frequency === "none") break;
        if (ev.frequency === "weekly")
          day2 = new Date(+base + n * 7 * 864e5).toISOString().slice(0, 10);
        else {
          const months2 = n * (ev.frequency === "yearly" ? 12 : 1), y = base.getUTCFullYear(), m = base.getUTCMonth() + months2, last = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
          day2 = new Date(Date.UTC(y, m, Math.min(base.getUTCDate(), last), 12)).toISOString().slice(0, 10);
        }
      }
      if (day2 >= high || ev.until_day && day2 > ev.until_day) break;
      if (day2 >= low) out.push({ ...ev, day: day2, series_day: start });
    }
  }
  return out.sort(
    (a, b) => a.day.localeCompare(b.day) || (a.start_time || "").localeCompare(b.start_time || "") || a.id - b.id
  );
}

// backend/worker/platform-contract.mjs
var platformContract = {
  "version": 2,
  "expenseCategories": [
    "Alimentari",
    "Ristorazione",
    "Casa",
    "Affitto",
    "Condominio",
    "Arredamento e casa",
    "Utenze",
    "Elettricit\xE0",
    "Gas",
    "Acqua",
    "Abbonamenti",
    "Auto",
    "Assicurazione",
    "Bollo",
    "Manutenzione auto",
    "Benzina",
    "Shopping",
    "Salute",
    "Palestra",
    "Dentista",
    "Farmaci e visite",
    "Svago",
    "Viaggi",
    "Altro"
  ],
  "incomeCategories": [
    "Stipendio",
    "Interessi",
    "Rimborsi",
    "Altro"
  ],
  "planKinds": {
    "advance": "Anticipa budget",
    "goal": "Obiettivo finito",
    "fund": "Fondo senza scadenza",
    "fixed": "Spesa ricorrente fissa",
    "estimated": "Utenza con quota stimata",
    "recovery": "Rateizza una spesa"
  },
  "planStatuses": {
    "active": "In corso",
    "stopped": "Interrotto",
    "closed": "Concluso",
    "cancelled": "Annullato",
    "pendingPayment": "Pagamento da completare"
  },
  "plansUnavailable": "Il server collegato non supporta Piani v2. Aggiorna il Worker usato da questa piattaforma e riprova. I piani precedenti sono conservati."
};

// backend/worker/runtime.generated.mjs
function attachSavingsPlanning(result, config, day2) {
  const cell = (row) => {
    const record = config.find((r) => r.sheet === "Budget" && Number(r.row_number) === row);
    return record ? JSON.parse(record.values_json)[14] : null;
  };
  const rawGoal = cell(13), saving = Number(cell(14));
  result.planning ||= {
    year: Number(day2.slice(0, 4)),
    goal: rawGoal === null || rawGoal === "" || rawGoal === void 0 ? null : Number(rawGoal),
    monthlySaving: Number.isFinite(saving) ? Math.max(0, saving) : 0,
    now: result.summary.budget
  };
  const setting = config.find((r) => r.sheet === "LifeOS Settings" && Number(r.row_number) === 1);
  const target = setting ? JSON.parse(setting.values_json)[0] : null;
  if (Number.isFinite(target) && target > 0) result.planning.savingsTarget = target;
  return result;
}
function forecastCashHistory(movements, plan, today) {
  const months2 = Array.from({ length: 6 }, (_, i) => {
    const d = /* @__PURE__ */ new Date(today.slice(0, 7) + "-01T12:00:00Z");
    d.setUTCMonth(d.getUTCMonth() - 6 + i);
    return d.toISOString().slice(0, 7);
  });
  const linked = /* @__PURE__ */ new Map();
  for (const link of plan.links || []) if (link.role === "payment") linked.set(Number(link.movement_source_row), (linked.get(Number(link.movement_source_row)) || 0) + Number(link.attributed_cents || 0) / 100);
  return months2.map((month2) => {
    const rows = movements.filter((r) => r.account === "Trade Republic" && r.status === "Eseguito" && String(r.actual_date).slice(0, 7) === month2 && String(r.actual_date).slice(0, 10) < today);
    const net = rows.reduce((s, r) => s + Number(r.amount || 0), 0);
    const extraPaid = rows.reduce((s, r) => s + (Number(r.amount) < 0 ? Math.min(-Number(r.amount), linked.get(Number(r.source_row)) || 0) : 0), 0);
    return { month: month2, observed: rows.length > 0, ordinaryNet: Math.round((net + extraPaid) * 100) / 100, extraPaid };
  });
}
var ICON_180 = "iVBORw0KGgoAAAANSUhEUgAAALQAAAC0CAYAAAA9zQYyAAAACXBIWXMAAAsTAAALEwEAmpwYAAARqElEQVR4nO3daVhV1RoH8D7um+XQxtBMy0p5UtMebdDUVFJx1sp5As1MLb15r8qgIAooOKAMgTmPKAqO4EAOmaIxiPNw62qDt9JyKMuywd77rM3ZsM6EIOfstc4+/w/vd/dav/0+f9/9Ag8o1VRC4QwUk5zBA6L/ASicgQLQQIBGoKJDA4Fq+jNA5JDgElAqQAMBXgQFHRoIFJOfASKHBJeAUgEaCPAiKOjQQKCY/AwQOSS4BJQK0ECAF0FBhwYCxeRngMghwSWgVIAGArwICjo0ECgmPwNEDgkuAaUCNBDgRVDQoYFAMfkZIHJIcAkoFaCBAC+Cgg4NBIrJzwCRQ4JLQKkADQR4ERR0aCBQTH4GiBwSXAJKBWggwIugoEMDgWLyM0DkkOASUCpAAwFeBAUdGggUk58BIocEl4BSARoI8CIo6NBAoJj8DBA5JLgElArQQIAXQUGHBgLF5GeAyCHBJaBUgAYCvAgKOjQQKCY/A1NEjk7dB9Ge/V/S1uzztD6jkOKTt9HE4Hh6c/B4atK8LT1Yo6bwfyNKBejyIujaO5BOnf+bTpz7m46fvUtFZ+7SsdN/UeHJP6ngxJ+09+AVmpu4jXr1G0OP1HoCuKqZ9wUzDeiT5/6mE2f/puNn7lLR6b/o2Kli0Pkn/qS843/Qp0V/0NFjv9P+3Js0M3Y9NXvJX/i/G6UCdNmg72qgte586i8qsAL9uwY6t/AOHS64Q4fyf6OFqTn0QuuugFXNPC+XqTq0Vdw49Wcx6ON/UJ6lOx8p/J1yC+7Q4fzf6FDeb/TJp7/SwaO/UuyC7VT3mabCnwOlAjRD0KV3YLnixpHCOyWgP8n7jQ5++it9fPRXOnDkNmXtvUo9+44Fqmqe/WKZCPTdEtDO4sYRLm6UgD5ymw7k3qb9h3+hvYd+ocjZ6aTWflL4M6FU7wZtHTd00H9ooK3jxh2ruMFA78+9TfssoD/65GdasqaA6tRvLPy5UKqXgu4VaBc3CsqIG4ds4kYp6J810HsO3qJV6WfpqWdbCH82lOqNoIffX9w4ersY9OFfaJ+lO+cc/Jn2fHyLdh/4idZlfkb1GjQT/nwo1ftAO4sbDPSRY+WPGzkHb5WA3rn/J1q69iT51mso/BlRqpeBPn23jLhhP65zFjcY6N0f36JdFtDZ+36kuITd9GCNR4U/J0r1JtDF+dk6bljnZ+u4oYP+RQNtHTdu0a79P9HOfT9S9t4fKeujmzRs1Azhz4lSvQN0QK/hTuOG1ddBm7hxoIy4scvSnbP2/kg7PrpJW3dfo+dfDhD+rCjVi0Bb4ka+C+NG1t6bGujtOTcoeWkeVVFrCX9elOoFoO/j66AeNxjonE+cx43tOTdp254btHX3DXpj0CThz4tSzQ+6PMtIGmincaN0XKeD1uNGKejrtDbjEtXwrSf8mVGq2UGXfxnJOm5Y52fruKGDvqGB3rL7Om3eeZ3eHDxZ+DOjVJODrkTc0L8OavnZJm7s4OLGll0M9DVatvY8PaTWFv7cKNW8oO93GakicUMHnZF9jVr79xf+3CjV7KDvbxnJ9uugo7jBQG/edZ0yGeisazR52hrhz41STQq65/BKLyNZjeucxo3rlJnNQP9AaZnfUPVH6wp/dpRqPtCdew53GDdyK7iMxOdnZ3GDgd6U9QNt3PEDvdi2t/BnR6lmBe2aZSRncWOLHjd00Nu/p2GjooU/O0o1J+g8V38dzLlJ253EjU07ikFHzd0t/NlRqjeArvwyEv91kI8bGZa4kb79e1qe9rnwZ0epZgQ9zOXLSLb52SpuWEBv2HqV1DpPC39+lGo+0O5YRtpWRtxI3/Y9rd96lRo17yD8+VGqmUG7dhnJWdzYYAH9Yps+wp8fpZoRtHuWkfivg1ZxY9tVDXSb1wYJf36UajLQPYa5dRmpuDtfs4sbaVuuUscebwt/fpRqLtCdSkC7ZxmJz8983GCgA3qPEf78KNW8oB3+qgIXLCM5ihtpW654LOgqai2q+bgf1a7/HD3p9zLVb/QKNWoeQNV8PfvXDZsGtLuXkfi4scHSnddtvkIBveQF/Y/qNalug+bUssMQ6j0wnALHpND4kAyKiMuluORzNOeDCxSXfIFik89TbNJ5mp10jho29eypjYlAu3cZSQfNx41i0O8If369qjziS41bBNDrg6fT+OCNNCvxBMUv+pzmL/qc5qV+ptXclP/QHFYWzHEc5tmJAC0daHcuI1nn5ysa6M6CQdeoVZ9avxZIo8Yvptikk7Rw8UVasPi/FP8hKwvmRaWY5+qYNdDnte6sY56VeBYdWhbQRiwj6XFjvaU7r80UB/rpxm1oyKh4mpdylhKWXqKFSy5qxTAv4DDP1zGnlmKew2GOZZiTGOZzNCsBoCUD7d5lJNu4sTbzO0NBV/WpQ517TaDpcw5R4rIvKHHpJQ1zAo95sT1mR1GDz816d45hoJ9DhpYGtLuXkWzjhlGgH1JrUYeub9OshQWUtPwLSmKYl1ljdhg1UsuIGjaYWXeOSTgD0DJUxx7DDFtG4uPGmozvqHPPd9w6pfDv9g7FJRZR8vIvKYmVhrm0OzvDPP8euTnWDvNZil4I0HKA7j6s3HFjTyWXkfi44U7QTz3biqZM30EfrPiKkld8WQzaEeYK5eYLVlFDz80Mc8zCMxroBs+1F36fireP7XTQRiwj8XGDge7kYtAP+9Sm/oExlLzsojVmJ1GDz83xFRzR6blZxxy94DRAywLaqGWkNC5urN7kWtC1n2xCITOyKWXlV/QBKzvMXxRjLiNqzKvAiE7PzTrmKICWBfRQty8j8V8HS0F/6zLQLVr3ofjUM5Sy8msLZldGjfMOR3R8d2aYAVoi0EYtI/FxY5WLQPfsH6x1ZYZZ6842UcNdI7oYG8wz408hcsgH2r3LSAy0HjdWbawc6H9U96EBgTGUuuprSllVitk+arhnRBfNRQ2GGaBlAm3QMhIfNyoDmv2Ji8AxCRpmDbRdbnb/iC5a787xxaBnzEeHlga0UctIetxgoFdWAvSIcUmUuuqyBbM7cvOFe47o+KjBMM+Yf5IaNMHYTjjo10pA3+8y0o1yLyOtyfyOVrP8vPFbWpn+LXXqUXHQvQeE0qLVl+2ihtEjuiguajDMkfMAWg7Q3YYatozEx42V6d9UGHQr/8GlMcNh1DBuRDeTixo66GfQoeUAbdQyEh83VqR/Qx0rAPrpxq9Q8vJLXG4WO6KzxRw57wRAywfavctIWtzQQW9goEeXe8EoInY/pepRQ4IR3cx4a8zT5wK0PKANWkbSx3UsblQE9KCRsQ5zs8gR3QyuOzPMAC0RaKOWkfT8zOLG8nKCbtKic0nMkGlEN0PHbOnOEXOOI3LIBdr9y0glcYOBXv8/6th99D0/nkyLyZFyRBfJRY2IucctoNsJv0/F27ftNNAGLSPxcYOBfu0eoFt3HCbtiC7SglnvzuEALUf5dxtq2DKSDprFjWX3AM3+Ixgdf1TaEd10G8zhcUXo0PKANmYZqSRulAN0u4CRUo/opnNRg2GeFldETzdG5BAPuutQw5aR+LixLK1s0GHRe6Qe0UXomOcUFYOOLaJ6fi8Lv0/F2zM0A23UMhIfN5aWAbph01elH9FFcFGDdedpsceodv2mwu8ToEtAu38ZiY8bS9MuOwUdNDZR+hFdhA3mqbHHSK3TQDhKgO46xLBlJD5uLFnnGDRbDZ2fckr6EV24Deaps49RVZ/HhaME6K5DDFtGWsHFDWeg/Zp18IgRXbglN+uYp0QdJaW6j3CUAK2BNmYZiY8bxaDtf+F5n0HTPGJEN03vzrOPUdjsQnp74ibhIAFa+0/hEMOWkfS4sXTdZVq89jL5d7MHHRKZ7REjumklUaOQwmYVUr+ghcJBAnQ1lTqUgHb/MtJyLm44As3yc8KSzzxiRDeV686hswqpY89JwkECtAPQ7lxG4vPz4rVf24Fmv2DcU0Z0Uy2YWXcOnVVAzVsPFA4SoC2gDVlG2lAaN5asvUwfrrEH/ULbvh4zogvjMIfGFJDvE42FgwRoBrrLEMOWkfi44Qh0j37BHjOiC7NEDYZ53JQs4RgB2gq0MctIfNxwBHrgiFiPGNGFcd05JKaAeg6IEo4RoC2H0K7TAMOWkfi4sWj119rvbeYvInBskkeM6MI4zCEx+dSsVV/hGAHacggt2/UxbBmJjxuLVn9lB/qd95d7xIgu1JKbGeh/Rx6mqo969p9zM9VyUvOWXQxbRuLjhiPQE0LSPWJEF6p35+h86jM4TvgdAjR3CM8+39awZSQNtCVupK6yB/2vqVs8YkQXYokawdH55Nesk3CIAM0dgu8TDQ1ZRtK/Dn5YBuiJDLQHjOhCLJjHBWdpf/pCNESAtvlB1G17rhqyjMTnZ8egN0s/oguJKdAws2rpP1I4QoB2cAhL1hQZsoyk52eGmS0g2YJ+n4GWfEQXYsH8bvAuekitLRwhQDs4hIjoDYYsI/FxI2Xllw5Byz6iC2ago/Lo5faBwgECtJNDGBQUZsgyEh83GOj2tqDDMqUe0QVbuvOYSduoilpLOECAdnIILV7pVsllpCvlWkbS4sbqryhlVfECUvsu9qBlHtEFR+fTlJmfUkMTTTZMN4fW/xxaxo5v3L6MxMeNYtCjrEGHZko9oguOyqPu/WcKvy+ALschTIta7/ZlJD5uJDsA/c/QDGlHdMHRedp/BKv5muOroKk7NKtOPUa4fRlpkR43nIEOyZB2RDcpMpeeaeLZf5zeq0BXrfkYrc+85NplpDRHcUNf4P/CDvQEBlrCEd2UqDx6qd1w4XcE0BU8hJFjY+3iRqYLl5H4/My26to5AC3jiK7HgGjh2AD6Pg6hzlNNKCPrituWkVK5uOEI9HgNtFwjur5BifTgI77CsQF0Jbq0u5aR+LjB1kTbBdiC3iTViK5fULIp581ekaH1quFbj1akXXDLMpIeNxjoREeggzdJM6LrH5TkVZhNC5pVqw5vUkb2Dy5fRuLjhjPQMozour4Z7jUxwytAsxo9YYHLl5H4uMHWRG1Bvxe8UeiIblJkLrVoM1j42QO0Gw7hYZ9aFDU326XLSHzcSHAEespGYSO6cVN2UD2/lsJRAbSb83RcwgGXLSPxcaMY9Fv2oI0e0UXnU/f+M6hazbrCQYkuU0cOvXwef4Zi5u1xyTJSye/b0H7E6hK9agP63cnpho7o2Nac2b/+KQDtOH6Mn7yk0stIen4u/qkUx6CNGNFNCMuhVv4jqcoj3jXFUO5RXtGh+WrTcTAtXv2ZS+IG23u2BT1OA+2+Ed3E8H3UNmCs6X7SRHFReR1oVnWeeo4mha+/r2UkPm6wn0p5tbM9aHeM6N6akEYvvjqUHvapI/z8FInLK0Hr1ai5P4XO3FKhZSQdNIsbCxyAHstAu2hENynyY+reL5LqNnxJ+FkpHlJeDVqvJ/1eoIFBUZS4+PQ9l5FK44YT0JPSKzWimxC2k7r1jSC/5zt55YcRpZIF0DZ/+bXpS11pYFA0RcTtpZQVFx18HSyNGws+vEht7UBvKPeILjTmMAW9u5wCXg+mZi3fIJ/H/YSDUDy8ALqMw3nY5zFq2Kw9+XcbTW8MmU4jxqbQ+6EZNHn6TgqffYgiYg/TK/7WO8ZB7y2hyTP20sSp2fRe8GYa/f46Chq3lN4YOps69ppIL7YdRA2b+pvidzErEhZAS3AJKBWggQAvgoIODQSKyc8AkUOCS0CpAA0EeBEUdGggUEx+BogcElwCSgVoIMCLoKBDA4Fi8jNA5JDgElAqQAMBXgQFHRoIFJOfASKHBJeAUgEaCPAiKOjQQKCY/AwQOSS4BJQK0ECAF0FBhwYCxeRngMghwSWgVIAGArwICjo0ECgmPwNEDgkuAaUCNBDgRVDQoYFAMfkZIHJIcAkoFaCBAC+Cgg4NBIrJzwCRQ4JLQKkADQR4ERR0aCBQTH4GiBwSXAJKBWggwIugoEMDgWLyM0DkkOASUCpAAwFeBAUdGggUk58BIocEl4BSARoI8CIo6NBAoJj8DBA5JLgElOqyM/g/5liT8Xbdsy0AAAAASUVORK5CYII=";
var ICON_64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAACXBIWXMAAAsTAAALEwEAmpwYAAAGrElEQVR4nOWaeVRUZRjG75+jZWqCWmHHzMpKrahOZnZCE8PATD0nUFOYwSxBz8mTGgoiiGyyyuaCrCI7sgso+yL7jnsmi4KA7LjreTrfvTOXAUGd43C+2/DH8+fMPO9zf9993/fOZUQTp2Asi6FtgLYY2gZoi6FtgLYY2gZoi6FtgLYY2gZoi6FtgLYY2gZoi6FtgLYY2gZoi6FtgLYY2gZoi6FtQCUCWKi1Aq5ecTCzPAK91cZQ03h3bAWgt8YYlXVPUFb9CMWVD5Fb3A9zm0DMmD1/bASgu9oYFXVPUFr9CEUVD5Bfeh85RXeRktUBnZXGYyOA8trHKKl6iMLyB8gvuYfswrvIyO/HmZxerBObq3oAEpTVPGbxP1d2H3nF95B17g7S8/qRlt2L5PQuLFluqLoB/LhKwuNfUHofuUV3kVlwB2dz+5Ca1YPk9G6En6qHmsZs1Q2gpOoRj38Oj38fUjJ7kHS2C/GpnRBvcVDdAIrl8M+Ww/90RjcSz3YhLrUDgRFXMX7yVNULYPnPEhRVPOTxz+Lx70VyRjcSznQiNqUDUUntmPeltmoGUCiHf6YM/6weJKV3IT6tE6dO30ZkYjt012xTxQDEOFf2gMefnP+0nF6czuzh8Y9Jvo2IhDask+xXvQB0Voql+MvaXx9Ss2X4d7H4Rye1Izy+DcZb3V/6916dMh3qGh9g3CQ14QSQL53+Mgv62fPP4d/N4x+V2I6wuFYYmyoWwFuz5mORthgbNntgt00GDrhXwdHrIuw9L+CV16cJJ4C8IdPfAP6dLP6RCW0IjW2FxNTtud83bpI6Pl+4Ctv+joC77zW4HfsHLkeuwsnnMhy9L8HB8wLsDp0XTgA/rBQjl5/++rjpbwj+EfFtOHnqFiQmzw5g7hc6sHLKg6ffdRw6/i9fvPPhKzhIive6CDuPC7B1rxNQAD+JpfgPTH8D+Hew+IfHtSIk5hbEJq7DfscEtTdgILaDl/91ePpzxbsfuwbXo9LiydUn6JPiD52HjVutkAIwGoR/yjD4h8W24kRMC4y2PB3A5OkzsXNfPLwDG+DlXw8PUrwvKZ5c/Ssc+l6X2HNP0D/gXof9rjXCCiBryPQ3gP9tFv/Q2FsIjn46AHJH/8siBj6k+IB6eBD05c/94csc+p4Efa54G9daWLtUY7xQAli2wuip5SdBhj/b/lrZ8x8U1QzDPwYHsH6TM3yCGuEdUD/o3PPoS889h34di761Sw2snKuEFUDGMMtPjHT6I+0vJKYFQZEkABf+cx9rarNX3jugAZ6D0OeK59DnWh459wfcaln0rZyrYelUKawA0odZfqKl0x/B/0R0CwIjbmLj7wMB7LJK4NAnxftdf2bLk517gv4+pyrsdawQTgDaekYjLj9k+iP4B0c1IyD8JjZu5gKYPXcRfAIb2XP/Ii2PQ58r3vJgJfbYFr+0b5HyAjAccfmRx98/7AY2SANYs36fFP0Xa3kc+lzxFo4V2G6RLqwA0kZYfsj0J8PfL/QGfv3Nmf3MTst4hVoeOfcy9M0dymFoEiCcAJbqGY64/Mjjf/xkEx+Ak3eNQi2PLZ5cfYdy7LErw7JVZsIJQGuZwYjLD5n+ZPj7hjRh/SYn9qkQufKKtDwWfYcK7LEvw27bUrz/ibZwAtBcoDPi8sPh38zifyykkQ1govoMhVsei759OXbblcLULAXjJqsLJ4B35miOuPwER7Vw+Ic24eiJRqwzJgFoKNzyzKXom9mWYMES5f3ZwijjS8iDiZCoq8MuP2T68w+/Cd+TTTgS3IC10gAUaXnsubcnxZdi8/YYdnwWVAAicle3CBh2+QmMbIZfGIf/4aAGrJUcZANQpOWZS8/9DusCzPxwkdKKFykzgDmffsve/IYuPwERBP8bLP4+gfUwkAagSMsj597MphifLTRQavEiZb8fsMM86KnlRx5/svAYiLkAFGl5u/YXQvObtUovXqTsACZNmwFnn/xB0x+HfxOLP3nYoS8N4EVbnsmuRMz66LtRKV40Gm+IkP//zKyj+OlPHn8y8+sbObIBPK/l7bDOw2LdPzFhypujVrxotF6RIQ81tXSMYOOSJcWf2/dJ79c3dMRr6hrDtjxz+xKItwbh6+8lmDj17VEtfFQDEPFBqGHWnK+wVG8L++Bj0zZfLNE1Ya+q2NQP+mIX6P2yF1rLTfHevMVKbW+CCED0PxBD2wBtMbQN0BZD2wBtMbQN0BZD2wBtMbQN0BZD2wBtMbQN0BZD2wBtMbQN0BZD2wBtMbQN0BZD2wBt/QeTY5LZjN0p1QAAAABJRU5ErkJggg==";
var APP_HTML = `<!-- Life OS 11.46. Source of truth for UI; build.py embeds this file in the Worker.
One design system owns layout and components. Finance and Life OS logic are preserved. -->
<!doctype html>
<html lang="it">
  <head><script>const lifeOSContract = {"version":2,"expenseCategories":["Alimentari","Ristorazione","Casa","Affitto","Condominio","Arredamento e casa","Utenze","Elettricit\xE0","Gas","Acqua","Abbonamenti","Auto","Assicurazione","Bollo","Manutenzione auto","Benzina","Shopping","Salute","Palestra","Dentista","Farmaci e visite","Svago","Viaggi","Altro"],"incomeCategories":["Stipendio","Interessi","Rimborsi","Altro"],"planKinds":{"advance":"Anticipa budget","goal":"Obiettivo finito","fund":"Fondo senza scadenza","fixed":"Spesa ricorrente fissa","estimated":"Utenza con quota stimata","recovery":"Rateizza una spesa"},"planStatuses":{"active":"In corso","stopped":"Interrotto","closed":"Concluso","cancelled":"Annullato","pendingPayment":"Pagamento da completare"},"plansUnavailable":"Il server collegato non supporta Piani v2. Aggiorna il Worker usato da questa piattaforma e riprova. I piani precedenti sono conservati."}<\/script>
    <meta charset="utf-8" />
    <script>
      try {
        document.documentElement.dataset.theme =
          localStorage.getItem("life-theme") ||
          (matchMedia("(prefers-color-scheme: light)").matches
            ? "light"
            : "dark");
      } catch (e) {
        document.documentElement.dataset.theme = "dark";
      }
    <\/script>
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1, viewport-fit=cover"
    />

    <title>Life OS</title>
    <meta name="theme-color" content="#0c0c0e" />
    <link rel="manifest" href="/manifest.webmanifest" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta
      name="apple-mobile-web-app-status-bar-style"
      content="black-translucent"
    />
    <meta name="apple-mobile-web-app-title" content="Life OS" />
    <link rel="icon" type="image/png" href="/favicon.png?v=1160periwinkle" />
    <link
      rel="apple-touch-icon"
      sizes="180x180"
      href="/apple-touch-icon.png?v=1160periwinkle"
    />

<style id="lifeos-design-system">/* Life OS: one set of tokens, one layout, one component system. */
:root {
 font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;font-size:14px;line-height:1.45;
 --os-bg:#0c0c0e;--os-panel:#171719;--os-panel-2:#222225;--ink:#f4f5f7;--muted:#a2a2a9;--line:#303034;--os-accent:#a5aeed;--os-focus:#a5aeed;--green:var(--os-accent);--red:#ee858e;
 --surface:var(--os-panel);--blue:var(--os-accent);--os-secondary:var(--muted);--os-border:var(--line);--os-text:var(--ink);
 --safe-top:env(safe-area-inset-top,0px);--safe-bottom:env(safe-area-inset-bottom,0px);--page-gutter:20px;--card-padding:20px;--card-radius:22px;--space:16px;--nav-height:72px;
 color-scheme:dark;background:var(--os-bg);color:var(--ink);
}
html[data-theme="light"] {--os-bg:#f3f3f5;--os-panel:#fff;--os-panel-2:#e8e8ec;--ink:#202024;--muted:#64646d;--line:#dcdce1;--os-accent:#565f9c;--os-focus:#565f9c;--green:var(--os-accent);--red:#b53747;color-scheme:light;}
*,*::before,*::after {box-sizing:border-box;} body {margin:0;background:var(--os-bg);color:var(--ink);-webkit-text-size-adjust:100%;}
button,input,select,textarea {font:inherit;}button {cursor:pointer;color:inherit;touch-action:manipulation;-webkit-tap-highlight-color:transparent;}
button {display:inline-flex;align-items:center;justify-content:center;gap:6px;min-height:40px;padding:9px 14px;background:transparent;border:1px solid var(--line);border-radius:12px;}
button:disabled {opacity:.45;cursor:default;}button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible,summary:focus-visible {outline:2px solid var(--os-focus);outline-offset:3px;}
button:hover {background:var(--os-panel-2);} button:active {opacity:.8;} a {color:var(--os-accent);} svg {display:block;}svg:not([width]) {max-width:100%;}
h1,h2,h3,p {margin:0;}h1 {font-size:32px;line-height:1.15;letter-spacing:-1.2px;font-weight:750;}h2 {font-size:19px;line-height:1.3;letter-spacing:-.4px;}h3 {font-size:15px;line-height:1.4;}small {font-size:12px;color:var(--muted);}b,strong {font-weight:650;font-variant-numeric:tabular-nums;} summary {cursor:pointer;}summary::-webkit-details-marker {display:none;}summary {list-style:none;}
.hidden,[hidden] {display:none!important;}.view {display:none;}.view.active {display:block;}.income,.positive {color:var(--green);}.outgo,.outgoings,.negative,.danger {color:var(--red);}.muted,.hint,.empty,.os-empty,.os-task-empty {color:var(--muted);}.hint {font-size:12px;margin-top:12px;}.empty,.os-empty,.os-task-empty {padding:16px 0;}
.shell {display:grid;grid-template-columns:208px minmax(0,1fr);min-height:100svh;}.sidebar {position:sticky;top:0;height:100svh;display:flex;flex-direction:column;padding:28px 18px;border-right:1px solid var(--line);background:var(--os-panel);}
.brand {display:flex;align-items:center;gap:10px;font-size:20px;font-weight:700;margin-bottom:32px;}.brand .mark,.brand .mark svg {width:28px;height:34px;}.nav {display:grid;gap:6px;}.nav button {justify-content:flex-start;border:0;gap:12px;min-height:48px;color:var(--muted);}.nav button.active {color:var(--os-accent);background:color-mix(in srgb,var(--os-accent) 12%,transparent);}.nav-symbol {width:22px;height:22px;flex:none;}.sidebar-foot {margin-top:auto;font-size:11px;color:var(--muted);}
main {width:100%;max-width:1140px;margin:0 auto;padding:32px 32px 104px;min-width:0;}.top {margin-bottom:20px;}.page-heading {display:flex;justify-content:space-between;align-items:center;gap:16px;min-height:44px;}.page-heading h1 {min-width:0;}.header-tools {display:flex;align-items:center;gap:8px;flex:none;}.theme-toggle {width:44px;height:44px;min-height:44px;padding:0;border-radius:50%;font-size:23px;line-height:1;}
.header-meta {margin-top:10px;}.home-context {display:none;color:var(--muted);font-size:13px;}.dashboard-mode .home-context {display:block;}.header-meta:not(:has(.top-right:not(.hidden))):not(:has(.dashboard-mode)) {margin-top:0;}.dashboard-mode .header-meta {margin-top:8px;}body:not(.dashboard-mode) .header-meta:has(.top-right.hidden) {display:none;}
.top-right {display:flex;align-items:center;justify-content:space-between;}.period {display:flex;align-items:center;gap:8px;width:210px;}.period button {width:32px;height:32px;min-height:32px;padding:0;border:0;font-size:23px;color:var(--muted);}.period strong {flex:1;text-align:center;font-size:13px;font-weight:550;}.sync {font-size:11px;color:var(--muted);}
.page-actions:empty {display:none;}.os-more-menu {position:relative;}.os-more-menu summary {display:grid;place-items:center;width:40px;height:40px;border:1px solid var(--line);border-radius:50%;font-size:20px;color:var(--muted);}.os-more-menu summary svg {width:20px;height:20px;}.os-more-menu > div {position:absolute;top:48px;right:0;z-index:60;background:var(--os-panel);padding:8px;border:1px solid var(--line);border-radius:14px;box-shadow:0 12px 30px #0003;min-width:200px;}.os-more-menu > div button {display:flex;width:100%;justify-content:flex-start;border:0;white-space:nowrap;font-size:13px;}
.finance-tabs,.os-category-tabs {display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:4px;border:1px solid var(--line);border-radius:17px;background:var(--os-panel);margin-bottom:16px;position:relative;}.finance-tabs::-webkit-scrollbar,.os-category-tabs::-webkit-scrollbar {display:none;}.finance-tabs button,.os-category-tabs button {border:0;flex:1;white-space:nowrap;padding:9px 12px;min-height:40px;color:var(--muted);font-size:13px;}.finance-tabs button.active,.os-category-tabs button.active {background:var(--os-panel-2);color:var(--os-accent);font-weight:650;}.os-category-tabs .add {position:sticky;right:0;flex:0 0 36px;min-width:36px;background:var(--os-panel);font-size:22px;}.os-category-tabs button:not(.add) {flex:0 0 auto;}
.card,.os-card,.extra-card {background:var(--os-panel);border:1px solid var(--line);border-radius:var(--card-radius);min-width:0;}.pad,.os-card,.extra-card {padding:var(--card-padding);}.card-title,.os-topline,.overview-section-heading,.extra-card-head {display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:18px;}.card-title .actions,.actions,.chart-range {display:flex;align-items:center;gap:6px;}.save,.os-button.primary {background:var(--os-accent);color:var(--os-bg);border-color:transparent;font-weight:600;}.save:hover,.os-button.primary:hover {filter:brightness(1.06);}.ghost,.os-button {background:transparent;}.os-button:not(.primary),.os-row-action {border:0;color:var(--os-accent);padding:6px 8px;}.os-icon-button,.privacy-toggle,.os-wait,.os-drag-handle {width:36px;height:36px;min-height:36px;flex:none;padding:6px;border:0;border-radius:50%;color:var(--muted);}.privacy-toggle svg {width:22px;height:22px;}.os-icon-button {font-size:25px;}.privacy-toggle:hover {background:var(--os-panel-2);}
.page-fab {position:fixed;right:24px;bottom:24px;z-index:35;}.page-fab .fab-button {display:grid;place-items:center;width:56px;height:56px;min-height:56px;padding:0;border-radius:50%;box-shadow:0 5px 18px #0004;border:0;}.fab-button svg {width:24px;height:24px;flex:none;}body:has(.modal-wrap:not(.hidden),dialog[open]) .page-fab {visibility:hidden;}
.os-home {display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:var(--space);}.os-home-daygrid {display:grid;grid-template-columns:minmax(0,1fr) auto;gap:14px;}.os-home-daygrid > div {border-left:3px solid var(--shift-color,var(--os-accent));padding-left:12px;}.os-home-daygrid h2 {font-size:25px;margin-top:5px;}.os-shift-time {font-size:.7em;font-weight:550;white-space:nowrap;}.os-home-label,.os-home-tomorrow > span {display:block;font-size:12px;color:var(--muted);}.os-home-tomorrow {align-self:center;}.os-home-tomorrow strong {display:block;margin-top:5px;font-size:16px;}.os-routine {display:flex;gap:16px;margin-top:18px;padding-top:16px;border-top:1px solid var(--line);align-items:center;}.os-routine-head {flex:none;min-width:54px;}.os-routine-head > span {color:var(--muted);font-size:12px;display:block;}.os-routine-head b {display:block;}.os-routine-manage {padding:6px 0;border:0;min-height:32px;color:var(--os-accent);font-size:12px;}.os-routine-items {display:flex;gap:7px;flex-wrap:wrap;min-width:0;}.os-routine-check {gap:7px;padding:8px 10px;min-height:42px;font-size:13px;white-space:normal;}.os-routine-tick {display:grid;place-items:center;width:17px;height:17px;border:1.5px solid var(--muted);border-radius:5px;flex:none;line-height:1;}.os-routine-check.checked .os-routine-tick {background:var(--os-accent);border-color:var(--os-accent);color:var(--os-bg);}
.os-home-agenda .os-topline h2 {color:var(--muted);}.os-home-agenda .os-topline .os-button {font-size:12px;white-space:nowrap;}.os-home-task {display:flex;align-items:center;gap:12px;padding:14px 0;min-height:58px;}.os-home-task + .os-home-task {border-top:1px solid var(--line);}.os-home-task-title {min-width:0;flex:1;text-align:left;justify-content:flex-start;padding:0;border:0;min-height:30px;font-size:16px;line-height:1.4;overflow-wrap:anywhere;}.os-check {display:grid;place-items:center;width:24px;height:24px;min-height:24px;padding:0;border-radius:50%;border:1.5px solid var(--muted);flex:none;}.os-check.checked {background:var(--os-accent);color:var(--os-bg);border-color:var(--os-accent);}.os-check.checked::after {content:'\u2713';font-size:14px;}
.os-agenda-entry {display:flex;align-items:center;gap:8px;padding:12px 0;border-top:1px solid var(--line);}.os-agenda-row {display:flex;justify-content:flex-start;gap:12px;flex:1;min-width:0;border:0;text-align:left;padding:0;}.os-agenda-date {text-align:center;width:36px;flex:none;}.os-agenda-date b,.os-agenda-date small {display:block;}.os-agenda-title {flex:1;min-width:0;}.os-agenda-title small {display:block;margin-top:3px;}.os-agenda-done {font-size:11px;border:0;color:var(--os-accent);padding:4px;}.os-home-finance {align-self:start;}.os-home-money {display:grid;grid-template-columns:minmax(0,1fr) 36px;align-items:start;gap:12px;padding-bottom:18px;border-bottom:1px solid var(--line);}.os-money-primary {container-type:inline-size;}.os-money-primary small {display:block;margin-bottom:8px;}.os-money-primary strong {display:block;font-size:min(42px,calc(100cqw / var(--money-units,6)));line-height:1.1;letter-spacing:-1.3px;white-space:nowrap;}.os-home-submoney.large-amount {grid-template-columns:minmax(0,1fr);}.os-home-submoney {display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:20px;padding-top:16px;}.os-home-metric > span {display:block;font-size:12px;color:var(--muted);margin-bottom:6px;}.os-home-metric > b {display:block;font-size:18px;line-height:1.4;letter-spacing:0;white-space:nowrap;}.os-home-private {padding-right:0;}.os-home-money .privacy-toggle {position:static;}.os-home-private .privacy-toggle {position:absolute;right:-4px;top:12px;width:32px;height:32px;min-height:32px;}.os-home-prayer {grid-column:1/-1;}.os-sunline-meta {display:flex;justify-content:space-between;gap:10px;color:var(--muted);font-size:12px;}.os-sunline-meta strong {text-align:right;font-size:12px;}.os-home-times summary {color:var(--os-accent);font-size:12px;padding-top:10px;}.os-prayer-list {display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:12px;}.os-prayer {display:flex;justify-content:space-between;font-size:12px;gap:8px;}.os-prayer.next {color:var(--os-accent);}
.os-category-page {padding:0 18px;}.os-task {display:grid;grid-template-columns:28px 26px minmax(0,1fr) 30px;gap:10px;align-items:center;min-height:72px;padding:16px 0;}.os-task + .os-task {border-top:1px solid var(--line);}.os-task-title {justify-content:flex-start;text-align:left;border:0;padding:0;min-height:24px;font-size:16px;line-height:1.45;overflow-wrap:anywhere;}.os-drag-handle {width:28px;min-height:44px;padding:0;cursor:grab;touch-action:none;user-select:none;-webkit-user-select:none;}.os-drag-handle svg {width:14px;height:22px;}.os-wait {width:30px;padding:5px;}.os-wait svg {width:17px;height:19px;}.os-task.is-dragging {opacity:.6;}.os-task-section {border-top:1px solid var(--line);padding-top:18px;}.os-task-section h3 {color:var(--muted);font-size:13px;margin-bottom:4px;font-weight:500;}.os-task-section .os-task {grid-template-columns:26px minmax(0,1fr) 30px;}.os-completed {border-top:1px solid var(--line);padding:16px 0;}.os-completed summary {font-size:13px;color:var(--muted);}.os-completed .os-task {grid-template-columns:26px minmax(0,1fr) 30px;}.os-task-delete,.os-delete-completed {font-size:12px;color:var(--red);border:0;}.due-badge {display:inline-block;font-size:10px;font-weight:500;color:var(--muted);margin-left:7px;}.due-badge.overdue {color:var(--red);}
.os-month-header {display:grid;grid-template-columns:36px minmax(0,1fr) 36px;align-items:center;margin-bottom:16px;}.os-month-header h2 {text-align:center;text-transform:capitalize;font-size:22px;}.os-month-header button {border:0;min-height:36px;padding:0;font-size:25px;color:var(--muted);}.os-weekdays {display:grid;grid-template-columns:repeat(7,minmax(0,1fr));text-align:center;font-size:12px;color:var(--muted);margin-bottom:10px;}.os-days {display:grid;gap:6px;}.os-calendar-week {display:grid;grid-template-columns:repeat(7,minmax(0,1fr));padding:3px;background:var(--os-panel-2);border:1px solid var(--line);border-radius:13px;gap:2px;}.os-day {display:grid;grid-template-columns:1fr;grid-template-rows:20px 20px 12px;justify-items:center;align-items:center;align-content:center;gap:3px;width:100%;height:64px;min-height:64px;padding:5px 0;border:0;border-radius:9px;line-height:1;}.os-day b {grid-row:1;display:grid;place-items:center;width:24px;height:20px;line-height:20px;font-size:14px;color:var(--ink);}.os-day .os-shift {grid-row:2;font-size:12px;font-weight:700;width:calc(100% - 8px);max-width:48px;height:20px;display:flex;align-items:center;justify-content:center;border-radius:5px;background:var(--shift-color);color:#101215;}.os-day-mark {grid-row:3;display:grid;place-items:center;min-height:10px;height:10px;line-height:10px;font-size:10px;font-weight:600;color:var(--ink);}.os-day-mark.dot::after {content:'';width:3px;height:3px;border-radius:50%;background:currentColor;}.os-day.today b {background:var(--ink);color:var(--os-bg);border-radius:50%;}.os-day.selected {background:color-mix(in srgb,var(--os-accent) 18%,var(--os-panel));box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--os-accent) 45%,transparent);}.os-day.other {opacity:.45;}
.os-calendar-week > .os-day:nth-child(n+6) {background:color-mix(in srgb,var(--os-panel-2) 86%,black);border-radius:0;}
.os-calendar-week > .os-day:nth-child(n+6).selected {background:color-mix(in srgb,var(--os-accent) 18%,color-mix(in srgb,var(--os-panel-2) 86%,black));}.os-calendar-details {margin-top:20px;padding-top:18px;border-top:1px solid var(--line);}.os-calendar-details > h3 {margin-bottom:16px;}.os-mini {display:flex;align-items:center;justify-content:space-between;gap:10px;padding:12px 0;border-bottom:1px solid var(--line);}.os-mini > div:first-child {flex:1;min-width:0;}.os-mini small {display:block;}.os-mini:last-child {border:0;}.os-section-label {color:var(--muted);margin-top:16px;font-size:12px;}.os-event-options {position:relative;font-size:12px;}.os-event-options summary {padding:8px;color:var(--muted);}.os-event-options[open] button {display:block;}.os-tools-drawer {margin-top:16px;color:var(--muted);font-size:13px;}.os-palette-state {padding:12px 0;}.os-palette {display:flex;gap:8px;flex-wrap:wrap;}.os-palette button.active {border-color:var(--os-accent);background:var(--os-panel-2);}.os-palette-stop {margin-top:8px;}
[data-kind="morning"] {--shift-color:#b4c6e7;}[data-kind="afternoon"] {--shift-color:#c6e0b4;}[data-kind="night"] {--shift-color:#808080;}[data-kind="rest"] {--shift-color:#f4b084;}[data-kind="holiday"] {--shift-color:#ffff00;}html[data-theme="light"] [data-kind="morning"] {--shift-color:#b4c6e7;}html[data-theme="light"] [data-kind="afternoon"] {--shift-color:#c6e0b4;}html[data-theme="light"] [data-kind="night"] {--shift-color:#808080;}html[data-theme="light"] [data-kind="rest"] {--shift-color:#f4b084;}html[data-theme="light"] [data-kind="holiday"] {--shift-color:#ffff00;}
.overview-essential {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);}.overview-essential > section:not(.overview-flow),.overview-flow > div {border:1px solid var(--line);background:var(--os-panel);border-radius:var(--card-radius);padding:var(--card-padding);}.overview-label {font-size:20px;color:var(--ink);line-height:1.25;font-weight:650;margin:0;}.overview-primary,.overview-accounts {container-type:inline-size;}.overview-balance {font-size:min(42px,calc(100cqw / var(--money-units,6)));line-height:1.1;font-weight:700;letter-spacing:-1.2px;white-space:nowrap;}.budget-equation {display:grid;grid-template-columns:minmax(0,1fr) auto minmax(0,1fr) auto minmax(0,1fr);align-items:baseline;gap:7px;margin-top:18px;padding-top:16px;border-top:1px solid var(--line);font-size:clamp(11px,3.3vw,15px);font-variant-numeric:tabular-nums;}.budget-equation span:nth-child(3) {text-align:center;}.budget-equation strong {text-align:right;}.budget-equation strong {margin-left:0;}.overview-section-heading {display:grid;grid-template-columns:minmax(0,1fr) 36px;align-items:center;gap:12px;min-height:36px;margin-bottom:18px;}.overview-section-heading h2 {font-size:20px;line-height:1.25;font-weight:650;margin:0;}.overview-primary .overview-section-heading {grid-template-columns:minmax(0,1fr);}.overview-total strong {font-size:min(42px,calc(100cqw / var(--money-units,6)));line-height:1.1;display:block;margin:0;white-space:nowrap;letter-spacing:-1.2px;}.overview-total small {display:block;}.overview-flow {grid-column:1/-1;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);}.overview-flow span {display:block;color:var(--muted);font-size:12px;margin-bottom:8px;}.overview-flow strong {font-size:25px;line-height:1.2;white-space:nowrap;}
.budget-flow,.budget-charts {display:grid;gap:var(--space);}.budget-charts {grid-template-columns:repeat(2,minmax(0,1fr));}.budget-charts > .integrated-chart {grid-column:1/-1;}.budget-charts .flow-card {grid-column:auto;}.kv {display:grid;grid-template-columns:minmax(0,1fr) max-content;gap:12px;padding:12px 0;border-bottom:1px solid var(--line);}.kv > span {min-width:0;overflow-wrap:anywhere;}.kv > strong {white-space:nowrap;text-align:right;}.kv:last-child {border:0;}.kv.total {font-weight:650;}.daily-budget {display:grid;gap:6px;padding-top:16px;}.daily-budget > span {font-size:12px;color:var(--muted);}.daily-budget strong {font-size:24px;}.budget-settings {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);padding-top:20px;}.budget-settings-wrap > summary,.annual-card > summary,.budget-history summary {font-size:16px;font-weight:600;}.balance-settings-column {display:grid;gap:20px;align-content:start;}.edit-line {display:flex;justify-content:space-between;align-items:center;gap:12px;padding:14px 0;border-bottom:1px solid var(--line);}.edit-line small {display:block;margin-top:4px;}.edit-controls {display:flex;align-items:center;gap:8px;}.edit-input {width:100px;}.budget-detail-content {padding-top:18px;}.annual-row,.annual-head {display:grid;grid-template-columns:1fr repeat(6,minmax(0,1fr));gap:8px;padding:12px 0;border-top:1px solid var(--line);font-size:12px;}.annual-row.selected {color:var(--os-accent);}.annual-head {font-weight:600;color:var(--muted);}.planning-inputs {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;}.planning-inputs label {display:grid;gap:6px;font-size:12px;}.fund-meter {display:flex;height:7px;background:var(--os-panel-2);border-radius:7px;overflow:hidden;margin:18px 0 8px;}.fund-meter i {display:block;height:100%;background:var(--os-accent);}#fund-surplus {background:color-mix(in srgb,var(--os-accent) 40%,var(--os-panel-2));}.fund-labels {display:flex;justify-content:space-between;color:var(--muted);font-size:12px;}.projection-result {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;margin-top:18px;}.projection-result span,.projection-result small {display:block;color:var(--muted);font-size:12px;}.projection-result strong {font-size:24px;}.planning-actions {display:flex;gap:8px;flex-wrap:wrap;margin-top:18px;}.plan-row {display:flex;justify-content:space-between;gap:10px;padding:10px 0;border-top:1px solid var(--line);}
.chart-scroll,.sankey-scroll,.table-scroll {overflow-x:auto;min-width:0;}.trend-svg,.sankey-svg {width:100%;height:auto;}.trend-svg text,.sankey-svg text {fill:var(--muted);font-size:11px;}.grid-line,.axis {stroke:var(--line);stroke-width:1;}.income-line,.income-path {stroke:var(--green);fill:none;stroke-width:2;}.spent-line,.spent-path {stroke:var(--red);fill:none;stroke-width:2;}.wealth-record-line,.wealth-estimate-line {stroke:var(--os-accent);fill:none;stroke-width:2;}.wealth-estimate-line {stroke-dasharray:4 4;}.wealth-dot {fill:var(--os-accent);}.chart-pair {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);}.flow-legend,.chart-values,.trend-values,.sankey-totals,.wealth-series {display:flex;gap:12px;flex-wrap:wrap;color:var(--muted);font-size:12px;}.flow-legend {margin-top:10px;}.flow-legend i {display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:5px;}.income-key,.spent-key {display:inline-flex;align-items:center;gap:5px;background:none;}.income-key::before,.spent-key::before {content:"";width:7px;height:7px;border-radius:50%;background:var(--green);}.spent-key::before {background:var(--red);}.chart-range button,.wealth-series button {min-height:30px;padding:4px 7px;font-size:11px;}.chart-range .active,.wealth-series .active {color:var(--os-accent);border-color:var(--os-accent);}.liquid-chart-heading {display:flex;justify-content:space-between;gap:8px;margin-bottom:12px;}.sankey-ribbon {opacity:.65;}.sankey-label {fill:var(--ink)!important;}.sankey-totals {margin-bottom:16px;}.expense-details {margin-top:14px;}.expense-category {padding:10px 0;border-top:1px solid var(--line);}.expense-category > summary {display:flex;justify-content:space-between;}.overview-recent-row {display:flex;justify-content:space-between;gap:8px;padding:8px 0;font-size:12px;}.quick-classify {font-size:11px;min-height:30px;padding:4px 7px;}
.breakdown {display:grid;grid-template-columns:120px minmax(0,1fr);gap:16px;align-items:center;}.category-ring {position:relative;width:120px;height:120px;flex:none;}.category-ring svg {width:120px;height:120px;}.category-ring-label {position:absolute;inset:22%;display:flex;flex-direction:column;justify-content:center;align-items:center;pointer-events:none;}.category-ring-label small {font-size:10px;}.category-ring-label strong {font-size:13px;white-space:nowrap;}.category-legend {min-width:0;}.bar-row {display:grid;grid-template-columns:minmax(0,1fr) auto;gap:4px 8px;margin-bottom:12px;font-size:12px;}.bar-row span {overflow-wrap:anywhere;}.bar {grid-column:1/-1;height:4px;background:var(--os-panel-2);border-radius:3px;overflow:hidden;}.bar i {display:block;height:100%;}.category-swatch {display:inline-block;width:7px;height:7px;border-radius:50%;margin-right:5px;}.details-label {margin-top:18px;color:var(--muted);font-size:12px;}.small-arrow {width:28px;height:30px;min-height:30px;border:0;padding:0;font-size:20px;}.category-month {font-size:12px;color:var(--muted);white-space:nowrap;}
.filters {display:flex;gap:10px;margin-bottom:18px;}.filters .search {flex:1;min-width:0;}.tabular {border-collapse:collapse;width:100%;font-size:13px;}.tabular th {color:var(--muted);font-size:11px;text-align:left;font-weight:500;}.tabular td,.tabular th {padding:12px 8px;border-bottom:1px solid var(--line);}.tabular th:first-child,.tabular td:first-child {padding-left:0;}.tabular .num {text-align:right;white-space:nowrap;}.tx-description-row {display:flex;justify-content:space-between;gap:12px;}.tx-description-text small {display:block;}.tx-actions {display:flex;gap:6px;}.tx-actions button {min-height:30px;font-size:11px;padding:4px 6px;}.movement-list {display:none;}.movement-more {margin-top:16px;}.extra-grid {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;}.extra-toolbar {display:none;}.extra-card-head {display:grid;grid-template-columns:minmax(0,1fr) max-content;align-items:baseline;}.extra-card-head h3 {min-width:0;overflow-wrap:anywhere;}.extra-card-head strong {white-space:nowrap;font-size:18px;}.extra-metadata {display:flex;justify-content:space-between;color:var(--muted);font-size:12px;gap:8px;margin-bottom:18px;}.extra-card-controls {display:flex;gap:8px;flex-wrap:wrap;}.extra-card-controls button {font-size:12px;}.extra-state-row {display:flex;align-items:center;gap:8px;flex:1;}.state-tag {font-size:11px;border-radius:6px;background:var(--os-panel-2);padding:5px 8px;color:var(--muted);}.extra-pay-action {color:var(--os-accent);border:0;}.extra-info {padding-top:12px;}
input,select,textarea {display:block;width:100%;min-height:42px;padding:10px 12px;border:1px solid var(--line);border-radius:10px;background:var(--os-panel-2);color:var(--ink);min-width:0;}textarea {min-height:84px;resize:vertical;}input[type=checkbox] {width:18px;min-height:18px;}input::placeholder,textarea::placeholder {color:var(--muted);}.modal-wrap {position:fixed;inset:0;z-index:100;display:flex;align-items:center;justify-content:center;padding:24px;background:#0008;overflow-y:auto;}.modal {background:var(--os-panel);border:1px solid var(--line);border-radius:24px;padding:24px;width:min(600px,100%);max-height:calc(100svh - 48px);overflow-y:auto;}.modal-top {display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:22px;}.modal-top h2 {font-size:22px;}.os-form,.form-grid {display:grid;grid-template-columns:1fr 1fr;gap:14px;}.os-form label,.form-grid label {display:grid;gap:6px;font-size:12px;color:var(--muted);}.os-form .wide,.form-grid .full,.form-grid .wide {grid-column:1/-1;}.form-actions {position:sticky;bottom:0;background:var(--os-panel);padding-top:12px;padding-bottom:4px;z-index:2;}
.form-actions,.os-form-actions {grid-column:1/-1;display:flex;justify-content:flex-end;gap:8px;margin-top:10px;}.os-form-error {grid-column:1/-1;color:var(--red);font-size:13px;}.os-inline-event {margin-top:18px;border-top:1px solid var(--line);padding-top:16px;}.os-routine-manager > div {display:flex;align-items:center;gap:8px;padding:10px 0;border-bottom:1px solid var(--line);}.os-routine-manager span {flex:1;}.os-routine-manager button {font-size:13px;min-height:44px;min-width:44px;padding:4px 7px;}.os-routine-manager span{min-width:0;overflow-wrap:anywhere;}.os-routine-manager small{color:var(--muted);font-size:12px;}.os-routine-dialog > p {color:var(--muted);font-size:12px;margin-bottom:12px;}.os-routine-dialog form {margin-top:16px;}.habit-fields{display:grid;gap:14px;}.habit-fields legend{font-size:12px;color:var(--muted);margin-bottom:6px;}.category-order {padding-top:12px;}.category-order > div {display:flex;align-items:center;gap:6px;padding:8px 0;}.category-order span {flex:1;}
.errorbox {background:color-mix(in srgb,var(--red) 10%,var(--os-panel));border:1px solid var(--red);color:var(--red);padding:12px;border-radius:12px;margin-bottom:16px;}.loading-overlay {position:fixed;inset:0;z-index:80;display:grid;place-items:center;background:#0004;}.loading-panel {display:grid;gap:12px;justify-items:center;background:var(--os-panel);border:1px solid var(--line);border-radius:20px;padding:28px;}.loading-spinner {width:24px;height:24px;border:2px solid var(--line);border-top-color:var(--os-accent);border-radius:50%;animation:spin .8s linear infinite;}@keyframes spin {to {transform:rotate(360deg);}}
@media(max-width:760px) {
 :root {--card-padding:18px;--space:14px;}.shell {display:block;min-height:100svh;}.sidebar {position:fixed;inset:auto 14px calc(12px + var(--safe-bottom));height:var(--nav-height);width:auto;max-width:520px;margin:0 auto;padding:5px;border:1px solid var(--line);border-radius:36px;z-index:40;background:color-mix(in srgb,var(--os-panel) 90%,transparent);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);}.brand,.sidebar-foot {display:none;}.nav {display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:2px;width:100%;height:100%;}.nav button {display:flex;flex-direction:column;justify-content:center;gap:5px;padding:4px 2px;min-height:0;border-radius:30px;font-size:11px;line-height:1.2;}.nav-symbol {width:22px;height:22px;}
 main {padding:calc(22px + var(--safe-top)) var(--page-gutter) calc(164px + var(--safe-bottom));max-width:600px;margin:0 auto;}.top {margin-bottom:18px;}.page-heading {gap:10px;}.header-tools {gap:6px;}h1 {font-size:30px;}.theme-toggle {width:40px;height:40px;min-height:40px;font-size:22px;}.os-more-menu summary {width:36px;height:36px;font-size:18px;}.sync {display:none;}.period {width:190px;gap:4px;}.header-meta {margin-top:10px;}.page-fab {right:20px;bottom:calc(100px + var(--safe-bottom));}.page-fab .fab-button {width:56px;height:56px;min-height:56px;}
 .os-home {grid-template-columns:minmax(0,1fr);}.os-home-daygrid h2 {font-size:24px;}.os-routine {gap:12px;}.os-routine-items {gap:6px;}.os-routine-check {font-size:12px;padding:8px;}.os-money-primary strong {font-size:min(40px,calc(100cqw / var(--money-units,6)));}.os-home-submoney {gap:14px;}.os-home-metric > b {font-size:18px;}.os-sunline-meta {font-size:11px;}.os-sunline-meta strong {font-size:11px;}.os-prayer-list {grid-template-columns:repeat(2,minmax(0,1fr));}
 .os-category-page {padding:0 14px;}.os-task {gap:8px;grid-template-columns:28px 24px minmax(0,1fr) 26px;min-height:68px;padding:16px 0;}.os-task-title {font-size:15px;}.os-wait {width:26px;}.os-drag-handle {width:16px;}.os-category-tabs button {padding:9px 11px;}.os-month-header {margin-bottom:16px;}.os-month-header h2 {font-size:21px;}.os-calendar-week {gap:0;padding:2px;}.os-calendar-details {margin-top:18px;}
 .overview-essential {grid-template-columns:minmax(0,1fr);}.overview-balance,.overview-total strong {font-size:min(42px,calc(100cqw / var(--money-units,6)));}.budget-equation {font-size:clamp(11px,3.3vw,14px);gap:6px;}.overview-flow strong {font-size:clamp(16px,4.8vw,24px);}.overview-flow.large-amount {grid-template-columns:minmax(0,1fr);}.budget-charts,.budget-settings,.extra-grid,.chart-pair {grid-template-columns:minmax(0,1fr);}.budget-charts .flow-card {grid-column:auto;}.daily-budget strong {font-size:23px;}.annual-row,.annual-head {min-width:480px;grid-template-columns:1fr repeat(5,minmax(0,1fr));}.annual-card .budget-detail-content {overflow-x:auto;}.card-title {flex-wrap:wrap;}.card-title h2 {font-size:18px;}.tr-category-card .card-title {flex-wrap:nowrap;}.breakdown {grid-template-columns:110px minmax(0,1fr);gap:12px;}.category-ring,.category-ring svg {width:110px;height:110px;}.category-ring-label strong {font-size:12px;}
 .mobile-ledger > table {display:none;}.movement-list {display:block;}.movement-compact {display:grid;grid-template-columns:42px minmax(0,1fr) auto;gap:8px 12px;padding:16px 0;border-bottom:1px solid var(--line);align-items:start;}.movement-compact time {font-size:11px;color:var(--muted);}.movement-main strong {font-size:14px;overflow-wrap:anywhere;}.movement-main small {display:block;font-size:11px;margin-top:4px;}.movement-compact > b {white-space:nowrap;font-size:13px;}.movement-tools {grid-column:2/-1;display:flex;justify-content:flex-end;gap:4px;}.movement-tools button {width:30px;height:30px;min-height:30px;padding:5px;border:0;}.movement-tools svg {width:17px;height:17px;}.filters {flex-wrap:wrap;}.filters .search {flex-basis:100%;}.filters select {width:100%;}.edit-line {flex-wrap:wrap;}.edit-controls {width:100%;}.edit-input {flex:1;}
 .modal-wrap {align-items:flex-end;padding:calc(12px + var(--safe-top)) 0 0;}.modal {border-radius:24px 24px 0 0;max-height:calc(100svh - 12px - var(--safe-top));padding:22px 20px calc(22px + var(--safe-bottom));width:100%;}.os-form,.form-grid {gap:12px;}.os-form label,.form-grid label {font-size:12px;}input,select,textarea {font-size:16px;}.desktop-only {display:none;}
}
@media(max-width:360px) { :root {--page-gutter:14px;--card-padding:14px;}h1 {font-size:28px;}.os-home-daygrid h2 {font-size:22px;}.os-home-submoney {gap:10px;}.os-home-metric > b {font-size:16px;}.os-home-private {padding-right:0;}.budget-equation {font-size:12px;gap:5px;}.breakdown {grid-template-columns:1fr;}.category-ring {justify-self:center;}.os-sunline-meta {flex-direction:column;}.os-sunline-meta strong {text-align:left;}.os-form,.form-grid {grid-template-columns:1fr;}.os-form label,.form-grid label {grid-column:1/-1;} }
.header-tools .page-fab {position:static;z-index:auto;}.header-tools .page-fab .fab-button {width:44px;height:44px;min-height:44px;border:1px solid var(--line);box-shadow:none;color:var(--os-accent);background:var(--os-panel-2);}.header-tools .theme-toggle {width:44px;height:44px;min-height:44px;}.header-tools .os-more-menu summary {width:44px;height:44px;}
@media(prefers-reduced-motion:reduce) {*,*::before,*::after {animation:none!important;transition:none!important;scroll-behavior:auto!important;}}

.os-category-navigation {display:grid;grid-template-columns:minmax(0,1fr) 40px;gap:8px;margin-bottom:16px;align-items:stretch;}.os-category-navigation .os-category-tabs {margin:0;}.os-category-add {width:40px;padding:0;border-radius:14px;background:var(--os-panel);font-size:22px;}.finance-tabs button {flex:1 1 0;min-width:0;padding:9px 6px;font-size:12px;}
@media(max-width:760px) {.os-routine {display:block;}.os-routine-head {display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:7px;}.os-routine-head > span {display:flex;gap:6px;align-items:baseline;}.os-routine-head b {display:inline;}.os-routine-head .os-routine-manage {min-height:28px;padding:0;}.os-routine-items {display:grid;grid-template-columns:repeat(3,minmax(0,1fr));}.os-routine-check {justify-content:center;min-width:0;padding:8px 5px;overflow-wrap:anywhere;}.os-home-task {padding:12px 0;}}

@media(min-width:761px) {.os-home-day-dashboard {grid-column:1;grid-row:1;}.os-home-finance {grid-column:2;grid-row:1;}.os-home-agenda {grid-column:1/-1;grid-row:2;}.os-home-prayer {grid-row:3;}}
@media(max-width:760px) {.os-home > .os-card {padding:16px;}.os-home .os-topline {margin-bottom:10px;}.os-home-task {min-height:48px;padding:10px 0;}.os-home .os-routine {margin-top:14px;padding-top:12px;}.os-home .os-routine-head .os-routine-manage {min-height:24px;}}

.os-day .os-shift.no-shift {background:transparent;}
.os-day-mark.event-count {min-width:18px;height:12px;line-height:12px;border-radius:4px;background:var(--os-panel);color:var(--ink);font-size:10px;font-weight:600;}
html[data-theme="light"] .os-day .os-shift {color:#101215;}html[data-theme="light"] .os-day[data-kind="night"] .os-shift {color:#fff;}
.budget-calculation {min-width:0;border-top:1px solid var(--line);margin-top:16px;padding-top:14px;}
.card > .budget-calculation {border-top:0;margin-top:0;}
.budget-calculation > summary {display:flex;align-items:center;justify-content:space-between;gap:12px;cursor:pointer;font-weight:500;list-style:none;min-height:28px;}
.budget-calculation > summary::after {content:"+";color:var(--muted);font-size:20px;}
.budget-calculation[open] > summary::after {content:"\u2212";}
.overview-essential > .budget-calculation {grid-column:1/-1;margin:0;border:1px solid var(--line);border-radius:var(--card-radius);padding:var(--card-padding);background:var(--os-panel);}
.os-home-money .os-money-primary {width:100%;}.os-home-money .privacy-toggle {margin-left:auto;}
.category-order > div {display:flex;gap:6px;flex-wrap:wrap;align-items:center;}.category-order > div > span {flex:1;min-width:80px;overflow-wrap:anywhere;}

.overview-analysis-grid {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);margin-top:var(--space);}
.overview-analysis-grid > .integrated-chart {grid-column:1/-1;}
.overview-analysis-grid .wealth-chart-card {order:-1;}
.overview-analysis-grid > .annual-card {grid-column:1/-1;}
.overview-analysis-grid > * {min-width:0;}
.os-day .os-shift:not(.no-shift) {background:var(--shift-color);box-shadow:none;}
html:not([data-theme="light"]) [data-kind="morning"] {--shift-color:#6191bd;}
html:not([data-theme="light"]) [data-kind="afternoon"] {--shift-color:#659b72;}
html:not([data-theme="light"]) [data-kind="night"] {--shift-color:#50545b;}
html:not([data-theme="light"]) [data-kind="rest"] {--shift-color:#ce916d;}
html:not([data-theme="light"]) [data-kind="holiday"] {--shift-color:#d7bf52;}

.os-day[data-kind="night"] .os-shift,.os-day .os-shift[data-kind="night"] {color:#fff;}
@media(max-width:760px) {.overview-analysis-grid {grid-template-columns:minmax(0,1fr);}.overview-analysis-grid > .annual-card,.overview-analysis-grid > .integrated-chart {grid-column:auto;}}
.plans-web {display:grid;gap:var(--space);}.plan-list-row {display:flex;justify-content:space-between;text-align:left;width:100%;gap:var(--space);}.plan-list-row > span:first-child {min-width:0;overflow-wrap:anywhere;}.plan-list-row small,.plan-list-row strong,.plan-list-row span span {display:block;}.plans-web button,input,select {min-height:44px;}.plans-web .kv strong {white-space:normal;}.budget-flow .kv strong small {display:block;white-space:normal;}.budget-flow > section {min-width:0;}.budget-flow svg {width:100%;height:auto;}[data-plan-preview] {max-height:280px;overflow:auto;}@media(max-width:420px){.plans-web .card-title{flex-wrap:wrap;}.budget-flow .kv {grid-template-columns:minmax(0,1fr) minmax(0,1fr);}.budget-flow .kv strong {white-space:normal;overflow-wrap:anywhere;}}
.home-native {display:grid;gap:24px;max-width:680px;margin:auto;}.home-week-grid{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:4px;text-align:center;}.home-week-grid .os-day{width:100%;}.home-week-grid small{display:block;margin-bottom:4px;}.home-summary{font-size:20px;line-height:1.55;}.home-next-time{display:flex;justify-content:space-between;width:100%;border:0;padding:12px 0;}.home-habit{display:flex;width:100%;justify-content:flex-start;border:0;border-radius:0;border-bottom:1px solid var(--line);padding:14px 0;}.home-habit span{font-size:22px;}.os-category-navigation{grid-template-columns:minmax(0,1fr);}.header-tools button,.card-title button,.period button{min-height:44px;min-width:44px;}
.page-heading{display:grid;grid-template-columns:44px minmax(0,1fr) auto;}.page-heading h1{font-size:20px;text-align:center;}.page-heading>.theme-toggle{width:44px;height:44px;min-height:44px;}
.settings-confirm{display:flex;align-items:center;gap:var(--space);}.settings-confirm input{width:24px;min-width:24px;flex:none;}
</style>
  <style id="native-web-parity">
/* Web parity with native 0.9.0. Shift palette and data contracts are unchanged. */
:root {--os-bg:#0b0b0b;--os-panel:#1c1c1e;--os-panel-2:#272729;--ink:#f4f4f5;--muted:#adadad;--os-accent:#dedede;--os-focus:#dedede;--green:#8cbaa1;--red:#d4928f;--card-radius:24px;font-size:17px;}
html[data-theme="light"] {--os-accent:#3b3b3b;--os-focus:#3b3b3b;--green:#387354;--red:#a14947;}
button,input,select,summary {min-height:44px;}small,.hint {font-size:13px;}h2 {font-size:17px;}button {transition:opacity .18s,background-color .16s,transform .18s;}button:active:not(:disabled) {transform:scale(.985);opacity:.75;}
.finance-tabs:not(.hidden) {display:flex;background:transparent;border:0;padding:0;}.finance-tabs:not(.hidden) button{flex:none;}.finance-open {max-width:720px;margin-inline:auto;}.finance-heading {display:flex;align-items:center;justify-content:space-between;gap:16px;}.finance-heading>button {border:0;}.finance-hero {padding:32px 0 24px;text-align:center;}.finance-hero h2 {color:var(--muted);font-weight:500;}.finance-value {display:block;font-size:clamp(32px,7vw,56px);line-height:1.2;letter-spacing:-1.5px;margin:12px 0;overflow-wrap:anywhere;}.finance-hero p {font-size:15px;}.finance-account {display:flex;align-items:center;flex-wrap:wrap;gap:12px;padding:16px 0 24px;}.finance-account>div {flex:1;min-width:0;}.finance-account h2 {color:var(--muted);font-size:15px;font-weight:500;}.finance-account strong {font-size:28px;overflow-wrap:anywhere;}.finance-account>small {flex-basis:100%;}.finance-actions {display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px;padding:8px 0 32px;}.finance-actions button {display:flex;flex-direction:column;border:0;padding:0;min-width:0;background:transparent;}.finance-actions span {display:grid;place-items:center;width:56px;height:56px;border-radius:50%;background:var(--os-panel-2);font-size:28px;border:1px solid var(--line);}.finance-recent {padding-top:16px;}.finance-movement {display:flex;width:100%;justify-content:space-between;gap:16px;text-align:left;border:0;border-radius:0;border-bottom:1px solid var(--line);padding:16px 0;background:transparent;}.finance-movement>span {min-width:0;}.finance-movement strong {display:block;overflow-wrap:anywhere;}.finance-movement small {display:block;}.finance-movement>b {flex-shrink:0;font-size:15px;}
:is(#budget,#analysis,#extras,#movements) .card {background:transparent;border:0;border-radius:0;padding:20px 0;border-bottom:1px solid var(--line);}.overview-analysis-grid,.chart-pair {gap:24px;}.os-calendar-week {background:transparent;border:0;border-top:1px solid var(--line);border-radius:0;padding:8px 0;gap:0;}.os-days {gap:0;}.os-day {height:64px;min-height:64px;background:transparent;border-radius:0;}.os-calendar-week>.os-day:nth-child(n+6),.os-calendar-week>.os-day:nth-child(n+6).selected,.os-day.selected {background:transparent;box-shadow:none;}.os-day b {width:26px;height:26px;border-radius:50%;font-size:15px;}.os-day.today b {background:transparent;color:var(--ink);outline:1px solid var(--muted);}.os-day.selected b {background:var(--os-accent);color:var(--os-bg);outline:0;}.os-day .os-shift {border-radius:6px;height:20px;}.os-day-mark {color:var(--shift-color,var(--muted));}.os-calendar-week>.os-day:nth-child(n+6):not(.selected) b {color:var(--muted);}#calendar>.os-card {background:transparent;border:0;padding:0;}.os-calendar-details {padding-top:24px;}.os-month-header h2 {font-size:26px;}.os-home-week .os-day {background:transparent;}
@supports ((backdrop-filter:blur(20px)) or (-webkit-backdrop-filter:blur(20px))) {.theme-toggle,.fab-button {background:color-mix(in srgb,var(--os-panel-2) 72%,transparent);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);}}
@media(max-width:760px) {.nav {background:color-mix(in srgb,var(--os-panel) 90%,transparent);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);}main {padding-inline:20px;}.overview-analysis-grid,.chart-pair {grid-template-columns:minmax(0,1fr);}.finance-hero {padding-top:24px;}.os-day {min-height:58px;height:58px;}}
.header-tools .page-fab {position:static;z-index:auto;}.header-tools .page-fab .fab-button {width:44px;height:44px;min-height:44px;border:1px solid var(--line);box-shadow:none;color:var(--os-accent);background:var(--os-panel-2);}.header-tools .theme-toggle {width:44px;height:44px;min-height:44px;}.header-tools .os-more-menu summary {width:44px;height:44px;}
@media(prefers-reduced-motion:reduce) {*,*::before,*::after {animation:none!important;transition:none!important;scroll-behavior:auto!important;}}
</style></head>
  <body class="dashboard-mode">
    <div class="shell">
      <aside class="sidebar">
        <div class="brand">
          <span class="mark"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 116" aria-hidden="true"><defs><linearGradient id="growthMint" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#d3d8ff"/><stop offset="1" stop-color="#8d98dc"/></linearGradient><linearGradient id="growthTeal" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#a5aeed"/><stop offset="1" stop-color="#6977bf"/></linearGradient></defs><path d="M8 6 C26 6 40 20 40 38 L40 110 C20 110 8 99 8 79 Z" fill="url(#growthMint)"/><path d="M44 110 L44 82 C44 58 65 40 94 40 L94 66 C94 92 74 110 44 110 Z" fill="url(#growthTeal)"/></svg></span>
          <span>Life OS</span>
        </div>
        <nav class="nav" aria-label="Navigazione principale">
          <button data-view="today" class="active">
            <svg
              class="nav-symbol"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z" />
              <path d="M9 21v-7h6v7" /></svg
            >Dashboard
          </button>
          <button data-view="tasks">
            <svg
              class="nav-symbol"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <rect x="4" y="4" width="16" height="16" rx="3" />
              <path d="m8 12 3 3 5-6" /></svg
            >Attivit\xE0
          </button>
          <button data-view="calendar">
            <svg
              class="nav-symbol"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <rect x="3" y="5" width="18" height="16" rx="2" />
              <path d="M7 3v4M17 3v4M3 10h18M8 14h2M14 14h2M8 18h2" /></svg
            >Calendario
          </button>
          <button data-view="overview">
            <svg
              class="nav-symbol"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <rect x="3" y="5" width="18" height="14" rx="3" />
              <path d="M3 10h18M7 15h4" /></svg
            >Finanza
          </button>
        </nav>
        <div class="sidebar-foot">
          <span id="sync-side">Caricamento...</span
          ><span id="version-side" hidden></span>
        </div>
      </aside>
      <main>
        <header class="top">
          <div class="page-heading"><button class="theme-toggle" type="button" aria-label="Impostazioni" title="Impostazioni"></button><h1 id="page-title">Dashboard</h1><div class="header-tools"><div id="page-actions" class="page-actions" aria-label="Azioni pagina"></div><div id="page-fab" class="page-fab"></div></div></div>
          <div class="header-meta"><div class="home-context"><span id="home-weather">Meteo \u2014</span></div><div class="top-right hidden"><div class="period"><button id="prev-month" aria-label="Mese precedente">\u2039</button><strong id="period-label">...</strong><button id="next-month" aria-label="Mese successivo">\u203A</button></div><div class="sync" id="sync-top"></div></div></div>
        </header>
        <nav
          id="finance-tabs"
          class="finance-tabs hidden"
          aria-label="Sezioni finanza"
        >
          <button data-view="overview" aria-label="Torna a Finanza">\u2039 Finanza</button>
        </nav>
        <div id="error" class="errorbox hidden" role="alert"></div>
        <div
          id="loading"
          class="loading-overlay"
          role="status"
          aria-live="polite"
        >
          <div class="loading-panel">
            <div class="loading-spinner" aria-hidden="true"></div>
            <strong>Caricamento\u2026</strong>
          </div>
        </div>
        <section id="today" class="view active"></section>
        <section id="tasks" class="view"></section>
        <section id="calendar" class="view"></section>
        <section id="overview" class="view"></section>
        <section id="movements" class="view"></section>

        <section id="budget" class="view"></section><section id="analysis" class="view"></section><section id="extras" class="view"></section>
      </main>
    </div>
    <div id="dialog" class="modal-wrap hidden"></div>
    <div id="life-dialog" class="modal-wrap hidden"></div>
    <script>
      /** Trasporto JSON same-origin con timeout; nessun retry automatico delle scritture. */
      async function workerRequest(method, args) {
        // A stalled read must not trap navigation. Never automatically retry writes:
        // a dropped response does not prove the server rolled the operation back.
        const controller = new AbortController(),
          timer = setTimeout(() => controller.abort(), 20000);
        try {
          const r = await fetch("/api/" + method, {
            method: "POST",
            headers: { "content-type": "application/json", "X-LifeOS-Plans-Version": "2" },
            body: JSON.stringify(args),
            signal: controller.signal,
          });
          if (!r.ok) {
            const raw = (await r.text()).slice(0, 500);
            let message = raw;
            try { message = JSON.parse(raw).error || raw; } catch {}
            if(r.headers.get('content-type')?.includes('text/html')||/<(?:!doctype|html|head|body)\\b/i.test(raw))
              message=[429,500,502,503,504].includes(r.status)?'Il server \xE8 momentaneamente occupato. Riprova tra poco.':'Il server non ha restituito dati validi. Verifica l\u2019accesso e riprova.';
            if (method.includes("FinancePlan") && (r.status === 404 || message.trim() === "Operazione non disponibile.")) message = lifeOSContract.plansUnavailable;
            throw Error(r.status === 401 ? "Sessione scaduta. Riapri l\u2019app e accedi." : message);
          }
          if (
            !(r.headers.get("content-type") || "").includes("application/json")
          )
            throw Error("Sessione non disponibile. Riapri l\u2019app e accedi.");
          return await r.json();
        } catch (error) {
          if (error.name === "AbortError")
            throw Error(
              method.startsWith("get")
                ? "Connessione lenta. Riprova a caricare la schermata."
                : "Risposta non ricevuta. Aggiorna e verifica il salvataggio prima di riprovare.",
            );
          throw error;
        } finally {
          clearTimeout(timer);
        }
      }
      window.google = {
        script: {
          run: new Proxy(
            {},
            {
              get(_target, name) {
                if (
                  name === "withSuccessHandler" ||
                  name === "withFailureHandler"
                )
                  return (callback) => {
                    const runner = {
                      success: name === "withSuccessHandler" ? callback : null,
                      failure: name === "withFailureHandler" ? callback : null,
                    };
                    const proxy = new Proxy(runner, {
                      get(obj, key) {
                        if (key === "withSuccessHandler")
                          return (cb) => {
                            obj.success = cb;
                            return proxy;
                          };
                        if (key === "withFailureHandler")
                          return (cb) => {
                            obj.failure = cb;
                            return proxy;
                          };
                        return (...args) =>
                          workerRequest(String(key), args)
                            .then((v) => obj.success?.(v))
                            .catch((e) => obj.failure?.(e));
                      },
                    });
                    return proxy;
                  };
              },
            },
          ),
        },
      };
    <\/script>

    <script>
      /* Offline solar calculation for Empoli. Angles and minute adjustments are configured settings.
   Solar position follows the public PrayTimes formulas; no network or location access. */
      const osPrayerConfig = Object.freeze({
        latitude: 43.7179,
        longitude: 10.9478,
        timeZone: "Europe/Rome",
        fajrAngle: 14.5,
        ishaAngle: 14.8,
        asrFactor: 1,
        adjustments: {
          fajr: 0,
          sunrise: -2,
          dhuhr: 1,
          asr: 1,
          maghrib: 2,
          isha: 0,
        },
      });
      const osDeg = Math.PI / 180;

      /** Calcolo astronomico locale per Empoli; restituisce orari, senza geolocalizzazione o richieste. */
      function osPrayerTimes(day, config = osPrayerConfig) {
        if (!/^\\d{4}-\\d{2}-\\d{2}$/.test(day)) throw Error("Data non valida");
        const [y, m, d] = day.split("-").map(Number),
          lat = config.latitude,
          lon = config.longitude;
        const jd = Date.UTC(y, m - 1, d) / 86400000 + 2440587.5 - lon / 360;
        const norm = (x, n) => ((x % n) + n) % n;
        const sin = (x) => Math.sin(x * osDeg),
          cos = (x) => Math.cos(x * osDeg),
          tan = (x) => Math.tan(x * osDeg);

        /** Declinazione solare ed equazione del tempo per il giorno giuliano corrente. */
        function sun(t) {
          const D = jd + t / 24 - 2451545,
            g = norm(357.529 + 0.98560028 * D, 360),
            q = norm(280.459 + 0.98564736 * D, 360);
          const L = norm(q + 1.915 * sin(g) + 0.02 * sin(2 * g), 360),
            e = 23.439 - 0.00000036 * D;
          const RA = norm(Math.atan2(cos(e) * sin(L), cos(L)) / osDeg / 15, 24);
          return { decl: Math.asin(sin(e) * sin(L)) / osDeg, eqt: q / 15 - RA };
        }

        /** Mezzogiorno solare normalizzato sulle 24 ore. */
        function noon(t) {
          return norm(12 - sun(t).eqt, 24);
        }

        /** Converte un angolo solare in ora; restituisce NaN se non esiste un attraversamento. */
        function angleTime(angle, t, before) {
          const decl = sun(t).decl,
            den = cos(decl) * cos(lat);
          const ratio = (-sin(angle) - sin(decl) * sin(lat)) / den;
          if (!Number.isFinite(ratio) || Math.abs(ratio) > 1) return NaN;
          const delta =
            Math.acos(Math.max(-1, Math.min(1, ratio))) / osDeg / 15;
          return noon(t) + (before ? -delta : delta);
        }

        /** Calcola il tempo pomeridiano dal fattore d\u2019ombra configurato. */
        function asr(t) {
          const decl = sun(t).decl,
            alt =
              -Math.atan(1 / (config.asrFactor + tan(Math.abs(lat - decl)))) /
              osDeg;
          return angleTime(alt, t, false);
        }
        let times = {
          fajr: 5,
          sunrise: 6,
          dhuhr: 12,
          asr: 13,
          maghrib: 18,
          isha: 18,
        };
        for (let i = 0; i < 2; i++) {
          const t = Object.fromEntries(
            Object.entries(times).map(([k, v]) => [k, v / 24]),
          );
          times = {
            fajr: angleTime(config.fajrAngle, t.fajr, true),
            sunrise: angleTime(0.833, t.sunrise, true),
            dhuhr: noon(t.dhuhr),
            asr: asr(t.asr),
            maghrib: angleTime(0.833, t.maghrib, false),
            isha: angleTime(config.ishaAngle, t.isha, false),
          };
        }
        const noonUtc = new Date(Date.UTC(y, m - 1, d, 12)),
          parts = new Intl.DateTimeFormat("en-GB", {
            timeZone: config.timeZone,
            hour: "2-digit",
            minute: "2-digit",
            hourCycle: "h23",
          }).formatToParts(noonUtc);
        const hour = Number(parts.find((p) => p.type === "hour")?.value),
          minute = Number(parts.find((p) => p.type === "minute")?.value);
        const utcOffset = hour + minute / 60 - 12;
        return Object.fromEntries(
          Object.entries(times).map(([key, value]) => {
            if (!Number.isFinite(value))
              return [key, { minutes: NaN, label: "\u2014" }];
            const minutes = norm(
              Math.round(
                (value + utcOffset - lon / 15) * 60 +
                  (config.adjustments[key] || 0),
              ),
              1440,
            );
            return [
              key,
              {
                minutes,
                label:
                  String(Math.floor(minutes / 60)).padStart(2, "0") +
                  ":" +
                  String(minutes % 60).padStart(2, "0"),
              },
            ];
          }),
        );
      }

      /** Markup degli orari locali; conserva lo stato del dettaglio aperto. */
      function osPrayerCard(day, now = new Date(), expanded = false) {
        const times = osPrayerTimes(day),
          current = Object.fromEntries(
            new Intl.DateTimeFormat("en-GB", {
              timeZone: osPrayerConfig.timeZone,
              hour: "2-digit",
              minute: "2-digit",
              hourCycle: "h23",
            })
              .formatToParts(now)
              .filter((p) => p.type === "hour" || p.type === "minute")
              .map((p) => [p.type, Number(p.value)]),
          );
        const currentDay = now.toLocaleDateString("sv-SE", {
            timeZone: osPrayerConfig.timeZone,
          }),
          minute = current.hour * 60 + current.minute;
        const prayers = [
          ["fajr", "Prima dell\u2019alba"],
          ["sunrise", "Alba"],
          ["dhuhr", "Mezzogiorno"],
          ["asr", "Pomeriggio"],
          ["maghrib", "Tramonto"],
          ["isha", "Notte"],
        ];
        const next =
          currentDay === day
            ? prayers.find(([key]) => times[key].minutes > minute)
            : null;
        const lead = next
          ? "Prossimo \xB7 " + next[1] + " " + times[next[0]].label
          : "Ciclo di oggi";
        return \`<div class="os-sunline" aria-label="Fasi del giorno a Empoli"><div class="os-sunline-meta"><span>Empoli \xB7 alba \${times.sunrise.label}</span><strong>\${lead}</strong></div><details class="os-home-times" data-home-times \${expanded ? "open" : ""}><summary>Tutti gli orari</summary><div class="os-prayer-list">\${prayers.map(([key, label]) => \`<div class="os-prayer \${next?.[0] === key ? "next" : ""}"><span>\${label}</span><time>\${times[key].label}</time></div>\`).join("")}</div></details></div>\`;
      }

      const life = {
        data: null,
        finance: null,
        financeError: false,
        month: new Date()
          .toLocaleDateString("sv-SE", { timeZone: "Europe/Rome" })
          .slice(0, 7),
        selected: null,
        tool: null,
        busy: false,
        undo: null,
        paintQueue: Promise.resolve(),
        routineQueue: Promise.resolve(),
        routinePending: 0,
        routineRevision: 0,
        editingEvent: null,
        creatingEvent: false,
        editingSplitFrom: null,
        category: "action",
        weather: null,
        weatherAt: 0,
        timesOpen: false,
        reorder: false,
        paletteOpen: false,
        readRevision: 0,
        paintRevision: 0,
      };
      const osSafe = (v) =>
        String(v ?? "").replace(
          /[&<>"']/g,
          (c) =>
            ({
              "&": "&amp;",
              "<": "&lt;",
              ">": "&gt;",
              '"': "&quot;",
              "'": "&#39;",
            })[c],
        );
      const osShift = {
        morning: "06\u201314",
        afternoon: "14\u201322",
        night: "22\u201306",
        holiday: "Ferie",
        rest: "Riposo",
      };
      const osShiftInitial = {
        morning: "M",
        afternoon: "P",
        night: "N",
        holiday: "F",
        rest: "R",
      };
      const osDate = (v) =>
        new Date(v + "T12:00:00Z").toLocaleDateString("it-IT", {
          day: "numeric",
          month: "long",
          year: "numeric",
          timeZone: "UTC",
        });
      const osNextDay = (v) =>
        new Date(Date.parse(v + "T12:00:00Z") + 86400000)
          .toISOString()
          .slice(0, 10);

      /** Adatta gli argomenti variadici Life OS al protocollo RPC array. */
      async function osRequest(method, ...args) {
        return workerRequest(method, args);
      }

      /** Mostra un errore leggibile senza nascondere la navigazione. */
      function osError(err) {
        const box = document.getElementById("error");
        box.textContent = "Operazione non riuscita: " + (err.message || err);
        box.classList.remove("hidden");
        window.scrollTo({ top: 0, behavior: "smooth" });
      }
      // Keep the latest month/request; an older network response must never replace it.

      /** Carica il mese richiesto; gli errori restano recuperabili dalla UI. */
      async function loadLifeOS() {
        try {
          await osRefresh();
        } catch (e) {
          osError(e);
        }
      }

      /** Azione principale flottante; opzioni secondarie vicino al titolo. */
      function osPageActions() {
        const view = state.view, active = life.data?.categories.find(c => c.key === life.category);
        let action = 'data-new-transaction="Spesa"', label = 'Aggiungi spesa', secondary = '';
        if (view === 'tasks') {
          action = 'data-life-task="new"'; label = 'Aggiungi attivit\xE0';
          secondary = '';
        } else if (view === 'calendar') {
          action = 'data-life-event="new"'; label = 'Aggiungi evento';
        } else if (['overview','movements','budget','extras'].includes(view)) {
          if (view === 'extras') { action = 'data-new-extra="1"'; label = 'Aggiungi straordinaria'; }
          secondary = '';
        }
        document.getElementById('page-actions').innerHTML = secondary;
        document.getElementById('page-fab').innerHTML = \`<button type="button" class="os-button primary fab-button" \${action} aria-label="\${label}" title="\${label}"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg></button>\`;
      }

      /** Ricrea solo la vista Life OS attiva; non eseguire su ogni clic generico. */
      function renderLifeOS() {
        osPageActions();
        if (!life.data) return;
        osUpdateHeader();
        const view = typeof state !== "undefined" ? state.view : "today";
        if (view === "today")
          document.getElementById("today").innerHTML = osToday();
        if (view === "tasks")
          document.getElementById("tasks").innerHTML = osTasks();
        if (view === "calendar") {
          document.getElementById("calendar").innerHTML = osCalendar();
          document.body.dataset.calendarRows = Math.ceil(
            document.querySelectorAll(".os-day").length / 7,
          );
          document.body.style.setProperty(
            "--calendar-rows",
            document.body.dataset.calendarRows,
          );
        }
      }

      /** Aggiorna la sintesi finanziaria della home per il mese corrente a Roma. */
      async function osLoadHomeFinance() {
        const revision = life.homeFinanceRevision = (life.homeFinanceRevision || 0) + 1;
        try {
          const day = new Date().toLocaleDateString("sv-SE", {
            timeZone: "Europe/Rome",
          });
          const fresh = await osRequest(
            "getFinanceOverview",
            Number(day.slice(0, 4)),
            Number(day.slice(5, 7)),
          );
          if (revision !== life.homeFinanceRevision) return;
          life.finance = fresh;
          life.financeError = false;
          if (life.data) document.getElementById("today").innerHTML = osToday();
        } catch (e) {
          if (revision !== life.homeFinanceRevision) return;
          life.financeError = true;
          if (life.data) document.getElementById("today").innerHTML = osToday();
        }
      }

      /** Aggiorna il meteo nell\u2019intestazione, senza ricreare la pagina. */
      function osUpdateHeader() {
        if (typeof document === "undefined") return;
        document.getElementById("home-weather").textContent = osWeatherText();
      }

      /** Etichetta meteo compatta da dati gi\xE0 caricati. */
      function osWeatherText() {
        const w = life.weather;
        if (!w) return "Meteo \u2014";
        const condition = [0].includes(w.code)
          ? "sereno"
          : [1, 2].includes(w.code)
            ? "poco nuvoloso"
            : [3].includes(w.code)
              ? "nuvoloso"
              : [45, 48].includes(w.code)
                ? "nebbia"
                : [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99].includes(
                      w.code,
                    )
                  ? "pioggia"
                  : "meteo";
        const rain = w.rain ? \` \xB7 pioggia \${w.rain}\` : \` \xB7 \${condition}\`;
        return Math.round(w.temp) + " \xB0C" + rain;
      }

      /** Meteo facoltativo con timeout breve e intervallo minimo di 30 minuti. */
      async function osLoadWeather() {
        if (life.weatherAt && Date.now() - life.weatherAt < 30 * 60000) return;
        life.weatherAt = Date.now();
        const controller = new AbortController(),
          timer = setTimeout(() => controller.abort(), 6000);
        try {
          const url =
            "https://api.open-meteo.com/v1/forecast?latitude=43.7179&longitude=10.9478&current=temperature_2m,weather_code&hourly=rain,precipitation_probability&forecast_hours=18&timezone=Europe%2FRome";
          const response = await fetch(url, { signal: controller.signal });
          if (!response.ok) throw Error("Meteo non disponibile");
          const data = await response.json(),
            temp = Number(data.current?.temperature_2m);
          if (!Number.isFinite(temp)) throw Error("Temperatura assente");
          const now = new Intl.DateTimeFormat("sv-SE", {
            timeZone: "Europe/Rome",
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit",
            hourCycle: "h23",
          })
            .format(new Date())
            .replace(" ", "T");
          const times = data.hourly?.time || [],
            amounts = data.hourly?.rain || [],
            prob = data.hourly?.precipitation_probability || [];
          const i = times.findIndex(
            (t, j) =>
              t >= now && Number(amounts[j]) >= 0.1 && Number(prob[j]) >= 40,
          );
          const rain =
            i < 0
              ? ""
              : times[i].slice(0, 10) === now.slice(0, 10)
                ? times[i].slice(11, 16)
                : "domani " + times[i].slice(11, 16);
          life.weather = {
            temp,
            code: Number(data.current.weather_code),
            rain,
          };
        } catch {
          life.weather = null;
        } finally {
          clearTimeout(timer);
          osUpdateHeader();
          if (life.data) document.getElementById("today").innerHTML = osToday();
        }
      }

      /** Markup dashboard: routine, oggi/domani, tre attivit\xE0, eventi e saldi. */
      function osToday() {
        const d = life.data,
          day = d.today,
          shift = d.shifts.find((s) => s.day === day),
          tomorrow = d.shifts.find((s) => s.day === osNextDay(day));
        const tasks = d.tasks.filter(
            (t) => t.status === "todo" && t.list_kind === "action",
          ),
          waiting = d.tasks.filter(
            (t) => t.status === "waiting" && t.list_kind === "action",
          ),
          upcoming = (d.upcomingEvents || []).slice(0, 3);
        const habits = d.routines || [],
          complete = habits.filter((h) => h.checked).length;
        const finance = life.finance?.summary;
        const shiftLabel = (v) =>
          v
            ? {
                morning: 'Mattina',
                afternoon:
                  'Pomeriggio',
                night: 'Notte',
                holiday: "Ferie",
                rest: "Riposo",
              }[v.kind] || osShift[v.kind]
            : "Nessun turno";
        const featured =
          upcoming
            .map(
              (ev) =>
                \`<div class="os-agenda-entry"><button class="os-agenda-row" data-life-event="\${ev.id}"><span class="os-agenda-date"><b>\${new Date(ev.day + "T12:00:00Z").toLocaleDateString("it-IT", { day: "2-digit", timeZone: "UTC" })}</b><small>\${new Date(ev.day + "T12:00:00Z").toLocaleDateString("it-IT", { month: "short", timeZone: "UTC" })}</small></span><span class="os-agenda-title"><span class="os-home-agenda-name">\${osSafe(ev.title)}\${osDueBadge(ev.day, ev.occurrence_status)}</span><small>\${ev.start_time || "Tutto il giorno"}\${ev.location ? " \xB7 " + osSafe(ev.location) : ""}</small></span><span class="os-agenda-arrow" aria-hidden="true">\u203A</span></button><button type="button" class="os-agenda-done" data-life-occurrence="\${ev.id}:\${ev.day}:done" aria-label="Segna fatta \${osSafe(ev.title)}">Fatto</button></div>\`,
            )
            .concat(
              tasks
                .slice(0, Math.max(0, 3 - upcoming.length))
                .map(
                  (t) =>
                    \`<div class="os-home-task"><button class="os-check" data-life-complete="\${t.id}" aria-label="Completa \${osSafe(t.title)}"></button><button class="os-home-task-title" data-life-task="\${t.id}">\${osSafe(t.title)}\${osDueBadge(t.due_date || t.scheduled_date, t.status)}</button></div>\`,
                ),
            )
            .slice(0, 3)
            .join("") || '<p class="os-empty">Nessun evento o attivit\xE0.</p>';
        const routine = habits
          .map(
            (h) =>
              \`<button type="button" class="os-routine-check \${h.checked ? "checked" : ""}" data-life-routine="\${h.id}" aria-pressed="\${!!h.checked}" aria-label="\${h.checked ? "Annulla" : "Completa"} \${osSafe(h.title)}"><span class="os-routine-tick" aria-hidden="true">\${h.checked ? "\u2713" : ""}</span>\${osSafe(h.title)}</button>\`,
          )
          .join("");
        const exactMoney = (n) =>
          new Intl.NumberFormat("it-IT", {
            style: "currency",
            currency: "EUR",
            useGrouping: "always",
          }).format(n);
        return \`<div class="os-home">
    <section class="os-card os-day-dashboard" aria-label="La giornata"><div class="os-home-daygrid"><div data-kind="\${shift?.kind || ""}"><span class="os-home-label">Oggi</span><h2>\${shiftLabel(shift)}</h2></div><div class="os-home-tomorrow" data-kind="\${tomorrow?.kind || ""}"><span>Domani</span><strong>\${shiftLabel(tomorrow)}</strong></div></div>
      <div class="os-routine"><div class="os-routine-head"><span>Routine <b>\${complete}/\${habits.length}</b></span><button type="button" class="os-routine-manage" data-life-routine-manage>Gestisci</button></div><div class="os-routine-items">\${routine || '<button class="os-home-routine-add" data-life-routine-manage>Aggiungi routine</button>'}</div></div>
    </section>
    <section class="os-card os-home-agenda"><div class="os-topline"><h2>In evidenza</h2><button class="os-button" data-life-nav="tasks">Tutte le attivit\xE0</button></div>\${featured}</section>
    <section class="os-card os-home-finance" aria-label="Denaro">
      \${finance ? \`<div class="os-home-money"><div class="os-money-primary" style="--money-units:\${exactMoney(finance.monthlyRemaining).length*0.62}"><small>Budget del mese</small><strong>\${state.assetsVisible ? exactMoney(finance.monthlyRemaining) : "\u2022\u2022\u2022\u2022 \u20AC"}</strong></div>\${privacyButton()}</div><div class="os-home-submoney \${Math.abs(finance.budget)>=100000 || Math.abs(finance.monthlyCommitted)>=100000?"large-amount":""}"><div class="os-home-metric"><span>Impegnato</span><b>\${exactMoney(finance.monthlyCommitted)}</b></div><div class="os-home-metric os-home-private"><span>Saldo</span><b>\${state.assetsVisible ? exactMoney(finance.budget) : "\u2022\u2022\u2022\u2022 \u20AC"}</b></div></div>\` : life.financeError ? '<p class="os-empty">Saldo non disponibile.</p><button class="os-button" data-life-nav="overview">Riprova in Finanza</button>' : '<p class="os-empty" role="status">Caricamento\u2026</p>'}
    </section>
    <section class="os-card os-home-prayer"><div class="os-solar-inline">\${osPrayerCard(day, new Date(), life.timesOpen)}</div></section>
  </div>\`;
      }

      /** Apre il foglio di gestione delle routine; non modifica le spunte. */
      function osManageRoutines() { return lifeOSHabits.open(); }

      /** Scadenza esplicita Domani/Oggi/Scaduto; nessun badge per completate. */
      function osDueBadge(day, status) {
        if (!day || status === "done" || !life.data) return "";
        const today = life.data.today;
        let label = "",
          kind = "";
        if (day < today) {
          label = "Scaduto";
          kind = "overdue";
        } else if (day === today) {
          label = "Oggi";
          kind = "today";
        } else if (day === osNextDay(today)) {
          label = "Domani";
          kind = "tomorrow";
        }
        return label
          ? \`<span class="due-badge due-\${kind}">\${label}</span>\`
          : "";
      }

      /** Riga attivit\xE0; escaping obbligatorio per titolo e attributi utente. */
      function osTaskRow(t) {
        const waiting = t.status === "waiting";
        return \`<div class="os-task \${t.status === "done" ? "done" : ""}" data-life-drag-row="\${t.id}">\${t.status === "todo" ? \`<button type="button" class="os-drag-handle" data-life-drag-handle="\${t.id}" aria-label="Riordina \${osSafe(t.title)}. Trascina o usa Alt pi\xF9 freccia su o gi\xF9" title="Trascina per riordinare"><svg viewBox="0 0 20 24" width="16" height="22" fill="currentColor" aria-hidden="true"><circle cx="6" cy="5" r="1.4"/><circle cx="14" cy="5" r="1.4"/><circle cx="6" cy="12" r="1.4"/><circle cx="14" cy="12" r="1.4"/><circle cx="6" cy="19" r="1.4"/><circle cx="14" cy="19" r="1.4"/></svg></button>\` : ""}<button class="os-check" data-life-status="\${t.id}:\${t.status === "done" ? "todo" : "done"}" aria-label="\${t.status === "done" ? "Riapri" : "Completa"} \${osSafe(t.title)}">\${t.status === "done" ? "\u2713" : ""}</button><button class="os-task-title" data-life-task="\${t.id}">\${osSafe(t.title)}\${osDueBadge(t.due_date || t.scheduled_date, t.status)}</button>\${t.status !== "done" ? \`<button class="os-wait \${waiting ? "waiting" : ""}" data-life-status="\${t.id}:\${waiting ? "todo" : "waiting"}" title="\${waiting ? "Riporta in Da fare" : "Metti in attesa"}" aria-label="\${waiting ? "Riporta in Da fare" : "Metti in attesa"} \${osSafe(t.title)}" aria-pressed="\${waiting}"><svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3h12M6 21h12M7 3v4c0 2 2 3 5 5-3 2-5 3-5 5v4M17 3v4c0 2-2 3-5 5 3 2 5 3 5 5v4"/></svg></button>\` : \`<button class="os-task-delete" data-life-delete-task="\${t.id}" aria-label="Elimina \${osSafe(t.title)}" title="Elimina attivit\xE0"><svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 7h16M10 4h4M6 7l1 13h10l1-13M10 11v5M14 11v5"/></svg></button>\`}</div>\`;
      }

      /** Lista della categoria selezionata; azioni secondarie nel menu Opzioni. */
      function osTasks() {
        const d = life.data;
        if (!d.categories.some((c) => c.key === life.category))
          life.category = d.categories[0]?.key || "action";
        const active = d.categories.find((c) => c.key === life.category),
          items = d.tasks.filter((t) => t.list_kind === life.category),
          todo = items.filter((t) => t.status === "todo"),
          waiting = items.filter((t) => t.status === "waiting"),
          done = items.filter((t) => t.status === "done");
        return \`<div class="card-title"><h2>Categorie</h2><div class="actions"><button data-life-reorder aria-pressed="\${life.reorder}">\${life.reorder?"Fine":"Riordina"}</button><button data-life-category aria-label="Gestisci categorie">\u25B1</button></div></div><div class="os-category-navigation"><nav class="os-category-tabs" aria-label="Categorie attivit\xE0">\${d.categories.map((c) => \`<button data-life-select-category="\${osSafe(c.key)}" class="\${life.category === c.key ? "active" : ""}" aria-current="\${life.category === c.key ? "page" : "false"}">\${osSafe(c.label)}</button>\`).join("")}</nav></div><div class="os-card os-category-page \${life.reorder ? "is-reordering" : ""}"><h3 class="details-label">Da fare</h3>\${todo.length ? todo.map(osTaskRow).join("") : '<p class="os-task-empty">Nessuna attivit\xE0 da fare</p>'}\${waiting.length ? \`<section class="os-task-section"><h3>In attesa</h3>\${waiting.map(osTaskRow).join("")}</section>\` : ""}\${done.length ? \`<section class="os-completed"><h3>Completate \xB7 \${done.length}</h3>\${done.map(osTaskRow).join("")}<button class="os-delete-completed" data-life-delete-completed="\${osSafe(life.category)}">Elimina tutte le completate</button></section>\` : ""}</div>\`;
      }

      /** Editor evento o serie; una modifica da qui passa split_from al server. */
      function osEventForm() {
        const ev = life.editingEvent
          ? life.data.events.find((e) => e.id === life.editingEvent) ||
            life.data.upcomingEvents?.find((e) => e.id === life.editingEvent)
          : null;
        if (!life.creatingEvent && !ev) return "";
        return \`<div class="os-inline-event" id="os-event-editor"><div class="os-topline"><h3>\${life.editingSplitFrom ? "Modifica da qui" : ev ? "Modifica serie" : "Nuovo evento"}</h3><button class="os-icon-button" data-life-close aria-label="Chiudi modulo evento">\xD7</button></div><form id="life-form" data-kind="event" class="os-form"><input type="hidden" name="record_id" value="\${ev?.id || ""}">\${life.editingSplitFrom ? \`<input type="hidden" name="split_from" value="\${life.editingSplitFrom}">\` : ""}<label class="wide">Titolo *<input name="title" maxlength="140" required value="\${osSafe(ev?.title || "")}"></label><label class="wide">Giorno *<input type="date" name="day" required value="\${life.editingSplitFrom || ev?.series_day || ev?.day || life.selected || life.data.today}"></label><label>Inizio<input type="time" name="start_time" value="\${ev?.start_time || ""}"></label><label>Fine<input type="time" name="end_time" value="\${ev?.end_time || ""}"></label><label>Ripeti<select name="frequency">\${[
          ["none", "Mai"],
          ["weekly", "Ogni settimana"],
          ["monthly", "Ogni mese"],
          ["yearly", "Ogni anno"],
        ]
          .map(
            ([v, t]) =>
              \`<option value="\${v}" \${(ev?.frequency || "none") === v ? "selected" : ""}>\${t}</option>\`,
          )
          .join(
            "",
          )}</select></label><label>Fino al (facoltativo)<input type="date" name="until_day" value="\${ev?.until_day || ""}"></label><p class="hint wide">\${life.editingSplitFrom ? "Le occorrenze precedenti restano invariate." : "Modifica tutte le occorrenze. Nei mesi pi\xF9 corti: ultimo giorno disponibile."}</p><label class="wide">Luogo<input name="location" maxlength="160" value="\${osSafe(ev?.location || "")}"></label><label class="wide">Note<textarea name="notes" maxlength="1000">\${osSafe(ev?.notes || "")}</textarea></label><div class="os-form-error hidden" role="alert"></div><div class="os-form-actions">\${ev ? \`<button class="os-button danger" type="button" data-life-delete-event="\${ev.id}">Elimina</button>\` : ""}<button class="os-button primary" type="button" data-life-save onclick="osSubmit(this.form);return false">Salva evento</button></div></form></div>\`;
      }

      /** Calendario luned\xEC-domenica, giorni adiacenti e dettagli solo su selezione. */
      function osCalendar() {
        const [year, month] = life.month.split("-").map(Number),
          first = new Date(Date.UTC(year, month - 1, 1)),
          days = new Date(Date.UTC(year, month, 0)).getUTCDate(),
          offset = (first.getUTCDay() + 6) % 7,
          shiftMap = new Map(life.data.shifts.map((s) => [s.day, s.kind])),
          events = life.data.events.filter((e) => e.day === life.selected),
          tasks = life.data.tasks.filter(
            (t) =>
              t.status !== "done" &&
              (t.scheduled_date === life.selected ||
                t.due_date === life.selected),
          ),
          shift = shiftMap.get(life.selected);
        const eventCounts = new Map(),
          taskDays = new Set();
        for (const event of life.data.events)
          eventCounts.set(event.day, (eventCounts.get(event.day) || 0) + 1);
        for (const task of life.data.tasks)
          if (task.status !== "done") {
            if (task.scheduled_date) taskDays.add(task.scheduled_date);
            if (task.due_date) taskDays.add(task.due_date);
          }
        let cells = "";
        for (let i = 0; i < Math.ceil((offset + days) / 7) * 7; i++) {
          const n = i - offset + 1,
            date = new Date(Date.UTC(year, month - 1, n)),
            day = date.toISOString().slice(0, 10),
            kind = shiftMap.get(day),
            dayEventCount = eventCounts.get(day) || 0,
            hasTask = taskDays.has(day);
          if (i % 7 === 0) cells += '<div class="os-calendar-week">';
          cells += \`<button class="os-day \${date.getUTCMonth() !== month - 1 ? "other" : ""} \${day === life.data.today ? "today" : ""} \${day === life.selected ? "selected" : ""}" data-life-day="\${day}" data-kind="\${kind || ""}" aria-label="\${osDate(day)}\${kind ? " \xB7 " + osShift[kind] : ""}\${dayEventCount ? " \xB7 " + dayEventCount + " eventi" : ""}\${hasTask ? " \xB7 attivit\xE0" : ""}" title="\${day}\${kind ? " \xB7 " + osShift[kind] : ""}"><b>\${date.getUTCDate()}</b><span class="os-shift \${kind ? "" : "no-shift"}">\${kind ? osShiftInitial[kind] : ""}</span><span class="os-day-mark \${dayEventCount ? "event-count" : hasTask ? "dot" : ""}" aria-hidden="true">\${dayEventCount ? dayEventCount : ""}</span></button>\`;
          if (i % 7 === 6) cells += "</div>";
        }
        document.body.style.setProperty(
          "--calendar-rows",
          Math.ceil((offset + days) / 7),
        );
        return \`<div class="os-card"><div class="os-month-header"><button data-life-month="-1" aria-label="Mese precedente">\u2039</button><h2>\${first.toLocaleDateString("it-IT", { month: "long", year: "numeric", timeZone: "UTC" })}</h2><button data-life-month="1" aria-label="Mese successivo">\u203A</button></div><div class="os-weekdays">\${["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"].map((x) => \`<span>\${x}</span>\`).join("")}</div><div class="os-days">\${cells}</div>\${life.selected ? \`<div class="os-calendar-details">\` : ""}\${life.selected ? \`<h3>\${osDate(life.selected)}\${shift ? " \xB7 " + osShift[shift] : ""}</h3>\${events.length ? events.map((e) => \`<div class="os-mini"><div><strong>\${osSafe(e.title)}</strong><small>\${e.start_time || "Tutto il giorno"}\${e.end_time ? "\u2013" + e.end_time : ""}\${e.location ? " \xB7 " + osSafe(e.location) : ""}\${e.occurrence_status === "done" ? " \xB7 Fatto" : ""}</small></div><button class="os-row-action" data-life-occurrence="\${e.id}:\${e.day}:\${e.occurrence_status === "done" ? "open" : "done"}">\${e.occurrence_status === "done" ? "Riapri" : "Fatto"}</button><details class="os-event-options"><summary aria-label="Opzioni evento">Opzioni</summary><button class="os-row-action" data-life-occurrence="\${e.id}:\${e.day}:skipped" aria-label="Elimina questa occorrenza">Elimina questa</button>\${e.frequency && e.frequency !== "none" ? \`<button class="os-row-action" data-life-split-event="\${e.id}:\${e.day}">Modifica da qui</button>\` : ""}<button class="os-row-action" data-life-event="\${e.id}" aria-label="Modifica serie">Modifica</button></details></div>\`).join("") : '<p class="os-empty">Nessun evento.</p>'}\${tasks.length ? '<div class="os-section-label">Attivit\xE0</div>' + tasks.map((t) => \`<div class="os-mini"><strong>\${osSafe(t.title)}</strong><button class="os-row-action" data-life-task="\${t.id}" aria-label="Modifica attivit\xE0">\xB7\xB7\xB7</button></div>\`).join("") : ""}\` : ""}\${life.selected ? "</div>" : ""}\${osEventForm()}</div><details class="os-palette-wrap os-tools-drawer" \${life.paletteOpen || life.tool ? "open" : ""}><summary>Dipingi turni\${life.tool ? " \xB7 " + osSafe(osShift[life.tool] || life.tool) : ""}</summary><div class="os-palette-state" role="status">\${life.tool ? \`Pennello attivo: <strong>\${osSafe(osShift[life.tool] || (life.tool === "event" ? "Evento" : "Cancella"))}</strong>\` : "Scegli un turno, poi tocca i giorni."}</div><div class="os-palette" aria-label="Pennello calendario">\${Object.entries(
          osShift,
        )
          .map(
            ([key, val]) =>
              \`<button data-life-tool="\${key}" title="\${val}" aria-label="\${val}" class="\${life.tool === key ? "active" : ""}" aria-pressed="\${life.tool === key}">\${osSafe(val)}</button>\`,
          )
          .join(
            "",
          )}<button data-life-tool="event" class="\${life.tool === "event" ? "active" : ""}" aria-pressed="\${life.tool === "event"}">+ Evento</button><button data-life-tool="erase" class="\${life.tool === "erase" ? "active" : ""}" aria-pressed="\${life.tool === "erase"}">Cancella</button>\${life.tool ? '<button class="os-palette-stop" data-life-tool="none" aria-label="Disattiva pennello">Fine</button>' : ""}\${life.undo ? '<button data-life-undo aria-label="Annulla ultimo turno">\u21B6</button>' : ""}</div></details>\`;
      }

      /** Accetta solo l\u2019ultima lettura del mese corrente; scarta risposte tardive. */
      async function osRefresh() {
        const revision = ++life.readRevision,
          month = life.month;
        const fresh = await osRequest("getLifeData", month);
        if (revision !== life.readRevision || month !== life.month) return;
        life.data = fresh;
        renderLifeOS();
      }
      // Serialize brush writes. Roll back only this day if no newer paint supersedes it.

      /** Aggiornamento ottimistico del turno, scritture serializzate e recupero errore. */
      function osPaint(day, kind) {
        const previous =
          life.data.shifts.find((s) => s.day === day)?.kind || null;
        const revision = ++life.paintRevision;
        ++life.readRevision;
        life.data.shifts = life.data.shifts.filter((s) => s.day !== day);
        if (kind !== "erase") life.data.shifts.push({ day, kind });
        renderLifeOS();
        life.paintQueue = life.paintQueue
          .then(() => osRequest("paintShift", { day, kind }))
          .catch((err) => {
            if (revision === life.paintRevision) {
              life.data.shifts = life.data.shifts.filter((s) => s.day !== day);
              if (previous) life.data.shifts.push({ day, kind: previous });
              renderLifeOS();
            }
            osError(err);
          });
        return life.paintQueue;
      }
      // A successful write followed by a failed refresh is still a successful write.
      // Do not restore stale data or invite a second submission in that case.

      /** Mutex scritture Life OS; distingue errore di scrittura da errore di aggiornamento. */
      async function osWrite(method, arg, optimistic) {
        if (life.busy) return;
        life.busy = true;
        ++life.readRevision;
        const previous = life.data ? structuredClone(life.data) : null;
        try {
          if (optimistic) {
            optimistic();
            renderLifeOS();
          }
          const result = await osRequest(method, arg);
          try {
            await osRefresh();
          } catch (error) {
            osError(
              Error("Salvato. Aggiornamento non riuscito: " + error.message),
            );
          }
          return result;
        } catch (error) {
          life.data = previous;
          renderLifeOS();
          osError(error);
        } finally {
          life.busy = false;
        }
      }

      /** Only direct draggable rows belong to the todo ordering contract. */
      function osTodoOrderIds(parent) {
        return [...parent.children]
          .filter(row => row.matches("[data-life-drag-row]") && row.querySelector("[data-life-drag-handle]"))
          .map(row => Number(row.dataset.lifeDragRow));
      }

      /** Salva l\u2019ordine completo delle attivit\xE0 aperte della categoria. */
      async function osCommitOrder(category, ids) {
        if (life.busy) return;
        await osWrite("reorderTasks", { category, ids });
      }
      let osDrag = null;
      document.addEventListener("pointerdown", (e) => {
        const handle = e.target.closest("[data-life-drag-handle]");
        if (!handle || (e.pointerType === "mouse" && e.button !== 0) || life.busy) return;
        const row = handle.closest("[data-life-drag-row]");
        osDrag = {
          handle,
          row,
          category: life.category,
          startY: e.clientY,
          active: false,
        };
        handle.setPointerCapture(e.pointerId);
        e.preventDefault();
      });
      document.addEventListener("pointermove", (e) => {
        if (!osDrag) return;
        const d = osDrag;
        if (Math.abs(e.clientY - d.startY) > 5) d.active = true;
        if (!d.active) return;
        d.row.classList.add("is-dragging");
        const at = document
          .elementFromPoint(e.clientX, e.clientY)
          ?.closest("[data-life-drag-row]");
        if (
          at &&
          at !== d.row &&
          at.parentElement === d.row.parentElement &&
          at.querySelector("[data-life-drag-handle]")
        ) {
          const midpoint = at.getBoundingClientRect().top + at.offsetHeight / 2;
          at.parentElement.insertBefore(
            d.row,
            e.clientY < midpoint ? at : at.nextSibling,
          );
        }
        if (e.clientY > innerHeight - 75) scrollBy(0, 15);
        else if (e.clientY < 75) scrollBy(0, -15);
        e.preventDefault();
      });
      document.addEventListener("pointercancel", () => {
        if (osDrag) {
          osDrag.row.classList.remove("is-dragging");
          osDrag = null;
          renderLifeOS();
        }
      });
      document.addEventListener("pointerup", (e) => {
        if (!osDrag) return;
        const d = osDrag;
        osDrag = null;
        d.row.classList.remove("is-dragging");
        if (!d.active) return;
        const ids = osTodoOrderIds(d.row.parentElement);
        osCommitOrder(d.category, ids);
      });
      document.addEventListener("keydown", (e) => {
        const handle = e.target.closest("[data-life-drag-handle]");
        if (!handle || !e.altKey || !["ArrowUp", "ArrowDown"].includes(e.key))
          return;
        e.preventDefault();
        const row = handle.closest("[data-life-drag-row]"),
          peer =
            e.key === "ArrowUp"
              ? row.previousElementSibling
              : row.nextElementSibling;
        if (
          !peer?.matches("[data-life-drag-row]") ||
          !peer.querySelector("[data-life-drag-handle]")
        )
          return;
        const parent = row.parentElement;
        parent.insertBefore(row, e.key === "ArrowUp" ? peer : peer.nextSibling);
        const ids = osTodoOrderIds(parent);
        osCommitOrder(life.category, ids).then(() =>
          document
            .querySelector(
              '[data-life-drag-handle="' + row.dataset.lifeDragRow + '"]',
            )
            ?.focus(),
        );
      });

      /** Editor creazione/modifica attivit\xE0, con valori HTML escapati. */
      function osOpenTask(id) {
        const t = life.data.tasks.find((t) => t.id === Number(id)),
          d = document.getElementById("life-dialog");
        d.innerHTML = \`<div class="modal os-dialog" role="dialog" aria-modal="true"><div class="os-topline"><h2>\${t ? "Modifica attivit\xE0" : "Nuova attivit\xE0"}</h2><button class="os-icon-button" data-life-close aria-label="Chiudi">\xD7</button></div><form id="life-form" data-kind="task" class="os-form"><input type="hidden" name="record_id" value="\${t?.id || ""}"><label class="wide">Titolo *<input name="title" maxlength="160" required value="\${osSafe(t?.title || "")}"></label><label>Categoria *<select name="list_kind" required>\${life.data.categories.map((c) => \`<option value="\${osSafe(c.key)}" \${t?.list_kind === c.key || (!t && c.key === life.category) ? "selected" : ""}>\${osSafe(c.label)}</option>\`).join("")}</select></label><label>In calendario<input type="date" name="scheduled_date" value="\${osSafe(t?.scheduled_date || "")}"></label><label>Scadenza<input type="date" name="due_date" value="\${osSafe(t?.due_date || "")}"></label><label class="wide">Note<textarea name="notes" maxlength="1000">\${osSafe(t?.notes || "")}</textarea></label><div class="os-form-actions">\${t && t.status !== "done" ? \`<button class="os-button" type="button" data-life-status="\${t.id}:\${t.status === "waiting" ? "todo" : "waiting"}">\${t.status === "waiting" ? "Riporta in Da fare" : "Metti in attesa"}</button>\` : ""}\${t ? \`<button class="os-button danger" type="button" data-life-delete-task="\${t.id}">Elimina</button>\` : ""}<button class="os-button primary" type="submit">Salva</button></div></form></div>\`;
        d.classList.remove("hidden");
        if (!matchMedia("(pointer:coarse)").matches)
          d.querySelector("[name=title]").focus();
      }

      /** Controlli Su/Gi\xF9 per l\u2019ordine delle categorie; estremi disabilitati. */
      function osCategoryOrder() {
        return \`<section class="category-order"><h3>Ordine categorie</h3>\${life.data.categories.map((c, i) => \`<div><span>\${osSafe(c.label)}</span><button type="button" data-life-rename-category="\${osSafe(c.key)}">Modifica</button><button type="button" data-category-order="\${i}:-1" \${i === 0 ? "disabled" : ""} aria-label="Sposta \${osSafe(c.label)} prima">Su</button><button type="button" data-category-order="\${i}:1" \${i === life.data.categories.length - 1 ? "disabled" : ""} aria-label="Sposta \${osSafe(c.label)} dopo">Gi\xF9</button></div>\`).join("")}</section>\`;
      }

      /** Editor nome categoria e ordine; chiavi stabili indipendenti dall\u2019etichetta. */
      function osOpenCategory(key) {
        const current = key
          ? life.data.categories.find((c) => c.key === key)
          : null;
        const d = document.getElementById("life-dialog");
        d.innerHTML = \`<div class="modal os-dialog" role="dialog" aria-modal="true"><div class="os-topline"><h2>\${current ? "Rinomina categoria" : "Nuova categoria"}</h2><button class="os-icon-button" data-life-close aria-label="Chiudi">\xD7</button></div><form id="life-form" data-kind="category" class="os-form"><input type="hidden" name="key" value="\${osSafe(current?.key || "")}"><label class="wide">Nome *<input name="label" maxlength="40" required value="\${osSafe(current?.label || "")}"></label><div class="os-form-actions"><button class="os-button primary" type="submit">\${current ? "Salva nome" : "Aggiungi categoria"}</button></div></form>\${current && life.data.categories.length>1 ? \`<div class="os-form"><label>Trasferisci attivit\xE0 a<select name="categoryDestination">\${life.data.categories.filter(c=>c.key!==current.key).map(c=>\`<option value="\${osSafe(c.key)}">\${osSafe(c.label)}</option>\`).join("")}</select></label><button type="button" class="os-button danger" data-life-delete-category="\${osSafe(current.key)}">Elimina categoria</button></div>\` : ""}\${osCategoryOrder()}</div>\`;
        d.classList.remove("hidden");
        if (!matchMedia("(pointer:coarse)").matches)
          d.querySelector("[name=label]").focus();
      }

      /** Seleziona l\u2019evento o l\u2019occorrenza e apre il relativo editor nel calendario. */
      function osOpenEvent(id, splitFrom = null) {
        life.editingSplitFrom = splitFrom;
        life.editingEvent = id === "new" ? null : Number(id);
        life.creatingEvent = id === "new";
        if (life.editingEvent) {
          const ev =
            life.data.events.find((e) => e.id === life.editingEvent) ||
            life.data.upcomingEvents?.find((e) => e.id === life.editingEvent);
          if (ev) {
            life.month = (splitFrom || ev.day).slice(0, 7);
            life.selected = splitFrom || ev.day;
          }
        }
        life.tool = "event";
        setView("calendar");
        document
          .getElementById("os-event-editor")
          ?.scrollIntoView({ behavior: "smooth", block: "center" });
        document.querySelector("#os-event-editor [name=title]")?.focus();
      }

      /** Chiude il foglio Life OS e termina la modifica evento. */
      function osClose() {
        document.getElementById("life-dialog").classList.add("hidden");
        life.creatingEvent = false;
        life.editingEvent = null;
        life.editingSplitFrom = null;
        if (life.tool === "event") life.tool = null;
        renderLifeOS();
      }
      document.addEventListener("click", (e) => {
        const el = e.target.closest(
          "[data-life-reorder],[data-life-nav],[data-life-task],[data-life-event],[data-life-split-event],[data-life-category],[data-life-rename-category],[data-life-delete-category],[data-life-delete-completed],[data-life-select-category],[data-life-close],[data-life-save],[data-life-status],[data-life-complete],[data-life-delete-task],[data-life-delete-event],[data-life-occurrence],[data-life-month],[data-life-day],[data-life-tool],[data-life-undo],[data-life-routine],[data-life-routine-manage],[data-life-routine-edit],[data-life-routine-delete]",
        );
        if (!el) return;
        if (el.hasAttribute("data-life-routine")) {
          const id = Number(el.dataset.lifeRoutine),
            habit = life.data.routines.find((h) => h.id === id);
          if (!habit) return;
          const checked = !habit.checked,
            day = life.data.today;
          habit.checked = checked ? 1 : 0;
          life.routinePending++;
          life.routineRevision++;
          document.getElementById("today").innerHTML = osToday();
          life.routineQueue = life.routineQueue
            .then(() => osRequest("setRoutineCheck", { id, checked, day }))
            .catch(osError)
            .finally(async () => {
              life.routinePending--;
              if (!life.routinePending) {
                const revision = life.routineRevision;
                const fresh = await osRequest("getLifeData", life.month);
                if (revision === life.routineRevision) {
                  life.data = fresh;
                  renderLifeOS();
                }
              }
            })
            .catch(osError);
          return;
        }
        if (el.hasAttribute("data-life-routine-manage"))
          return osManageRoutines();
        if (el.hasAttribute("data-life-routine-edit")) {
          const h = life.data.routines.find(
            (x) => x.id === Number(el.dataset.lifeRoutineEdit),
          );
          if (!h) return;
          lifeOSHabits.edit(h);
          return;
        }
        if (el.hasAttribute("data-life-routine-delete")) {
          if (!confirm("Eliminare questa voce e le sue spunte?")) return;
          return osWrite(
            "deleteRoutine",
            Number(el.dataset.lifeRoutineDelete),
          ).then((saved) => {
            if (saved) osManageRoutines();
          });
        }
        if (el.hasAttribute("data-life-reorder")) {
          life.reorder = !life.reorder;
          renderLifeOS();
          return;
        }
        if (el.hasAttribute("data-life-nav"))
          return setView(el.dataset.lifeNav);
        if (el.hasAttribute("data-life-task"))
          return osOpenTask(el.dataset.lifeTask);
        if (el.hasAttribute("data-life-split-event")) {
          const [id, day] = el.dataset.lifeSplitEvent.split(":");
          return osOpenEvent(id, day);
        }
        if (el.hasAttribute("data-life-event"))
          return osOpenEvent(el.dataset.lifeEvent);
        if (el.hasAttribute("data-life-delete-category")) {
          const key=el.dataset.lifeDeleteCategory, destination=document.querySelector("[name=categoryDestination]")?.value;
          osWrite("deleteCategory",{key,destination}).then(()=>osClose());return;
        }
        if (el.hasAttribute("data-life-category")) return osOpenCategory();
        if (el.hasAttribute("data-life-rename-category"))
          return osOpenCategory(el.dataset.lifeRenameCategory);
        if (el.hasAttribute("data-life-delete-completed")) {
          if (confirm("Eliminare tutte le completate di questa categoria?"))
            return osWrite("deleteCompletedTasks", {
              category: el.dataset.lifeDeleteCompleted,
            });
          return;
        }
        if (el.hasAttribute("data-life-select-category")) {
          const top = window.scrollY,
            left = document.querySelector(".os-category-tabs").scrollLeft;
          life.category = el.dataset.lifeSelectCategory;
          renderLifeOS();
          document.querySelector(".os-category-tabs").scrollLeft = left;
          window.scrollTo({ top, behavior: "instant" });
          return;
        }
        if (el.hasAttribute("data-life-close")) return osClose();
        if (el.hasAttribute("data-life-save")) {
          if (!e.defaultPrevented) {
            e.preventDefault();
            osSubmit(el.closest("form"));
          }
          return;
        }
        if (el.hasAttribute("data-life-status")) {
          const [id, status] = el.dataset.lifeStatus.split(":");
          if (el.closest(".os-dialog")) osClose();
          return osWrite("setTaskStatus", { id: Number(id), status }, () => {
            const t = life.data.tasks.find((t) => t.id === Number(id));
            t.status = status;
            t.completed_at =
              status === "done" ? new Date().toISOString() : null;
          });
        }
        if (el.hasAttribute("data-life-complete"))
          return osWrite(
            "setTaskStatus",
            { id: Number(el.dataset.lifeComplete), status: "done" },
            () => {
              life.data.tasks.find(
                (t) => t.id === Number(el.dataset.lifeComplete),
              ).status = "done";
            },
          );
        if (el.hasAttribute("data-life-delete-task")) {
          if (confirm("Eliminare questa attivit\xE0?")) {
            osClose();
            return osWrite("deleteTask", Number(el.dataset.lifeDeleteTask));
          }
          return;
        }
        if (el.hasAttribute("data-life-occurrence")) {
          const [id, day, status] = el.dataset.lifeOccurrence.split(":");
          if (
            status === "skipped" &&
            !confirm("Eliminare solo questa occorrenza?")
          )
            return;
          return osWrite("setEventOccurrence", { id: Number(id), day, status });
        }
        if (el.hasAttribute("data-life-delete-event")) {
          if (confirm("Eliminare questo evento e tutte le sue ricorrenze?")) {
            osClose();
            return osWrite("deleteEvent", Number(el.dataset.lifeDeleteEvent));
          }
          return;
        }
        if (el.hasAttribute("data-life-tool")) {
          life.tool =
            el.dataset.lifeTool === "none" || life.tool === el.dataset.lifeTool
              ? null
              : el.dataset.lifeTool;
          if (life.tool !== "event") {
            life.creatingEvent = false;
            life.editingEvent = null;
          }
          return renderLifeOS();
        }
        if (el.hasAttribute("data-life-month")) {
          const [y, m] = life.month.split("-").map(Number);
          life.month = new Date(
            Date.UTC(y, m - 1 + Number(el.dataset.lifeMonth), 1),
          )
            .toISOString()
            .slice(0, 7);
          life.selected = null;
          life.creatingEvent = false;
          life.editingEvent = null;
          return loadLifeOS();
        }
        if (el.hasAttribute("data-life-day")) {
          const day = el.dataset.lifeDay,
            old = life.data.shifts.find((s) => s.day === day)?.kind || null;
          life.selected = day;
          if (!life.tool) {
            renderLifeOS();
            return;
          }
          if (life.tool === "event") {
            life.creatingEvent = true;
            life.editingEvent = null;
            renderLifeOS();
            document
              .getElementById("os-event-editor")
              ?.scrollIntoView({ behavior: "smooth", block: "center" });
            return;
          }
          life.undo = { day, kind: old };
          return osPaint(day, life.tool);
        }
        if (el.hasAttribute("data-life-undo") && life.undo) {
          const { day, kind } = life.undo;
          life.undo = null;
          return osPaint(day, kind || "erase");
        }
      });

      /** Valida il form e invia una sola scrittura; evita il reinvio di eventi gi\xE0 salvati. */
      async function osSubmit(form) {
        if (!form || form.getAttribute("id") !== "life-form") return;
        const formMessage = form.querySelector(".os-form-error");
        if (!form.reportValidity()) {
          if (formMessage) {
            formMessage.textContent = "Completa i campi indicati con *.";
            formMessage.classList.remove("hidden");
          }
          return;
        }
        const values = Object.fromEntries(new FormData(form).entries()),
          kind = form.dataset.kind;
        if (values.record_id) values.id = Number(values.record_id);
        delete values.record_id;
        if (kind === "category") {
          const saved = await osWrite(
            values.key ? "renameCategory" : "addCategory",
            { key: values.key, label: values.label },
          );
          if (saved) {
            life.category = values.key || saved.key;
            osClose();
            renderLifeOS();
          }
          return;
        }
        if (kind === "event") {
          if (form.dataset.saving === "true") return;
          form.dataset.saving = "true";
          const button = form.querySelector("[data-life-save]"),
            message = form.querySelector(".os-form-error");
          let savedOnServer = form.dataset.saved === "true";
          try {
            if (values.end_time && !values.start_time)
              throw Error("Indica anche l\u2019ora di inizio.");
            button.disabled = true;
            button.textContent = "Salvataggio\u2026";
            message.textContent = "Salvataggio in corso\u2026";
            message.classList.add("is-pending");
            message.classList.remove("hidden");
            if (!savedOnServer) {
              await osRequest(
                values.split_from ? "splitEventSeries" : "saveEvent",
                values,
              );
              savedOnServer = true;
              form.dataset.saved = "true";
            }
            const eventMonth = values.day.slice(0, 7);
            const fresh = await osRequest("getLifeData", eventMonth);
            life.month = eventMonth;
            life.selected = values.day;
            life.data = fresh;
            life.creatingEvent = false;
            life.editingEvent = null;
            life.tool = null;
            renderLifeOS();
            document
              .querySelector('[data-life-day="' + values.day + '"]')
              ?.scrollIntoView({ block: "center", behavior: "smooth" });
            document.getElementById("error").classList.add("hidden");
          } catch (err) {
            message.textContent =
              (savedOnServer
                ? "Evento salvato, aggiornamento non riuscito. Riprova ad aggiornare: "
                : "Evento non salvato: ") + (err.message || err);
            message.classList.remove("hidden");
            message.classList.remove("is-pending");
            button.disabled = false;
            button.textContent = savedOnServer
              ? "Aggiorna calendario"
              : "Salva evento";
          } finally {
            delete form.dataset.saving;
          }
          return;
        }
        const saved = await osWrite("saveTask", values);
        if (saved) osClose();
      }
      document.addEventListener(
        "submit",
        (e) => {
          if (e.target.getAttribute("id") === "life-form") {
            e.preventDefault();
            osSubmit(e.target);
          }
          if (e.target.getAttribute("id") === "os-routine-form") {
            e.preventDefault();
            lifeOSHabits.save(e.target);
          }
        },
        true,
      );

      /** Gestisce il cambio giorno a Roma senza moltiplicare i timer. */
      function osRefreshClock() {
        if (!life.data) return;
        const today = new Date().toLocaleDateString("sv-SE", {
          timeZone: "Europe/Rome",
        });
        if (today !== life.data.today) {
          life.month = today.slice(0, 7);
          life.selected = null;
          loadLifeOS();
          osLoadHomeFinance();
          osLoadWeather();
          osUpdateHeader();
          return;
        }
        const box = document.querySelector(".os-solar-inline");
        if (box) box.innerHTML = osPrayerCard(today);
        if (Date.now() - life.weatherAt >= 30 * 60000) osLoadWeather();
      }
      window.setInterval?.(osRefreshClock, 60000);
      document.addEventListener("visibilitychange", () => {
        if (!document.hidden) {
          osRefreshClock();
          osLoadWeather();
        }
      });

      document.addEventListener(
        "toggle",
        (e) => {
          if (e.target.matches(".os-tools-drawer"))
            life.paletteOpen = e.target.open;
        },
        true,
      );
      document.addEventListener("click", async (e) => {
        const b = e.target.closest("[data-category-order]");
        if (!b || life.busy) return;
        const [i, delta] = b.dataset.categoryOrder.split(":").map(Number),
          keys = life.data.categories.map((c) => c.key);
        [keys[i], keys[i + delta]] = [keys[i + delta], keys[i]];
        await osWrite("reorderCategories", { keys });
        const section = document.querySelector(".category-order");
        if (section) section.outerHTML = osCategoryOrder();
      });
    <\/script>
    <script>
      // The finance month follows Rome even when the device is abroad.
      const now = new Date(
        new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Rome" }) +
          "T12:00:00",
      );
      const state = {
        year: now.getFullYear(),
        month: now.getMonth() + 1,
        view: "today",
        categoryMonth: now.getMonth() + 1,
        data: null,
        search: "",
        type: "Tutti",
        busy: false,
        assetsVisible: true,
        overviewCardsOpen: false,
        overviewAnalysisOpen: false,
        overviewPlanOpen: false,
        loadedDetail: false,
        loadRevision: 0,
        movementLimit: 100,
        planningDraft: null,
        wealthSeries: "total",
        budgetSettingsOpen: false,
        budgetAnnualOpen: false,
        budgetHistoryOpen: false,
      };
      const euroFormatter = new Intl.NumberFormat("it-IT", {
        style: "currency",
        currency: "EUR",
            useGrouping: "always",
        maximumFractionDigits: 0,
      });
      const euro = (n) => euroFormatter.format(n || 0);
      const exactEuroFormatter = new Intl.NumberFormat("it-IT", {
        style: "currency",
        currency: "EUR",
            useGrouping: "always",
      });
      const exactEuro = (n) => exactEuroFormatter.format(n || 0);
      const privateAmount = (n) => (state.assetsVisible ? euro(n) : "\u2022\u2022\u2022\u2022 \u20AC");

      /** Pulsante patrimonio con stato e nome accessibile coerenti. */
      function privacyButton() {
        const label = state.assetsVisible
          ? "Nascondi patrimonio"
          : "Mostra patrimonio";
        const eye = state.assetsVisible
          ? '<path d="M2 12s3.8-7 10-7 10 7 10 7-3.8 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>'
          : '<path d="M3 3l18 18M10.6 5.1A10.8 10.8 0 0 1 12 5c6.2 0 10 7 10 7a16.7 16.7 0 0 1-3.2 3.9M6.2 6.2A16 16 0 0 0 2 12s3.8 7 10 7c1.6 0 3-.5 4.2-1.3M10.1 10.1a3 3 0 0 0 3.8 3.8"/>';
        return (
          '<button type="button" class="privacy-toggle" data-toggle-assets aria-label="' +
          label +
          '" title="' +
          label +
          '" aria-pressed="' +
          state.assetsVisible +
          '"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
          eye +
          "</svg></button>"
        );
      }
      const shortMonth = (key) =>
        key
          ? new Date(
              +key.slice(0, 4),
              +key.slice(5, 7) - 1,
              1,
            ).toLocaleDateString("it-IT", { month: "short", year: "2-digit" })
          : "\u2014";
      const titleMonth = (year, month) =>
        new Date(year, month - 1, 1).toLocaleDateString("it-IT", {
          month: "long",
          year: "numeric",
        });
      const escapeHtml = (value) =>
        String(value ?? "").replace(
          /[&<>"']/g,
          (s) =>
            ({
              "&": "&amp;",
              "<": "&lt;",
              ">": "&gt;",
              '"': "&quot;",
              "'": "&#39;",
            })[s],
        );
      const amountClass = (n) => (n < 0 ? "negative" : "");

      /** Carica dati finanziari leggeri o completi in base alla vista; protegge da risposte obsolete. */
      function load() {
        if (state.data && (state.data.year !== state.year || state.data.month !== state.month)) {
          state.data = null; state.loadedDetail = false;
          for (const id of ["overview", "movements", "budget", "analysis", "extras"]) document.getElementById(id).replaceChildren();
        }
        document.getElementById("period-label").textContent = titleMonth(
          state.year,
          state.month,
        );
        const revision = ++state.loadRevision,
          detail = ["movements", "budget", "analysis"].includes(state.view),
          method = detail
            ? "getFinanceData"
            : state.view === "extras"
              ? "getFinanceOverview"
              : "getFinanceOverview";
        document.getElementById("error").classList.add("hidden");
        document.getElementById("loading").classList.remove("hidden");
        const args = [state.year, state.month];
        const request = detail ? workerRequest("getFinanceCategoryOptions", []).then(() => workerRequest(method, args)) : workerRequest(method, args);
        request.then((data) => {
            if (revision !== state.loadRevision) return;
            state.data = data;
            state.loadedDetail = detail;
            document.getElementById("loading").classList.add("hidden");
            render();
            if (life.data && data.key === life.data.today.slice(0, 7)) {
              life.finance = data;
              document.getElementById("today").innerHTML = osToday();
            }
          })
          .catch((err) => {
            if (revision !== state.loadRevision) return;
            document.getElementById("loading").classList.add("hidden");
            const box = document.getElementById("error");
            const message=document.createElement("span");message.textContent="Lettura non riuscita: "+err.message;
            const retry=document.createElement("button");retry.textContent="Riprova";retry.dataset.financeRetry="";retry.onclick=load;
            box.replaceChildren(message,retry);
            box.classList.remove("hidden");
          });
      }

      /** Unico punto di navigazione; aggiorna tab, layout e caricamento necessario. */
      function setView(view) {

        if (
          ![
            "today",
            "tasks",
            "calendar",
            "overview",
            "movements",
            "budget",
            "analysis",
            "extras",
          ].includes(view)
        )
          return;
        const previousView = state.view;
        // Invalidate an in-flight finance read when leaving its view, not on every click.
        if (previousView !== view) {
          ++state.loadRevision;
          document.getElementById("loading").classList.add("hidden");
        }
        state.view = view;
        document.body.classList.toggle("dashboard-mode", view === "today");
        document
          .querySelectorAll(".view")
          .forEach((x) => x.classList.toggle("active", x.id === view));
        document
          .querySelectorAll("button[data-view]")
          .forEach((x) =>
            x.classList.toggle("active", x.dataset.view === view),
          );
        document.getElementById("page-title").textContent = {
          today: "Dashboard",
          tasks: "Attivit\xE0",
          calendar: "Calendario",
          overview: "Finanza",
          movements: "Movimenti",
          budget: "Budget",
          analysis: "Analisi",
          extras: "Piani",
        }[view];
        document
          .getElementById("finance-tabs")
          .classList.toggle(
            "hidden",
            !["movements", "budget", "analysis", "budget", "extras", "analysis"].includes(view),
          );
        document
          .querySelector(".top-right")
          .classList.toggle(
            "hidden",
            !["overview", "movements", "budget", "analysis", "budget", "extras", "analysis"].includes(view),
          );
        document.body.dataset.view = view;
        osPageActions();
        if (["overview", "movements", "budget", "analysis", "budget", "extras", "analysis"].includes(view)) {
          if (
            !state.data ||
            state.data.year !== state.year ||
            state.data.month !== state.month ||
            (["movements", "budget", "analysis"].includes(view) && !state.loadedDetail)
          )
            load();
          else render();
        }
        document
          .querySelector(".nav [data-view=overview]")
          .classList.toggle(
            "active",
            ["overview", "movements", "budget", "analysis", "budget", "extras", "analysis"].includes(view),
          );
        document
          .querySelectorAll(".nav [data-view]")
          .forEach((button) =>
            button.setAttribute(
              "aria-current",
              button.classList.contains("active") ? "page" : "false",
            ),
          );
        if (view !== "calendar") life.tool = null;
        if (["today", "tasks", "calendar"].includes(view)) {
          renderLifeOS();
          if (view === "today") osLoadHomeFinance();
        }
        window.scrollTo({ top: 0, behavior: "instant" });
      }

      /** Render finanziario limitato alla vista attiva; evita grafici nascosti costosi. */
      function render() {
        const d = state.data;
        if (!d) return;
        for (const id of ["overview", "extras", "movements", "budget", "analysis"])
          if (id !== state.view) document.getElementById(id).innerHTML = "";
        document.getElementById("sync-top").textContent =
          "Aggiornato " + d.updatedAt;
        document.getElementById("sync-side").textContent =
          "Aggiornato " + d.updatedAt;
        document.getElementById("version-side").textContent =
          "Versione " + (d.appVersion || "precedente");
        if (state.view === "overview") {
          document.getElementById("overview").innerHTML = overview(d);

        }
        if (state.view === "budget" && state.loadedDetail) {
          document.getElementById("budget").innerHTML = monthlyBudgetDetails(d.summary) + overviewAnalysis(d);
          updateProjection();
        }
        if (state.view === "analysis" && state.loadedDetail) document.getElementById("analysis").innerHTML = platformAnalysis(d);
        if (state.view === "extras")
          document.getElementById("extras").innerHTML = extrasView(d);
        if (state.view === "movements" && state.loadedDetail) renderMovements();
      }

      /** Tabella mensile annuale; gli importi patrimonio rispettano la modalit\xE0 privacy. */
      function annual(d) {
        const format = (x) =>
          '<div class="annual-row ' +
          (x.month === d.key ? "selected" : "") +
          '" data-month="' +
          x.month +
          '"><strong>' +
          shortMonth(x.month) +
          "</strong><span>" +
          (x.hasRecords
            ? (x.incomePayslip ? "\u2248 " : "") + euro(x.income)
            : "\u2014") +
          "</span><span>" +
          (x.hasRecords ? euro(x.spent) : "\u2014") +
          '</span><span class="desktop-only">' +
          (x.hasRecords ? euro(x.net) : "\u2014") +
          '</span><span class="annual-wealth">' +
          (() => {
            const w = (d.lifetime?.series || []).find(
              (m) => m.month === x.month,
            )?.wealth;
            return Number.isFinite(w) ? privateAmount(w) : "\u2014";
          })() +
          "</span><span>" +
          exactEuro(x.budgetCommitments ?? x.commitments) +
          '</span><span class="emphasis ' +
          (x.spendable < 0 ? "bad" : "") +
          '">' +
          exactEuro(x.month === d.key ? d.summary.monthlyRemaining : (x.monthlyRemaining ?? x.spendable)) +
          "</span></div>";
        const t = d.yearTotal;
        return (
          '<div class="annual-head"><span>Mese</span><span>Entrate</span><span>Uscite</span><span class="desktop-only">Netto</span><span>Patrimonio</span><span>Impegni</span><span title="Mese corrente: residuo; mesi: libero dopo gli impegni">Spendibile</span></div>' +
          d.yearly.map(format).join("") +
          '<div class="annual-row total"><strong>Anno</strong><span>' +
          (t.incomePayslip ? "\u2248 " : "") +
          euro(t.income) +
          "</span><span>" +
          euro(t.spent) +
          '</span><span class="desktop-only">' +
          euro(t.net) +
          "</span><span>\u2014</span><span>" +
          euro(t.commitments) +
          "</span><span>\u2014</span></div>"
        );
      }
      // A monotone cubic spline keeps the curves smooth without inventing peaks.

      /** Genera una curva SVG dai punti senza dipendenze esterne. */
      function chartCurve(points) {
        if (!points.length) return "";
        const chunks = [];
        let current = [];
        const flush = () => {
          if (!current.length) return;
          if (current.length === 1) {
            chunks.push("M" + current[0].x + " " + current[0].y);
            current = [];
            return;
          }
          const slope = current
            .slice(1)
            .map((p, i) => (p.y - current[i].y) / (p.x - current[i].x));
          const tangent = current.map((_, i) => {
            if (i === 0) return slope[0];
            if (i === current.length - 1) return slope[slope.length - 1];
            return slope[i - 1] * slope[i] <= 0
              ? 0
              : (2 * slope[i - 1] * slope[i]) / (slope[i - 1] + slope[i]);
          });
          let path = "M" + current[0].x + " " + current[0].y;
          for (let i = 0; i < current.length - 1; i++) {
            const a = current[i],
              b = current[i + 1],
              dx = (b.x - a.x) / 3,
              lo = Math.min(a.y, b.y),
              hi = Math.max(a.y, b.y);
            const c1 = Math.max(lo, Math.min(hi, a.y + tangent[i] * dx));
            const c2 = Math.max(lo, Math.min(hi, b.y - tangent[i + 1] * dx));
            path +=
              " C" +
              (a.x + dx).toFixed(1) +
              " " +
              c1.toFixed(1) +
              " " +
              (b.x - dx).toFixed(1) +
              " " +
              c2.toFixed(1) +
              " " +
              b.x +
              " " +
              b.y;
          }
          chunks.push(path);
          current = [];
        };
        for (const point of points) {
          if (point) current.push(point);
          else flush();
        }
        flush();
        return chunks.join(" ");
      }

      /** Grafici entrate/uscite e liquidit\xE0; nasconde dati privati quando richiesto. */
      function cashFlowChart(d) {
        const compact = window.matchMedia("(max-width:760px)").matches,
          limit = state.chartMonths ?? (compact ? 6 : 12),
          series = limit ? d.lifetime.series.slice(-limit) : d.lifetime.series;
        const W = compact ? 420 : 820,
          H = compact ? 250 : 260,
          L = 46,
          R = W - 16,
          T = 22,
          B = H - 40;
        const x = (i) => L + ((i + 0.5) * (R - L)) / series.length,
          slot = (R - L) / series.length,
          bw = Math.min(12, slot * 0.32);
        const max =
            Math.max(100, ...series.flatMap((m) => [m.income, m.spent])) * 1.1,
          y = (v) => B - (v / max) * (B - T);
        const grid = Array.from({ length: 4 }, (_, i) => (max * i) / 3)
          .map(
            (v) =>
              '<line x1="' +
              L +
              '" x2="' +
              R +
              '" y1="' +
              y(v) +
              '" y2="' +
              y(v) +
              '" class="grid-line"/><text x="' +
              (L - 8) +
              '" y="' +
              (y(v) + 4) +
              '" text-anchor="end">' +
              Math.round(v / 100) / 10 +
              "k</text>",
          )
          .join("");
        const labels = series
          .map((m, i) =>
            i % Math.max(1, Math.ceil(series.length / (compact ? 4 : 8))) &&
            i !== series.length - 1
              ? ""
              : '<text x="' +
                x(i) +
                '" y="' +
                (H - 12) +
                '" text-anchor="middle">' +
                shortMonth(m.month) +
                "</text>",
          )
          .join("");
        const bars = series
          .map((m, i) =>
            ["income", "spent"]
              .map(
                (k, j) =>
                  '<rect data-chart-month="' +
                  m.month +
                  '" data-month="' +
                  m.month +
                  '" data-series="' +
                  k +
                  '" x="' +
                  (x(i) + (j ? 1 : -bw - 1)) +
                  '" y="' +
                  y(m[k]) +
                  '" width="' +
                  bw +
                  '" height="' +
                  Math.max(0, B - y(m[k])) +
                  '" rx="2" fill="' +
                  (j ? "#ff9da4" : "var(--os-accent)") +
                  '"><title>' +
                  shortMonth(m.month) +
                  " \xB7 " +
                  (j ? "Uscite " : "Entrate ") +
                  euro(m[k]) +
                  "</title></rect>",
              )
              .join(""),
          )
          .join("");
        const visible = state.assetsVisible,
          totalMode = false;
        const valueOf = (m) => (totalMode ? m.liquidWealth : m.wealth);
        const known = series.filter((m) => Number.isFinite(valueOf(m)));
        const wm = Math.max(100, ...known.map(valueOf)),
          wl = Math.min(0, ...known.map(valueOf));
        const wy = (v) => B - ((v - wl) / (wm - wl || 1)) * (B - T);
        const path = chartCurve(
          series.map((m, i) =>
            Number.isFinite(valueOf(m)) ? { x: x(i), y: wy(valueOf(m)) } : null,
          ),
        );
        const dots = known
          .map(
            (m) =>
              \`<circle cx="\${x(series.indexOf(m))}" cy="\${wy(valueOf(m))}" r="4" class="wealth-dot"><title>\${shortMonth(m.month)} \xB7 \${euro(valueOf(m))}</title></circle>\`,
          )
          .join("");
        const wg = Array.from({ length: 4 }, (_, i) => wl + ((wm - wl) * i) / 3)
          .map(
            (v) =>
              \`<line x1="\${L}" x2="\${R}" y1="\${wy(v)}" y2="\${wy(v)}" class="grid-line"/><text x="\${L - 8}" y="\${wy(v) + 4}" text-anchor="end">\${Math.round(v / 100) / 10}k</text>\`,
          )
          .join("");
        const liquid = visible
          ? known.length
            ? \`<div class="chart-scroll"><svg class="trend-svg is-compact wealth-chart" viewBox="0 0 \${W} \${H}" role="img" aria-label="Patrimonio">\${wg}<path class="wealth-record-line" d="\${path}"/>\${dots}\${labels}</svg></div><p class="hint">Dati verificati da \${shortMonth(known[0].month)}.</p>\`
            : '<p class="empty">Nessun saldo verificato nel periodo.</p>'
          : '<button type="button" class="ghost" data-toggle-assets>Mostra patrimonio</button>';
        const wealthControls = "";
        const selected =
          series.find((m) => m.month === state.chartSelectedMonth) ||
          series.at(-1);
        const selectedValues = selected
          ? '<div class="trend-values"><b>' +
            shortMonth(selected.month) +
            "</b><span>Entrate <strong>" +
            euro(selected.income) +
            "</strong></span><span>Uscite <strong>" +
            euro(selected.spent) +
            "</strong></span></div>"
          : "";
        const controls =
          '<div class="chart-range" role="group" aria-label="Periodo del grafico">' +
          [
            [3, "3 mesi"],
            [6, "6 mesi"],
            [12, "12 mesi"],
            [0, "Tutto"],
          ]
            .map(
              ([n, label]) =>
                '<button type="button" data-chart-range="' +
                n +
                '" aria-pressed="' +
                (limit === n) +
                '">' +
                label +
                "</button>",
            )
            .join("") +
          "</div>";
        const table = series
          .map(
            (m) =>
              '<tr><th scope="row">' +
              shortMonth(m.month) +
              "</th><td>" +
              euro(m.income) +
              "</td><td>" +
              euro(m.spent) +
              "</td><td>" +
              (Number.isFinite(valueOf(m)) ? privateAmount(valueOf(m)) : "\u2014") +
              "</td></tr>",
          )
          .join("");
        return (
          '<div class="integrated-chart chart-pair"><section class="card pad flow-card"><div class="card-title"><h2>Entrate e uscite</h2></div>' +
          controls +
          '<div class="flow-legend"><span class="income-key">Entrate</span><span class="spent-key">Uscite</span></div><div class="chart-scroll"><svg class="trend-svg is-compact" viewBox="0 0 ' +
          W +
          " " +
          H +
          '" role="img" aria-label="Entrate e uscite mensili">' +
          grid +
          bars +
          labels +
          "</svg></div>" +
          selectedValues +
          '</section><section class="card pad wealth-chart-card"><div class="card-title liquid-chart-heading"><div><h2>Patrimonio</h2><small>' +
          "Patrimonio" +
          " \xB7 " +
          privateAmount(totalMode ? d.summary.totalAssets : d.summary.assets) +
          "</small></div>" +
          privacyButton() +
          "</div>" +
          wealthControls +
          liquid +
          '<details class="chart-values"><summary>Valori mensili</summary><div class="chart-scroll"><table><thead><tr><th>Mese</th><th>Entrate</th><th>Uscite</th><th>Patrimonio</th></tr></thead><tbody>' +
          table +
          "</tbody></table></div></details></section></div>"
        );
      }

      document.addEventListener("click", (e) => {
        const range = e.target.closest("[data-chart-range]"),
          month = e.target.closest("[data-chart-month]"),
          wealth = e.target.closest("[data-wealth-series]");
        if (!range && !month && !wealth) return;
        if (wealth) state.wealthSeries = wealth.dataset.wealthSeries;
        if (range) {
          state.chartMonths = Number(range.dataset.chartRange);
          state.chartSelectedMonth = null;
        }
        if (month) state.chartSelectedMonth = month.dataset.chartMonth;
        const chart = document.querySelector("#analysis .integrated-chart");
        if (chart && state.data) chart.outerHTML = cashFlowChart(state.data);
      });

      /** Ripartizione spese storiche con dettaglio; le stime non alterano il saldo. */
      function sankeyCard(d) {
        const compact =
          typeof window !== "undefined" &&
          window.matchMedia("(max-width:760px)").matches;
        const income = Math.max(0, d.lifetime.income),
          out = Math.max(0, d.lifetime.spent),
          total = out;
        if (!total)
          return (
            '<div class="card pad"><h2>Cash flow \xB7 ' +
            d.year +
            '</h2><p class="empty">Nessun movimento disponibile.</p></div>'
          );
        const spent = Object.fromEntries(
          d.lifetime.expenseGroups.map((x) => [x.name, x.amount]),
        );
        const cats = Object.entries(spent)
            .filter((r) => r[1] > 0)
            .sort((a, b) => b[1] - a[1]),
          dest = cats;

        const src = [["Spese registrate", out]];

        const colors = [
          "#ff9f0a",
          "var(--os-accent)",
          "#0a84ff",
          "#bf5af2",
          "#ff453a",
          "#ffd60a",
          "#64d2ff",
          "#ff6482",
        ];

        const sx = compact ? 86 : 174,
          cx = compact ? 170 : 388,
          dx = compact ? 268 : 650,
          labelX = compact ? 279 : 669,
          W = compact ? 400 : 920;
        const gap = compact ? 28 : 24,
          top = compact ? 28 : 42,
          body = compact ? 150 : 200,
          height =
            body +
            gap * (Math.max(src.length, dest.length) - 1) +
            (compact ? 64 : 84);
        const ribbon = (x0, y0, x1, y1, h, color) =>
          '<path class="sankey-ribbon" fill="' +
          color +
          '" d="M' +
          x0 +
          " " +
          y0 +
          " C" +
          (x0 + (x1 - x0) * 0.48) +
          " " +
          y0 +
          " " +
          (x1 - (x1 - x0) * 0.48) +
          " " +
          y1 +
          " " +
          x1 +
          " " +
          y1 +
          " L" +
          x1 +
          " " +
          (y1 + h) +
          " C" +
          (x1 - (x1 - x0) * 0.48) +
          " " +
          (y1 + h) +
          " " +
          (x0 + (x1 - x0) * 0.48) +
          " " +
          (y0 + h) +
          " " +
          x0 +
          " " +
          (y0 + h) +
          ' Z"/>';
        let paths = "",
          nodes = "",
          labels = "",
          sy = top,
          cy = top + (gap * (Math.max(src.length, dest.length) - 1)) / 2;
        const centralTop = cy;
        src.forEach(([name, amount], i) => {
          const h = (amount / total) * body,
            color = name === "Altre risorse nette" ? "#9aa9bd" : "#aeaeb2";
          paths += ribbon(sx, sy, cx, cy, h, color);
          nodes +=
            '<rect x="' +
            (sx - 6) +
            '" y="' +
            sy +
            '" width="6" height="' +
            Math.max(0.8, h) +
            '" rx="2" fill="' +
            color +
            '"/>';
          labels +=
            '<text x="' +
            (sx - 11) +
            '" y="' +
            (sy + h / 2 - 3) +
            '" text-anchor="end" class="sankey-label">' +
            escapeHtml(
              (compact && name === "Spese registrate"
                ? "Spese"
                : compact && name === "Altre risorse nette" ? "Saldo precedente" : name
              ).slice(0, compact ? 14 : 25),
            ) +
            '</text><text x="' +
            (sx - 11) +
            '" y="' +
            (sy + h / 2 + 13) +
            '" text-anchor="end" class="sankey-value">' +
            euro(amount) +
            "</text>";
          sy += h + gap;
          cy += h;
        });
        let dy = top;
        cy = centralTop;
        dest.forEach(([name, amount], i) => {
          const h = (amount / total) * body,
            color =
              name === "Da riconciliare"
                ? "#9aa9bd"
                : colors[i % colors.length];
          paths += ribbon(cx + 8, cy, dx, dy, h, color);
          nodes +=
            '<rect x="' +
            dx +
            '" y="' +
            dy +
            '" width="6" height="' +
            Math.max(0.8, h) +
            '" rx="2" fill="' +
            color +
            '"/>';
          labels +=
            '<text x="' +
            labelX +
            '" y="' +
            (dy + h / 2 - 3) +
            '" class="sankey-label">' +
            escapeHtml(name.slice(0, compact ? 22 : 40)) +
            '</text><text x="' +
            labelX +
            '" y="' +
            (dy + h / 2 + 13) +
            '" class="sankey-value">' +
            euro(amount) +
            " \xB7 " +
            (d.lifetime.expenseGroups.find((g) => g.name === name)
              ?.percentage || 0) +
            "%</text>";
          dy += h + gap;
          cy += h;
        });
        return (
          '<div class="card pad sankey-card"><div class="card-title"><div><div class="section-kicker">STORICO \xB7 ' +
          shortMonth(d.lifetime.from) +
          " - " +
          shortMonth(d.lifetime.to) +
          '</div><h2>Destinazione delle spese</h2></div><div class="sankey-totals"><span>Entrate<b>' +
          euro(income) +
          "</b></span><span>Spese<b>" +
          euro(out) +
          '</b></span></div></div><div class="chart-scroll sankey-scroll"><svg class="sankey-svg' +
          (compact ? " is-compact" : "") +
          '" viewBox="0 0 ' +
          W +
          " " +
          height +
          '" role="img" aria-label="Ripartizione delle spese registrate; percentuali sul totale delle spese">' +
          paths +
          nodes +
          '<rect x="' +
          cx +
          '" y="' +
          centralTop +
          '" width="8" height="' +
          body +
          '" rx="3" fill="#8e8e93"/>' +
          labels +
          '</svg></div><div class="sankey-savings">Patrimonio <strong>' +
          privateAmount(d.summary.totalAssets) +
          "</strong>" +
          privacyButton() +
          "</div>" +
          '<details class="expense-details"><summary>Dettaglio categorie</summary>' +
          d.lifetime.expenseGroups
            .map(
              (c) =>
                '<details class="expense-category"><summary><span>' +
                escapeHtml(c.name) +
                "</span><b>" +
                euro(c.amount) +
                "</b></summary>" +
                d.lifetime.expenseAudit
                  .filter((r) => c.members.includes(r.category))
                  .sort((a, b) => b.amount - a.amount)
                  .map(
                    (r) =>
                      '<div class="overview-recent-row"><time>' +
                      escapeHtml(r.date) +
                      "</time><div><strong>" +
                      escapeHtml(r.name) +
                      "</strong><small>" +
                      escapeHtml(r.account) +
                      " \xB7 " +
                      (r.estimated ? "Stima" : escapeHtml(r.category)) +
                      "</small>" +
                      (r.category === "Da classificare"
                        ? quickClassify(r)
                        : "") +
                      "</div><b>" +
                      euro(r.amount) +
                      "</b></div>",
                  )
                  .join("") +
                "</details>",
            )
            .join("") +
          '</details><p class="hint">Spese storiche stimate: ' +
          euro(d.lifetime.historicalSpendingEstimate?.amount || 0) +
          " \xB7 escluse dai saldi e dai totali mensili.</p></div>"
        );
      }
      document.addEventListener("change", (e) => {
        if(e.target.name === "category" && e.target.closest("#entry-form")){syncUtilityFields();}
        const wrap = e.target.closest(".quick-classify");
        if (wrap && e.target.tagName === "SELECT")
          wrap.querySelector("button").disabled = !e.target.value;
      });

      // Compact manual catalog. Legacy values remain intact until explicitly reclassified.
      const financeManualCategories = lifeOSContract.expenseCategories;
      const financeIncomeCategories = lifeOSContract.incomeCategories;
      function financialCommittedCategories() {
        const recurring=state.data?.recurring || life.finance?.recurring || [];
        return [...new Set(["Affitto", ...recurring.filter(r=>r.treatment==="Vincolata" && r.name!=="Benzina").map(r=>r.name).filter(Boolean)])];
      }
      function financeCategoryLabel(value) { return String(value || ""); }
      function categoryOptionsHtml(values,value="") {
        const choices=[...new Set([...values,...(value?[value]:[])])];
        return choices.map(x=>\`<option value="\${escapeHtml(x)}" \${x===value?"selected":""}>\${escapeHtml(x)}</option>\`).join("");
      }
      function financialCategoryOptions(type = "Spesa") {
        return [...(type === "Entrata" ? financeIncomeCategories : financeManualCategories)];
      }
      document.addEventListener("change", (e) => {
        if (e.target.name !== "type" || !e.target.closest("#entry-form")) return;
        const form = e.target.form, category = form.elements.category;
        if (!category) return;
        const choices = financialCategoryOptions(e.target.value), label = financeCategoryLabel(category.value);
        category.innerHTML = categoryOptionsHtml(choices);
        category.value = choices.includes(label) ? label : "Altro";
        syncUtilityFields();
      });

      /** Controllo per classificare un movimento storico, senza modificarne importo o conto. */
      function quickClassify(r) {
        return (
          '<div class="quick-classify" data-classify-row="' +
          r.row +
          '"><select aria-label="Categoria di ' +
          escapeHtml(r.name) +
          '"><option value="" disabled selected>Scegli categoria</option>' +
          financialCategoryOptions()
            .map((x) => "<option>" + escapeHtml(x) + "</option>")
            .join("") +
          '</select><button class="ghost" type="button" data-apply-category="' +
          r.row +
          '" disabled>Applica</button></div>'
        );
      }

      /** Obiettivi e proiezione risparmi; distinti dal budget operativo. */
      function planningCard(d) {
        const p = d.planning;
        return (
          '<div class="card pad planning-card"><div class="card-title"><h2>Fondo e fine anno</h2><small>' +
          p.year +
          "</small></div>" +
          '<div class="planning-inputs"><label>Fondo Emergenza \u20AC<input id="goal-input" type="number" min="0" max="1000000" step="0.01" inputmode="decimal" placeholder="Imposta la soglia" value="' +
          (state.planningDraft?.goal ?? (p.goal === null ? "" : p.goal)) +
          '"></label>' +
          '<label>Risparmio mensile \u20AC<input id="saving-input" type="number" min="0" max="100000" step="0.01" required inputmode="decimal" value="' +
          (state.planningDraft?.saving ?? p.monthlySaving) +
          '"></label><label>Obiettivo patrimonio \u20AC<input id="target-input" type="number" min="0.01" max="1000000" step="0.01" inputmode="decimal" value="' +
          (state.planningDraft?.target ?? p.savingsTarget ?? '') + '"></label></div>' +
          '<div class="plan-row"><span>Saldo</span><strong>' +
          privateAmount(p.now) +
          "</strong></div>" +
          '<div class="plan-row"><span>Oltre il fondo, oggi</span><strong id="surplus-now">\u2014</strong></div>' +
          '<div class="fund-meter" role="progressbar" aria-label="Copertura fondo" aria-valuemin="0" aria-valuemax="100"><i id="fund-covered"></i><i id="fund-surplus"></i></div><div class="fund-labels"><span id="fund-label">Fondo da impostare</span><span id="surplus-label"></span></div>' +
          '<div class="projection-result"><span>Al 31 dicembre \xB7 ' +
          p.monthsRemaining +
          ' mesi</span><strong id="projected-total">' +
          privateAmount(p.projection) +
          '</strong><small id="projected-surplus">\u2014</small></div>' +
          '<div class="planning-actions"><button type="button" class="save plan-save" id="save-plan">Salva</button><span id="planning-status" role="status" aria-live="polite"></span></div><p class="hint">Simulazione: saldo + risparmio mensile \xD7 ' +
          p.monthsRemaining +
          " mesi.</p></div>"
        );
      }

      /** Aggiorna i soli campi della proiezione, senza ricreare il form. */
      function renderProjection(p) {
        const set = (id, v) => {
          const el = document.getElementById(id);
          if (el) el.textContent = v;
        };
        if (!state.assetsVisible) {
          set("surplus-now", "\u2022\u2022\u2022\u2022 \u20AC");
          set("projected-total", "\u2022\u2022\u2022\u2022 \u20AC");
          set("projected-surplus", "Patrimonio nascosto");
          set("fund-label", "Patrimonio nascosto");
          set("surplus-label", "");
          document
            .querySelector(".fund-meter")
            .removeAttribute("aria-valuenow");
          document.getElementById("fund-covered").style.width = "0%";
          document.getElementById("fund-surplus").style.width = "0%";
          return;
        }
        set("surplus-now", p.surplusNow === null ? "\u2014" : euro(p.surplusNow));
        set("projected-total", euro(p.projection));
        set(
          "projected-surplus",
          p.projectedSurplus === null
            ? "Imposta il fondo"
            : euro(p.projectedSurplus) + " oltre il fondo",
        );
        set(
          "fund-label",
          p.goal === null
            ? "Fondo da impostare"
            : p.missing > 0
              ? "Coperto " + euro(p.now) + " su " + euro(p.goal)
              : "Fondo " + euro(p.goal),
        );
        set(
          "surplus-label",
          p.goal === null
            ? ""
            : p.missing > 0
              ? "Mancano " + euro(p.missing)
              : "Avanzano " + euro(p.surplusNow),
        );
        document
          .querySelector(".fund-meter")
          .setAttribute("aria-valuenow", Math.min(100, Math.round(p.covered)));
        document.getElementById("fund-covered").style.width = p.covered + "%";
        document.getElementById("fund-surplus").style.width = p.surplus + "%";
      }

      /** Local preview uses the reconciled TR balance already loaded in Finance.
       * Input does not trigger database reads. Draft survives chart/theme redraws. */
      function projectPlanning(p, goal, saving) {
        const total =
          Math.round((p.now + saving * p.monthsRemaining) * 100) / 100;
        const base = Math.max(1, goal || 0, p.now);
        return {
          ...p,
          goal,
          monthlySaving: saving,
          projection: total,
          surplusNow:
            goal === null
              ? null
              : Math.max(0, Math.round((p.now - goal) * 100) / 100),
          projectedSurplus:
            goal === null
              ? null
              : Math.max(0, Math.round((total - goal) * 100) / 100),
          missing:
            goal === null
              ? null
              : Math.max(0, Math.round((goal - p.now) * 100) / 100),
          covered:
            goal === null
              ? 0
              : (Math.max(0, Math.min(goal, p.now)) / base) * 100,
          surplus: goal === null ? 0 : (Math.max(0, p.now - goal) / base) * 100,
        };
      }
      function updateProjection() {
        const p = state.data?.planning,
          goal = document.getElementById("goal-input"),
          saving = document.getElementById("saving-input");
        if (!p || !goal || !saving) return;
        state.planningDraft = { goal: goal.value, saving: saving.value, target: document.getElementById("target-input")?.value ?? "" };
        const valid = goal.validity.valid && saving.validity.valid;
        document.getElementById("save-plan").disabled = !valid || state.busy;
        const status = document.getElementById("planning-status");
        status.textContent = valid ? "" : "Importo non valido.";
        if (!valid) {
          document.getElementById("projected-total").textContent = "\u2014";
          return;
        }
        renderProjection(
          projectPlanning(
            p,
            goal.value === "" ? null : Number(goal.value),
            Number(saving.value),
          ),
        );
      }

      /** Anello SVG proporzionale agli importi, indipendente dai CSS del vecchio donut. */
      function categoryCard(d) {
        const key = d.year + '-' + String(state.categoryMonth).padStart(2, '0');
        const data = d.monthlyBreakdowns?.[key] || {};
        const top = (Array.isArray(data.items) ? data.items : []).map(x => ({...x, amount:Number(x.amount)})).filter(x => Number.isFinite(x.amount) && x.amount > 0);
        const total = top.reduce((sum,x) => sum + x.amount,0);
        const colors = ['var(--os-accent)','#6e9cc1','#c79a58','#a788b8','#b9777b','#8b929b'];
        let offset = 0;
        const segments = top.map((x,i) => {
          const share = x.amount / total * 100;
          const segment = \`<circle cx="60" cy="60" r="48" pathLength="100" fill="none" stroke="\${colors[i % colors.length]}" stroke-width="12" stroke-dasharray="\${share} \${100-share}" stroke-dashoffset="\${-offset}" transform="rotate(-90 60 60)"><title>\${escapeHtml(x.name)}: \${euro(x.amount)}</title></circle>\`;
          offset += share;
          return segment;
        }).join('');
        const max = Math.max(0,...top.map(x => x.amount));
        return \`<div class="card pad tr-category-card"><div class="card-title"><h2>Uscite</h2><div class="actions"><button class="small-arrow" data-cat="-1" aria-label="Mese precedente">\u2039</button><span class="category-month">\${shortMonth(key)}</span><button class="small-arrow" data-cat="1" aria-label="Mese successivo">\u203A</button></div></div>\${total > 0 ? \`<div class="breakdown"><div class="category-ring"><svg viewBox="0 0 120 120" role="img" aria-label="Uscite: \${euro(total)}"><circle cx="60" cy="60" r="48" fill="none" stroke="var(--line)" stroke-width="12"/>\${segments}</svg><div class="category-ring-label"><small>Uscite</small><strong>\${euro(total)}</strong></div></div><div class="category-legend">\${top.map((x,i) => \`<div class="bar-row"><span><i class="category-swatch" style="background:\${colors[i % colors.length]}"></i>\${escapeHtml(x.name)}</span><b>\${euro(x.amount)}</b><div class="bar"><i style="width:\${x.amount/max*100}%;background:\${colors[i % colors.length]}"></i></div></div>\`).join('')}</div></div>\` : '<div class="empty">Nessuna uscita registrata.</div>'}<div class="details-label">Gi\xE0 impegnato \xB7 \${euro(Number(data.commitmentTotal)||0)}</div>\${(Array.isArray(data.commitments)?data.commitments:[]).map(x => kv(x.name,x.amount)).join('')}</div>\`;
      }
      const extraPriority = {
        Programmato: 0,
        Anticipato: 1,
        Previsto: 2,
        Annullato: 3,
        Pagato: 4,
      };

      /** Ordine stabile delle straordinarie per stato e periodo. */
      function orderedExtras(extras) {
        return [...extras].sort(
          (a, b) =>
            (extraPriority[a.status] ?? 3) - (extraPriority[b.status] ?? 3) ||
            a.row - b.row,
        );
      }

      /** Mappa lo stato dominio in classe CSS controllata. */
      function statusClass(status) {
        return (
          {
            Programmato: "scheduled",
            Previsto: "planned",
            Anticipato: "advance",
            Annullato: "cancelled",
            Pagato: "paid",
          }[status] || "planned"
        );
      }

      /** Etichetta stato con testo escapato; non \xE8 un comando di pagamento. */
      function statusTag(status) {
        return (
          '<span class="state-tag state-' +
          statusClass(status) +
          '">' +
          escapeHtml(status) +
          "</span>"
        );
      }



      function monthlyBudgetDetails(s) {
        const items = Array.isArray(s.monthlyBudgetBreakdown) ? s.monthlyBudgetBreakdown : [];
        const line = (label,value) => \`<div class="kv"><span>\${escapeHtml(label)}</span><strong>\${exactEuro(value)}</strong></div>\`;
        return \`<details class="budget-calculation"><summary>Calcolo budget del mese</summary>
          \${line("Media stipendio",s.monthlySalary)}
          \${items.map(x=>line(x.name,-x.amount)).join("")}
          \${line("Spese non gi\xE0 coperte",-s.monthlySpent)}
          \${(s.monthlyFixedSettlements||[]).filter(r=>r.paid!==r.estimate).map(r=>\`<div class="details-label">\${escapeHtml(r.name)}: previsti \${exactEuro(r.estimate)}, pagati \${exactEuro(r.paid)}. La differenza incide sul saldo, senza un secondo addebito al budget libero.</div>\`).join("")}
          <div class="kv total"><span>Budget del mese</span><strong>\${exactEuro(s.monthlyRemaining)}</strong></div>
          \${s.monthlyAdvanceReturned ? \`<div class="details-label">Anticipo: \${exactEuro(s.monthlyAdvanceGross)} \u2212 \${exactEuro(s.monthlyAdvanceReturned)} restituiti = \${exactEuro(s.monthlyAdvances)}.<br>Spese gi\xE0 coperte: \${exactEuro(s.monthlyAdvanceCovered)}. Incluse nelle uscite, non sottratte di nuovo dal budget.</div>\` : ""}
        </details>\`;
      }

      /** Panoramica essenziale: saldo Trade Republic, impegnato, spendibile, patrimonio e flussi TR. */
      function overview(d) {
        const s = d.summary, daily = dailyBudgetRange(s);
        const recent = (d.transactions || []).slice(0, 3);
        return \`<div class="finance-open"><div class="finance-heading"><span></span><button data-view="analysis">Analisi</button></div>
        <section class="finance-hero"><h2>Budget rimanente</h2><strong class="finance-value \${amountClass(s.monthlyRemaining)}">\${state.assetsVisible ? exactEuro(s.monthlyRemaining) : "\u2022\u2022\u2022\u2022 \u20AC"}</strong><p class="muted">\${daily.days ? (state.assetsVisible ? exactEuro(daily.low) : "\u2022\u2022\u2022\u2022 \u20AC")+" al giorno" : "Mese concluso \xB7 riepilogo del budget"}</p>\${daily.days?\`<small>\${daily.days} giorni\${d.key===todayIso().slice(0,7)?", incluso oggi":" del mese selezionato"}</small>\`:""}</section>
        <section class="finance-account"><div><h2>Saldo attuale</h2><strong>\${state.assetsVisible ? exactEuro(s.budget) : "\u2022\u2022\u2022\u2022 \u20AC"}</strong></div>\${privacyButton()}<small>Saldo dell\u2019ultima sincronizzazione, distinto dal mese selezionato.</small></section>
        <div class="finance-actions"><button data-view="budget"><span aria-hidden="true">\u25F7</span>Budget</button><button data-view="extras"><span aria-hidden="true">\u22EF</span>Extra</button><button data-new-transaction="Spesa"><span aria-hidden="true">\uFF0B</span>Spesa</button></div>
        <section class="finance-recent"><div class="finance-heading"><h2>Ultimi movimenti</h2><button data-view="movements">Vedi tutti</button></div>\${recent.length ? recent.map(t => \`<button class="finance-movement" data-edit-movement="\${Number(t.row)}"><span><strong>\${escapeHtml(t.name)}</strong><small>\${escapeHtml(t.date || '')} \xB7 \${escapeHtml(t.category || t.type || '')}</small></span><b class="\${amountClass(t.amount)}">\${state.assetsVisible ? exactEuro(t.amount) : '\u2022\u2022\u2022\u2022 \u20AC'}</b></button>\`).join('') : '<p class="empty">Nessun movimento nel mese.</p>'}</section></div>\`;
      }

      /** Riga chiave/importo; la linea di confine appartiene a una sola riga. */
      function kv(label, value, extra = "") {
        return \`<div class="kv \${extra}"><span>\${escapeHtml(label)}</span><strong class="\${amountClass(value)}">\${euro(value)}</strong></div>\`;
      }

      /** Ricerca sull\u2019intero mese; render progressivo a gruppi e ripristino del cursore. */
      function renderMovements() {
        const d = state.data;
        if (!d) return;
        const q = state.search.toLocaleLowerCase("it-IT");
        const items = d.transactions.filter(
          (t) =>
            (state.type === "Tutti" || t.type === state.type) &&
            (!q ||
              (t.name + " " + t.category + " " + t.account)
                .toLocaleLowerCase("it-IT")
                .includes(q)),
        );
        const target = document.getElementById("movements");
        const focus = document.activeElement?.id === "transaction-search";
        const caret = focus ? document.activeElement.selectionStart : 0;
        target.innerHTML = \`<div class="card pad"><div class="card-title"><h2>\${d.transactions.length} movimenti nel mese</h2></div><div class="filters"><input class="search" id="transaction-search" placeholder="Cerca movimento" value="\${escapeHtml(state.search)}" aria-label="Cerca movimento"><select id="type-filter" aria-label="Tipo movimento">\${["Tutti", "Spesa", "Entrata", "Trasferimento", "Investimento", "Da verificare"].map((t) => \`<option \${state.type === t ? "selected" : ""}>\${t}</option>\`).join("")}</select></div><div class="table-scroll mobile-ledger"><table class="tabular"><thead><tr><th>Data</th><th>Movimento</th><th>Categoria</th><th>Conto</th><th>Importo</th></tr></thead><tbody>\${items
          .slice(0, state.movementLimit)
          .map(
            (t) =>
              \`<tr><td>\${t.date ? new Date(t.date + "T12:00").toLocaleDateString("it-IT", { day: "2-digit", month: "short" }) : "\u2014"}</td><td class="description"><div class="tx-description-row"><div class="tx-description-text">\${escapeHtml(t.name)}<small>\${escapeHtml(t.type)}</small></div><div class="tx-actions"><button type="button" class="ghost" data-edit-movement="\${t.row}" aria-label="Modifica movimento">Modifica</button><button type="button" class="ghost" data-delete-movement="\${t.row}" aria-label="Elimina movimento">Elimina</button></div></div></td><td data-label="Categoria">\${escapeHtml(t.category)}</td><td data-label="Conto">\${escapeHtml(t.account === "Trade Republic" ? "Conto attuale" : t.account)}</td><td class="num \${amountClass(t.amount)}">\${exactEuro(t.amount)}</td></tr>\`,
          )
          .join("")}</tbody></table><div class="movement-list">\${items
          .slice(0, state.movementLimit)
          .map(
            (t) =>
              \`<div class="movement-compact"><time>\${t.date ? new Date(t.date + "T12:00").toLocaleDateString("it-IT", { day: "2-digit", month: "short" }) : "\u2014"}</time><div class="movement-main"><strong>\${escapeHtml(t.name)}</strong><small>\${escapeHtml(t.displayCategory || t.category || t.type)} \xB7 \${escapeHtml(t.account === "Trade Republic" ? "Conto attuale" : t.account)}</small></div><b class="\${amountClass(t.amount)}">\${exactEuro(t.amount)}</b><div class="movement-tools"><button type="button" data-edit-movement="\${t.row}" aria-label="Modifica \${escapeHtml(t.name)}" title="Modifica"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><path d="m4 16 12-12 4 4-12 12-5 1zM14 6l4 4"/></svg></button><button type="button" data-delete-movement="\${t.row}" aria-label="Elimina \${escapeHtml(t.name)}" title="Elimina"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><path d="M4 7h16M10 4h4M6 7l1 13h10l1-13M10 11v5M14 11v5"/></svg></button></div></div>\`,
          )
          .join(
            "",
          )}</div>\${items.length ? "" : '<div class="empty">Nessun movimento.</div>'}\${items.length > state.movementLimit ? '<button type="button" class="ghost movement-more" data-movements-more>Mostra altri (' + (items.length - state.movementLimit) + ")</button>" : ""}</div><p class="hint">Trasferimenti interni esclusi dalle entrate e dalle uscite.</p></div>\`;
        if (focus) {
          const box = document.getElementById("transaction-search");
          box.focus();
          box.setSelectionRange(caret, caret);
        }
      }

      /** Vista dettagliata con impegni, stime, saldi, storico e grafici differiti. */
      function overviewAnalysis(d) {
        const s = d.summary;
        return \`<div class="overview-analysis-grid">
          \${planningCard(d)}
          <section class="card pad recurring-settings"><div class="card-title"><h2>Utenze e ricorrenti</h2></div>\${d.recurring
              .map((r) => {
                const a = d.averages.find((x) => x.name === r.name),
                  commitment = s.recurringCommitments.find(
                    (x) => x.name === r.name,
                  );
                const note =
                  r.name === "Benzina"
                    ? "Non impegnata"
                    : "Residuo " + exactEuro(commitment?.remaining || 0);
                return \`<div class="edit-line"><div><b>\${escapeHtml(r.name)}</b><small>\${note}\${r.estimateSource ? " \xB7 " + escapeHtml(r.estimateSource) + " \xB7 Prossimo mese " + exactEuro(r.nextEstimate) : ""}\${a?.count ? " \xB7 Media " + exactEuro(a.mean) : ""}</small></div><div class="edit-controls"><input class="edit-input" aria-label="Stima \${escapeHtml(r.name)}" type="number" min="0" max="1000" step="0.01" inputmode="decimal" value="\${r.estimate}" data-estimate="\${escapeHtml(r.name)}"><button class="save" data-save-estimate="\${escapeHtml(r.name)}">Salva</button></div></div>\`;
              })
              .join("")}</section>
        </div>\`;
      }

      /** Range giornaliero esatto, senza arrotondare prima della divisione.
       * Limite inferiore = budget mensile residuo / giorni; superiore = (media stipendio - spesi) / giorni.
       * Include oggi: l\u2019ultimo giorno il divisore \xE8 1, mai zero. Il mese \xE8 quello attuale a Roma.
       */
      function dailyBudgetRange(summary, day = todayIso()) {
        const selected=String(state.year)+'-'+String(state.month).padStart(2,'0');
        const count=new Date(Date.UTC(state.year,state.month,0)).getUTCDate();
        const days=selected<day.slice(0,7)?0:selected>day.slice(0,7)?count:Math.max(1,count-Number(day.slice(-2))+1);
        return {days,low:days?summary.monthlyRemaining/days:0,high:days?(summary.monthlySalary-summary.monthlySpent)/days:0};
      }

      /** Storico dettagliato in fondo a Budget, dopo grafici e impostazioni. */
      function billsHistory(d) {
        return \`<section class="card pad budget-history"><details data-budget-panel="budgetHistoryOpen" \${state.budgetHistoryOpen ? "open" : ""}><summary>Storico pagamenti \xB7 \${d.history.length}</summary><div class="budget-detail-content"><div class="card-title"><button class="save" data-new-recurring="1">Vai a Piani</button></div>\${d.history.length ? '<div class="table-scroll"><table class="tabular"><thead><tr><th>Data</th><th>Voce</th><th>Pagato</th><th>Mesi</th><th>Nota</th></tr></thead><tbody>' + d.history.map((h) => "<tr><td>" + escapeHtml(h.date) + "</td><td>" + escapeHtml(h.name) + "</td><td>" + exactEuro(h.paid) + "</td><td>" + h.months + "</td><td>" + escapeHtml(String(h.note||"").replace(/ ?\\[Categoria manuale\\]/g,"")) + "</td></tr>").join("") + "</tbody></table></div>" : '<p class="empty">Nessun pagamento.</p>'}</div></details></section>\`;
      }

      /** Carte straordinarie: stato, Segna pagato, Modifica e Annulla/Elimina. */
      function extrasView(d) {
        const cycles = new Map();
        for (const a of d.extraPlan?.allocations || [])
          if (a.month === d.key || !cycles.has(a.extraordinary_source_row))
            cycles.set(a.extraordinary_source_row, a);
        const sorted = orderedExtras(
          d.extras.map((e) => ({
            ...e,
            status: cycles.get(e.row)?.status || e.status,
          })),
        );
        return (
          '<div class="extra-grid">' +
          (d.extraPlan?.budgetPolicies || []).filter(p=>p.treatment==="recovery").map(p=>\`<article class="extra-card"><div class="extra-card-head"><h3>\${escapeHtml(p.description)}</h3><strong>\${exactEuro(JSON.parse(p.recovery_json).reduce((n,q)=>n+q.amount_cents,0)/100)}</strong></div><p class="hint">Recupero dai risparmi \xB7 nessuna nuova uscita</p><div class="extra-metadata"><span>\${JSON.parse(p.recovery_json).map(q=>\`\${shortMonth(q.month)}: \${exactEuro(q.amount_cents/100)}\`).join(" \xB7 ")}</span></div><button class="ghost" data-edit-movement="\${p.movement_source_row}">Modifica recupero</button></article>\`).join("") +
          sorted
            .map((e) => {
              const c = cycles.get(e.row),
                total = c ? c.total_cents / 100 : e.total;
              const links = (d.extraPlan?.links || []).filter(
                  (l) => l.cycle_id === c?.cycle_id,
                ),
                canDelete = e.status === "Annullato" && !links.length;
              const settlement=(d.extraPlan?.settlements||[]).find(s=>s.cycle_id===c?.cycle_id), paidCents=links.reduce((n,l)=>n+l.attributed_cents,0)+Math.max(0,(settlement?.actual_cents||0)-(settlement?.planned_cents||0));
              return (
                '<article class="extra-card"><div class="extra-card-head"><h3>' +
                escapeHtml(e.name) +
                "</h3><strong>" +
                exactEuro(total) +
                '</strong></div><div class="extra-metadata"><span>' +
                shortMonth(c?.start_month || e.start) +
                " - " +
                shortMonth(c?.end_month || e.end) +
                (e.repeat === "Annuale" ? " \xB7 Annuale" : "") +
                "</span><span>" +
                escapeHtml(e.account==="Trade Republic"?"Conto attuale":e.account) +
                '</span></div>' + (links.length?\`<p class="hint extra-info">Previsto \${exactEuro(total)} \xB7 Pagato \${exactEuro(paidCents/100)}. Differenze sui risparmi.</p>\`:"") + '<div class="extra-card-controls">' +
                (c?.kind === "budget_advance"
                  ? statusTag(e.status)
                  : '<div class="extra-state-row">' +
                    statusTag(e.status) +
                    (!c || ["Pagato", "Annullato"].includes(e.status)
                      ? ""
                      : '<button type="button" class="extra-pay-action" data-extra-mark-paid="' +
                        c.cycle_id +
                        '" aria-label="Segna ' +
                        escapeHtml(e.name) +
                        ' come pagato">Segna pagato<span aria-hidden="true"> \u2192</span></button>') +
                    "</div>") +
                (c && !["Pagato","Annullato"].includes(e.status) ? \`<button class="ghost" data-extra-link="\${e.row}">Collega movimento</button>\` : "") +
                '<button class="ghost" data-extra-edit="' +
                e.row +
                '">Modifica</button><button class="ghost" data-extra-cancel="' +
                (c?.cycle_id || "") +
                '" data-delete="' +
                canDelete +
                '" ' +
                (!c ? "disabled" : "") +
                ">" +
                (canDelete ? "Elimina" : "Annulla") +
                "</button></div></article>"
              );
            })
            .join("") +
          "</div>"
        );
      }

      /** Apre il foglio finanza; la gestione focus \xE8 centralizzata. */
      function financeRequestId(){return Array.from(crypto.getRandomValues(new Uint32Array(4)),x=>x.toString(16).padStart(8,"0")).join("-");}
      function modal(title, fields, kind) {
        const box = document.getElementById("dialog");
        box.innerHTML =
          '<div class="modal" role="dialog" aria-modal="true" aria-label="' +
          escapeHtml(title) +
          '"><div class="modal-top"><h2>' +
          title +
          '</h2><button class="ghost" data-close="1" aria-label="Chiudi">\xD7</button></div><form id="entry-form" data-kind="' +
          kind +
          '"><div class="form-grid">' +
          fields + \`<input type="hidden" name="requestId" value="\${financeRequestId()}">\` +
          '</div><p id="finance-form-error" class="os-form-error hidden" role="alert"></p><div class="form-actions"><button type="button" class="ghost" data-close="1">Annulla</button><button type="submit" class="save">Salva</button></div></form></div>';
        box.classList.remove("hidden");
        // iOS zooms and shifts a bottom sheet when an input is focused while opening.
        if (
          !window.matchMedia ||
          !window.matchMedia("(pointer:coarse)").matches
        )
          box.querySelector('input[name="amount"]')?.focus();
      }

      /** Genera un input del form con escaping dei valori. */
      function field(title, name, type, value = "", extra = "", cls = "") {
        const mandatory = !["note", "paidDate"].includes(name);
        return (
          '<label class="' +
          cls +
          '">' +
          title +
          (mandatory ? " *" : "") +
          '<input name="' +
          name +
          '" type="' +
          type +
          '" value="' +
          escapeHtml(value) +
          '" ' +
          extra +
          (mandatory ? " required" : "") +
          "></label>"
        );
      }

      /** Genera una select del form preservando la scelta corrente. */
      function select(title, name, values, value) {
        if (name === "category")return "<label>"+title+' *<select name="category" required>'+categoryOptionsHtml(values,value)+"</select></label>";
        return (
          "<label>" +
          title +
          ' *<select name="' +
          name +
          '" required>' +
          values
            .map(
              (x) =>
                "<option " +
                (x === value ? "selected" : "") +
                ">" +
                escapeHtml(x) +
                "</option>",
            )
            .join("") +
          "</select></label>"
        );
      }

      function isUtilityCategory(category) {
        return ["Utenze","Elettricit\xE0","Gas","Acqua"].includes(category);
      }
      function utilityFields(category="") {
        return \`<label class="full \${category==="Utenze"?"":"hidden"}" id="utility-fields">Tipo utenza *<select name="utilityKind" \${category==="Utenze"?"required":"disabled"}><option value="">Scegli</option>\${["Elettricit\xE0","Gas","Acqua"].map(x=>\`<option>\${x}</option>\`).join("")}</select></label>\`;
      }
      function syncUtilityFields() {
        const f=document.getElementById("entry-form"),box=document.getElementById("utility-fields");if(!f||!box)return;
        const active=f.elements.type.value==="Spesa"&&f.elements.category.value==="Utenze";
        box.classList.toggle("hidden",!active);f.elements.utilityKind.disabled=!active;f.elements.utilityKind.required=active;
      }
      function movementPolicyMetadata(r) {
        const fields={months:r.competence_months||1,budgetTreatment:r.budgetTreatment||"auto",recoveryMonths:r.recoveryMonths||"",recoveryAmount:r.recoveryAmount||""};
        return Object.entries(fields).map(([name,value])=>\`<input type="hidden" name="\${name}" value="\${escapeHtml(String(value))}">\`).join("");
      }

      /** Data civile usata dai form, nel fuso Europe/Rome. */
      function todayIso() {
        return new Date().toLocaleDateString("sv-SE", {
          timeZone: "Europe/Rome",
        });
      }

      /** Form spesa/entrata/trasferimento; il trasferimento crea due righe coerenti. */
      async function openTransaction(type = "Spesa") {
        if (!financialCategoryOptions().length) {
          try {
            const categories = await workerRequest(
              "getFinanceCategoryOptions",
              [],
            );
            if (state.data) state.data.categoryOptions = categories;
            if (life.finance) life.finance.categoryOptions = categories;
          } catch (err) {
            osError(err);
            return;
          }
        }
        const category = financialCategoryOptions(type);
        const chosen = todayIso();
        modal(
          "Nuovo movimento",
          select(
            "Tipo",
            "type",
            ["Spesa", "Entrata", "Rimborso", "Trasferimento"],
            type,
          ) +
            field(
              "Importo \u20AC",
              "amount",
              "number",
              "",
              'min="0.01" max="1000000" step="0.01" inputmode="decimal"',
            ) +
            field(
              "Descrizione",
              "name",
              "text",
              "",
              'maxlength="120" autocomplete="off"',
              "full",
            ) +
            '<input type="hidden" name="account" value="Trade Republic">'  +
            select(
              "Categoria",
              "category",
              category,
              "Altro",
            ) +
            field("Data effettiva", "date", "date", chosen, 'max="'+todayIso()+'"') +
            field("Note", "note", "text", "", 'maxlength="1000"', "full") +

            '<label id="counterpart-box" class="' +
            (type === "Trasferimento" ? "" : "hidden") +
            '">Trasferimento finale da Revolut a<select name="counterpart"><option>Trade Republic</option></select></label>' +
            '<label class="full hidden" id="already-snapshot-box"><input type="checkbox" name="includedInSnapshot" value="yes" style="display:inline-block;width:auto;margin-right:7px">Gi\xE0 inclusa nel saldo bancario rilevato</label>' +
            '<p class="hint full">Restituzione di un prestito: Rimborso. Rimborso esterno che vuoi conteggiare come entrata: Entrata \u2192 Rimborsi.</p>',
          "transaction",
        );
        updateTransactionAccount();
        updateSnapshotChoice();
      }

      /** Mostra l\u2019opzione gi\xE0 incluso nel saldo soltanto per date e conti compatibili. */
      function updateTransactionAccount() {
        const form = document.getElementById("entry-form");
        if (form?.dataset.kind !== "transaction") return;
        form.elements.account.value = form.elements.type.value === "Trasferimento" ? "Revolut" : "Trade Republic";
      }
      function updateSnapshotChoice() {
        const form = document.getElementById("entry-form"),
          box = document.getElementById("already-snapshot-box");
        if (!form || !box) return;
        const summary = state.data?.summary || life.finance?.summary;
        const day = form.elements.date?.value,
          account = form.elements.account?.value,
          type = form.elements.type?.value;
        const anchor =
          account === "Revolut" ? summary?.balanceDate : summary?.assetDate;
        const visible =
          type !== "Trasferimento" && Boolean(day && anchor && day <= anchor);
        box.classList.toggle("hidden", !visible);
        if (!visible) box.querySelector("input").checked = false;
      }

      /** Recupera il movimento completo prima di consentirne la modifica. */
      function openMovementEdit(row) {
        if (state.busy) return;
        google.script.run
          .withSuccessHandler((r) => {
            if(r.financePlanPaymentId){globalThis.openPlanPayment(r.financePlanId,r.financePlanPaymentId);return;}
            const categories = financialCategoryOptions(r.movement_type);
            if (r.category && !categories.includes(financeCategoryLabel(r.category)))
              categories.push(r.category);
            const type =
              r.movement_type === "Spesa" &&
              String(r.notes || "").startsWith("Rimborso / restituzione:")
                ? "Rimborso"
                : r.movement_type;
            const allowed = [
              "Spesa",
              "Entrata",
              "Rimborso",
              "Trasferimento",
              "Investimento",
              "Da verificare",
            ];
            if (!allowed.includes(type)) {
              alert("Questa tipologia storica non \xE8 ancora modificabile.");
              return;
            }
            const accounts = ["Trade Republic", "Revolut", "IsyBank"];
            modal(
              "Modifica movimento",
              '<input type="hidden" name="row" value="' +
                r.source_row +
                '">' +
                select("Tipo", "type", allowed, type) +
                field(
                  "Importo \u20AC",
                  "amount",
                  "number",
                  Math.abs(r.amount),
                  'min="0.01" max="1000000" step="0.01" inputmode="decimal"',
                ) +
                field(
                  "Descrizione",
                  "name",
                  "text",
                  r.description || "",
                  'maxlength="120"',
                  "full",
                ) +
                select("Conto", "account", accounts, r.account) +
                select("Categoria", "category", categories, r.category) +
                movementPolicyMetadata(r) +
                field(
                  "Data effettiva",
                  "date",
                  "date",
                  String(r.actual_date || r.budget_date || todayIso()).slice(
                    0,
                    10,
                  ),
                ) +
                '<label id="counterpart-box" class="' +
                (type === "Trasferimento" ? "" : "hidden") +
                '">Altro conto *<select name="counterpart">' +
                accounts
                  .map(
                    (a) =>
                      "<option " +
                      (r.counterparty_account === a ? "selected" : "") +
                      ">" +
                      a +
                      "</option>",
                  )
                  .join("") +
                "</select></label>" +
                '<p class="hint full">Dopo una correzione, verifica i saldi nel Budget.</p>',
              "movement-edit",
            );
            syncUtilityFields();
          })
          .withFailureHandler((err) => {
            const box = document.getElementById("error");
            box.textContent = "Lettura non riuscita: " + (err.message || err);
            box.classList.remove("hidden");
          })
          .getMovement(row);
      }

      function openRecurring() { setView("extras"); }

      /** Crea una pianificazione straordinaria; non implica pagamento. */
      function openExtra(c) {
        const date = c?.date || todayIso();
        modal(
          "Nuova straordinaria",
          field(
            "Voce",
            "name",
            "text",
            c?.name || "",
            'maxlength="100"',
            "full",
          ) +
            field(
              "Totale \u20AC",
              "amount",
              "number",
              c?.amount || "",
              'min="0.01" max="1000000" step="0.01" inputmode="decimal"',
            ) +
            field("Dal mese", "month", "month", date.slice(0, 7)) +
            field("Al mese", "endMonth", "month", date.slice(0, 7)) +
            select("Ripeti", "repeat", ["No", "Annuale"], "No") +
            select(
              "Stato",
              "status",
              ["Previsto", "Programmato"],
              "Programmato",
            ) +
            '<input type="hidden" name="account" value="Trade Republic">' +
            field(
              "Nota",
              "note",
              "text",
              c
                ? "Da verificare: movimento gi\xE0 registrato, nessuna nuova uscita"
                : "",
              'maxlength="200"',
              "full",
            ) +
            '<p class="hint full" id="extra-allocation-preview"></p>',
          "extra",
        );
        updateExtraPreview();
      }

      /** Anteprima quote, durata e totale prima di salvare il piano. */
      function updateExtraPreview() {
        const form = document.getElementById("entry-form"),
          out = document.getElementById("extra-allocation-preview");
        if (!form || !out) return;
        const from = form.elements.month?.value,
          to = form.elements.endMonth?.value,
          amount = Number(form.elements.amount?.value);
        const months =
          from && to
            ? (Number(to.slice(0, 4)) - Number(from.slice(0, 4))) * 12 +
              Number(to.slice(5)) -
              Number(from.slice(5)) +
              1
            : 0;
        if (
          !Number.isFinite(amount) ||
          amount <= 0 ||
          months < 1 ||
          months > 60
        ) {
          out.textContent = "";
          return;
        }
        const cents = Math.round(amount * 100),
          base = Math.floor(cents / months),
          remainder = cents % months;
        out.textContent =
          months +
          " " +
          (months === 1 ? "mese" : "mesi") +
          " \xB7 " +
          exactEuro(base / 100) +
          " al mese" +
          (remainder
            ? " \xB7 " +
              remainder +
              " " +
              (remainder === 1 ? "mese riceve" : "mesi ricevono") +
              " un centesimo in pi\xF9"
            : "");
      }

      /** Trova il ciclo della straordinaria dal piano caricato. */
      function extraCycle(row) {
        const month =
          String(state.year) + "-" + String(state.month).padStart(2, "0");
        const options = (state.data?.extraPlan?.allocations || []).filter(
          (a) => a.extraordinary_source_row === row,
        );
        return options.find((a) => a.month === month) || options[0];
      }

      /** Carica il dettaglio del ciclo prima di modificarne totale e periodo. */
      function openExtraEdit(row) {
        const c = extraCycle(row);
        if (!c) {
          const box = document.getElementById("error");
          box.textContent =
            "Seleziona un anno che contiene una quota di questa straordinaria.";
          box.classList.remove("hidden");
          return;
        }
        google.script.run
          .withSuccessHandler((r) => {
            const annual = r.repeat === "Annuale";
            modal(
              "Modifica pianificazione",
              '<input type="hidden" name="cycleId" value="' +
                r.id +
                '">' +
                field(
                  "Voce",
                  "name",
                  "text",
                  r.name,
                  'maxlength="100"',
                  "full",
                ) +
                field(
                  "Totale \u20AC",
                  "amount",
                  "number",
                  (r.total_cents / 100).toFixed(2),
                  'min="0.01" max="1000000" step="0.01" inputmode="decimal"',
                ) +
                field(
                  "Dal mese",
                  "month",
                  "month",
                  r.start_month,
                  annual ? "readonly" : "",
                ) +
                field(
                  "Al mese",
                  "endMonth",
                  "month",
                  r.end_month,
                  annual ? "readonly" : "",
                ) +
                (r.kind === "budget_advance"
                  ? '<input type="hidden" name="account" value="' +
                    escapeHtml(r.account) +
                    '">'
                  : '<input type="hidden" name="account" value="Trade Republic">') +
                field(
                  "Nota",
                  "note",
                  "text",
                  r.notes || "",
                  'maxlength="200"',
                  "full",
                ) +
                '<p class="hint full">' +
                (annual ? "Solo questo ciclo annuale. " : "") +
                "I pagamenti registrati restano invariati." +
                (r.linked_cents
                  ? " Gi\xE0 collegato: " + exactEuro(r.linked_cents / 100) + "."
                  : "") +
                "</p>" +
                '<p class="hint full" id="extra-allocation-preview"></p>',
              "extra-edit",
            );
            updateExtraPreview();
          })
          .withFailureHandler((err) => {
            const box = document.getElementById("error");
            box.textContent = "Lettura non riuscita: " + (err.message || err);
            box.classList.remove("hidden");
          })
          .getExtraCycleDetail(c.cycle_id);
      }

      /** Editor compatibilit\xE0 per il pagamento; il server impedisce doppi addebiti. */
      function openExtraPayment(row) {
        const e = state.data.extras.find((x) => x.row === row),
          cycle = extraCycle(row);
        if (!e || !cycle) return;
        modal(
          "Registra pagamento",
          '<input type="hidden" name="cycleId" value="' +
            cycle.cycle_id +
            '">' +
            field(
              "Importo \u20AC",
              "amount",
              "number",
              ((cycle.total_cents-(state.data.extraPlan.links||[]).filter(l=>l.cycle_id===cycle.cycle_id).reduce((n,l)=>n+l.attributed_cents,0))/100).toFixed(2),
              'min="0.01" step="0.01" inputmode="decimal"',
            ) +
            field("Descrizione", "name", "text", e.name, 'maxlength="120"') +
            '<input type="hidden" name="account" value="Trade Republic">' +
            field("Data pagamento", "date", "date", todayIso()) +
            '<p class="hint full">La quota mensile resta nel piano; l\u2019importo effettivo incide sul saldo. Le differenze sono assorbite dai risparmi. Il pagamento chiude questo ciclo; i rinnovi annuali continuano.</p>',
          "extra-payment",
        );
      }

      /** Collega un movimento esistente senza crearne un altro; flusso storico compatibile. */
      function openExtraLink(row) {
        const e = state.data.extras.find((x) => x.row === row),
          cycle = extraCycle(row);
        if (!e || !cycle) return;
        const type =
          cycle.kind === "budget_advance" ? "Trasferimento" : "Spesa";
        const choices = (state.data.transactions || []).filter(
          (t) => t.status === "Eseguito" && t.type === type && t.amount < 0,
        );
        if (!choices.length) {
          const box = document.getElementById("error");
          box.textContent =
            "Seleziona il mese del movimento nella barra superiore e riprova.";
          box.classList.remove("hidden");
          return;
        }
        const options = choices
          .map(
            (t) =>
              '<option value="' +
              t.row +
              '">' +
              escapeHtml(t.date + " \xB7 " + t.name + " \xB7 " + euro(-t.amount)) +
              "</option>",
          )
          .join("");
        modal(
          "Collega movimento esistente",
          '<input type="hidden" name="cycleId" value="' +
            cycle.cycle_id +
            '">' +
            '<label>Movimento *<select name="movementId" required>' +
            options +
            "</select></label>" +
            field(
              "Importo attribuito \u20AC",
              "amount",
              "number",
              e.total,
              'min="0.01" step="0.01" inputmode="decimal"',
            ) +
            '<p class="hint full">Nessun nuovo addebito.</p>',
          "extra-link",
        );
      }

      /** Chiude il foglio finanziario; l\u2019observer restituisce il focus al controllo iniziale. */
      function closeDialog() {
        document.getElementById("dialog").classList.add("hidden");
      }

      /** Cambia mese finanziario entro l\u2019intervallo supportato e ricarica i dati. */
      function moveMonth(delta) {
        const date = new Date(state.year, state.month - 1 + delta, 1);
        if (date.getFullYear() < 2024 || date.getFullYear() > 2035) return;
        state.year = date.getFullYear();
        state.month = date.getMonth() + 1;
        state.categoryMonth = state.month;
        load();
      }

      /** Cambia il mese del grafico categorie; attraversando l\u2019anno ricarica i dati. */
      function moveCategory(delta) {
        const date = new Date(state.year, state.categoryMonth - 1 + delta, 1);
        if (date.getFullYear() !== state.year) {
          state.year = date.getFullYear();
          state.month = date.getMonth() + 1;
          state.categoryMonth = state.month;
          load();
          return;
        }
        state.categoryMonth = date.getMonth() + 1;
        render();
      }

      /** Invia la stima della voce selezionata; il server valida nome e intervallo. */
      function saveEstimate(name) {
        const input = [...document.querySelectorAll("[data-estimate]")].find(
          (e) => e.dataset.estimate === name,
        );
        if (input) submit("saveEstimate", [name, input.value]);
      }

      /** Mutex finanziario; invalida dati vecchi e ripristina i pulsanti anche dopo errore. */
      async function submit(method, args) {
        if (state.busy) return false;
        state.busy = true;
        document.getElementById("error").classList.add("hidden");
        document.getElementById("finance-form-error")?.classList.add("hidden");
        const controls = [
          ...document.querySelectorAll(
            "#dialog [type=submit],[data-extra-mark-paid],#save-plan,#goal-input,#saving-input",
          ),
        ];
        const formButton = document.querySelector("#dialog [type=submit]"), formButtonLabel = formButton?.textContent;
        if(formButton) {formButton.textContent="Salvataggio\u2026";formButton.setAttribute("aria-busy","true");}
        const disabled = controls.map((b) => b.disabled);
        controls.forEach((b) => (b.disabled = true));
        try {
          await workerRequest(method, args);
          if (method === "savePlanningSettings") {
            state.planningDraft = null;
            if (state.data?.planning) {
              state.data.planning = projectPlanning(
                state.data.planning,
                args[0] === "" ? null : Number(args[0]),
                Number(args[1]),
              );
              if (args.length > 2) state.data.planning.savingsTarget = Number(args[2]);
              updateProjection();
              const status = document.getElementById("planning-status");
              if (status) status.textContent = "Salvato";
            }
            return true;
          }
          closeDialog();
          state.loadedDetail = false;
          state.data = null;
          life.finance = null;
          if (
            ["overview", "budget", "movements", "extras"].includes(state.view)
          )
            load();
          if (state.view === "today") osLoadHomeFinance();
          return true;
        } catch (error) {
          const box = document.getElementById("error");
          const planStatus =
            method === "savePlanningSettings" &&
            document.getElementById("planning-status");
          if (planStatus)
            planStatus.textContent =
              "Salvataggio non riuscito: " + error.message;
          box.textContent = "Salvataggio non riuscito: " + error.message;
          box.classList.remove("hidden");
          const formError=document.getElementById("finance-form-error");if(formError && !document.getElementById("dialog").classList.contains("hidden")){formError.textContent=box.textContent;formError.classList.remove("hidden");formError.scrollIntoView({block:"nearest"});}
          return false;
        } finally {
          state.busy = false;
          controls.forEach((b, i) => (b.disabled = disabled[i]));
          if(formButton) {formButton.textContent=formButtonLabel;formButton.removeAttribute("aria-busy");}
        }
      }
      document.addEventListener("click", (e) => {
        if (e.target.closest("[data-toggle-assets]")) {
          const goal = document.getElementById("goal-input")?.value,
            saving = document.getElementById("saving-input")?.value;
          state.assetsVisible = !state.assetsVisible;
          render();
          if (life.data) document.getElementById("today").innerHTML = osToday();
          if (goal !== undefined && document.getElementById("goal-input"))
            document.getElementById("goal-input").value = goal;
          if (saving !== undefined && document.getElementById("saving-input"))
            document.getElementById("saving-input").value = saving;
          updateProjection();
          return;
        }
        if (e.target.closest("[data-movements-more]")) {
          state.movementLimit += 100;
          renderMovements();
          return;
        }
        const classify = e.target.closest("[data-apply-category]");
        if (classify) {
          const choice = classify
            .closest(".quick-classify")
            .querySelector("select").value;
          submit("classifyMovement", [
            Number(classify.dataset.applyCategory),
            choice,
          ]);
          return;
        }
        // body[data-view] is layout state, NOT a navigation control. Matching it
        // rebuilt the current screen after every click and destroyed open menus.
        const nav = e.target.closest("button[data-view]");
        if (nav) {
          setView(nav.dataset.view);
          return;
        }
        if (e.target.closest("#prev-month")) moveMonth(-1);
        if (e.target.closest("#next-month")) moveMonth(1);
        const cat = e.target.closest("[data-cat]");
        if (cat) moveCategory(Number(cat.dataset.cat));
        const row = e.target.closest(".annual-row[data-month]");
        if (row) {
          const [year, month] = row.dataset.month.split("-").map(Number);
          state.year = year;
          state.month = month;
          state.categoryMonth = month;
          load();
        }
        const save = e.target.closest("[data-save-estimate]");
        if (save) saveEstimate(save.dataset.saveEstimate);
        const tx = e.target.closest("[data-new-transaction]");
        if (tx) openTransaction(tx.dataset.newTransaction);
        const edit = e.target.closest("[data-edit-movement]");
        if (edit) openMovementEdit(Number(edit.dataset.editMovement));
        const del = e.target.closest("[data-delete-movement]");
        if (del) {
          const id = Number(del.dataset.deleteMovement),
            item = state.data?.transactions.find((t) => t.row === id);
          if (
            item &&
            confirm(
              "Eliminare definitivamente \xAB" +
                item.name +
                "\xBB (" +
                exactEuro(item.amount) +
                ")? Se \xE8 un trasferimento creato nell\u2019app, verr\xE0 eliminata anche la riga speculare.",
            )
          )
            submit("deleteMovement", [id]);
        }
        if (e.target.closest("[data-new-extra]")) openExtra();
        const paid = e.target.closest("[data-extra-mark-paid]");
        if (paid) {
          const cycle=(state.data?.extraPlan?.allocations || []).find(c=>c.cycle_id===Number(paid.dataset.extraMarkPaid));
          if(cycle)openExtraPayment(cycle.extraordinary_source_row);
          return;
        }
        const extraEdit = e.target.closest("[data-extra-edit]");
        if (extraEdit) openExtraEdit(Number(extraEdit.dataset.extraEdit));
        const cancel = e.target.closest("[data-extra-cancel]");
        if (cancel) {
          const cycleId = Number(cancel.dataset.extraCancel),
            remove = cancel.dataset.delete === "true";
          if (
            confirm(
              remove
                ? "Eliminare definitivamente la voce?"
                : "Annullare questa pianificazione? Eventuali pagamenti restano nei Movimenti.",
            )
          )
            submit(remove ? "deleteExtraPlan" : "cancelExtraCycle", [
              { cycleId },
            ]);
          return;
        }
        const extraPay = e.target.closest("[data-extra-pay]");
        if (extraPay) openExtraPayment(Number(extraPay.dataset.extraPay));
        const extraLink = e.target.closest("[data-extra-link]");
        if (extraLink) openExtraLink(Number(extraLink.dataset.extraLink));
        const candidate = e.target.closest("[data-candidate]");
        if (candidate)
          openExtra({
            name: candidate.dataset.candidate,
            amount: candidate.dataset.amount,
            date: candidate.dataset.date,
            account: candidate.dataset.account,
          });
        if (e.target.closest("[data-new-recurring]")) openRecurring();
        if (e.target.closest("[data-close]")) closeDialog();


        if (e.target.closest("#save-plan")) {
          const inputs = [
            document.getElementById("goal-input"),
            document.getElementById("saving-input"),
            document.getElementById("target-input"),
          ];
          if (!inputs.every((input) => input.reportValidity())) return;
          submit("savePlanningSettings", [
            document.getElementById("goal-input").value,
            document.getElementById("saving-input").value,
            ...(document.getElementById("target-input").value ? [document.getElementById("target-input").value] : []),
          ]);
        }
      });
      document.addEventListener("click", (e) => {
        if (e.target.closest("[data-open-analysis]")) {
          state.overviewAnalysisOpen = true;
          document.querySelector("[data-overview-panel=analysis]").open = true;
          document
            .querySelector("[data-overview-panel=analysis]")
            .scrollIntoView({ behavior: "smooth", block: "start" });
        }
      });
      window
        .matchMedia?.("(max-width:760px)")
        .addEventListener?.("change", () => {
          if (!state.data) return;
          const sankey = document.querySelector("#overview .sankey-card"),
            trend = document.querySelector("#analysis .integrated-chart");
          if (sankey) sankey.outerHTML = sankeyCard(state.data);
          if (trend) trend.outerHTML = cashFlowChart(state.data);
        });
      document.addEventListener(
        "toggle",
        (e) => {
          if (e.target?.hasAttribute?.("data-home-times"))
            life.timesOpen = e.target.open;
          const budgetPanel = e.target?.dataset?.budgetPanel;
          if (
            [
              "budgetSettingsOpen",
              "budgetAnnualOpen",
              "budgetHistoryOpen",
            ].includes(budgetPanel)
          )
            state[budgetPanel] = e.target.open;
          const name = e.target?.dataset?.overviewPanel;
          if (name === "cards") state.overviewCardsOpen = e.target.open;
          if (name === "analysis") state.overviewAnalysisOpen = e.target.open;
          if (name === "plan") state.overviewPlanOpen = e.target.open;
        },
        true,
      );
      document.addEventListener("input", (e) => {
        if (e.target.id === "transaction-search") {
          state.search = e.target.value;
          state.movementLimit = 100;
          renderMovements();
        }
        if (
          e.target.closest("#entry-form") &&
          ["amount", "month", "endMonth"].includes(e.target.name)
        )
          updateExtraPreview();
        if (e.target.id === "goal-input" || e.target.id === "saving-input" || e.target.id === "target-input")
          updateProjection();
      });
      document.addEventListener("change", (e) => {
        if (
          e.target.closest("#entry-form") &&
          ["date", "account", "type"].includes(e.target.name)
        )
          updateSnapshotChoice();
        if (e.target.id === "type-filter") {
          state.type = e.target.value;
          state.movementLimit = 100;
          renderMovements();
        }
        if (e.target.matches("[data-extra-status]")) {
          e.target.className =
            "status-select state-tag state-" + statusClass(e.target.value);
          const row = Number(e.target.dataset.extraStatus),
            previous = e.target.dataset.previous,
            next = e.target.value;
          if (next === "Anticipato" || next === "Pagato") {
            e.target.value = previous;
            e.target.className =
              "status-select state-tag state-" + statusClass(previous);
            if (next === "Pagato") openExtraPayment(row);
            else openExtraLink(row);
          } else if (next !== previous)
            submit("setExtraStatus", [row, previous, next]);
        }
        if (e.target.closest("#entry-form") && e.target.name === "type") {
          updateTransactionAccount();
          updateSnapshotChoice();
          document
            .getElementById("counterpart-box")
            .classList.toggle("hidden", e.target.value !== "Trasferimento");
        }
      });
      document.addEventListener("invalid", (e) => {
        if (!e.target.closest("#entry-form")) return;
        const box = document.getElementById("finance-form-error");
        if (!box) return;
        const label = e.target.closest("label")?.childNodes[0]?.textContent?.trim() || "Campo";
        box.textContent = label + ": " + e.target.validationMessage;
        box.classList.remove("hidden");
        e.target.scrollIntoView({block:"center"});
      }, true);
      document.addEventListener("submit", (e) => {
        if (e.target.id !== "entry-form") return;
        e.preventDefault();
        const f = e.target,
          d = Object.fromEntries(new FormData(f).entries()),
          kind = f.dataset.kind;
        if (
          (kind === "transaction" || kind === "movement-edit") &&
          d.type === "Trasferimento" &&
          d.account === d.counterpart
        ) {
          const box = document.getElementById("error");
          box.textContent = "Scegli un conto di destinazione diverso.";
          box.classList.remove("hidden");
          return;
        }
        if((kind==="transaction"||kind==="movement-edit") && d.type!=="Spesa"){d.budgetTreatment="auto";delete d.recoveryMonths;delete d.recoveryAmount;}

        if(kind==="transaction"){d.months=1;d.budgetTreatment=d.type==="Spesa"?"ordinary":"auto";}
        if (kind === "extra-payment") return submit("recordExtraPayment", [d]);
        if (kind === "extra-link") return submit("linkExtraMovement", [d]);
        submit(
          {
            transaction: "saveTransaction",
            "movement-edit": "editMovement",
            recurring: "saveRecurringPayment",
            extra: "saveExtra",
            "extra-edit": "updateExtraPlan",
          }[kind],
          [d],
        );
      });
      document.getElementById("period-label").textContent = titleMonth(
        state.year,
        state.month,
      );
      document.getElementById("loading").classList.add("hidden");
      window.addEventListener("lifeos-ready", () => {
        loadLifeOS(); osLoadHomeFinance(); osLoadWeather();
      }, {once:true});
    <\/script>

    <script>
      (function () {
        let previousFocus = null,
          activeSheet = null,
          lastOutsideFocus = null;
        document.addEventListener("focusin", (e) => {
          if (!e.target.closest(".modal-wrap")) lastOutsideFocus = e.target;
        });
        document.addEventListener(
          "click",
          (e) => {
            if (!activeSheet) {
              const b = e.target.closest("button");
              if (b && !b.closest(".modal-wrap")) lastOutsideFocus = b;
            }
          },
          true,
        );
        const wrappers = [
          document.getElementById("dialog"),
          document.getElementById("life-dialog"),
        ];
        const focusables = () =>
          activeSheet
            ? [
                ...activeSheet.querySelectorAll(
                  'button:not([disabled]),input:not([type=hidden]):not([disabled]),select:not([disabled]),textarea:not([disabled]),a[href],[tabindex="0"]',
                ),
              ].filter((e) => e.getClientRects().length)
            : [];
        const observer = new MutationObserver(() => {
          const next =
            wrappers.find((w) => !w.classList.contains("hidden")) || null;
          if (next === activeSheet) return;
          if (next) {
            previousFocus =
              lastOutsideFocus || document.querySelector(".nav button.active");
            activeSheet = next;
            document.querySelector(".shell").inert = true;
            const title = next.querySelector("h2");
            if (title) title.setAttribute("tabindex", "-1");
            const initial = !matchMedia("(pointer:coarse)").matches
              ? next.querySelector("input[name=amount]") || title
              : title;
            if (initial) initial.focus({ preventScroll: true });
          } else {
            activeSheet = null;
            document.querySelector(".shell").inert = false;
            if (previousFocus?.isConnected)
              previousFocus.focus({ preventScroll: true });
            previousFocus = null;
          }
        });
        wrappers.forEach((w) =>
          observer.observe(w, { attributes: true, attributeFilter: ["class"] }),
        );
        document.addEventListener("keydown", (e) => {
          if (!activeSheet) return;
          if (e.key === "Escape") {
            e.preventDefault();
            activeSheet
              .querySelector("[data-close],[data-life-close],[data-plans-close]")
              ?.click();
            return;
          }
          if (e.key !== "Tab") return;
          const list = focusables();
          if (!list.length) {
            e.preventDefault();
            return;
          }
          const at = list.indexOf(document.activeElement);
          if (e.shiftKey && at <= 0) {
            e.preventDefault();
            list.at(-1).focus();
          } else if (!e.shiftKey && (at === list.length - 1 || at === -1)) {
            e.preventDefault();
            list[0].focus();
          }
        });
        document.querySelectorAll("summary").forEach((e) => (e.tabIndex = 0));
        document.addEventListener("pointermove", (e) => {
          if (e.pointerType !== "mouse") return;
          const control = e.target.closest(".save,.os-button.primary,.sidebar");
          if (!control) return;
          const r = control.getBoundingClientRect();
          control.style.setProperty(
            "--light-x",
            Math.round(((e.clientX - r.left) / r.width) * 100) + "%",
          );
        });
      })();

      // Menus retain native summary semantics. One open menu, close outside or on Escape.
      document.addEventListener("click", (event) => {
        const menu = event.target.closest(".os-more-menu,.os-event-options");
        document
          .querySelectorAll(".os-more-menu[open],.os-event-options[open]")
          .forEach((other) => {
            if (other !== menu || event.target.closest("button"))
              other.open = false;
          });
      });
      document.addEventListener("keydown", (event) => {
        if (event.key !== "Escape" || event.defaultPrevented) return;
        const menu = document.querySelector(
          ".os-more-menu[open],.os-event-options[open]",
        );
        if (menu) {
          menu.open = false;
          menu.querySelector("summary").focus();
          event.preventDefault();
        }
      });
    <\/script>
    <script>
      (() => {
        let scheduled = false;
        const sync = () => {
          scheduled = false;
          document.querySelectorAll(".nav button[data-view]").forEach((b) => {
            if (b.classList.contains("active"))
              b.setAttribute("aria-current", "page");
            else b.removeAttribute("aria-current");
          });
          document
            .querySelectorAll(".os-category-tabs,.finance-tabs")
            .forEach((n) => {
              const b = n.querySelector("button.active");
              if (b) {
                const left = b.offsetLeft,
                  right = left + b.offsetWidth;
                if (left < n.scrollLeft) n.scrollLeft = left;
                else if (right > n.scrollLeft + n.clientWidth)
                  n.scrollLeft = right - n.clientWidth;
              }
            });
        };
        new MutationObserver(() => {
          if (!scheduled) {
            scheduled = true;
            requestAnimationFrame(sync);
          }
        }).observe(document.querySelector(".shell"), {
          subtree: true,
          childList: true,
          attributes: true,
          attributeFilter: ["class"],
        });
        sync();
      })();
    <\/script>
    <script>
      (() => {
        const b = document.querySelector(".theme-toggle");
        const draw = () => {
          const light = document.documentElement.dataset.theme === "light";
          b.textContent = light ? "\u25D0" : "\u25D1";
          b.setAttribute(
            "aria-label",
            light ? "Attiva modalit\xE0 scura" : "Attiva modalit\xE0 chiara",
          );
          document.querySelector('meta[name="theme-color"]').content = light
            ? "#f3f3f5"
            : "#0c0c0e";
        };
        b.onclick = () => {
          const theme =
            document.documentElement.dataset.theme === "light"
              ? "dark"
              : "light";
          document.documentElement.dataset.theme = theme;
          try {
            localStorage.setItem("life-theme", theme);
          } catch (e) {}
          draw();
        };
        matchMedia("(prefers-color-scheme: light)").addEventListener(
          "change",
          (e) => {
            try {
              if (localStorage.getItem("life-theme")) return;
            } catch (x) {}
            document.documentElement.dataset.theme = e.matches
              ? "light"
              : "dark";
            draw();
          },
        );
        draw();
      })();
    <\/script>
    <script>
      (() => {
        if (
          /iPad|iPhone|iPod/.test(navigator.userAgent) ||
          (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
        )
          return;
        let start = 0,
          target = null,
          pulling = false;
        const reduced = matchMedia("(prefers-reduced-motion: reduce)");
        /** Termina il rimbalzo artificiale sui dispositivi privi del comportamento iOS nativo. */
        function reset() {
          if (!target) return;
          const node = target;
          node.style.transition = reduced.matches
            ? "none"
            : "translate 280ms cubic-bezier(.2,.8,.2,1)";
          node.style.translate = "0 0";
          setTimeout(() => {
            node.style.transition = "";
            node.style.translate = "";
          }, 300);
          target = null;
          pulling = false;
        }
        document.addEventListener(
          "touchstart",
          (e) => {
            reset();
            if (
              e.touches.length !== 1 ||
              reduced.matches ||
              e.target.closest(
                "input,textarea,select,button,.os-drag-handle,.os-category-tabs,.finance-tabs,.chart-scroll,.os-routine-items,.modal-wrap",
              )
            )
              return;
            start = e.touches[0].clientY;
            target =
              e.target.closest(".view.active") ||
              document.querySelector("main");
          },
          { passive: true },
        );
        document.addEventListener(
          "touchmove",
          (e) => {
            if (!target || e.touches.length !== 1) return;
            const delta = e.touches[0].clientY - start,
              root = document.scrollingElement;
            let node = e.target;
            while (node && node !== document.body) {
              if (
                node.scrollHeight > node.clientHeight + 2 &&
                getComputedStyle(node).overflowY.match(/auto|scroll/)
              )
                return;
              node = node.parentElement;
            }
            const end = root.scrollHeight - root.clientHeight;
            if (
              (root.scrollTop <= 0 && delta > 0) ||
              (root.scrollTop >= end - 1 && delta < 0)
            ) {
              pulling = true;
              e.preventDefault();
              target.style.transition = "none";
              target.style.translate =
                "0 " +
                Math.sign(delta) *
                  Math.min(62, 62 * (1 - Math.exp(-Math.abs(delta) / 150))) +
                "px";
            } else if (pulling) reset();
          },
          { passive: false },
        );
        document.addEventListener("touchend", reset, { passive: true });
        document.addEventListener("touchcancel", reset, { passive: true });
      })();
    <\/script>
  <script>(() => {
  // backend/worker/habits.mjs
  var habitWeekdays = ["Luned\\xEC", "Marted\\xEC", "Mercoled\\xEC", "Gioved\\xEC", "Venerd\\xEC", "Sabato", "Domenica"];
  function validHabitDay(day) {
    return typeof day === "string" && /^\\d{4}-\\d{2}-\\d{2}$/.test(day) && Number.isFinite(Date.parse(day + "T12:00:00Z")) && (/* @__PURE__ */ new Date(day + "T12:00:00Z")).toISOString().slice(0, 10) === day;
  }
  function habitSchedule(value) {
    if (value === void 0) return { mode: "daily", intervalDays: 1, weekdays: [], startDate: "" };
    if (!value || typeof value !== "object" || Array.isArray(value) || !["daily", "interval", "weekdays"].includes(value.mode)) throw Error("Ripetizione non valida.");
    const { mode } = value, startDate = value.startDate ?? "", intervalDays = value.intervalDays ?? 1, days = value.weekdays ?? [];
    if (startDate !== "" && !validHabitDay(startDate) || mode !== "daily" && !validHabitDay(startDate)) throw Error("Scegli una data di inizio valida.");
    if (mode === "interval" && (!Number.isInteger(intervalDays) || intervalDays < 1 || intervalDays > 365)) throw Error("Scegli un intervallo da 1 a 365 giorni.");
    if (mode === "weekdays" && (!Array.isArray(days) || !days.length || days.some((d) => !Number.isInteger(d) || d < 1 || d > 7))) throw Error("Scegli almeno un giorno della settimana.");
    return { mode, intervalDays: mode === "interval" ? intervalDays : 1, weekdays: mode === "weekdays" ? [...new Set(days)].sort((a, b) => a - b) : [], startDate };
  }
  function habitDue(routine, day) {
    const s = habitSchedule(routine.schedule);
    if (!validHabitDay(day) || s.startDate && day < s.startDate) return false;
    if (s.mode === "daily") return true;
    if (s.mode === "weekdays") return s.weekdays.includes(((/* @__PURE__ */ new Date(day + "T12:00:00Z")).getUTCDay() + 6) % 7 + 1);
    return Math.round((Date.parse(day + "T12:00:00Z") - Date.parse(s.startDate + "T12:00:00Z")) / 864e5) % s.intervalDays === 0;
  }
  function habitSummary(routine) {
    const s = habitSchedule(routine.schedule);
    return s.mode === "daily" ? "Ogni giorno" : s.mode === "interval" ? \`Ogni \${s.intervalDays} \${s.intervalDays === 1 ? "giorno" : "giorni"}\` : s.weekdays.map((d) => habitWeekdays[d - 1]).join(", ");
  }

  // backend/worker/habits-web.js
  (() => {
    const supported = () => life.data?.routineScheduleVersion === 1 || globalThis.lifeOSLocalMode?.mode === "demo";
    function updateFields(form) {
      const mode = form.elements.mode.value;
      form.querySelector("[data-habit-interval]").hidden = mode !== "interval";
      form.querySelector("[data-habit-weekdays]").hidden = mode !== "weekdays";
      form.querySelector("[data-habit-start]").hidden = mode === "daily";
      form.elements.startDate.required = mode !== "daily";
      form.elements.startDate.disabled = mode === "daily";
      form.elements.intervalDays.required = mode === "interval";
      form.elements.intervalDays.disabled = mode !== "interval";
    }
    function edit(routine) {
      const form = document.getElementById("os-routine-form"), s = habitSchedule(routine.schedule);
      form.elements.record_id.value = routine.id;
      form.elements.title.value = routine.title;
      form.elements.mode.value = s.mode;
      form.elements.intervalDays.value = s.mode === "interval" ? s.intervalDays : 2;
      form.elements.startDate.value = s.startDate || life.data.today;
      form.querySelectorAll("[name=weekday]").forEach((el) => el.checked = s.weekdays.includes(Number(el.value)));
      form.querySelector("[type=submit]").textContent = "Salva";
      form.querySelector("[data-habit-cancel]").hidden = false;
      updateFields(form);
      form.elements.title.focus();
    }
    function open() {
      const host = document.getElementById("life-dialog"), ok = supported();
      host.innerHTML = \`<div class="modal os-dialog os-routine-dialog" role="dialog" aria-modal="true" aria-label="Abitudini"><div class="os-topline"><h2>Abitudini</h2><button data-life-close aria-label="Chiudi">\\xD7</button></div><p>La dashboard mostra le abitudini previste oggi. Ogni data ha i propri completamenti.</p>\${ok ? "" : '<p role="alert">Aggiorna il Worker collegato per programmare le abitudini.</p>'}<div class="os-routine-manager">\${(life.data.routines || []).map((h) => \`<div><span>\${osSafe(h.title)}<small style="display:block">\${osSafe(habitSummary(h))}\${h.schedule?.startDate ? " \\xB7 Dal " + osSafe(h.schedule.startDate) : ""}</small></span><button data-life-routine-edit="\${h.id}" aria-label="Modifica \${osSafe(h.title)}">Modifica</button><button data-life-routine-delete="\${h.id}" aria-label="Elimina \${osSafe(h.title)}">Elimina</button></div>\`).join("")}</div><form id="os-routine-form" class="os-form"><fieldset \${ok ? "" : "disabled"} style="border:0;padding:0;min-width:0" class="wide habit-fields"><input type="hidden" name="record_id" value=""><label>Nome<input name="title" maxlength="60" required autocomplete="off"></label><label>Ripetizione<select name="mode"><option value="daily">Ogni giorno</option><option value="interval">Ogni N giorni</option><option value="weekdays">Giorni della settimana</option></select></label><label data-habit-interval hidden>Intervallo in giorni<input name="intervalDays" type="number" min="1" max="365" step="1" value="2"></label><fieldset data-habit-weekdays hidden style="border:0;padding:0"><legend>Giorni della settimana</legend>\${habitWeekdays.map((name, i) => \`<label style="display:flex;align-items:center;min-height:44px;gap:8px"><input name="weekday" type="checkbox" value="\${i + 1}" style="width:auto">\${name}</label>\`).join("")}</fieldset><label data-habit-start hidden>Data di inizio<input name="startDate" type="date" value="\${life.data.today}"></label><p class="hint">Gli intervalli si contano dalla data di inizio, anche se salti un completamento.</p><p role="alert" data-habit-error></p><div class="os-form-actions"><button type="button" data-habit-cancel hidden>Annulla modifica</button><button type="submit">Aggiungi</button></div></fieldset></form></div>\`;
      host.classList.remove("hidden");
      const form = host.querySelector("form");
      form.elements.mode.onchange = () => updateFields(form);
      form.querySelector("[data-habit-cancel]").onclick = open;
      updateFields(form);
    }
    async function save(form) {
      if (life.busy || !supported() || !form.reportValidity()) return;
      const error = form.querySelector("[data-habit-error]");
      error.textContent = "";
      try {
        const schedule = habitSchedule({ mode: form.elements.mode.value, intervalDays: Number(form.elements.intervalDays.value), weekdays: [...form.querySelectorAll("[name=weekday]:checked")].map((el) => Number(el.value)), startDate: form.elements.mode.value === "daily" ? "" : form.elements.startDate.value });
        const payload = { id: Number(form.elements.record_id.value || 0), title: form.elements.title.value, schedule };
        form.querySelector("fieldset").disabled = true;
        form.closest(".modal").querySelector("[data-life-close]").disabled = true;
        const result = await osWrite("saveRoutine", payload);
        if (result) open();
      } catch (e) {
        error.textContent = e.message;
      } finally {
        if (form.isConnected) {
          form.querySelector("fieldset").disabled = !supported();
          form.closest(".modal").querySelector("[data-life-close]").disabled = false;
        }
      }
    }
    globalThis.lifeOSHabits = { due: habitDue, summary: habitSummary, open, edit, save };
  })();
})();
<\/script><script>/* Home follows the native order: rolling week, day summary, next time, habits. */
(() => {
  const safe=osSafe;
  const shiftNames={morning:'di mattina',afternoon:'di pomeriggio',night:'di notte',rest:'di riposo',holiday:'in ferie'};
  const labels=[['fajr','Prima dell\u2019alba'],['sunrise','Alba'],['dhuhr','Mezzogiorno'],['asr','Pomeriggio'],['maghrib','Tramonto'],['isha','Notte']];
  const addDay=(day,n)=>{const d=new Date(day+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10);};
  let agenda=[];
  function sheet(title,body){
    const host=document.getElementById('life-dialog');
    host.innerHTML=\`<div class="modal os-dialog" role="dialog" aria-modal="true" aria-label="\${safe(title)}"><div class="modal-top"><h2>\${safe(title)}</h2><button data-life-close aria-label="Chiudi">\xD7</button></div>\${body}</div>\`;
    host.classList.remove('hidden');
  }
  function nextTime(now=new Date()){
    const today=todayIso(),clock=new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Rome',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(now);
    const times=osPrayerTimes(today),found=labels.find(([key])=>times[key].label>clock);
    const day=found?today:addDay(today,1),entry=found||labels[0],schedule=found?times:osPrayerTimes(day);
    return {day,label:entry[1],time:schedule[entry[0]].label};
  }
  osToday=function(){
    const d=life.data,today=d.today,tomorrow=addDay(today,1),end=addDay(today,7),seen=new Set();
    const hour=Number(new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Rome',hour:'2-digit',hourCycle:'h23'}).format(new Date()));
    const clock=new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Rome',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(new Date());
    agenda=[...(d.upcomingEvents||[]),...(d.events||[])].filter(e=>{
      const key=\`\${e.id}:\${e.day}\`;
      if(e.day<today||e.day>=end||(e.occurrence_status||'open')!=='open'||e.day===today&&e.start_time&&e.start_time<clock||seen.has(key))return false;
      seen.add(key);return true;
    }).sort((a,b)=>\`\${a.day}|\${a.start_time||''}|\${String(a.id).padStart(10,'0')}\`.localeCompare(\`\${b.day}|\${b.start_time||''}|\${String(b.id).padStart(10,'0')}\`));
    const shifts=new Map((d.shifts||[]).map(s=>[s.day,s.kind]));
    const mark=new Set([...(d.events||[]).map(e=>e.day),...(d.tasks||[]).map(t=>t.scheduled_date)]);
    const week=Array.from({length:7},(_,i)=>addDay(today,i-3)).map(day=>{
      const date=new Date(day+'T12:00:00Z'),kind=shifts.get(day);
      return \`<div><small>\${['D','L','M','M','G','V','S'][date.getUTCDay()]}</small><button class="os-day \${day===today?'today selected':''}" data-home-day="\${day}" data-kind="\${kind||''}" aria-label="\${safe(osDate(day))}\${kind?' \xB7 '+safe(osShift[kind]):''}"><b>\${date.getUTCDate()}</b><span class="os-shift \${kind?'':'no-shift'}">\${kind?osShiftInitial[kind]:''}</span><span class="os-day-mark \${mark.has(day)?'dot':''}"></span></button></div>\`;
    }).join('');
    const parts=[];
    if(life.weather){const w=life.weather,c=w.code===0?'sereno':w.code<=3?'cielo nuvoloso':w.code<50?'nebbia':w.code<70?'pioggia':w.code<80?'neve':w.code<95?'rovesci':'temporali';parts.push(\`A Empoli, \${Math.round(w.temp)}\xB0 e \${c}.\`);}
    const shift=shifts.get(today),next=shifts.get(tomorrow);
    if(shifts.get(addDay(today,-1))==='night'&&hour<6)parts.push('Stai terminando il turno di notte.');
    const phrase=(kind,when)=>\`\${when} \${['rest','holiday'].includes(kind)?'sei':'lavori'} \${shiftNames[kind]}.\`;
    if(shift&&shift===next)parts.push(phrase(shift,'Oggi e domani'));
    else {if(shift)parts.push(phrase(shift,'Oggi'));if(next)parts.push(phrase(next,'Domani'));}
    if(!shift&&!next)parts.push('Turni non disponibili.');
    if(agenda.length){const e=agenda[0],when=e.day===today?'Oggi':e.day===tomorrow?'Domani':osDate(e.day);parts.push(\`\${when}: \${String(e.title||'Appuntamento').replace(/\\s+/g,' ').slice(0,70)}\${e.start_time?' alle '+e.start_time:''}.\`);}
    else parts.push('Nessun appuntamento nei prossimi 7 giorni.');
    const nextSolar=nextTime(),habits=(d.routines||[]).filter(h=>lifeOSHabits.due(h,today));
    return \`<div class="home-native"><section class="home-week"><div class="card-title"><span>\${safe(titleMonth(Number(today.slice(0,4)),Number(today.slice(5,7))))}</span><button data-home-day="\${today}" aria-label="Apri calendario">\u25A6</button></div><div class="home-week-grid">\${week}</div></section><section><p class="hint">\${hour<12?'Buongiorno':hour<18?'Buon pomeriggio':'Buonasera'}, Anass.</p><p class="home-summary">\${safe(parts.join(' '))}</p>\${agenda.length?\`<button data-home-agenda>\${agenda.length===1?'Dettagli appuntamento':'Tutti i '+agenda.length+' appuntamenti'}</button>\`:''}</section><button class="home-next-time" data-home-times-sheet aria-label="Prossimo orario, \${safe(nextSolar.label)}, \${safe(nextSolar.time)}"><span>\${safe(nextSolar.label)}</span><strong>\${safe(nextSolar.time)}</strong></button><section class="os-card"><div class="card-title"><h2>Abitudini</h2><button data-life-routine-manage>Gestisci</button></div>\${habits.map(h=>\`<button class="home-habit" data-life-routine="\${h.id}" aria-pressed="\${!!h.checked}"><span aria-hidden="true">\${h.checked?'\u2713':'\u25CB'}</span>\${safe(h.title)}</button>\`).join('')||(d.routines?.length?'<p class="hint">Nessuna abitudine prevista per oggi.</p>':'<button data-life-routine-manage>Aggiungi la prima abitudine</button>')}</section></div>\`;
  };
  document.addEventListener('click',async e=>{
    const b=e.target.closest('[data-home-day],[data-home-times-sheet],[data-home-agenda]');if(!b)return;
    if(b.hasAttribute('data-home-day')){
      const day=b.dataset.homeDay,month=day.slice(0,7),changed=life.month!==month;
      life.month=month;life.selected=day;setView('calendar');if(changed)await loadLifeOS();
    }
    if(b.hasAttribute('data-home-times-sheet')){const next=nextTime(),times=osPrayerTimes(next.day);sheet('Empoli \xB7 '+osDate(next.day),labels.map(([key,label])=>\`<div class="kv"><span>\${label}</span><strong>\${safe(times[key].label)}</strong></div>\`).join(''));}
    if(b.hasAttribute('data-home-agenda'))sheet('Appuntamenti',agenda.map(ev=>\`<div class="os-agenda-entry"><button class="os-agenda-row" data-life-event="\${ev.id}"><span>\${safe(ev.title)}<small>\${safe(osDate(ev.day))} \xB7 \${safe(ev.start_time||'Tutto il giorno')}</small></span></button><button data-life-occurrence="\${ev.id}:\${ev.day}:done" aria-label="Segna fatto \${safe(ev.title)}">Fatto</button></div>\`).join(''));
  });
})();
<\/script><script>(() => {
  const safe=escapeHtml;
  function progress(goal=state.data?.planning?.goal,target=state.data?.planning?.savingsTarget){
    const assets=Number(state.data?.summary?.budget)||0,emergency=Math.max(0,Number(goal)||0);
    target=Number(target)>0?Number(target):Math.max(5000,(Math.floor(Math.max(assets,emergency)/5000)+1)*5000);
    const months=Math.max(1,13-Number(todayIso().slice(5,7))),reserved=Math.min(Math.max(0,assets),emergency),missing=Math.max(0,target-assets);
    return {assets,emergency,target,months,reserved,other:Math.max(0,assets-reserved),missing,monthly:missing/months};
  }
  const line=(label,n)=>\`<div class="kv"><span>\${label}</span><strong>\${state.assetsVisible?exactEuro(n):'\u2022\u2022\u2022\u2022'}</strong></div>\`;
  planningCard=function(){
    const p=progress();
    return \`<section class="card pad planning-card"><h2>Obiettivo di risparmio</h2>\${line('Patrimonio totale',p.assets)}\${line('Fondo emergenza',p.emergency)}\${line('Fondo emergenza coperto',p.reserved)}\${line('Altri risparmi',p.other)}\${line('Prossimo traguardo',p.target)}\${line('Manca',p.missing)}\${line('Da risparmiare al mese',p.monthly)}<p class="hint">Cifra mancante divisa per \${p.months} mesi fino a dicembre, incluso quello corrente.</p><button data-edit-planning>Obiettivo e fondo emergenza</button></section>\`;
  };
  overviewAnalysis=function(d){return \`<div class="budget-flow"><section class="card pad"><h2>Ricorrenti</h2>\${(d.recurring||[]).map((r,i)=>\`<button class="plan-list-row" data-budget-recurring="\${i}"><span>\${safe(r.name)}</span><strong>\${state.assetsVisible?exactEuro(r.estimate):'\u2022\u2022\u2022\u2022'}</strong></button>\`).join('')||'<p class="empty">Nessuna voce ricorrente</p>'}</section>\${planningCard(d)}</div>\`;};
  function sheet(title,body){
    const host=document.getElementById('dialog');
    host.innerHTML=\`<div class="modal" role="dialog" aria-modal="true" aria-label="\${safe(title)}"><div class="modal-top"><h2>\${safe(title)}</h2><button data-close aria-label="Chiudi">\xD7</button></div>\${body}</div>\`;host.classList.remove('hidden');return host;
  }
  function settings(){
    const p=progress(),host=sheet('Obiettivo e fondo',\`<form id="platform-planning-form" class="form-grid"><label>Fondo emergenza \u20AC<input name="goal" type="number" min="0" max="1000000" step="0.01" value="\${p.emergency}" required></label><label>Obiettivo di risparmio \u20AC<input name="target" type="number" min="0.01" max="1000000" step="0.01" value="\${p.target}" required></label><div class="full" data-saving-preview></div><p role="alert" class="os-form-error full"></p><div class="form-actions"><button type="button" data-close>Annulla</button><button class="save" type="submit">Salva</button></div></form>\`);
    const form=host.querySelector('form');
    const preview=()=>{const p=progress(form.elements.goal.value,form.elements.target.value);form.querySelector('[data-saving-preview]').innerHTML=line('Da risparmiare',p.missing)+\`<p>Mesi fino a dicembre: \${p.months}</p>\`+line('Al mese',p.monthly);};
    form.addEventListener('input',preview);preview();
    form.addEventListener('submit',async e=>{
      e.preventDefault();if(!form.reportValidity()||form.dataset.busy)return;
      const p=progress(form.elements.goal.value,form.elements.target.value),button=form.querySelector('[type=submit]');form.dataset.busy='true';button.disabled=true;
      try{
        const result=await workerRequest('savePlanningSettings',[p.emergency,p.monthly,p.target]);if(result===false)throw Error('Il server non ha confermato la modifica.');
        const fresh=await workerRequest('getFinanceOverview',[state.year,state.month],{fresh:true});
        if(Math.abs(Number(fresh.planning?.goal)-p.emergency)>0.005||Math.abs(Number(fresh.planning?.savingsTarget)-p.target)>0.005||!Number.isFinite(fresh.planning?.goal)||!Number.isFinite(fresh.planning?.savingsTarget))throw Error('Impostazioni inviate ma non ancora verificate. Aggiorna prima di riprovare.');
        state.data={...state.data,...fresh};closeDialog();render();
      }catch(error){form.querySelector('[role=alert]').textContent=error.message;}
      finally{delete form.dataset.busy;button.disabled=false;}
    });
  }
  function recurring(index){
    const r=state.data?.recurring?.[index];if(!r)return;
    closeDialog();setView('extras');
  }

  document.addEventListener('click',e=>{const b=e.target.closest('[data-edit-planning],[data-budget-recurring]');if(!b)return;if(b.hasAttribute('data-edit-planning'))settings();else recurring(Number(b.dataset.budgetRecurring));});
})();
<\/script><script>(() => {
  // backend/worker/finance-model.mjs
  function addMonth(value, count) {
    const [y, m, d = 1] = value.split("-").map(Number);
    const first = new Date(Date.UTC(y, m - 1 + count, 1));
    const last = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0)).getUTCDate();
    first.setUTCDate(Math.min(d, last));
    return first.toISOString().slice(0, value.length);
  }
  var endOfMonth = (m) => new Date(Date.UTC(Number(m.slice(0, 4)), Number(m.slice(-2)), 0)).toISOString().slice(0, 10);
  var sum = (rows) => rows.reduce((a, b) => a + b, 0);
  var median = (rows) => rows.length ? (rows[Math.floor((rows.length - 1) / 2)] + rows[Math.floor(rows.length / 2)]) / 2 : 0;
  var monthDelta = (a, b) => (Number(a.slice(0, 4)) - Number(b.slice(0, 4))) * 12 + Number(a.slice(5, 7)) - Number(b.slice(5, 7));
  function wealthForecast(finance, plan = {}, day) {
    const month = day.slice(0, 7), earliest = addMonth(month, -6);
    const source = (finance.forecastHistory || []).filter((r) => r.month >= earliest && r.month < month && r.observed).sort((a, b) => a.month.localeCompare(b.month));
    const grouped = /* @__PURE__ */ new Map(), actual = {};
    for (const link of plan.links || []) if (link.role === "payment" && link.account === "Trade Republic") {
      const rows = grouped.get(link.movement_source_row) || [];
      rows.push(link);
      grouped.set(link.movement_source_row, rows);
    }
    for (const links of grouped.values()) {
      const first = links[0], attributed = sum(links.map((link) => ((plan.settlements || []).find((s) => s.cycle_id === link.cycle_id && s.movement_source_row === link.movement_source_row)?.actual_cents ?? link.attributed_cents) / 100));
      const m = first.actual_date.slice(0, 7);
      actual[m] = (actual[m] || 0) + Math.min(Math.max(0, -first.amount), attributed);
    }
    const plans = finance.plansV2?.plans || [], posted = (finance.plansV2?.payments || []).filter((p) => p.status === "posted");
    for (const p of posted) if (!p.legacy) {
      const linked = plans.find((r) => r.id === p.planId);
      if (linked && (["goal", "fund", "recovery"].includes(linked.kind) || linked.kind === "fixed" && linked.intervalMonths > 1)) {
        const m = p.date.slice(0, 7);
        actual[m] = (actual[m] || 0) + p.amountCents / 100;
      }
    }
    const nets = source.map((r) => (r.ordinaryNet || 0) + Math.max(0, (actual[r.month] || 0) - (r.extraPaid || 0))).filter(Number.isFinite).sort((a, b) => a - b);
    const center = median(nets), mad = median(nets.map((v) => Math.abs(v - center)).sort((a, b) => a - b));
    const spread = mad > 0 ? 3 * 1.4826 * mad : Math.max(0, nets.length >= 4 ? nets.at(-2) - nets[1] : 0);
    const robust = nets.map((v) => Math.min(center + spread, Math.max(center - spread, v)));
    const normalizedNet = robust.length ? sum(robust) / robust.length : 0, assets = finance.summary?.budget || 0;
    const balances = /* @__PURE__ */ new Map();
    for (const row of [...finance.lifetime?.series || [], ...finance.wealthHistory || []]) balances.set(row.month, { ...balances.get(row.month), ...row });
    const history = [...balances.values()].filter((r) => r.month >= earliest && r.month < month).map((r) => ({ day: endOfMonth(r.month), value: [r.measured, r.estimated, r.wealth].find(Number.isFinite) })).filter((p) => Number.isFinite(p.value)).sort((a, b) => a.day.localeCompare(b.day));
    history.push({ day, value: assets });
    const payments = [], cycles = /* @__PURE__ */ new Map();
    for (const row of plan.allocations || []) if (row.kind === "expense" && (row.payment_account || "Trade Republic") === "Trade Republic" && !["Pagato", "Annullato", "Previsto"].includes(row.status) && !cycles.has(row.cycle_id)) cycles.set(row.cycle_id, row);
    for (const row of cycles.values()) if (row.end_month) {
      const linked = sum((plan.links || []).filter((l) => l.cycle_id === row.cycle_id && l.role === "payment").map((l) => l.attributed_cents));
      payments.push({ day: [day, endOfMonth(row.end_month.slice(0, 7))].sort().at(-1), amount: Math.max(0, row.total_cents - linked) / 100 });
    }
    for (const row of plans.filter((r) => r.status === "active")) {
      if (row.kind === "goal" && /^20\\d\\d-\\d\\d$/.test(row.endMonth)) payments.push({ day: [day, endOfMonth(row.endMonth)].sort().at(-1), amount: (row.outstandingCents ?? row.amountCents) / 100 });
      if (row.kind === "fixed" && row.intervalMonths > 1) for (let offset = 0; offset <= 6; offset++) {
        const m = addMonth(month, offset);
        if (m < row.startMonth) continue;
        const anchor = row.intervalAnchor || row.startMonth, cycle = addMonth(anchor, Math.floor(monthDelta(m, anchor) / row.intervalMonths) * row.intervalMonths);
        if (addMonth(cycle, row.intervalMonths - 1) !== m) continue;
        let amount = row.amountCents;
        for (const rate of [...row.rateChanges || []].sort((a, b) => a.fromMonth.localeCompare(b.fromMonth))) if (rate.fromMonth <= m) amount = rate.amountCents;
        const paid = sum(posted.filter((p) => p.planId === row.id && p.settlementKey === cycle).map((p) => p.amountCents));
        payments.push({ day: [day, endOfMonth(m)].sort().at(-1), amount: Math.max(0, amount - paid) / 100 });
      }
    }
    const horizon = addMonth(day, 6), knownExtra = sum(payments.filter((p) => p.day <= horizon).map((p) => p.amount));
    if (robust.length < 4) return { history, prediction: [], samples: source.length, normalizedNet, knownExtra };
    let seed = 0x4C6966654F53n;
    const draw = () => {
      seed = BigInt.asUintN(64, seed * 6364136223846793005n + 1442695040888963407n);
      return robust[Number((seed >> 32n) % BigInt(robust.length))];
    };
    const paths = Array(2e3).fill(assets), prediction = [{ day, value: assets, lower: assets, upper: assets }];
    let previous = day;
    for (let step = 1; step <= 6; step++) {
      const date = addMonth(day, step), payment = sum(payments.filter((p) => p.day <= date && (p.day > previous || step === 1 && p.day === day)).map((p) => p.amount));
      for (let i = 0; i < paths.length; i++) paths[i] += draw() - payment;
      const sorted = [...paths].sort((a, b) => a - b), expected = assets + step * normalizedNet - sum(payments.filter((p) => p.day <= date).map((p) => p.amount));
      prediction.push({ day: date, value: expected, lower: Math.min(expected, sorted[199]), upper: Math.max(expected, sorted[1799]) });
      previous = date;
    }
    return { history, prediction, samples: source.length, normalizedNet, knownExtra };
  }
  function aggregateCategories(snapshots, months) {
    if (!months.length || new Set(months).size !== months.length) throw Error("Dati incompleti per il periodo selezionato.");
    const totals = /* @__PURE__ */ new Map();
    for (const month of months) {
      const rows = snapshots.get(month);
      if (!Array.isArray(rows)) throw Error("Dati incompleti per il periodo selezionato.");
      for (const row of rows) {
        const name = String(row.name || "").trim(), cents = Math.sign(row.amount) * Math.round(Math.abs(row.amount) * 100);
        if (!name || typeof row.amount !== "number" || !Number.isSafeInteger(cents)) throw Error("Dati categoria non validi.");
        const total = (totals.get(name) || 0) + cents;
        if (!Number.isSafeInteger(total)) throw Error("Totale categoria non valido.");
        totals.set(name, total);
      }
    }
    return [...totals].filter(([, n]) => n > 0).sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1)).map(([name, cents]) => ({ name, amount: cents / 100 }));
  }

  // backend/worker/analysis-web.js
  (() => {
    let range = 3, cache = /* @__PURE__ */ new Map(), active = "", generation = 0, lastFinance = null;
    const safe = escapeHtml;
    const selectedMonth = () => \`\${state.year}-\${String(state.month).padStart(2, "0")}\`;
    const monthList = (last, count) => Array.from({ length: count }, (_, i) => addMonth(last, i - count + 1));
    function chart(rows, label, bar = false, directional = false) {
      if (!rows.length) return '<p class="empty">Nessun dato disponibile nel periodo.</p>';
      if (!state.assetsVisible) return "<button data-toggle-assets>Mostra importi</button>";
      const values = rows.flatMap((p) => [p.value, p.lower, p.upper, p.base, p.additional].filter(Number.isFinite)), low = Math.min(0, ...values), high = Math.max(1, ...values), W = 640, H = 250;
      const x = (i) => rows.length === 1 ? 320 : 48 + i * 560 / Math.max(1, rows.length - 1), y = (v) => 205 - (v - low) / (high - low) * 180;
      const path = rows.map((p, i) => \`\${i ? "L" : "M"}\${x(i)},\${y(p.value)}\`).join(" ");
      const bandRows = rows.map((p, i) => ({ p, i })).filter(({ p }) => Number.isFinite(p.lower) && Number.isFinite(p.upper));
      const band = bandRows.length ? \`<path fill="var(--os-accent)" opacity=".15" d="\${bandRows.map(({ p, i }, n) => \`\${n ? "L" : "M"}\${x(i)},\${y(p.upper)}\`).join(" ")} \${[...bandRows].reverse().map(({ p, i }) => \`L\${x(i)},\${y(p.lower)}\`).join(" ")} Z"/>\` : "";
      const rectangle = (i, a, b, color) => \`<rect x="\${x(i) - 8}" y="\${Math.min(y(a), y(b))}" width="16" height="\${Math.abs(y(a) - y(b))}" fill="\${color}"><title>\${safe(rows[i].label)}: \${safe(exactEuro(b - a))}</title></rect>\`;
      const shapes = bar ? rows.map((p, i) => rectangle(i, 0, p.base ?? p.value, "var(--os-accent)") + (p.additional ? rectangle(i, Math.sign(p.base) === Math.sign(p.additional) ? p.base : 0, (Math.sign(p.base) === Math.sign(p.additional) ? p.base : 0) + p.additional, "var(--muted)") : "")).join("") : \`\${band}\${directional ? rows.slice(1).map((p, i) => \`<path d="M\${x(i)},\${y(rows[i].value)} L\${x(i + 1)},\${y(p.value)}" fill="none" stroke="\${p.value < rows[i].value ? "var(--red)" : "var(--green)"}" stroke-width="2"/>\`).join("") : \`<path d="\${path}" fill="none" stroke="var(--os-accent)" stroke-width="2"/>\`}\${rows.map((p, i) => \`<circle cx="\${x(i)}" cy="\${y(p.value)}" r="3" fill="var(--os-accent)"><title>\${safe(p.label)}: \${safe(exactEuro(p.value))}</title></circle>\`).join("")}\`;
      return \`<svg class="trend-svg" viewBox="0 0 \${W} \${H}" role="img" aria-label="\${safe(label)}"><line class="grid-line" x1="40" x2="620" y1="205" y2="205"/>\${shapes}\${rows.map((p, i) => i % Math.max(1, Math.ceil(rows.length / 6)) && i !== rows.length - 1 ? "" : \`<text style="font-size:20px" x="\${x(i)}" y="235" text-anchor="middle">\${safe(p.label)}</text>\`).join("")}</svg><details><summary>Valori del grafico</summary>\${rows.map((p) => \`<div class="kv"><span>\${safe(p.label)}</span><strong>\${safe(exactEuro(p.value))}\${Number.isFinite(p.lower) ? \`<small> \${safe(exactEuro(p.lower))} \\u2013 \${safe(exactEuro(p.upper))}</small>\` : ""}</strong></div>\`).join("")}</details>\`;
    }
    const card = (title, body) => \`<section class="card pad"><h2>\${title}</h2>\${body}</section>\`;
    globalThis.platformAnalysis = function(d) {
      if (lastFinance !== d) {
        cache.clear();
        lastFinance = d;
      }
      const month = selectedMonth(), period = monthList(month, 12), first = period[0];
      const model = wealthForecast(d, d.forecastPlan || d.extraPlan, todayIso());
      const wealth = /* @__PURE__ */ new Map();
      for (const row of [...d.lifetime?.series || [], ...d.wealthHistory || []]) wealth.set(row.month, { ...wealth.get(row.month), ...row });
      const wealthRows = [...wealth.values()].filter((r) => r.month >= first && r.month <= month).sort((a, b) => a.month.localeCompare(b.month)).map((r) => ({ label: shortMonth(r.month), value: [r.measured, r.estimated, r.wealth].find(Number.isFinite) })).filter((r) => Number.isFinite(r.value));
      const salary = (d.lifetime?.salaryHistory || []).filter((r) => r.month >= first && r.month <= month).sort((a, b) => a.month.localeCompare(b.month));
      const forecast = model.prediction.length ? chart([...model.history.slice(0, -1), ...model.prediction].map((p) => ({ ...p, label: p.day.slice(0, 7) })), "Previsione patrimonio") : \`<p class="empty">Servono almeno 4 mesi completi osservati sui 6 precedenti. Disponibili: \${model.samples}.</p>\`;
      const html = \`<div class="budget-flow">\${card("Spese per categoria", \`<div class="chart-range" role="group" aria-label="Periodo categorie">\${[3, 6, 12].map((n) => \`<button data-category-period="\${n}" class="\${n === range ? "active" : ""}" aria-pressed="\${n === range}">\${n} mesi</button>\`).join("")}</div><p class="hint" data-category-interval></p><div data-period-categories role="status">Caricamento categorie\\u2026</div><button data-refresh-categories>Aggiorna categorie</button>\`)}\${card("Previsione patrimonio", \`<p class="hint">6 mesi precedenti \\xB7 6 mesi successivi</p>\${forecast}<details><summary>Come viene calcolata</summary><p>Fascia centrale dell\\u201980% di 2.000 simulazioni dei flussi osservati, con valori anomali limitati tramite mediana e deviazione assoluta mediana. Sono sottratti i pagamenti futuri pianificati, senza sottrarre gli accantonamenti una seconda volta.</p><p>Pagamenti noti nei prossimi 6 mesi: \${state.assetsVisible ? exactEuro(model.knownExtra) : "\\u2022\\u2022\\u2022\\u2022"}</p><p>Scenario indicativo sul conto principale, non garantito.</p></details>\`)}\${card("Patrimonio", \`<p class="hint">12 mesi fino a \${safe(titleMonth(state.year, state.month))}</p>\${chart(wealthRows, "Patrimonio", false, true)}\`)}\${card("Stipendi per competenza", \`<p class="hint">12 mesi fino a \${safe(titleMonth(state.year, state.month))}</p>\${chart(salary.map((r) => ({ label: shortMonth(r.month), value: (r.base || 0) + (r.additional || 0), base: r.base || 0, additional: r.additional || 0 })), "Stipendi per competenza", true)}\${salary.length ? \`<details><summary>Base e aggiuntive</summary>\${salary.map((r) => \`<div class="kv"><span>\${safe(shortMonth(r.month))}</span><strong>\${state.assetsVisible ? \`Base \${exactEuro(r.base || 0)} \\xB7 Aggiuntive \${exactEuro(r.additional || 0)}\` : "\\u2022\\u2022\\u2022\\u2022"}</strong></div>\`).join("")}</details>\` : ""}\`)}</div>\`;
      if (Array.isArray(d.categories)) cache.set(month, d.categories);
      queueMicrotask(() => loadCategories(d));
      return html;
    };
    async function loadCategories(d) {
      const month = selectedMonth(), requested = monthList(month, range), token = \`\${month}|\${range}|\${++generation}\`;
      active = token;
      const target = document.querySelector("[data-period-categories]");
      if (!target) return;
      const interval = document.querySelector("[data-category-interval]");
      interval.textContent = shortMonth(requested[0]) + " \\u2013 " + shortMonth(month);
      const refresh = document.querySelector("[data-refresh-categories]");
      refresh.disabled = true;
      const current = () => active === token && state.view === "analysis" && selectedMonth() === month && target.isConnected;
      try {
        const local = globalThis.lifeOSLocalMode;
        if (local?.mode === "snapshot") throw Error("Collega il server per analizzare 3, 6 o 12 mesi. Lo snapshot locale non garantisce la copertura del periodo.");
        if (local?.mode === "demo") {
          const samples = new Map(requested.map((m) => [m, []]));
          for (const row of local.archive.finance.transactions || []) {
            const m = String(row.date || "").slice(0, 7);
            if (samples.has(m) && ["Spesa", "Rimborso"].includes(row.type)) samples.get(m).push({ name: row.displayCategory || row.category || "Altro", amount: -row.amount });
          }
          if (month === todayIso().slice(0, 7) && Array.isArray(d.categories)) samples.set(month, d.categories);
          for (const [m, rows2] of samples) cache.set(m, rows2);
        }
        if (requested.some((m) => !cache.has(m))) {
          if (!current()) return;
          const data = await workerRequest("getFinanceCategoryPeriod", [month, range]);
          if (!current()) return;
          if (!Array.isArray(data.months) || data.months.length !== requested.length) throw Error("Periodo categorie incompleto. Riprova.");
          const samples = new Map(data.months.map((r) => [r.month, r.categories]));
          aggregateCategories(samples, requested);
          for (const m of requested) cache.set(m, samples.get(m));
        }
        if (!current()) return;
        const rows = aggregateCategories(cache, requested);
        const colors = ["var(--os-accent)", "#6e9cc1", "#c79a58", "#a788b8", "#b9777b", "#8b929b"], total = rows.reduce((s, r) => s + r.amount, 0);
        let offset = 0;
        const segments = rows.map((r, i) => {
          const share = r.amount / total * 100, shape = \`<circle cx="60" cy="60" r="48" pathLength="100" fill="none" stroke="\${colors[i % colors.length]}" stroke-width="12" stroke-dasharray="\${share} \${100 - share}" stroke-dashoffset="\${-offset}" transform="rotate(-90 60 60)"/>\`;
          offset += share;
          return shape;
        }).join("");
        target.innerHTML = rows.length ? \`<div class="breakdown"><div class="category-ring"><svg viewBox="0 0 120 120" role="img" aria-label="Spese per categoria">\${segments}</svg><div class="category-ring-label"><small>Spese</small><strong>\${state.assetsVisible ? exactEuro(total) : "\\u2022\\u2022\\u2022\\u2022"}</strong></div></div><div>\${rows.map((r, i) => \`<div class="kv"><span><i class="category-swatch" style="background:\${colors[i % colors.length]}"></i>\${safe(r.name)}</span><strong>\${state.assetsVisible ? exactEuro(r.amount) : "\\u2022\\u2022\\u2022\\u2022"}</strong></div>\`).join("")}</div></div>\` : '<p class="empty">Nessuna spesa nel periodo</p>';
        refresh.textContent = "Aggiorna categorie";
      } catch (error) {
        if (current()) {
          target.textContent = error.message + " Premi Riprova per caricare il periodo.";
          refresh.textContent = "Riprova";
        }
      } finally {
        if (current()) refresh.disabled = false;
      }
    }
    document.addEventListener("click", (e) => {
      const period = e.target.closest("[data-category-period]"), refresh = e.target.closest("[data-refresh-categories]");
      if (period) {
        range = Number(period.dataset.categoryPeriod);
        render();
      }
      if (refresh) {
        if (refresh.textContent !== "Riprova") cache.clear();
        loadCategories(state.data);
      }
    });
  })();
})();
<\/script><script>(() => {
  // backend/plans/engine.mjs
  var PlanError = class extends Error {
    constructor(message, status = 422) {
      super(message);
      this.status = status;
    }
  };
  var fail = (message) => {
    throw new PlanError(message);
  };
  var kinds = ["advance", "goal", "fund", "fixed", "estimated", "recovery"];
  function month(value) {
    if (typeof value !== "string" || !/^20\\d\\d-(0[1-9]|1[0-2])$/.test(value)) fail("Scegli mese e anno validi.");
    return value;
  }
  function addMonth(value, count) {
    month(value);
    const [y, m] = value.split("-").map(Number), date = new Date(Date.UTC(y, m - 1 + count, 1));
    return date.toISOString().slice(0, 7);
  }
  function months(first, last, limit = 240) {
    month(first);
    month(last);
    if (last < first) fail("L\\u2019ultimo mese precede il primo.");
    const count = (Number(last.slice(0, 4)) - Number(first.slice(0, 4))) * 12 + Number(last.slice(-2)) - Number(first.slice(-2)) + 1;
    if (count > limit) fail("Il piano finito pu\\xF2 coprire al massimo 240 mesi; per un fondo usa Senza scadenza.");
    return Array.from({ length: count }, (_, i) => addMonth(first, i));
  }
  function cents(value) {
    if (!Number.isSafeInteger(value) || value <= 0 || value > 1e8) fail("Importo non valido.");
    return value;
  }
  function split(total, count) {
    cents(total);
    if (!Number.isInteger(count) || count < 1 || count > 240) fail("Numero di mesi non valido.");
    return Array.from({ length: count }, (_, i) => Math.floor(total / count) + (i < total % count ? 1 : 0));
  }
  function day(value, today) {
    if (typeof value !== "string" || !/^20\\d\\d-(0[1-9]|1[0-2])-\\d\\d$/.test(value)) fail("Data del pagamento non valida.");
    const parsed = /* @__PURE__ */ new Date(value + "T12:00:00Z");
    if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value || value > today) fail("La data deve essere valida e non futura.");
    return value;
  }
  function newPlan(input, today, id) {
    const kind = input.kind, current = month(today.slice(0, 7));
    if (!kinds.includes(kind)) fail("Scegli il tipo di piano.");
    const name = String(input.name ?? "").trim();
    if (!name || name.length > 120) fail("Inserisci un nome di massimo 120 caratteri.");
    const first = month(input.startMonth);
    if (first < current) fail("Le quote nuove possono iniziare dal mese corrente.");
    const finite = ["advance", "goal", "recovery"].includes(kind), last = finite ? month(input.endMonth) : null;
    const amount = cents(input.amountCents), interval = Number(input.intervalMonths ?? 1);
    const category = String(input.category ?? "Altro").trim();
    if (!category || category.length > 60) fail("Categoria non valida.");
    if (!Number.isInteger(interval) || interval < 1 || interval > 12) fail("Periodicit\\xE0 non valida.");
    if (finite) months(first, last);
    const plan = {
      id,
      name,
      category,
      kind,
      amountCents: amount,
      startMonth: first,
      endMonth: last,
      intervalMonths: interval,
      createdDay: today,
      status: "active",
      stopAfter: null,
      closedMonth: null,
      rateChanges: []
    };
    if (kind === "advance") {
      plan.beneficiaryMonth = month(input.beneficiaryMonth);
      if (plan.beneficiaryMonth < current || plan.beneficiaryMonth >= first) fail("Il mese beneficiario deve essere aperto e precedere i mesi di recupero.");
    }
    if (kind === "recovery") {
      plan.paymentDate = day(input.paymentDate, today);
      if (first < plan.paymentDate.slice(0, 7)) fail("Il recupero non pu\\xF2 precedere il pagamento.");
      plan.status = "pendingPayment";
    }
    return plan;
  }
  function contribution(plan, m) {
    month(m);
    if (plan.status === "cancelled" || plan.status === "pendingPayment") return 0;
    if (plan.kind === "advance") {
      if (m === plan.beneficiaryMonth) return -plan.amountCents;
    }
    if (m < plan.startMonth || plan.endMonth && m > plan.endMonth || plan.stopAfter && m > plan.stopAfter || plan.closedMonth && m > plan.closedMonth) return 0;
    if (plan.legacySchedule) return Number(plan.legacySchedule[m] ?? 0);
    if (["advance", "goal", "recovery"].includes(plan.kind)) {
      const range = months(plan.startMonth, plan.endMonth), i = range.indexOf(m);
      return i < 0 ? 0 : split(plan.amountCents, range.length)[i];
    }
    if (plan.kind === "fixed") {
      const anchor = plan.intervalAnchor ?? plan.startMonth;
      const delta = (Number(m.slice(0, 4)) - Number(anchor.slice(0, 4))) * 12 + Number(m.slice(-2)) - Number(anchor.slice(-2));
      let amount = plan.amountCents;
      for (const rate2 of plan.rateChanges ?? []) if (rate2.fromMonth <= m) amount = rate2.amountCents;
      return amount === 0 ? 0 : split(amount, plan.intervalMonths)[(delta % plan.intervalMonths + plan.intervalMonths) % plan.intervalMonths];
    }
    let rate = plan.amountCents;
    for (const change of plan.rateChanges ?? []) if (change.fromMonth <= m) rate = change.amountCents;
    return rate;
  }

  // backend/worker/plans-web.js
  (() => {
    const kinds2 = lifeOSContract.planKinds;
    const statuses = lifeOSContract.planStatuses;
    const today = () => (/* @__PURE__ */ new Date()).toLocaleDateString("sv-SE", { timeZone: "Europe/Rome" });
    const current = () => today().slice(0, 7);
    const next = (m) => {
      const [y, n] = m.split("-").map(Number);
      return new Date(Date.UTC(y, n, 1)).toISOString().slice(0, 7);
    };
    const safe = osSafe, money = (c) => exactEuro(Number(c || 0) / 100);
    const view = () => state.data?.plansV2;
    const plan = (id) => view()?.plans.find((p) => p.id === id);
    const field = (label, name, type, value = "", attrs = "") => \`<label class="\${name === "name" ? "full" : ""}">\${label}<input name="\${name}" type="\${type}" value="\${safe(value)}" \${attrs}></label>\`;
    const amount = (label, value = "") => field(label, "amount", "number", value, 'required min="0.01" max="1000000" step="0.01"');
    const monthField = (label, name, value) => field(label, name, "month", value, 'required min="' + current() + '" max="2099-12"');
    const oldActions = osPageActions;
    osPageActions = function() {
      oldActions();
      document.querySelectorAll("[data-new-extra]").forEach((b) => {
        b.setAttribute("aria-label", "Nuovo piano");
        b.setAttribute("title", "Nuovo piano");
        if (!b.classList.contains("fab-button")) b.textContent = "+ Piano";
      });
    };
    const oldSetView = setView;
    setView = function(v) {
      if (v !== "extras") activePlan = null;
      oldSetView(v);
      if (v === "extras") document.getElementById("page-title").textContent = activePlan ? "Dettagli piano" : "Piani";
    };
    const oldOverview = overview;
    overview = function(d) {
      return oldOverview(d).replace(">Extra</button>", ">Piani</button>");
    };
    let activePlan = null;
    extrasView = function(d) {
      const v = d.plansV2;
      if (!v || v.version !== 2 || !Array.isArray(v.plans) || !Array.isArray(v.payments)) return \`<p role="alert">\${safe(lifeOSContract.plansUnavailable)}</p><button data-plans-refresh>Riprova</button>\`;
      const p = v.plans.find((p2) => p2.id === activePlan);
      if (p) {
        document.getElementById("page-title").textContent = "Dettagli piano";
        return detail(p, v);
      }
      activePlan = null;
      document.getElementById("page-title").textContent = "Piani";
      const legacy = [...new Map((d.extraPlan?.allocations || []).map((r) => [r.cycle_id, r])).values()];
      return \`<div class="plans-web"><div class="card-title"><div><h2>Piani</h2><p class="hint">Tutti i piani \\xB7 impatto su \${safe(titleMonth(state.year, state.month))}</p></div><div class="actions"><button data-plans-info aria-label="Come funzionano i piani">\\u24D8</button><button class="save" data-new-extra>Nuovo piano</button></div></div><div class="extra-grid">\${v.plans.map((p2) => \`<button class="extra-card plan-list-row" data-plans-detail="\${safe(p2.id)}"><span><strong>\${safe(p2.name)}</strong><small>\${safe(kinds2[p2.kind])} \\xB7 \${safe(statuses[p2.status] || p2.status)}</small><span>Budget del mese: \${money(-p2.contributionCents)}</span></span><span aria-hidden="true">\\u203A</span></button>\`).join("") || '<p class="empty">Anticipa budget, metti da parte o distribuisci una spesa sui mesi scelti.</p>'}</div>\${legacy.length ? \`<section class="card pad"><h2>Piani precedenti</h2><p class="hint">Le voci storiche non adottate sono conservate. Non duplicarle con un nuovo piano.</p>\${legacy.map((r) => \`<button class="plan-list-row" data-plans-legacy="\${Number(r.extraordinary_source_row)}"><span>\${safe(r.name)}<small>\${safe(NativeExtraTitle(r.status))}</small></span><span aria-hidden="true">\\u203A</span></button>\`).join("")}</section>\` : ""}</div>\`;
    };
    function NativeExtraTitle(status) {
      return { Pagato: "Pagata", Programmato: "In corso", Previsto: "Da valutare", Annullato: "Annullata" }[status] || status;
    }
    function detail(p, v) {
      let cycle = v.month;
      if (p.kind === "fixed" && p.intervalMonths > 1) {
        const anchor = p.intervalAnchor || p.startMonth, [y, m] = anchor.split("-").map(Number), delta = (Number(cycle.slice(0, 4)) - y) * 12 + Number(cycle.slice(-2)) - m;
        cycle = addMonth(anchor, Math.floor(delta / p.intervalMonths) * p.intervalMonths);
      }
      const payments = v.payments.filter((x) => x.planId === p.id), paid = p.kind !== "fund" && payments.some((x) => ["posted", "deleting"].includes(x.status) && (p.kind === "goal" || x.settlementKey === cycle));
      const payable = p.status === "active" && !["advance", "recovery"].includes(p.kind) && p.startMonth <= current();
      return \`<div class="plans-web"><button data-plans-back>\\u2039 Piani</button><section class="card pad"><h2>\${safe(p.name)}</h2><p>\${safe(kinds2[p.kind])} \\xB7 \${safe(statuses[p.status] || p.status)}</p><p class="hint">\${safe(p.startMonth)}\${p.endMonth ? " \\u2192 " + safe(p.endMonth) : " \\xB7 Senza scadenza"}</p><div class="kv"><span>Categoria della spesa</span><strong>\${safe(p.category || "Altro")}</strong></div><div class="kv"><span>Budget di \${safe(shortMonth(v.month))}</span><strong>\${money(-p.contributionCents)}</strong></div>\${p.kind === "advance" ? \`<div class="kv"><span>Mese beneficiario</span><strong>\${safe(shortMonth(p.beneficiaryMonth))}</strong></div>\` : p.kind !== "recovery" ? \`<div class="kv"><span>Destinato al fondo nel mese consultato</span><strong>\${money(p.fundCents)}</strong></div>\${p.fromGeneralSavingsCents > 0 ? \`<div class="kv"><span>Pagato dagli altri risparmi</span><strong>\${money(p.fromGeneralSavingsCents)}</strong></div>\` : ""}\` : ""}\${p.kind === "goal" ? \`<div class="kv"><span>Obiettivo</span><strong>\${money(p.amountCents)}</strong></div><div class="kv"><span>Residuo</span><strong>\${money(p.outstandingCents)}</strong></div>\` : ""}\${payable && !paid ? \`<button data-plans-pay="\${safe(p.id)}">\${p.kind === "goal" ? "Paga dai risparmi e chiudi il piano" : "Registra un pagamento"}</button>\` : paid ? "<p>Pagamento registrato</p>" : ""}</section><section class="card pad"><h2>Pagamenti</h2>\${payments.map((p2) => \`<div class="kv"><span>\${safe(p2.date || "")}<small>\${p2.status === "posted" ? "Pagato \\xB7 movimento collegato" : p2.status === "deleting" ? "Eliminazione da completare" : "Da completare \\xB7 non registrare una nuova spesa"}</small></span><strong>\${money(p2.amountCents)}</strong></div>\${["posted", "deleting"].includes(p2.status) ? \`<button data-plans-payment="\${safe(p2.id)}">\${p2.status === "deleting" ? "Completa eliminazione" : "Gestisci pagamento"}</button>\` : ""}\${p2.status === "pending" ? \`<button data-plans-resume="\${safe(p2.id)}">Completa questa registrazione</button>\` : ""}\`).join("") || '<p class="empty">Nessun pagamento registrato</p>'}</section>\${p.status === "active" ? \`<section class="card pad">\${!["advance", "recovery"].includes(p.kind) ? \`<button data-plans-edit="\${safe(p.id)}">Modifica le quote future</button>\` : ""}<button class="danger" data-plans-stop="\${safe(p.id)}">\${p.kind === "advance" ? "Annulla l\\u2019intero anticipo" : "Interrompi le quote future"}</button></section>\` : ""}</div>\`;
    }
    function modal(title, body, method, makePayload) {
      const host = document.getElementById("dialog");
      host.innerHTML = \`<div class="modal" role="dialog" aria-modal="true" aria-label="\${safe(title)}"><div class="modal-top"><h2>\${safe(title)}</h2><button type="button" data-plans-close aria-label="Chiudi">\\xD7</button></div><form id="plans-web-form" class="form-grid">\${body}<p class="os-form-error full" role="alert"></p><div class="form-actions full"><button type="button" data-plans-close>Annulla</button><button class="save" type="submit">Salva</button></div></form></div>\`;
      host.classList.remove("hidden");
      const form = host.querySelector("form"), requestId = crypto.randomUUID();
      let payload = null, busy = false;
      form.addEventListener("submit", async (e) => {
        e.preventDefault();
        if (busy || !form.reportValidity()) return;
        const error = form.querySelector("[role=alert]"), button = form.querySelector("[type=submit]");
        try {
          if (!payload) payload = { requestId, ...makePayload(new FormData(form)) };
          busy = true;
          form.dataset.submitted = "true";
          host.querySelectorAll("[data-plans-close]").forEach((b) => b.disabled = true);
          button.disabled = true;
          button.textContent = "Salvataggio\\u2026";
          error.textContent = "";
          form.querySelectorAll("input,select").forEach((x) => x.disabled = true);
          const result = await workerRequest(method, [payload]);
          if (result === false) throw Error("Il server non ha confermato la modifica.");
          host.classList.add("hidden");
          state.data = null;
          state.loadedDetail = false;
          load();
          osLoadHomeFinance();
        } catch (err) {
          error.textContent = err.message + " Puoi riprovare la stessa operazione senza duplicarla.";
          button.textContent = "Riprova";
        } finally {
          busy = false;
          button.disabled = false;
          host.querySelectorAll("[data-plans-close]").forEach((b) => b.disabled = false);
        }
      });
      return form;
    }
    const cents2 = (f) => {
      const n = Number(f.get("amount"));
      if (!Number.isFinite(n) || n <= 0 || Math.abs(n * 100 - Math.round(n * 100)) > 1e-6) throw Error("Usa un importo positivo con massimo due decimali.");
      return Math.round(n * 100);
    };
    openExtra = function() {
      const form = modal("Nuovo piano", \`<label class="full">Tipo<select name="kind">\${Object.entries(kinds2).map(([k, v]) => \`<option value="\${k}" \${k === "goal" ? "selected" : ""}>\${v}</option>\`).join("")}</select></label>\${field("Nome", "name", "text", "", 'required maxlength="120" class="full"')}<div class="full" data-plan-fields></div>\`, "saveFinancePlan", (f) => {
        const kind = String(f.get("kind")), p = { kind, name: String(f.get("name")).trim(), amountCents: cents2(f), startMonth: String(f.get("startMonth")), category: String(f.get("category") || "Altro") };
        if (["goal", "advance", "recovery"].includes(kind)) p.endMonth = String(f.get("endMonth"));
        if (kind === "advance") p.beneficiaryMonth = String(f.get("beneficiaryMonth"));
        if (kind === "fixed") p.intervalMonths = Number(f.get("intervalMonths"));
        if (kind === "recovery") {
          p.paymentDate = String(f.get("date"));
          if (f.get("movementId")) p.movementId = Number(f.get("movementId"));
        }
        newPlan(p, today(), "preview");
        return p;
      });
      const update = () => {
        const kind = form.elements.kind.value, start = kind === "advance" ? next(current()) : current();
        const labels = { goal: "Totale obiettivo \\u20AC", fund: "Quota mensile \\u20AC", fixed: "Importo per scadenza \\u20AC", estimated: "Stima mensile \\u20AC", advance: "Budget da anticipare \\u20AC", recovery: "Spesa da recuperare \\u20AC" };
        form.querySelector("[data-plan-fields]").innerHTML = \`<div class="form-grid">\${kind !== "advance" ? \`<label>Categoria della spesa<select name="category">\${lifeOSContract.expenseCategories.map((c) => \`<option \${c === "Altro" ? "selected" : ""}>\${safe(c)}</option>\`).join("")}</select></label>\` : ""}\${amount(labels[kind])}\${monthField(kind === "advance" ? "Primo mese di recupero" : "Dal mese", "startMonth", start)}\${["goal", "advance", "recovery"].includes(kind) ? monthField("Ultimo mese", "endMonth", start) : '<p class="hint">Senza scadenza: continua finch\\xE9 non lo interrompi.</p>'}\${kind === "advance" ? monthField("Mese beneficiario", "beneficiaryMonth", current()) : ""}\${kind === "fixed" ? \`<label>Ogni quanti mesi<select name="intervalMonths">\${Array.from({ length: 12 }, (_, i) => \`<option value="\${i + 1}">Ogni \${i + 1} \${i === 0 ? "mese" : "mesi"}</option>\`).join("")}</select></label>\` : ""}\${kind === "recovery" ? \`\${field("Data della spesa", "date", "date", today(), 'required max="' + today() + '"')}<label class="full">Movimento<select name="movementId"><option value="">Registra una nuova spesa</option></select></label><p class="hint full">Collega una spesa gi\\xE0 registrata per recuperarla senza un secondo addebito.</p>\` : ""}<p class="hint full">\${kind === "advance" ? "Non sposta denaro tra conti: aumenta il budget del mese beneficiario e lo recupera nei mesi scelti." : kind === "recovery" ? "La spesa incide sul saldo una sola volta; le quote recuperano il budget nei mesi scelti." : "Creare il piano non registra un pagamento."}</p><section class="full" data-plan-preview aria-live="polite"></section></div>\`;
        preview();
        if (kind === "recovery") loadMovements(form);
      };
      function preview() {
        const target = form.querySelector("[data-plan-preview]");
        if (!target) return;
        const save = form.querySelector("[type=submit]");
        save.disabled = true;
        try {
          const f = new FormData(form), kind = String(f.get("kind"));
          if (!f.get("amount")) {
            target.textContent = "Inserisci importo e mesi per vedere l\\u2019anteprima budget.";
            return;
          }
          const p = newPlan({ kind, name: f.get("name") || "Anteprima", category: f.get("category") || "Altro", amountCents: cents2(f), startMonth: f.get("startMonth"), endMonth: f.get("endMonth"), beneficiaryMonth: f.get("beneficiaryMonth"), intervalMonths: Number(f.get("intervalMonths") || 1), paymentDate: f.get("date") }, today(), "preview");
          p.status = "active";
          const range = p.endMonth ? months(p.startMonth, p.endMonth) : [0, 1, 2].map((i) => addMonth(p.startMonth, i));
          if (kind === "advance") range.unshift(p.beneficiaryMonth);
          save.disabled = state.data?.plansV2?.version !== 2;
          if (save.disabled) form.querySelector("[role=alert]").textContent = lifeOSContract.plansUnavailable;
          target.innerHTML = "<h3>Anteprima budget" + (p.endMonth ? "" : " \\xB7 primi tre mesi") + "</h3>" + range.map((m) => \`<div class="kv"><span>\${safe(shortMonth(m))}</span><strong>\${money(-contribution(p, m))}</strong></div>\`).join("");
        } catch (error) {
          target.textContent = error.message;
        }
      }
      form.addEventListener("input", preview);
      form.addEventListener("change", preview);
      form.elements.kind.addEventListener("change", update);
      update();
    };
    async function loadMovements(form) {
      const select = form.elements.movementId;
      if (!select) return;
      const date = form.elements.date;
      let revision = 0;
      const refresh = async () => {
        const token = ++revision;
        select.disabled = true;
        try {
          const d = await workerRequest("getFinancePlanMovements", [date.value.slice(0, 7)]);
          if (!form.isConnected || !select.isConnected || token !== revision) return;
          select.innerHTML = '<option value="">Registra una nuova spesa</option>' + d.movements.map((m) => \`<option value="\${m.row}" data-cents="\${m.amountCents}" data-date="\${safe(m.date)}">\${safe(m.name)} \\xB7 \${money(m.amountCents)}</option>\`).join("");
        } catch (err) {
          if (token === revision && select.isConnected) form.querySelector("[role=alert]").textContent = "Movimenti non disponibili: " + err.message;
        } finally {
          if (token === revision && select.isConnected && !form.dataset.submitted) select.disabled = false;
        }
      };
      select.addEventListener("change", () => {
        const o = select.selectedOptions[0];
        if (o?.dataset.cents) {
          form.elements.amount.value = Number(o.dataset.cents) / 100;
          date.value = o.dataset.date;
        }
        form.elements.amount.readOnly = !!o?.dataset.cents;
        date.readOnly = !!o?.dataset.cents;
        form.dispatchEvent(new Event("input"));
      });
      date.addEventListener("change", refresh);
      await refresh();
    }
    function paymentDetail(id) {
      const p = view()?.payments.find((p2) => p2.id === id);
      if (!p) return;
      const removing = p.status === "deleting";
      const form = modal("Pagamento del piano", \`<div class="full"><p>\${safe(p.date)} \\xB7 \${money(p.amountCents)}</p><p>Elimina il pagamento e il movimento collegato. Il saldo verr\\xE0 aggiornato. Un piano interrotto resta interrotto; un obiettivo chiuso torna aperto.</p></div>\`, removing ? "resumeFinancePlanPayment" : "deleteFinancePlanPayment", () => ({ paymentId: id, ...removing ? {} : { planId: p.planId } }));
      form.querySelector("[type=submit]").textContent = removing ? "Completa eliminazione" : "Elimina pagamento";
    }
    globalThis.openPlanPayment = (planId, paymentId) => {
      activePlan = planId;
      closeDialog();
      setView("extras");
      paymentDetail(paymentId);
    };
    function pay(id) {
      const p = plan(id);
      if (!p) return;
      const m = view().month <= current() ? view().month : current();
      const form = modal("Paga o collega \\xB7 " + p.name, \`\${amount("Importo effettivo \\u20AC", (p.kind === "goal" ? p.outstandingCents : ["fixed", "fund", "estimated"].includes(p.kind) ? (p.rateChanges || []).filter((r) => r.fromMonth <= current()).sort((a, b) => a.fromMonth.localeCompare(b.fromMonth)).at(-1)?.amountCents ?? p.amountCents : Math.max(p.contributionCents, 1)) / 100)}\${field("Data pagamento", "date", "date", today(), 'required max="' + today() + '"')}\${["fixed", "estimated"].includes(p.kind) ? monthField("Scadenza pagata", "cycleMonth", m) : ""}\${p.kind === "estimated" ? field("Mesi coperti dalla bolletta", "competenceMonths", "number", 1, 'required min="1" max="12"') : ""}<label class="full">Movimento<select name="movementId"><option value="">Registra un nuovo pagamento</option></select></label><p class="hint full">Collegare un movimento esistente non genera un nuovo addebito.\${p.kind === "goal" ? " Il pagamento chiude l\\u2019obiettivo e libera le quote future." : ""}</p>\${p.kind === "goal" ? \`<section class="full hidden" data-overage><label class="full">Eccedenza<select name="recoverDifference"><option value="">Usa i risparmi</option><option value="yes">Recupera solo l\\u2019eccedenza nei mesi successivi</option></select></label><div class="full hidden" data-excess-recovery>\${monthField("Primo mese", "recoveryStartMonth", next(current()))}\${monthField("Ultimo mese", "recoveryEndMonth", next(current()))}</div></section>\` : ""}\`, "recordFinancePlanPayment", (f) => {
        const out = { planId: id, amountCents: cents2(f), date: String(f.get("date")), cycleMonth: String(f.get("cycleMonth") || current()), competenceMonths: Number(f.get("competenceMonths") || 1) };
        if (f.get("movementId")) out.movementId = Number(f.get("movementId"));
        if (f.get("recoverDifference") === "yes") Object.assign(out, { recoverDifference: true, recoveryStartMonth: String(f.get("recoveryStartMonth")), recoveryEndMonth: String(f.get("recoveryEndMonth")) });
        return out;
      });
      if (form.elements.cycleMonth) form.elements.cycleMonth.min = "2024-01";
      if (form.elements.recoverDifference) {
        const update = () => {
          const extra = Number(form.elements.amount.value) * 100 > (p.outstandingCents ?? p.amountCents);
          form.querySelector("[data-overage]").classList.toggle("hidden", !extra);
          if (!extra) form.elements.recoverDifference.value = "";
        };
        form.addEventListener("input", update);
        update();
      }
      form.elements.recoverDifference?.addEventListener("change", () => form.querySelector("[data-excess-recovery]").classList.toggle("hidden", form.elements.recoverDifference.value !== "yes"));
      loadMovements(form);
    }
    function edit(id) {
      const p = plan(id);
      if (!p) return;
      modal("Modifica quote future \\xB7 " + p.name, \`\${amount(p.kind === "goal" ? "Nuovo totale obiettivo \\u20AC" : "Nuova quota / scadenza \\u20AC", (p.kind === "goal" ? p.amountCents : (p.rateChanges || []).filter((r) => r.fromMonth <= next(current())).sort((a, b) => a.fromMonth.localeCompare(b.fromMonth)).at(-1)?.amountCents ?? p.amountCents) / 100)}\${monthField("Decorrenza", "fromMonth", next(current()))}\${p.kind === "goal" ? monthField("Nuova scadenza", "endMonth", p.endMonth < next(current()) ? next(current()) : p.endMonth) : ""}<p class="hint full">Il mese corrente e le quote precedenti restano invariati.</p>\`, "editFinancePlan", (f) => ({ planId: id, amountCents: cents2(f), fromMonth: String(f.get("fromMonth")), ...p.kind === "goal" ? { endMonth: String(f.get("endMonth")) } : {} }));
    }
    function showInfo() {
      const host = document.getElementById("dialog");
      const sections = [["La regola di base", ["Il budget indica quanto puoi destinare ai mesi. Il saldo \\xE8 il denaro reale sul conto. Accantonare modifica il budget, pagare registra una sola uscita reale."]], ["+ \\xB7 Scegli cosa vuoi fare", ["Il + \\xE8 indipendente dal mese che stai consultando. Prima scegli l\\u2019intento, poi nome, importo e mesi. Il giorno serve soltanto per il pagamento."]], ["Anticipa budget", ["250 \\u20AC su ottobre, recuperati da novembre e dicembre: ottobre +250 \\u20AC, novembre \\u2212125 \\u20AC, dicembre \\u2212125 \\u20AC. Il saldo non cambia. Non puoi cancellare solo le quote future mantenendo l\\u2019anticipo di un mese chiuso."]], ["Obiettivo finito", ["Distribuisci il totale sui mesi scelti. Quando paghi, confermi l\\u2019importo effettivo e chiudi le quote future. Le quote maturate restano nello storico.", "Previsti 600 \\u20AC, pagati 500 \\u20AC: il residuo rimane nei risparmi. Pagati 700 \\u20AC: puoi recuperare i soli 100 \\u20AC in pi\\xF9 nei budget futuri; altrimenti restano a carico dei risparmi."]], ["Fondo senza scadenza \\xB7 manutenzione auto", ["Scegli una quota mensile. Il fondo accumula nel tempo. Un pagamento riduce il fondo e il saldo una sola volta; il piano continua. Interrompi ferma le quote future senza generare una spesa e libera l\\u2019eventuale residuo nei risparmi generali."]], ["Affitto e utenze", ["Affitto: importo e periodicit\\xE0 fissi. Il pagamento chiude una scadenza, non il piano. Utenze: quota stimata dai pagamenti e dai mesi coperti. Una bolletta di 160 \\u20AC per due mesi vale 80 \\u20AC/mese. La media aggiorna soltanto le quote dal prossimo mese."]], ["Rateizza una spesa", ["Il pagamento \\xE8 una sola uscita dai risparmi. Nei mesi scelti riduci il budget per ricostituirli. Questo piano non ha un secondo pulsante Paga. Se la registrazione \\xE8 rimasta in sospeso, usa Completa questa registrazione, senza creare un altro pagamento."]], ["Piani precedenti e modifiche", ["Affitto, utenze e accantonamenti esistenti vengono adottati una sola volta, senza creare movimenti bancari n\\xE9 riscrivere i mesi chiusi. Il pagamento pu\\xF2 essere nuovo oppure collegato a una spesa gi\\xE0 registrata. Le modifiche alle quote decorrono da un mese futuro."]], ["Spesa rapida", ["Automatico applica le regole ordinarie. Da risparmi evita un nuovo addebito al budget. I piani, i recuperi e i pagamenti pianificati si gestiscono qui."]], ["Prima di confermare", ["Controlla l\\u2019anteprima mese per mese. Le quote sono esatte al centesimo. Un anticipo non \\xE8 un\\u2019entrata bancaria. Un piano interrotto non cancella pagamenti gi\\xE0 effettuati. L\\u2019adozione conserva le identit\\xE0 delle voci esistenti e sostituisce le loro quote dal mese corrente, senza duplicarle. Gli anticipi storici restano consultabili."]]];
      host.innerHTML = \`<div class="modal" role="dialog" aria-modal="true" aria-label="Come funzionano i piani"><div class="modal-top"><h2>Come funzionano i piani</h2><button data-plans-close aria-label="Chiudi">\\xD7</button></div>\${sections.map(([title, texts]) => \`<section class="os-task-section"><h3>\${safe(title)}</h3>\${texts.map((t) => \`<p>\${safe(t)}</p>\`).join("")}</section>\`).join("")}<button data-plans-close>Fine</button></div>\`;
      host.classList.remove("hidden");
      host.querySelector("button").focus();
    }
    document.addEventListener("click", (e) => {
      const b = e.target.closest("[data-plans-payment],[data-new-extra],[data-plans-pay],[data-plans-edit],[data-plans-stop],[data-plans-close],[data-plans-refresh],[data-plans-resume],[data-plans-info],[data-plans-detail],[data-plans-back],[data-plans-legacy]");
      if (!b) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      if (b.hasAttribute("data-plans-detail")) {
        activePlan = b.dataset.plansDetail;
        render();
      }
      if (b.hasAttribute("data-plans-back")) {
        activePlan = null;
        render();
      }
      if (b.hasAttribute("data-plans-legacy")) openExtraEdit(Number(b.dataset.plansLegacy));
      if (b.hasAttribute("data-plans-info")) showInfo();
      if (b.hasAttribute("data-new-extra")) {
        activePlan = null;
        openExtra();
      }
      if (b.hasAttribute("data-plans-close")) document.getElementById("dialog").classList.add("hidden");
      if (b.hasAttribute("data-plans-payment")) paymentDetail(b.dataset.plansPayment);
      if (b.hasAttribute("data-plans-pay")) pay(b.dataset.plansPay);
      if (b.hasAttribute("data-plans-edit")) edit(b.dataset.plansEdit);
      if (b.hasAttribute("data-plans-stop")) {
        const id = b.dataset.plansStop, p = plan(id);
        modal("Interrompi \\xB7 " + p.name, '<p class="full">Conserva i pagamenti e lo storico. Le quote successive al mese corrente si interrompono. Gli anticipi di mesi chiusi non possono essere annullati.</p>', "stopFinancePlan", () => ({ planId: id }));
      }
      if (b.hasAttribute("data-plans-resume")) modal("Riprendi pagamento", '<p class="full">Completa la conferma del movimento gi\\xE0 avviato, senza creare un secondo addebito.</p>', "resumeFinancePlanPayment", () => ({ paymentId: b.dataset.plansResume }));
      if (b.hasAttribute("data-plans-refresh")) load();
    }, true);
  })();
})();
<\/script><script>/* Shared controls retain browser/OS storage on their respective devices. */
(() => {
  const control=document.querySelector('.theme-toggle');
  function theme(value){
    try{if(value==='system')localStorage.removeItem('life-theme');else localStorage.setItem('life-theme',value);}catch{}
    document.documentElement.dataset.theme=value==='system'?(matchMedia('(prefers-color-scheme: light)').matches?'light':'dark'):value;
    document.querySelector('meta[name="theme-color"]').content=document.documentElement.dataset.theme==='light'?'#f3f3f5':'#0c0c0e';
  }
  const draw=()=>{control.textContent='\u2699\uFE0E';control.setAttribute('aria-label','Impostazioni');control.title='Impostazioni';};
  matchMedia('(prefers-color-scheme: light)').addEventListener('change',draw);draw();
  control.onclick=()=>{
    let selected='system';try{selected=localStorage.getItem('life-theme')||'system';}catch{}
    const local=globalThis.lifeOSLocalMode,mode=local?.mode||'server';
    const host=document.getElementById('dialog');
    host.innerHTML=\`<div class="modal" role="dialog" aria-modal="true" aria-label="Impostazioni"><div class="modal-top"><h2>Impostazioni</h2><button data-close aria-label="Chiudi">\xD7</button></div><section class="os-task-section"><h3>Aspetto</h3><label>Tema<select data-settings-theme>\${[['system','Automatico'],['light','Chiaro'],['dark','Scuro']].map(([key,label])=>\`<option value="\${key}" \${key===selected?'selected':''}>\${label}</option>\`).join('')}</select></label></section><section class="os-task-section"><h3>Modalit\xE0</h3><p>\${mode==='demo'?'Demo locale':mode==='snapshot'?'Snapshot locale':'Server collegato'}</p><button data-settings-demo \${mode==='demo'?'disabled':''}>Apri demo completa</button>\${mode!=='server'?'<button data-settings-restore>Torna ai dati precedenti</button>':'<button data-settings-disconnect>Scollega per consultare uno snapshot</button>'}<p class="hint">La demo contiene dati simulati. Non invia dati al server.</p></section><section class="os-task-section"><h3>Connessione Life OS</h3><label>Indirizzo del server<input data-settings-endpoint type="url" value="\${escapeHtml(location.origin)}" placeholder="https://lifeos-native-test.a-zeroual-it.workers.dev"></label><label class="settings-confirm"><input data-settings-confirm type="checkbox">Confermo l\u2019indirizzo del mio server Life OS</label><button data-settings-connect disabled>Collega</button><button data-settings-sync \${mode!=='server'?'disabled':''}>Sincronizza</button><a href="/login">Accedi</a><p role="status" aria-live="polite" data-settings-status></p></section><section class="os-task-section"><h3>Importazione e backup</h3><label>Importa snapshot JSON<input data-settings-import type="file" accept="application/json,.json" \${mode==='server'?'disabled':''}></label><button data-settings-paste \${mode==='server'?'disabled':''}>Incolla JSON</button><div class="hidden" data-settings-paste-area><label>Snapshot JSON<textarea name="snapshot" maxlength="5000000"></textarea></label><button data-settings-import-text>Importa snapshot</button></div><button data-settings-export>Esporta backup completo</button><p class="hint">Il backup contiene i dati gi\xE0 caricati su questo dispositivo. Le modifiche restano sullo stesso database usato dall\u2019app.</p></section><button data-close>Fine</button></div>\`;
    host.classList.remove('hidden');
    const report=error=>{host.querySelector('[data-settings-status]').textContent=error.message||String(error);};
    const connect=host.querySelector('[data-settings-connect]');host.querySelector('[data-settings-confirm]').onchange=e=>connect.disabled=!e.target.checked;
    connect.onclick=()=>{try{const url=new URL(host.querySelector('[data-settings-endpoint]').value.trim());if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash||url.pathname!=='/')throw Error('Inserisci l\u2019indirizzo HTTPS del server Life OS.');if((globalThis.lifeOSDeviceBackup?.().pending.length||0)&&url.origin!==location.origin)throw Error('Ci sono movimenti da conservare. Sincronizza prima di cambiare server.');if(url.origin===location.origin)local.server();else location.assign(url.origin);}catch(error){report(error);}};

    host.querySelector('[data-settings-demo]').onclick=()=>{if(confirm('Aprire la demo con dati simulati? I dati attuali verranno conservati separatamente.'))try{local.demo();}catch(error){report(error);}};
    host.querySelector('[data-settings-restore]')?.addEventListener('click',()=>{try{local.server();}catch(error){report(error);}});
    host.querySelector('[data-settings-disconnect]')?.addEventListener('click',()=>{try{local.disconnect();}catch(error){report(error);}});
    host.querySelector('[data-settings-paste]').onclick=()=>host.querySelector('[data-settings-paste-area]').classList.remove('hidden');
    const importText=text=>{if(text.length>5000000)throw Error('Il file \xE8 troppo grande.');local.import(JSON.parse(text));};
    host.querySelector('[data-settings-import-text]').onclick=()=>{try{importText(host.querySelector('[name=snapshot]').value);}catch(error){report(error);}};
    host.querySelector('[data-settings-import]').onchange=async e=>{try{const file=e.target.files[0];if(!file)return;if(file.size>5000000)throw Error('Il file \xE8 troppo grande.');importText(await file.text());}catch(error){report(error);}};
    host.querySelector('[data-settings-theme]').onchange=e=>{theme(e.target.value);draw();};
    host.querySelector('[data-settings-sync]').onclick=async e=>{
      const button=e.currentTarget,status=host.querySelector('[data-settings-status]');button.disabled=true;status.textContent='Aggiornamento\u2026';
      try{
        const d=await workerRequest('getFinanceOverview',[state.year,state.month],{fresh:true});
        const current=await workerRequest('getLifeData',[life.month],{fresh:true});
        state.data=d;state.loadedDetail=false;life.data=current;renderLifeOS();if(['overview','extras'].includes(state.view))render();else if(['budget','analysis','movements'].includes(state.view))load();
        const pending=globalThis.lifeOSDeviceBackup?.().pending.length||0;
        status.textContent=pending?\`\${pending} movimenti ancora in attesa di sincronizzazione.\`:'Aggiornamento completato.';
      }catch(error){status.textContent=error.message;}
      finally{button.disabled=false;}
    };
    host.querySelector('[data-settings-export]').onclick=()=>{
      const pending=(mode==='server'?(globalThis.lifeOSDeviceBackup?.().pending||[]):[]).map(w=>({id:w.id,method:'saveTransaction',payload:w.payload,accepted:false}));
      const current={...(local?.archive||{}),life:local?.archive?.life||life.data||{},finance:state.data||{},plan:state.data?.extraPlan||{},pending,demo:mode==='demo',imported:mode==='snapshot',financeMonth:\`\${state.year}-\${String(state.month).padStart(2,'0')}\`,calendarMonth:life.month,routineDay:life.data?.today||''};
      const blob=new Blob([JSON.stringify({format:'LifeOS-native-backup-v2',current,...(mode!=='server'&&local?.previousArchive?{previous:local.previousArchive}:{}),...(local?.rawArchive?{rawLocalArchive:local.rawArchive}:{}),...(globalThis.lifeOSDeviceBackup?.().rawArchive?{rawDeviceArchive:globalThis.lifeOSDeviceBackup().rawArchive}:{})},null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),link=document.createElement('a');
      link.href=url;link.download='LifeOS-backup-'+todayIso()+'.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
    };
  };
})();
<\/script><script>/* Same quick-movement contract as NativeStore: durable payload first, then sync. */
(() => {
  const transport=workerRequest,key='lifeos-web-device-v2';
  let device={pending:[],cache:{}},draining=null,offline=false,corrupt=false,lastFailure='';
  try{const saved=JSON.parse(localStorage.getItem(key)||'null');if(saved){if(!Array.isArray(saved.pending)||!saved.pending.every(w=>w&&typeof w.id==='string'&&w.payload&&w.payload.requestId===w.id)||!saved.cache||Array.isArray(saved.cache))throw Error('Archivio non valido.');device=saved;}}catch{corrupt=true;}
  const status=document.createElement('div');status.id='platform-sync-status';status.className='hint';status.setAttribute('role','status');document.getElementById('error').before(status);
  function persist(){
    if(corrupt)throw Error('Archivio locale non leggibile. I dati originali sono conservati.');
    // Remote read caches are replaceable; pending financial writes never are.
    while(true){
      try{localStorage.setItem(key,JSON.stringify(device));return;}
      catch(error){const oldest=Object.keys(device.cache)[0];if(error.name!=='QuotaExceededError'||!oldest)throw error;delete device.cache[oldest];}
    }
  }
  function draw(){status.textContent=corrupt?'Archivio locale non leggibile. I dati originali sono conservati.':device.pending.length?\`\${device.pending.length} movimenti salvati sul dispositivo. In attesa di sincronizzazione. Il saldo mostra l\u2019ultimo dato del server. \${lastFailure}\`:offline?'Dati locali \xB7 connessione non disponibile. Sincronizza per aggiornare.':'';}
  const cacheKey=(method,args)=>\`\${method}:\${JSON.stringify(args)}\`;
  async function drain(){
    if(globalThis.lifeOSLocalMode&&(globalThis.lifeOSLocalMode.mode!=='server'||!globalThis.lifeOSLocalMode.isValid))return;
    if(draining)return draining;
    draining=(async()=>{
      for(const write of [...device.pending]){
        try{
          const result=await transport('saveTransaction',[write.payload]);if(result!==true)throw Error('Movimento non confermato.');lastFailure='';
          const previous=device.pending;device.pending=device.pending.filter(p=>p.id!==write.id);
          try{persist();}catch(error){device.pending=previous;throw error;}
        }catch(error){lastFailure=String(error.message||error).slice(0,200);break;}
      }
      draw();
    })();
    try{await draining;}finally{draining=null;}
  }
  workerRequest=async function(method,args,{fresh=false}={}){
    if(method==='saveTransaction'){
      if(corrupt)throw Error('Archivio locale non leggibile. I dati originali sono conservati.');
      const payload=structuredClone(args[0]),id=payload.requestId||crypto.randomUUID();payload.requestId=id;
      const previous=device.pending.find(w=>w.id===id);
      if(previous&&JSON.stringify(previous.payload)!==JSON.stringify(payload))throw Error('Operazione gi\xE0 salvata con dati diversi. Sincronizza prima di riprovare.');
      if(!previous){device.pending.push({id,payload});try{persist();}catch(error){device.pending=device.pending.filter(w=>w.id!==id);throw Error('Impossibile conservare il movimento sul dispositivo. Nessuna richiesta inviata.');}}
      draw();await drain();return true;
    }
    const cached=['getFinanceOverview','getFinanceData','getLifeData'].includes(method),slot=cacheKey(method,args);
    if(cached&&device.pending.length)await drain();
    try{
      const result=await transport(method,args);
      if(cached){device.cache[slot]=result;try{persist();}catch{}offline=false;draw();}
      return result;
    }catch(error){
      // Never substitute a different month's data or an expired authorization.
      if(!fresh&&cached&&device.cache[slot]&&!/sessione|accedi/i.test(error.message)){
        offline=true;draw();return structuredClone(device.cache[slot]);
      }
      throw error;
    }
  };
  window.addEventListener('online',async()=>{if(globalThis.lifeOSLocalMode?.mode!=='server')return;await drain();if(state.data)load();});
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')drain();});
  globalThis.lifeOSDeviceBackup=()=>({...structuredClone(device),rawArchive:corrupt?localStorage.getItem(key):null});
  const movementRender=renderMovements;
  renderMovements=function(){
    movementRender();
    if(device.pending.length)document.getElementById('movements').insertAdjacentHTML('afterbegin',\`<section class="card pad"><h2>Salvati sul dispositivo</h2>\${device.pending.map(w=>\`<div class="kv"><span>\${escapeHtml(w.payload.name)}<small>In attesa di sincronizzazione</small></span><strong>\${state.assetsVisible?exactEuro(Number(w.payload.amount)):'\u2022\u2022\u2022\u2022'}</strong></div>\`).join('')}</section>\`);
  };
  draw();
})();
<\/script><script>(() => {
  // backend/worker/habits.mjs
  function validHabitDay(day2) {
    return typeof day2 === "string" && /^\\d{4}-\\d{2}-\\d{2}$/.test(day2) && Number.isFinite(Date.parse(day2 + "T12:00:00Z")) && (/* @__PURE__ */ new Date(day2 + "T12:00:00Z")).toISOString().slice(0, 10) === day2;
  }
  function habitSchedule(value) {
    if (value === void 0) return { mode: "daily", intervalDays: 1, weekdays: [], startDate: "" };
    if (!value || typeof value !== "object" || Array.isArray(value) || !["daily", "interval", "weekdays"].includes(value.mode)) throw Error("Ripetizione non valida.");
    const { mode } = value, startDate = value.startDate ?? "", intervalDays = value.intervalDays ?? 1, days = value.weekdays ?? [];
    if (startDate !== "" && !validHabitDay(startDate) || mode !== "daily" && !validHabitDay(startDate)) throw Error("Scegli una data di inizio valida.");
    if (mode === "interval" && (!Number.isInteger(intervalDays) || intervalDays < 1 || intervalDays > 365)) throw Error("Scegli un intervallo da 1 a 365 giorni.");
    if (mode === "weekdays" && (!Array.isArray(days) || !days.length || days.some((d) => !Number.isInteger(d) || d < 1 || d > 7))) throw Error("Scegli almeno un giorno della settimana.");
    return { mode, intervalDays: mode === "interval" ? intervalDays : 1, weekdays: mode === "weekdays" ? [...new Set(days)].sort((a, b) => a - b) : [], startDate };
  }
  function habitDue(routine, day2) {
    const s = habitSchedule(routine.schedule);
    if (!validHabitDay(day2) || s.startDate && day2 < s.startDate) return false;
    if (s.mode === "daily") return true;
    if (s.mode === "weekdays") return s.weekdays.includes(((/* @__PURE__ */ new Date(day2 + "T12:00:00Z")).getUTCDay() + 6) % 7 + 1);
    return Math.round((Date.parse(day2 + "T12:00:00Z") - Date.parse(s.startDate + "T12:00:00Z")) / 864e5) % s.intervalDays === 0;
  }

  // shared/demo-data.json
  var demo_data_default = {
    calendarMonth: "2026-10",
    demo: true,
    finance: {
      categories: [
        {
          amount: 12.34,
          name: "Alimentari"
        }
      ],
      forecastHistory: [
        {
          month: "2026-04",
          observed: true,
          ordinaryNet: 170
        },
        {
          month: "2026-05",
          observed: true,
          ordinaryNet: 155
        },
        {
          month: "2026-06",
          observed: true,
          ordinaryNet: 140
        },
        {
          month: "2026-07",
          observed: true,
          ordinaryNet: 125
        },
        {
          month: "2026-08",
          observed: true,
          ordinaryNet: 110
        },
        {
          month: "2026-09",
          observed: true,
          ordinaryNet: 95
        }
      ],
      history: [],
      lifetime: {
        series: [
          {
            month: "2026-04",
            observed: true,
            ordinaryNet: 170,
            wealth: 200
          },
          {
            month: "2026-05",
            observed: true,
            ordinaryNet: 155,
            wealth: 330
          },
          {
            month: "2026-06",
            observed: true,
            ordinaryNet: 140,
            wealth: 460
          },
          {
            month: "2026-07",
            observed: true,
            ordinaryNet: 125,
            wealth: 590
          },
          {
            month: "2026-08",
            observed: true,
            ordinaryNet: 110,
            wealth: 720
          },
          {
            month: "2026-09",
            observed: true,
            ordinaryNet: 95,
            wealth: 850
          }
        ]
      },
      planning: {
        goal: 3e3,
        monthlySaving: 150,
        now: 1e3,
        projection: 1450
      },
      recurring: [
        {
          estimate: 44,
          name: "Elettricit\\xE0",
          treatment: "Vincolata"
        },
        {
          estimate: 30,
          name: "Gas",
          treatment: "Vincolata"
        },
        {
          estimate: 20,
          name: "Acqua",
          treatment: "Vincolata"
        },
        {
          estimate: 25,
          name: "Condominio",
          treatment: "Vincolata"
        },
        {
          estimate: 33,
          name: "Palestra",
          treatment: "Vincolata"
        },
        {
          estimate: 13,
          name: "Abbonamenti",
          treatment: "Vincolata"
        },
        {
          estimate: 66,
          name: "Benzina",
          treatment: "Flessibile"
        }
      ],
      summary: {
        account: "Trade Republic",
        budget: 1e3,
        committedCurrent: 200,
        monthlyBudgetBreakdown: [
          {
            amount: 550,
            name: "Affitto"
          },
          {
            amount: 100,
            name: "Bollette e abbonamenti"
          },
          {
            amount: 200,
            name: "Accantonamenti"
          }
        ],
        monthlyCommitted: 850,
        monthlyRemaining: 837.66,
        monthlySalary: 1800,
        monthlySpent: 112.34,
        remainingFree: 800,
        revolutBalance: 0
      },
      transactions: [
        {
          account: "Trade Republic",
          amount: -12.34,
          category: "Alimentari",
          date: "2026-10-21",
          name: "Spesa alimentare",
          row: 2,
          type: "Spesa"
        },
        {
          account: "Trade Republic",
          amount: 1800,
          category: "Stipendio",
          date: "2026-10-20",
          name: "Stipendio demo",
          row: 3,
          type: "Entrata"
        }
      ],
      yearly: [
        {
          commitments: 850,
          income: 1800,
          month: "2026-01",
          spent: 723
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-02",
          spent: 746
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-03",
          spent: 769
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-04",
          spent: 792
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-05",
          spent: 815
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-06",
          spent: 838
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-07",
          spent: 861
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-08",
          spent: 884
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-09",
          spent: 907
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-10",
          spent: 930
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-11",
          spent: 953
        },
        {
          commitments: 850,
          income: 1800,
          month: "2026-12",
          spent: 976
        }
      ]
    },
    financeMonth: "2026-10",
    imported: false,
    life: {
      categories: [
        {
          key: "action",
          label: "Attivit\\xE0",
          position: 0
        },
        {
          key: "wish",
          label: "Desideri",
          position: 1
        },
        {
          key: "games",
          label: "Giochi",
          position: 2
        },
        {
          key: "reading",
          label: "Letture",
          position: 3
        }
      ],
      events: [
        {
          day: "2026-10-22",
          end_time: "19:00",
          frequency: "weekly",
          id: 1,
          location: "Palestra",
          notes: "",
          start_time: "18:00",
          title: "Allenamento"
        }
      ],
      month: "2026-10",
      occurrences: {},
      routines: [
        {
          checked: 0,
          id: 1,
          position: 0,
          title: "Leggere"
        },
        {
          checked: 0,
          id: 2,
          position: 1,
          title: "Camminare"
        }
      ],
      shifts: [
        {
          day: "2026-10-21",
          kind: "morning"
        },
        {
          day: "2026-10-22",
          kind: "rest"
        }
      ],
      tasks: [
        {
          id: 1,
          list_kind: "action",
          notes: "Esempio modificabile nella demo.",
          sort_order: 1,
          status: "todo",
          title: "Organizzare la settimana"
        },
        {
          id: 2,
          list_kind: "action",
          notes: "Esempio modificabile nella demo.",
          sort_order: 2,
          status: "todo",
          title: "Prenotare il controllo auto"
        },
        {
          id: 3,
          list_kind: "reading",
          notes: "Esempio modificabile nella demo.",
          sort_order: 3,
          status: "todo",
          title: "Finire il libro"
        }
      ],
      today: "2026-10-21"
    },
    pending: [],
    plan: {
      allocations: [
        {
          amount_cents: 5e3,
          cycle_id: 1,
          end_month: "2027-09",
          extraordinary_source_row: 2,
          kind: "expense",
          month: "2026-10",
          name: "Manutenzione auto",
          payment_account: "Trade Republic",
          repeat: "Annuale",
          start_month: "2026-10",
          status: "Programmato",
          total_cents: 6e4
        }
      ],
      links: []
    },
    refreshedAt: 8142811632316678e-7,
    routineDay: "2026-10-21"
  };

  // backend/plans/engine.mjs
  var PlanError = class extends Error {
    constructor(message, status = 422) {
      super(message);
      this.status = status;
    }
  };
  var fail = (message) => {
    throw new PlanError(message);
  };
  var kinds = ["advance", "goal", "fund", "fixed", "estimated", "recovery"];
  function month(value) {
    if (typeof value !== "string" || !/^20\\d\\d-(0[1-9]|1[0-2])$/.test(value)) fail("Scegli mese e anno validi.");
    return value;
  }
  function addMonth(value, count) {
    month(value);
    const [y, m] = value.split("-").map(Number), date = new Date(Date.UTC(y, m - 1 + count, 1));
    return date.toISOString().slice(0, 7);
  }
  function months(first, last, limit = 240) {
    month(first);
    month(last);
    if (last < first) fail("L\\u2019ultimo mese precede il primo.");
    const count = (Number(last.slice(0, 4)) - Number(first.slice(0, 4))) * 12 + Number(last.slice(-2)) - Number(first.slice(-2)) + 1;
    if (count > limit) fail("Il piano finito pu\\xF2 coprire al massimo 240 mesi; per un fondo usa Senza scadenza.");
    return Array.from({ length: count }, (_, i) => addMonth(first, i));
  }
  function cents(value) {
    if (!Number.isSafeInteger(value) || value <= 0 || value > 1e8) fail("Importo non valido.");
    return value;
  }
  function split(total, count) {
    cents(total);
    if (!Number.isInteger(count) || count < 1 || count > 240) fail("Numero di mesi non valido.");
    return Array.from({ length: count }, (_, i) => Math.floor(total / count) + (i < total % count ? 1 : 0));
  }
  function day(value, today) {
    if (typeof value !== "string" || !/^20\\d\\d-(0[1-9]|1[0-2])-\\d\\d$/.test(value)) fail("Data del pagamento non valida.");
    const parsed = /* @__PURE__ */ new Date(value + "T12:00:00Z");
    if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value || value > today) fail("La data deve essere valida e non futura.");
    return value;
  }
  function newPlan(input, today, id) {
    const kind = input.kind, current = month(today.slice(0, 7));
    if (!kinds.includes(kind)) fail("Scegli il tipo di piano.");
    const name = String(input.name ?? "").trim();
    if (!name || name.length > 120) fail("Inserisci un nome di massimo 120 caratteri.");
    const first = month(input.startMonth);
    if (first < current) fail("Le quote nuove possono iniziare dal mese corrente.");
    const finite = ["advance", "goal", "recovery"].includes(kind), last = finite ? month(input.endMonth) : null;
    const amount = cents(input.amountCents), interval = Number(input.intervalMonths ?? 1);
    const category = String(input.category ?? "Altro").trim();
    if (!category || category.length > 60) fail("Categoria non valida.");
    if (!Number.isInteger(interval) || interval < 1 || interval > 12) fail("Periodicit\\xE0 non valida.");
    if (finite) months(first, last);
    const plan = {
      id,
      name,
      category,
      kind,
      amountCents: amount,
      startMonth: first,
      endMonth: last,
      intervalMonths: interval,
      createdDay: today,
      status: "active",
      stopAfter: null,
      closedMonth: null,
      rateChanges: []
    };
    if (kind === "advance") {
      plan.beneficiaryMonth = month(input.beneficiaryMonth);
      if (plan.beneficiaryMonth < current || plan.beneficiaryMonth >= first) fail("Il mese beneficiario deve essere aperto e precedere i mesi di recupero.");
    }
    if (kind === "recovery") {
      plan.paymentDate = day(input.paymentDate, today);
      if (first < plan.paymentDate.slice(0, 7)) fail("Il recupero non pu\\xF2 precedere il pagamento.");
      plan.status = "pendingPayment";
    }
    return plan;
  }
  function contribution(plan, m) {
    month(m);
    if (plan.status === "cancelled" || plan.status === "pendingPayment") return 0;
    if (plan.kind === "advance") {
      if (m === plan.beneficiaryMonth) return -plan.amountCents;
    }
    if (m < plan.startMonth || plan.endMonth && m > plan.endMonth || plan.stopAfter && m > plan.stopAfter || plan.closedMonth && m > plan.closedMonth) return 0;
    if (plan.legacySchedule) return Number(plan.legacySchedule[m] ?? 0);
    if (["advance", "goal", "recovery"].includes(plan.kind)) {
      const range = months(plan.startMonth, plan.endMonth), i = range.indexOf(m);
      return i < 0 ? 0 : split(plan.amountCents, range.length)[i];
    }
    if (plan.kind === "fixed") {
      const anchor = plan.intervalAnchor ?? plan.startMonth;
      const delta = (Number(m.slice(0, 4)) - Number(anchor.slice(0, 4))) * 12 + Number(m.slice(-2)) - Number(anchor.slice(-2));
      let amount = plan.amountCents;
      for (const rate2 of plan.rateChanges ?? []) if (rate2.fromMonth <= m) amount = rate2.amountCents;
      return amount === 0 ? 0 : split(amount, plan.intervalMonths)[(delta % plan.intervalMonths + plan.intervalMonths) % plan.intervalMonths];
    }
    let rate = plan.amountCents;
    for (const change of plan.rateChanges ?? []) if (change.fromMonth <= m) rate = change.amountCents;
    return rate;
  }
  function adjustment(plans, m) {
    return -Object.values(plans).reduce((sum, p) => sum + contribution(p, m), 0) || 0;
  }
  function requestKey(value) {
    if (typeof value !== "string" || !/^[a-zA-Z0-9-]{8,80}$/.test(value)) fail("Identificatore operazione non valido.");
    return value;
  }
  function initialState() {
    return { version: 1, plans: {}, payments: {}, commands: {} };
  }
  function fingerprint(input) {
    return JSON.stringify(Object.fromEntries(Object.entries(input).filter(([k]) => k !== "requestId").sort(([a], [b]) => a.localeCompare(b))));
  }
  function command(state2, action, input, today) {
    const next = structuredClone(state2), key = requestKey(input.requestId), signature = fingerprint({ action, ...input });
    if (next.commands[key]) {
      if (next.commands[key].signature !== signature) fail("Questa operazione \\xE8 gi\\xE0 stata usata con dati diversi.");
      return { state: next, result: next.commands[key].result };
    }
    let result;
    if (action === "create") {
      const plan = newPlan(input, today, key);
      next.plans[key] = plan;
      if (plan.kind === "recovery") reservePayment(next, plan, { ...input, amountCents: plan.amountCents, date: plan.paymentDate }, today, key);
      result = { planId: key, paymentId: plan.kind === "recovery" ? key : null };
    } else {
      const plan = next.plans[input.planId];
      if (!plan) fail("Piano non trovato.");
      if (action === "pay") {
        if (["advance", "recovery"].includes(plan.kind)) fail("Questo piano non prevede un nuovo pagamento.");
        if (plan.status !== "active") fail("Il piano non \\xE8 attivo.");
        reservePayment(next, plan, input, today, key);
        result = { planId: plan.id, paymentId: key };
      } else if (action === "deletePayment") {
        const payment = next.payments[input.paymentId];
        if (!payment || payment.planId !== plan.id) fail("Pagamento non trovato.");
        if (!["posted", "deleting", "deleted"].includes(payment.status)) fail("Completa l\\u2019operazione in sospeso prima di eliminare il pagamento.");
        if (Object.values(next.payments).some((p) => p.id !== payment.id && p.status !== "deleted" && p.movementId === payment.movementId)) fail("Il movimento \\xE8 condiviso con un altro pagamento.");
        if (payment.status !== "deleted") payment.status = "deleting";
        result = { planId: plan.id, paymentId: payment.id };
      } else if (action === "edit") {
        if (plan.status !== "active" || ["advance", "recovery"].includes(plan.kind)) fail("Questo piano non \\xE8 modificabile.");
        const amount = plan.kind === "goal" ? cents(input.amountCents) : input.amountCents, first = month(input.fromMonth ?? addMonth(today.slice(0, 7), 1));
        if (!Number.isSafeInteger(amount) || amount < 0 || amount > 1e8) fail("Quota non valida.");
        if (first <= today.slice(0, 7) || first < plan.startMonth) fail("Le modifiche possono decorrere soltanto da un mese futuro del piano.");
        if (plan.kind === "goal") {
          const last = month(input.endMonth), future = months(first, last);
          const oldFuture = plan.endMonth >= first ? months(first, plan.endMonth).reduce((n, m) => n + contribution(plan, m), 0) : 0;
          const matured = plan.amountCents - oldFuture, rest = Math.max(0, amount - matured);
          const schedule = { ...plan.legacySchedule ?? Object.fromEntries(months(plan.startMonth, plan.endMonth).map((m) => [m, contribution(plan, m)])) };
          for (const m of Object.keys(schedule)) if (m >= first) delete schedule[m];
          const shares = rest ? split(rest, future.length) : future.map(() => 0);
          future.forEach((m, i) => schedule[m] = shares[i]);
          plan.legacySchedule = schedule;
          plan.endMonth = last;
          plan.amountCents = amount;
        } else {
          plan.rateChanges = (plan.rateChanges ?? []).filter((c) => c.fromMonth !== first);
          plan.rateChanges.push({ fromMonth: first, amountCents: amount });
          plan.rateChanges.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
        }
        result = { planId: plan.id };
      } else if (action === "stop") {
        if (plan.status !== "active") fail("Il piano non \\xE8 attivo.");
        if (Object.values(next.payments).some((p) => p.planId === plan.id && ["pending", "deleting"].includes(p.status))) fail("Completa il pagamento in sospeso prima di interrompere.");
        if (plan.kind === "advance") {
          if (plan.beneficiaryMonth < today.slice(0, 7)) fail("L\\u2019anticipo ha gi\\xE0 inciso su un mese chiuso: non puoi cancellarne solo il recupero.");
          plan.status = "cancelled";
        } else {
          plan.status = "stopped";
          plan.stopAfter = today.slice(0, 7);
        }
        result = { planId: plan.id };
      } else fail("Operazione sconosciuta.");
    }
    next.commands[key] = { signature, result };
    return { state: next, result };
  }
  function reservePayment(state2, plan, input, today, id) {
    const amount = cents(input.amountCents), date = day(input.date, today), covered = Number(input.competenceMonths ?? 1);
    if (!Number.isInteger(covered) || covered < 1 || covered > 12) fail("I mesi coperti devono essere tra 1 e 12.");
    const cycle = month(input.cycleMonth ?? date.slice(0, 7));
    if (cycle > today.slice(0, 7)) fail("Non puoi segnare pagata una scadenza futura.");
    if (["fixed", "estimated"].includes(plan.kind) && cycle < plan.startMonth) fail("La scadenza precede l\\u2019inizio del piano.");
    const settlement = ["goal", "recovery"].includes(plan.kind) ? "once" : ["fixed", "estimated"].includes(plan.kind) ? cycleKey(plan, cycle) : id;
    const existingMovementId = input.movementId === void 0 ? null : Number(input.movementId);
    if (existingMovementId !== null && (!Number.isSafeInteger(existingMovementId) || existingMovementId < 2)) fail("Movimento non valido.");
    if (existingMovementId && Object.values(state2.payments).some((p) => p.movementId === existingMovementId || p.existingMovementId === existingMovementId)) fail("Questo movimento \\xE8 gi\\xE0 collegato a un piano.");
    if (Object.values(state2.payments).some((p) => p.planId === plan.id && p.status !== "deleted" && p.settlementKey === settlement)) fail("Pagamento gi\\xE0 registrato o in completamento.");
    let recovery = null;
    if (input.recoverDifference) {
      if (plan.kind !== "goal" || amount + Object.values(state2.payments).filter((p) => p.planId === plan.id && p.status === "posted").reduce((n, p) => n + p.amountCents, 0) <= plan.amountCents) fail("Il recupero riguarda soltanto l\\u2019eccedenza di un obiettivo finito.");
      recovery = newPlan({
        kind: "goal",
        name: ("Recupero eccedenza \\xB7 " + plan.name).slice(0, 120),
        amountCents: amount + Object.values(state2.payments).filter((p) => p.planId === plan.id && p.status === "posted").reduce((n, p) => n + p.amountCents, 0) - plan.amountCents,
        startMonth: input.recoveryStartMonth,
        endMonth: input.recoveryEndMonth
      }, today, id + "-difference");
      recovery.kind = "recovery";
      recovery.sourcePaymentId = id;
    }
    state2.payments[id] = {
      id,
      planId: plan.id,
      settlementKey: settlement,
      status: "pending",
      amountCents: amount,
      date,
      cycleMonth: cycle,
      competenceMonths: covered,
      recovery,
      requestId: id,
      existingMovementId,
      cashName: input.originalName ? String(input.originalName).trim().slice(0, 120) : null
    };
  }
  function completePayment(state2, id, movementId, today) {
    const next = structuredClone(state2), payment = next.payments[id];
    if (!payment) fail("Pagamento non trovato.");
    if (["posted", "deleting", "deleted"].includes(payment.status)) return next;
    if (!Number.isSafeInteger(movementId) || movementId <= 0) fail("Il movimento bancario non \\xE8 stato confermato.");
    const plan = next.plans[payment.planId];
    payment.status = "posted";
    payment.movementId = movementId;
    if (plan.kind === "goal") {
      plan.status = "closed";
      plan.closedMonth = today.slice(0, 7);
    }
    if (plan.kind === "recovery") plan.status = "active";
    if (payment.recovery) next.plans[payment.recovery.id] = payment.recovery;
    if (plan.kind === "estimated") {
      const history = Object.values(next.payments).filter((p) => p.planId === plan.id && p.status === "posted").sort((a, b) => a.date.localeCompare(b.date)).slice(-12);
      const amount = Math.round(history.reduce((sum, p) => sum + p.amountCents, 0) / history.reduce((sum, p) => sum + p.competenceMonths, 0));
      const fromMonth = addMonth(today.slice(0, 7), 1);
      plan.rateChanges = (plan.rateChanges ?? []).filter((c) => c.fromMonth !== fromMonth);
      plan.rateChanges.push({ fromMonth, amountCents: Math.max(1, amount) });
      plan.rateChanges.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
    }
    return next;
  }
  function cycleKey(plan, cycle) {
    if (plan.kind !== "fixed" || plan.intervalMonths === 1) return cycle;
    const anchor = plan.intervalAnchor ?? plan.startMonth, delta = (Number(cycle.slice(0, 4)) - Number(anchor.slice(0, 4))) * 12 + Number(cycle.slice(-2)) - Number(anchor.slice(-2));
    return addMonth(anchor, Math.floor(delta / plan.intervalMonths) * plan.intervalMonths);
  }
  function completePaymentDeletion(state2, id, today) {
    const next = structuredClone(state2), payment = next.payments[id];
    if (!payment) fail("Pagamento non trovato.");
    if (payment.status === "deleted") return next;
    if (payment.status !== "deleting") fail("Eliminazione non avviata.");
    payment.status = "deleted";
    payment.deletedDay = today;
    const plan = next.plans[payment.planId];
    if (plan.kind === "goal" && plan.status === "closed") {
      plan.status = "active";
      plan.closedMonth = null;
    }
    if (plan.kind === "recovery") plan.status = "cancelled";
    for (const linked of Object.values(next.plans)) if (linked.sourcePaymentId === id) linked.status = "cancelled";
    if (plan.kind === "estimated") {
      const history = Object.values(next.payments).filter((p) => p.planId === plan.id && p.status === "posted").sort((a, b) => a.date.localeCompare(b.date)).slice(-12);
      const rate = history.length ? Math.max(1, Math.round(history.reduce((n, p) => n + p.amountCents, 0) / history.reduce((n, p) => n + p.competenceMonths, 0))) : plan.amountCents;
      const fromMonth = addMonth(today.slice(0, 7), 1);
      plan.rateChanges = (plan.rateChanges ?? []).filter((c) => c.fromMonth !== fromMonth);
      plan.rateChanges.push({ fromMonth, amountCents: rate });
      plan.rateChanges.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
    }
    return next;
  }
  function balance(state2, plan, throughMonth) {
    const last = throughMonth < plan.startMonth ? null : throughMonth;
    const saved = (throughMonth >= plan.startMonth ? Number(plan.openingBalanceCents ?? 0) : 0) + (last ? months(plan.startMonth, last, 1200).reduce((n, m) => n + Math.max(0, contribution(plan, m)), 0) : 0);
    const spent = Object.values(state2.payments).filter((p) => p.planId === plan.id && ["posted", "deleting"].includes(p.status) && p.date.slice(0, 7) <= throughMonth && p.date.slice(0, 7) >= plan.startMonth).reduce((n, p) => n + p.amountCents, 0);
    return { contributedCents: saved, paidCents: spent, fundCents: plan.status === "active" && !["advance", "recovery"].includes(plan.kind) ? Math.max(0, saved - spent) : 0, fromGeneralSavingsCents: Math.max(0, spent - saved) };
  }
  function project(state2, selectedMonth) {
    month(selectedMonth);
    return {
      version: 2,
      month: selectedMonth,
      adjustmentCents: adjustment(state2.plans, selectedMonth),
      plans: Object.values(state2.plans).map((p) => ({ ...p, outstandingCents: Math.max(0, p.amountCents - Object.values(state2.payments).filter((x) => x.planId === p.id && ["posted", "deleting"].includes(x.status)).reduce((n, x) => n + x.amountCents, 0)), contributionCents: contribution(p, selectedMonth), ...balance(state2, p, selectedMonth) })),
      payments: Object.values(state2.payments).filter((p) => p.status !== "deleted").map(({ recovery, ...p }) => p)
    };
  }

  // backend/plans/service.mjs
  var PlanService = class {
    constructor(repository, cash, today) {
      this.repository = repository;
      this.cash = cash;
      this.today = today;
    }
    async change(transform) {
      for (let attempt = 0; attempt < 5; attempt++) {
        const { revision, state: state2 } = await this.repository.read(), next = transform(state2);
        if (JSON.stringify(next.state) === JSON.stringify(state2)) return next.result;
        if (await this.repository.compareAndSet(revision, next.state)) return next.result;
      }
      throw new PlanError("Un altro dispositivo sta aggiornando i piani. Riprova.", 409);
    }
    async execute(action, input) {
      const result = await this.change((state2) => command(state2, action, input, this.today));
      if (result.paymentId) await this.finish(result.paymentId);
      return result;
    }
    async finish(paymentId) {
      const { state: state2 } = await this.repository.read(), p = state2.payments[paymentId];
      if (!p) throw new PlanError("Pagamento non trovato.", 404);
      if (["posted", "deleted"].includes(p.status)) return;
      if (p.status === "deleting") {
        await this.cash.remove(p);
        await this.change((current) => ({ state: completePaymentDeletion(current, paymentId, this.today), result: {} }));
        return;
      }
      const plan = state2.plans[p.planId];
      const movementId = await this.cash.record({
        requestId: p.requestId,
        name: p.cashName || plan.name,
        category: plan.category,
        amountCents: p.amountCents,
        date: p.date,
        competenceMonths: p.competenceMonths,
        planId: p.planId,
        existingMovementId: p.existingMovementId
      });
      await this.change((current) => ({ state: completePayment(current, paymentId, movementId, this.today), result: {} }));
    }
    async view(month2) {
      const { state: state2 } = await this.repository.read();
      return project(state2, month2);
    }
  };

  // backend/worker/events.mjs
  function expandEvents(rows, low, high) {
    const out = [];
    for (const ev of rows) {
      const start = ev.day, base = /* @__PURE__ */ new Date(start + "T12:00:00Z");
      for (let n = 0; n < 12e3; n++) {
        let day2 = start;
        if (n) {
          if (!ev.frequency || ev.frequency === "none") break;
          if (ev.frequency === "weekly")
            day2 = new Date(+base + n * 7 * 864e5).toISOString().slice(0, 10);
          else {
            const months2 = n * (ev.frequency === "yearly" ? 12 : 1), y = base.getUTCFullYear(), m = base.getUTCMonth() + months2, last = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
            day2 = new Date(Date.UTC(y, m, Math.min(base.getUTCDate(), last), 12)).toISOString().slice(0, 10);
          }
        }
        if (day2 >= high || ev.until_day && day2 > ev.until_day) break;
        if (day2 >= low) out.push({ ...ev, day: day2, series_day: start });
      }
    }
    return out.sort(
      (a, b) => a.day.localeCompare(b.day) || (a.start_time || "").localeCompare(b.start_time || "") || a.id - b.id
    );
  }

  // backend/worker/local-model.mjs
  var copy = structuredClone;
  var addDay = (value, n) => new Date(Date.parse(value + "T12:00:00Z") + n * 864e5).toISOString().slice(0, 10);
  var nextID = (rows, key = "id") => Math.max(0, ...rows.map((r) => Number(r[key]) || 0)) + 1;
  var title = (s) => {
    s = String(s || "").trim();
    if (!s || s.length > 160) throw Error("Inserisci un nome valido.");
    return s;
  };
  function demoArchive(today) {
    const source = demo_data_default.life.today, delta = Math.round((Date.parse(today) - Date.parse(source)) / 864e5), monthOffset = (Number(today.slice(0, 4)) - Number(source.slice(0, 4))) * 12 + Number(today.slice(5, 7)) - Number(source.slice(5, 7));
    function translate(value) {
      if (typeof value === "string" && /^20\\d\\d-\\d\\d-\\d\\d$/.test(value)) return addDay(value, delta);
      if (typeof value === "string" && /^20\\d\\d-\\d\\d$/.test(value)) return addMonth(value, monthOffset);
      if (Array.isArray(value)) return value.map(translate);
      if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, translate(v)]));
      return value;
    }
    const archive = translate(copy(demo_data_default));
    archive.finance.yearly = (archive.finance.yearly || []).map((row, i) => ({ ...row, month: today.slice(0, 4) + "-" + String(i + 1).padStart(2, "0") }));
    return { ...archive, demo: true, pending: [], routineDay: today };
  }
  function snapshotArchive(raw, fallbackMonth = (/* @__PURE__ */ new Date()).toLocaleDateString("sv-SE", { timeZone: "Europe/Rome" }).slice(0, 7)) {
    const finance = raw?.current?.finance || raw?.finance || raw;
    if (!finance || !finance.summary || !["budget", "committedCurrent", "remainingFree"].every((k) => Number.isFinite(finance.summary[k])) || !Array.isArray(finance.transactions)) throw Error("Snapshot finanziario non valido.");
    const ids = /* @__PURE__ */ new Set();
    for (const r of finance.transactions) {
      if (!Number.isFinite(r.amount) || !Number.isSafeInteger(r.row) || r.row <= 0 || ids.has(r.row) || typeof r.name !== "string" || !r.name) throw Error("Il JSON contiene un movimento non valido.");
      day(r.date, "2099-12-31");
      ids.add(r.row);
    }
    const dates = [...new Set(finance.transactions.map((r) => r.date.slice(0, 7)))];
    const candidate = finance.key || raw?.current?.financeMonth || raw?.financeMonth;
    const key = /^20\\d\\d-(0[1-9]|1[0-2])$/.test(candidate) ? candidate : dates.length === 1 ? dates[0] : fallbackMonth;
    month(key);
    return { finance: copy(finance), life: { today: key + "-01", categories: [{ key: "action", label: "Attivit\\xE0", position: 0 }], tasks: [], routines: [], shifts: [], events: [], occurrences: {} }, plan: copy(finance.extraPlan || {}), pending: [], demo: false, imported: true, financeMonth: key, calendarMonth: key };
  }
  var LocalModel = class {
    constructor(archive, today, persist = () => {
    }) {
      this.archive = copy(archive);
      this.today = today;
      this.persist = persist;
      this.planState = initialState();
      this.revision = 0;
    }
    save() {
      this.persist(this);
    }
    finance(selected) {
      const d = copy(this.archive.finance), v = project(this.planState, selected), current = project(this.planState, this.today.slice(0, 7));
      const s = d.summary;
      d.key = selected;
      d.year = Number(selected.slice(0, 4));
      d.month = Number(selected.slice(-2));
      d.updatedAt = "Demo locale";
      d.extraPlan = copy(this.archive.plan);
      d.plansV2 = v;
      s.monthlyRemaining = (s.monthlyRemaining || 0) + v.adjustmentCents / 100;
      s.monthlyCommitted = (s.monthlyCommitted || 0) - v.adjustmentCents / 100;
      s.committedCurrent += current.plans.reduce((n, p) => n + p.fundCents, 0) / 100;
      s.remainingFree = s.budget - s.committedCurrent;
      return d;
    }
    life(selected) {
      const d = copy(this.archive.life), low = addMonth(selected, -1) + "-01", high = addMonth(selected, 2) + "-01";
      const state2 = (e) => ({ ...e, occurrence_status: d.occurrences?.[\`\${e.id}:\${e.day}\`] || "open" });
      d.events = expandEvents(d.events || [], low, high).map(state2).filter((e) => e.occurrence_status !== "skipped");
      d.upcomingEvents = expandEvents(this.archive.life.events || [], this.today, addDay(this.today, 7)).map(state2).filter((e) => e.occurrence_status === "open");
      d.today = this.today;
      d.month = selected;
      if (this.archive.routineDay !== this.today) {
        for (const r of this.archive.life.routines || []) r.checked = 0;
        this.archive.routineDay = this.today;
        d.routines = copy(this.archive.life.routines);
        this.save();
      }
      d.routineScheduleVersion = 1;
      return d;
    }
    adjustMoney(next, old) {
      const s = this.archive.finance.summary, contribution2 = (r, account) => r?.account === account ? r.amount : 0;
      s.budget = Math.round((s.budget + contribution2(next, "Trade Republic") - contribution2(old, "Trade Republic")) * 100) / 100;
      s.remainingFree = s.budget - s.committedCurrent;
      s.revolutBalance = (s.revolutBalance || 0) + contribution2(next, "Revolut") - contribution2(old, "Revolut");
      const ordinary = (r) => r && ["Spesa", "Rimborso"].includes(r.type) && !["savings", "planned", "recovery"].includes(r.budgetTreatment) && r.date.slice(0, 7) === this.today.slice(0, 7) ? -r.amount : 0;
      const delta = ordinary(next) - ordinary(old);
      s.monthlySpent = (s.monthlySpent || 0) + delta;
      s.monthlyRemaining = (s.monthlyRemaining || 0) - delta;
    }
    movement(p, editing = false) {
      const rows = this.archive.finance.transactions;
      if (!editing && p.requestId) {
        const prior = rows.filter((r) => r.requestId === p.requestId).sort((a, b) => a.row - b.row)[0];
        if (prior) return prior.row;
      }
      const amount = Number(p.amount);
      if (!Number.isFinite(amount) || amount <= 0 || amount > 1e6 || Math.abs(amount * 100 - Math.round(amount * 100)) > 1e-6) throw Error("Importo non valido.");
      day(p.date, this.today);
      const name = title(p.name), type = p.type || "Spesa", account = p.account || "Trade Republic";
      const old = editing ? rows.find((r) => r.row === Number(p.row)) : null;
      if (editing && !old) throw Error("Movimento non trovato.");
      if (editing && Object.values(this.planState.payments).some((x) => x.movementId === old.row)) throw Error("Gestisci il pagamento dal piano collegato.");
      const signed = type === "Trasferimento" && old?.amount > 0 ? amount : ["Spesa", "Trasferimento"].includes(type) ? -amount : amount;
      const row = { ...p, row: old?.row || nextID(rows, "row"), amount: signed, name, type, account, months: Number(p.months) || 1 };
      if (type === "Trasferimento") {
        if (!p.counterpart || p.counterpart === account) throw Error("Scegli due conti diversi.");
        const pair = old?.transfer_id ? rows.find((r) => r.transfer_id === old.transfer_id && r.row !== old.row) : null;
        if (old && !pair) throw Error("Mantieni entrambi i conti del trasferimento.");
        row.transfer_id = old?.transfer_id || p.requestId || crypto.randomUUID();
        const other = { ...row, row: pair?.row || Math.max(nextID(rows, "row"), row.row + 1), amount: -signed, account: p.counterpart, counterpart: account, name: "Trasferimento da " + account };
        if (pair) rows[rows.indexOf(pair)] = other;
        else rows.push(other);
        this.adjustMoney(other, pair);
      }
      if (old) rows[rows.indexOf(old)] = row;
      else rows.push(row);
      this.adjustMoney(row, old);
      return row.row;
    }
    async request(method, args = []) {
      const p = args[0] || {}, id = Number(p.id ?? args[0]), life2 = this.archive.life, finance = this.archive.finance;
      const remove = (key) => life2[key] = life2[key].filter((r) => r.id !== id);
      const update = (key, value, identity = "id") => {
        const rows = life2[key], index = rows.findIndex((r) => r[identity] === value[identity]);
        if (index >= 0) rows[index] = { ...rows[index], ...value };
        else rows.push(value);
        return value;
      };
      if (method === "getLifeData") return this.life(args[0] || this.today.slice(0, 7));
      if (["getFinanceData", "getFinanceOverview", "getFinanceExtras"].includes(method)) return this.finance(\`\${args[0]}-\${String(args[1]).padStart(2, "0")}\`);
      if (method === "getFinancePlans") return project(this.planState, args[0] || this.today.slice(0, 7));
      if (method === "getExtraPlan") return copy(this.archive.plan);
      if (method === "getExtraCycleDetail") {
        const row = this.archive.plan.allocations?.find((r) => r.cycle_id === Number(args[0]));
        if (!row) throw Error("Piano non trovato.");
        return { ...copy(row), id: row.cycle_id, account: row.payment_account, links: copy((this.archive.plan.links || []).filter((l) => l.cycle_id === row.cycle_id)) };
      }
      if (method === "getMovement") {
        const r = finance.transactions.find((r2) => r2.row === Number(args[0]));
        if (!r) throw Error("Movimento non trovato.");
        return { ...copy(r), source_row: r.row, description: r.name, actual_date: r.date, movement_type: r.type, competence_months: r.months || 1, notes: r.note || "" };
      }
      if (method === "getFinancePlanMovements") return { movements: finance.transactions.filter((r) => r.amount < 0 && r.account === "Trade Republic" && r.date.startsWith(args[0]) && !Object.values(this.planState.payments).some((p2) => p2.movementId === r.row)).map((r) => ({ row: r.row, name: r.name, date: r.date, amountCents: Math.round(-r.amount * 100) })) };
      const actions = { saveFinancePlan: "create", recordFinancePlanPayment: "pay", editFinancePlan: "edit", stopFinancePlan: "stop" };
      if (actions[method] || method === "resumeFinancePlanPayment") {
        const repo = { read: async () => ({ revision: this.revision, state: copy(this.planState) }), compareAndSet: async (revision, state2) => {
          if (revision !== this.revision) return false;
          this.planState = state2;
          this.revision++;
          this.save();
          return true;
        } };
        const cash = { record: async (p2) => {
          if (p2.existingMovementId) {
            const row = finance.transactions.find((r) => r.row === p2.existingMovementId);
            if (!row || Math.round(-row.amount * 100) !== p2.amountCents || row.date !== p2.date) throw Error("Movimento non compatibile.");
            if (!["savings", "planned", "recovery"].includes(row.budgetTreatment)) this.adjustMoney({ ...row, budgetTreatment: "savings" }, row);
            row.budgetTreatment = "savings";
            this.save();
            return row.row;
          }
          const id2 = this.movement({ ...p2, type: "Spesa", amount: p2.amountCents / 100, budgetTreatment: "savings", account: "Trade Republic", months: p2.competenceMonths });
          this.save();
          return id2;
        } };
        const service = new PlanService(repo, cash, this.today);
        if (method === "resumeFinancePlanPayment") await service.finish(p.paymentId);
        else await service.execute(actions[method], p);
        return { ok: true };
      }
      let result = true;
      switch (method) {
        case "saveTask":
          result = update("tasks", { ...p, id: id || nextID(life2.tasks), title: title(p.title), status: life2.tasks.find((r) => r.id === id)?.status || "todo", sort_order: life2.tasks.find((r) => r.id === id)?.sort_order || nextID(life2.tasks, "sort_order") });
          break;
        case "setTaskStatus":
          if (!["todo", "waiting", "done"].includes(p.status)) throw Error("Stato non valido.");
          update("tasks", { ...life2.tasks.find((r) => r.id === id), id, status: p.status });
          break;
        case "deleteTask":
          remove("tasks");
          break;
        case "deleteCompletedTasks":
          life2.tasks = life2.tasks.filter((t) => t.list_kind !== p.category || t.status !== "done");
          break;
        case "reorderTasks":
          life2.tasks.forEach((t) => {
            const i = p.ids.indexOf(t.id);
            if (i >= 0) t.sort_order = i + 1;
          });
          break;
        case "addCategory": {
          const label = title(p.label);
          if (life2.categories.some((c) => c.label.toLowerCase() === label.toLowerCase())) throw Error("La categoria esiste gi\\xE0.");
          result = update("categories", { key: "custom-" + crypto.randomUUID(), label, position: life2.categories.length }, "key");
          break;
        }
        case "renameCategory":
          result = update("categories", { ...p, label: title(p.label) }, "key");
          break;
        case "reorderCategories":
          life2.categories.forEach((c) => c.position = p.keys.indexOf(c.key));
          break;
        case "deleteCategory":
          if (p.key === p.destination || !life2.categories.some((c) => c.key === p.destination)) throw Error("Scegli dove spostare le attivit\\xE0.");
          life2.categories = life2.categories.filter((c) => c.key !== p.key);
          life2.tasks.forEach((t) => {
            if (t.list_kind === p.key) t.list_kind = p.destination;
          });
          break;
        case "saveRoutine":
          if (!id && life2.routines.length >= 100) throw Error("Massimo 100 abitudini.");
          result = update("routines", { ...p, id: id || nextID(life2.routines), title: title(p.title), schedule: habitSchedule(p.schedule ?? life2.routines.find((r) => r.id === id)?.schedule), checked: life2.routines.find((r) => r.id === id)?.checked || 0 });
          break;
        case "deleteRoutine":
          remove("routines");
          break;
        case "setRoutineCheck":
          if (p.day !== this.today) throw Error("\\xC8 iniziato un nuovo giorno. Aggiorna le routine.");
          if (!life2.routines.some((r) => r.id === id)) throw Error("Abitudine non trovata.");
          if (p.checked && !habitDue(life2.routines.find((r) => r.id === id), this.today)) throw Error("Questa abitudine non \\xE8 prevista per oggi.");
          result = update("routines", { ...life2.routines.find((r) => r.id === id), id, checked: p.checked ? 1 : 0 });
          break;
        case "paintShift":
          life2.shifts = life2.shifts.filter((r) => r.day !== p.day);
          if (p.kind !== "erase") life2.shifts.push(p);
          break;
        case "saveEvent": {
          const old = life2.events.find((e) => e.id === id);
          if (old && (old.day !== p.day || old.frequency !== p.frequency) && Object.keys(life2.occurrences || {}).some((k) => k.startsWith(id + ":"))) throw Error("Usa Modifica da qui per preservare le occorrenze segnate.");
          result = update("events", { ...p, id: id || nextID(life2.events), title: title(p.title) });
          break;
        }
        case "splitEventSeries": {
          const old = life2.events.find((e) => e.id === id);
          if (!old) throw Error("Serie non trovata.");
          if (Object.keys(life2.occurrences || {}).some((k) => k.startsWith(id + ":") && k.slice(-10) >= p.split_from)) throw Error("Riapri prima le occorrenze future gi\\xE0 segnate.");
          old.until_day = addDay(p.split_from, -1);
          result = update("events", { ...p, id: nextID(life2.events), title: title(p.title) });
          break;
        }
        case "setEventOccurrence":
          life2.occurrences ??= {};
          if (p.status === "open") delete life2.occurrences[\`\${id}:\${p.day}\`];
          else life2.occurrences[\`\${id}:\${p.day}\`] = p.status;
          break;
        case "deleteEvent":
          remove("events");
          break;
        case "saveTransaction":
        case "editMovement":
          result = this.movement(p, method === "editMovement");
          break;
        case "deleteMovement": {
          const row = finance.transactions.find((r) => r.row === id);
          if (Object.values(this.planState.payments).some((p2) => p2.movementId === id)) throw Error("Gestisci il pagamento dal piano collegato.");
          const removed = finance.transactions.filter((r) => r.row === id || row?.transfer_id && r.transfer_id === row.transfer_id);
          finance.transactions = finance.transactions.filter((r) => !removed.includes(r));
          removed.forEach((r) => this.adjustMoney(null, r));
          break;
        }
        case "saveEstimate": {
          const row = finance.recurring.find((r) => r.name === args[0]);
          if (!row || Number(args[1]) <= 0) throw Error("Stima non valida.");
          row.estimate = Number(args[1]);
          break;
        }
        case "savePlanningSettings":
          if (args.some((n) => !Number.isFinite(Number(n))) || Number(args[0]) < 0 || Number(args[2]) <= 0) throw Error("Impostazioni non valide.");
          finance.planning = { ...finance.planning, goal: Number(args[0]), monthlySaving: Number(args[1]), savingsTarget: Number(args[2]) };
          break;
        case "updateExtraPlan": {
          const plan = this.archive.plan, old = plan.allocations.find((r) => r.cycle_id === Number(p.cycleId));
          if (!old) throw Error("Piano non trovato.");
          const range = months(p.month, p.endMonth, 60), cents2 = Math.round(Number(p.amount) * 100), shares = split(cents2, range.length), linked = (plan.links || []).filter((l) => l.cycle_id === old.cycle_id).reduce((n, l) => n + l.attributed_cents, 0);
          if (cents2 < linked) throw Error("Il piano non pu\\xF2 scendere sotto quanto gi\\xE0 attribuito.");
          plan.allocations = plan.allocations.filter((r) => r.cycle_id !== old.cycle_id);
          range.forEach((m, i) => plan.allocations.push({ ...old, name: title(p.name), month: m, start_month: p.month, end_month: p.endMonth, total_cents: cents2, amount_cents: shares[i], notes: p.note || "" }));
          break;
        }
        case "recordExtraPayment":
        case "markExtraPaid":
        case "cancelExtraCycle":
        case "deleteExtraPlan": {
          const plan = this.archive.plan, cycle = Number(p.cycleId), row = plan.allocations.find((r) => r.cycle_id === cycle);
          if (!row) throw Error("Piano non trovato.");
          if (method === "deleteExtraPlan") {
            if (row.status !== "Annullato" || (plan.links || []).some((l) => l.cycle_id === cycle)) throw Error("Annulla prima il piano e conserva i pagamenti collegati.");
            plan.allocations = plan.allocations.filter((r) => r.cycle_id !== cycle);
            break;
          }
          if (method === "recordExtraPayment" && row.status !== "Pagato") {
            const movement = this.movement({ ...p, requestId: p.requestId || "legacy-payment-" + cycle, type: "Spesa", name: p.name || row.name, category: "Straordinarie", budgetTreatment: "savings", account: "Trade Republic" }), actual = Math.round(Number(p.amount) * 100);
            plan.links ??= [];
            plan.settlements ??= [];
            plan.links.push({ cycle_id: cycle, movement_source_row: movement, attributed_cents: Math.min(actual, row.total_cents), role: "payment" });
            plan.settlements.push({ cycle_id: cycle, movement_source_row: movement, actual_cents: actual, planned_cents: row.total_cents });
          }
          plan.allocations.forEach((r) => {
            if (r.cycle_id === cycle) r.status = method === "cancelExtraCycle" ? "Annullato" : "Pagato";
          });
          break;
        }
        case "linkExtraMovement":
        case "unlinkExtraMovement": {
          const plan = this.archive.plan, cycle = Number(p.cycleId), movement = Number(p.movementId), row = plan.allocations.find((r) => r.cycle_id === cycle);
          if (!row) throw Error("Piano non trovato.");
          plan.links ??= [];
          if (method === "unlinkExtraMovement") plan.links = plan.links.filter((l) => l.cycle_id !== cycle || l.movement_source_row !== movement);
          else {
            const cash = finance.transactions.find((r) => r.row === movement), amount = Math.round(Number(p.amount) * 100), used = plan.links.filter((l) => l.movement_source_row === movement).reduce((n, l) => n + l.attributed_cents, 0), paid2 = plan.links.filter((l) => l.cycle_id === cycle).reduce((n, l) => n + l.attributed_cents, 0);
            if (!cash || cash.amount >= 0 || cash.budgetTreatment === "recovery" || ["Pagato", "Annullato"].includes(row.status) || amount <= 0 || amount + used > Math.round(-cash.amount * 100) || amount + paid2 > row.total_cents || plan.links.some((l) => l.cycle_id === cycle && l.movement_source_row === movement)) throw Error("Movimento o importo non compatibile con il piano.");
            plan.links.push({ cycle_id: cycle, movement_source_row: movement, attributed_cents: amount, role: "payment" });
          }
          const paid = plan.links.filter((l) => l.cycle_id === cycle).reduce((n, l) => n + l.attributed_cents, 0);
          plan.allocations.forEach((r) => {
            if (r.cycle_id === cycle) r.status = paid >= row.total_cents ? "Pagato" : "Programmato";
          });
          break;
        }
        default:
          throw Error("Questa azione richiede il server collegato.");
      }
      this.save();
      return copy(result);
    }
  };

  // backend/worker/local-web.js
  (() => {
    const key = "lifeos-web-local-v2", transport = workerRequest;
    let mode = "server", model = null, snapshot = null, previous = null, invalid = false;
    const status = document.createElement("p");
    status.className = "hint";
    status.id = "platform-local-status";
    status.setAttribute("role", "status");
    document.getElementById("error").before(status);
    function persist(value = model) {
      localStorage.setItem(key, JSON.stringify({ mode, archive: value?.archive || snapshot, planState: value?.planState, revision: value?.revision, previous }));
    }
    function restore(raw) {
      if (!raw || !["demo", "snapshot"].includes(raw.mode) || !raw.archive || !/^20\\d\\d-(0[1-9]|1[0-2])$/.test(raw.archive.financeMonth) || !["tasks", "categories", "routines", "events", "shifts"].every((k) => Array.isArray(raw.archive.life?.[k]))) throw Error("Archivio locale non valido.");
      snapshotArchive({ current: raw.archive });
      if (raw.revision !== void 0 && (!Number.isSafeInteger(raw.revision) || raw.revision < 0)) throw Error("Revisione archivio non valida.");
      if (raw.planState && (raw.planState.version !== 1 || !["plans", "payments", "commands"].every((k) => raw.planState[k] && typeof raw.planState[k] === "object" && !Array.isArray(raw.planState[k])))) throw Error("Archivio piani non valido.");
      mode = raw.mode;
      previous = raw.previous && Number.isInteger(raw.previous.year) && Number.isInteger(raw.previous.month) && raw.previous.month >= 1 && raw.previous.month <= 12 && /^20\\d\\d-(0[1-9]|1[0-2])$/.test(raw.previous.calendarMonth) ? raw.previous : null;
      if (mode === "demo") {
        model = new LocalModel(raw.archive, todayIso(), persist);
        if (raw.planState) model.planState = raw.planState;
        model.revision = raw.revision || 0;
      } else if (mode === "snapshot") snapshot = raw.archive;
      else throw Error("Modalit\\xE0 non valida.");
    }
    try {
      const raw = JSON.parse(localStorage.getItem(key) || "null");
      if (raw) restore(raw);
    } catch {
      invalid = true;
      status.textContent = "Archivio locale non leggibile. I dati originali sono conservati.";
    }
    function draw() {
      document.getElementById("platform-sync-status").hidden = mode !== "server";
      if (!invalid) status.textContent = mode === "demo" ? "Demo con dati simulati \\xB7 nessuna modifica al server." : mode === "snapshot" ? "Snapshot locale \\xB7 consultazione senza modificare il database." : "";
    }
    function connection() {
      const finance = state.data || life.finance || {}, pending = (globalThis.lifeOSDeviceBackup?.().pending || []).map((w) => ({ id: w.id, method: "saveTransaction", payload: w.payload, accepted: false }));
      return { year: state.year, month: state.month, calendarMonth: life.month, archive: { life: structuredClone(life.data || {}), finance: structuredClone(finance), plan: structuredClone(finance.extraPlan || {}), pending, demo: false, imported: false, endpoint: location.origin, financeMonth: finance.key || \`\${state.year}-\${String(state.month).padStart(2, "0")}\`, calendarMonth: life.month, routineDay: life.data?.today || todayIso() } };
    }
    function apply() {
      const archive = mode === "demo" ? model.archive : snapshot;
      if (archive) {
        const m = archive.financeMonth || todayIso().slice(0, 7);
        state.year = Number(m.slice(0, 4));
        state.month = Number(m.slice(-2));
        life.month = archive.calendarMonth || m;
      } else if (previous) {
        state.year = previous.year;
        state.month = previous.month;
        life.month = previous.calendarMonth;
      }
      const view = state.view;
      ++state.loadRevision;
      ++life.readRevision;
      life.homeFinanceRevision = (life.homeFinanceRevision || 0) + 1;
      state.data = null;
      state.loadedDetail = false;
      life.finance = null;
      life.data = null;
      life.selected = null;
      document.querySelectorAll(".view").forEach((element) => element.replaceChildren());
      closeDialog();
      draw();
      loadLifeOS();
      setView(view);
    }
    globalThis.lifeOSLocalMode = {
      get mode() {
        return mode;
      },
      get isValid() {
        return !invalid;
      },
      get previousArchive() {
        return previous?.archive ? structuredClone(previous.archive) : null;
      },
      get rawArchive() {
        return invalid ? localStorage.getItem(key) : null;
      },
      get archive() {
        return mode === "demo" ? structuredClone(model.archive) : mode === "snapshot" ? structuredClone(snapshot) : null;
      },
      demo() {
        if (state.busy || life.busy) throw Error("Attendi la fine dell\\u2019operazione in corso.");
        if (invalid) throw Error("Conserva prima l\\u2019archivio locale non leggibile.");
        if (mode === "demo") throw Error("La demo \\xE8 gi\\xE0 aperta. Le modifiche locali sono conservate.");
        const old = { mode, model, snapshot, previous };
        if (mode === "server") previous = connection();
        mode = "demo";
        model = new LocalModel(demoArchive(todayIso()), todayIso(), persist);
        try {
          persist();
        } catch (error) {
          ({ mode, model, snapshot, previous } = old);
          throw error;
        }
        apply();
      },
      import(raw) {
        if (mode === "server") throw Error("Scollega prima il server per importare uno snapshot locale.");
        const next = snapshotArchive(raw, snapshot?.financeMonth || \`\${state.year}-\${String(state.month).padStart(2, "0")}\`);
        const old = { mode, model, snapshot };
        mode = "snapshot";
        model = null;
        snapshot = next;
        try {
          persist();
        } catch (error) {
          ({ mode, model, snapshot } = old);
          throw error;
        }
        apply();
      },
      disconnect() {
        const finance = state.data || life.finance;
        if (!finance) throw Error("Carica prima uno snapshot da conservare.");
        const old = { mode, model, snapshot, previous };
        previous = connection();
        snapshot = snapshotArchive(finance);
        mode = "snapshot";
        model = null;
        try {
          persist();
        } catch (error) {
          ({ mode, model, snapshot, previous } = old);
          throw error;
        }
        apply();
      },
      server() {
        if (invalid) {
          const raw = localStorage.getItem(key);
          if (raw) localStorage.setItem(key + "-recovery-" + crypto.randomUUID(), raw);
        }
        localStorage.removeItem(key);
        mode = "server";
        model = null;
        snapshot = null;
        invalid = false;
        apply();
      }
    };
    workerRequest = async function(method, args = [], options) {
      if (invalid) throw Error("Archivio locale non leggibile. I dati originali sono conservati.");
      if (mode === "server") return transport(method, args, options);
      if (method === "getFinanceCategoryOptions") return [.../* @__PURE__ */ new Set([...lifeOSContract.expenseCategories, ...lifeOSContract.incomeCategories])];
      if (mode === "demo") {
        model.today = todayIso();
        try {
          return await model.request(method, args);
        } catch (error) {
          const raw = JSON.parse(localStorage.getItem(key));
          if (raw) restore(raw);
          throw error;
        }
      }
      if (method === "getLifeData") return { ...structuredClone(snapshot.life), today: todayIso(), month: args[0] };
      if (["getFinanceOverview", "getFinanceData", "getFinanceExtras"].includes(method)) {
        const m = \`\${args[0]}-\${String(args[1]).padStart(2, "0")}\`;
        if (m !== snapshot.financeMonth) throw Error("Questo mese non \\xE8 incluso nello snapshot. Collega Life OS per aggiornarlo.");
        return { ...structuredClone(snapshot.finance), key: m, year: Number(m.slice(0, 4)), month: Number(m.slice(-2)), extraPlan: structuredClone(snapshot.plan) };
      }
      if (method === "getFinancePlans" && snapshot.finance.plansV2) return structuredClone(snapshot.finance.plansV2);
      throw Error("Questo snapshot \\xE8 consultabile. Per modificare attivit\\xE0 e calendario usa la demo o collega Life OS.");
    };
    if (mode !== "server") {
      const archive = mode === "demo" ? model.archive : snapshot, m = archive.financeMonth || todayIso().slice(0, 7);
      state.year = Number(m.slice(0, 4));
      state.month = Number(m.slice(-2));
      life.month = archive.calendarMonth || m;
    }
    draw();
  })();
})();
<\/script><script>(() => {
  // backend/worker/weight-transfer.mjs
  var parts = (date) => Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Rome", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).formatToParts(date).filter((p) => p.type !== "literal").map((p) => [p.type, p.value]));
  function romeInput(date = /* @__PURE__ */ new Date()) {
    const p = parts(date);
    return \`\${p.year}-\${p.month}-\${p.day}T\${p.hour}:\${p.minute}\`;
  }
  function romeTimestamp(value) {
    if (!/^20\\d\\d-(0[1-9]|1[0-2])-\\d\\dT[0-2]\\d:[0-5]\\d$/.test(value)) throw Error("Data della pesata non valida.");
    const [y, m, d, h, n] = value.split(/[-T:]/).map(Number), naive = Date.UTC(y, m - 1, d, h, n);
    let guess = naive;
    for (let i = 0; i < 3; i++) {
      const p = parts(new Date(guess)), represented = Date.UTC(Number(p.year), Number(p.month) - 1, Number(p.day), Number(p.hour), Number(p.minute));
      guess -= represented - naive;
    }
    if (romeInput(new Date(guess)) !== value) throw Error("Questo orario non \\xE8 valido a Roma. Scegli un altro orario.");
    return guess;
  }
  function weightLink(kilograms, value, id, now = /* @__PURE__ */ new Date()) {
    const weight = Number(kilograms), at = romeTimestamp(value);
    if (!Number.isFinite(weight) || weight <= 0 || weight > 500 || at > now.getTime() || !/^\\p{ASCII_Hex_Digit}{8}-\\p{ASCII_Hex_Digit}{4}-\\p{ASCII_Hex_Digit}{4}-\\p{ASCII_Hex_Digit}{4}-\\p{ASCII_Hex_Digit}{12}$/u.test(id)) throw Error("Controlla peso e data della pesata.");
    const url = new URL("lifeos://weight");
    url.search = new URLSearchParams({ id, kg: String(weight), at: String(at) }).toString();
    return url.href;
  }

  // backend/worker/weight-web.js
  (() => {
    const renderHome = osToday;
    osToday = function() {
      const html = renderHome();
      return html.slice(0, -6) + \`<section class="os-card"><div class="card-title"><h2>Peso e calorie</h2><button data-web-weight aria-label="Aggiungi peso">+</button></div><p class="hint">La lettura di Apple Health \\xE8 disponibile nell\\u2019app. Puoi preparare una pesata da confermare su iPhone.</p></section></div>\`;
    };
    document.addEventListener("click", (e) => {
      if (!e.target.closest("[data-web-weight]")) return;
      const host = document.getElementById("life-dialog"), id = crypto.randomUUID();
      host.innerHTML = \`<div class="modal os-dialog" role="dialog" aria-modal="true" aria-label="Aggiungi peso"><div class="modal-top"><h2>Aggiungi peso</h2><button data-life-close aria-label="Chiudi">\\xD7</button></div><form id="web-weight-form" class="form-grid"><label>Peso in chilogrammi<input name="weight" type="number" min="0.001" max="500" step="any" required></label><label>Data \\xB7 Roma<input name="date" type="datetime-local" max="\${romeInput()}" value="\${romeInput()}" required></label><p class="hint full">La pesata viene salvata in Apple Health dopo la conferma nell\\u2019app Life OS su iPhone. Questi valori non vengono inviati al server.</p><p role="alert" class="os-form-error full"></p><div class="form-actions"><button type="button" data-life-close>Annulla</button><button type="submit">Continua nell\\u2019app</button></div><div class="full" data-weight-handoff></div></form></div>\`;
      host.classList.remove("hidden");
      const form = host.querySelector("form");
      let link = null;
      form.onsubmit = (e2) => {
        e2.preventDefault();
        if (!form.reportValidity()) return;
        try {
          link ??= weightLink(form.elements.weight.value, form.elements.date.value, id);
          form.elements.weight.readOnly = true;
          form.elements.date.readOnly = true;
          const target = form.querySelector("[data-weight-handoff]");
          target.replaceChildren();
          const anchor = document.createElement("a");
          anchor.href = link;
          anchor.textContent = "Apri Life OS su iPhone e conferma la pesata";
          anchor.className = "os-button";
          anchor.dataset.weightLink = "";
          target.append(anchor);
          const text = document.createElement("p");
          text.className = "hint";
          text.textContent = "Il salvataggio non \\xE8 ancora confermato. Apri il link con Life OS 0.9.5 o successivo e tocca Salva nell\\u2019app.";
          target.append(text);
        } catch (error) {
          form.querySelector("[role=alert]").textContent = error.message;
        }
      };
    });
  })();
})();
<\/script><script>window.dispatchEvent(new Event("lifeos-ready"));<\/script></body>
</html>
`;
function octoberAdvanceReconciliation(movements, month2, todayDay, grossAdvance, rules = {}) {
  const none = { returned: 0, covered: /* @__PURE__ */ new Set() }, cfg = rules.reconciliation;
  if (!cfg || month2 !== cfg.month || todayDay < cfg.day || grossAdvance < cfg.minimum) return none;
  const day2 = (r) => r[1] instanceof Date ? r[1].toISOString().slice(0, 10) : String(r[1] || "").slice(0, 10);
  const cents2 = (r) => Math.round(Number(r[3]) * 100);
  const leg = (account, amount) => movements.some((r) => day2(r) === cfg.day && r[4] === account && r[6] === "Trasferimento" && r[7] === "Eseguito" && cents2(r) === amount);
  if (!leg("Revolut", -cfg.returnedCents) || !leg("Trade Republic", cfg.returnedCents)) return none;
  const covered = /* @__PURE__ */ new Set();
  for (const [date2, amount, name] of cfg.reviewed) {
    const row = movements.find((r) => !covered.has(r) && day2(r) === date2 && r[4] === "Revolut" && r[6] === "Spesa" && r[7] === "Eseguito" && cents2(r) === -amount && String(r[2] || "").toLowerCase().includes(name));
    if (row) covered.add(row);
  }
  return { returned: cfg.returnedCents / 100, covered };
}
function utilityEstimates(recurring, movements, month2, todayDay, settings = {}) {
  const utilities = /* @__PURE__ */ new Set(["Elettricit\xE0", "Gas", "Acqua"]);
  const day2 = (r) => r[1] instanceof Date ? r[1].toISOString().slice(0, 10) : String(r[1] || "").slice(0, 10);
  return recurring.map((r) => {
    if (!utilities.has(r.name) && r.name !== "Condominio") return { ...r };
    const config = settings[r.name] || {}, changes = (config.changes || []).filter((x) => x.month <= month2).sort((a, b) => a.month.localeCompare(b.month));
    const manual = changes.at(-1), base = manual ? manual.value : config.base ?? r.estimate;
    const history = (r.name === "Condominio" ? [] : movements).filter((m) => m[5] === r.name && m[6] === "Spesa" && m[7] === "Eseguito" && Number(m[3]) < 0 && ["Revolut", "Trade Republic"].includes(m[4]) && day2(m) <= todayDay && day2(m).slice(0, 7) < month2 && (!manual || day2(m).slice(0, 7) >= manual.month)).sort((a, b) => day2(b).localeCompare(day2(a)) || Number(b[19]) - Number(a[19])).slice(0, 3);
    const months2 = history.reduce((n, m) => n + Math.max(1, Number(m[8]) || 1), 0);
    const estimate = history.length ? Math.round(history.reduce((n, m) => n - Number(m[3]), 0) / months2 * 100) / 100 : Number(base) || 0;
    return { ...r, estimate, estimateSource: history.length ? "Media ultime " + history.length + " bollette" : "Stima manuale", estimateSamples: history.length };
  });
}
function rentEstimate(configuredRent, month2, split2) {
  return split2 && month2 >= split2.fromMonth && Math.round(configuredRent * 100) === Math.round(split2.sourceAmount * 100) ? Number(split2.rent) : configuredRent;
}
var SAVINGS_CATEGORIES = ["Assicurazione", "Bollo", "Manutenzione auto", "Dentista", "Straordinarie"];
var budgetSchemaJobs = /* @__PURE__ */ new WeakMap();
async function ensureBudgetPolicies(env) {
  if (!budgetSchemaJobs.has(env.DB)) budgetSchemaJobs.set(env.DB, (async () => {
    if (await env.DB.prepare("SELECT value FROM os_meta WHERE key='budget_policies_ready_v2'").first()) return;
    await env.DB.batch([
      env.DB.prepare("CREATE TABLE IF NOT EXISTS movement_budget_policies(movement_source_row INTEGER PRIMARY KEY REFERENCES movements(source_row) ON DELETE CASCADE,treatment TEXT NOT NULL CHECK(treatment IN ('auto','ordinary','planned','savings','recovery')),recovery_json TEXT NOT NULL DEFAULT '[]')"),
      env.DB.prepare("CREATE TABLE IF NOT EXISTS finance_write_requests(id TEXT PRIMARY KEY,fingerprint TEXT NOT NULL)"),
      env.DB.prepare("CREATE TABLE IF NOT EXISTS finance_extra_requests(id TEXT PRIMARY KEY,source_row INTEGER NOT NULL,fingerprint TEXT NOT NULL)"),
      env.DB.prepare("CREATE TABLE IF NOT EXISTS extraordinary_settlements(cycle_id INTEGER PRIMARY KEY REFERENCES extraordinary_cycles(id) ON DELETE CASCADE,movement_source_row INTEGER NOT NULL REFERENCES movements(source_row) ON DELETE CASCADE,planned_cents INTEGER NOT NULL,actual_cents INTEGER NOT NULL)")
    ]);
    await env.DB.prepare("INSERT OR IGNORE INTO os_meta(key,value) VALUES ('budget_policies_ready_v2','1')").run();
  })());
  try {
    await budgetSchemaJobs.get(env.DB);
  } catch (error) {
    budgetSchemaJobs.delete(env.DB);
    throw error;
  }
}
function validatedBudgetPolicy(input, amount, day2, type) {
  const treatment = String(input.budgetTreatment || "auto");
  if (!["auto", "ordinary", "planned", "savings", "recovery"].includes(treatment)) throw Error("Trattamento budget non valido.");
  if (type !== "Spesa" && treatment !== "auto") throw Error("Il trattamento budget \xE8 disponibile solo per le spese.");
  if (treatment !== "recovery") return { treatment, recovery: [] };
  const raw = Array.isArray(input.recoveryMonths) ? input.recoveryMonths : String(input.recoveryMonths || "").split(",").map((v) => v.trim()).filter(Boolean);
  if (!raw.length || raw.length > 60 || new Set(raw).size !== raw.length || raw.some((m) => !/^20[2-3]\d-(0[1-9]|1[0-2])$/.test(m) || m < day2.slice(0, 7))) throw Error("Scegli da 1 a 60 mesi distinti, dalla data della spesa in avanti (AAAA-MM).");
  const months2 = [...raw].sort(), total = validCents(input.recoveryAmount === void 0 || input.recoveryAmount === null || input.recoveryAmount === "" ? amount : input.recoveryAmount);
  if (total > Math.round(amount * 100)) throw Error("Il recupero non pu\xF2 superare la spesa.");
  return { treatment, recovery: months2.map((month2, i) => ({ month: month2, amount_cents: Math.floor(total / months2.length) + (i < total % months2.length ? 1 : 0) })) };
}
function budgetPolicyStatement(env, row, policy) {
  return env.DB.prepare("INSERT INTO movement_budget_policies(movement_source_row,treatment,recovery_json) SELECT ?,?,? WHERE EXISTS(SELECT 1 FROM movements WHERE source_row=?) ON CONFLICT(movement_source_row) DO UPDATE SET treatment=excluded.treatment,recovery_json=excluded.recovery_json").bind(row, policy.treatment, JSON.stringify(policy.recovery), row);
}
function monthlyBudgetAmounts({ salary, rent, recurring, movements, month: month2, todayDay, extraPlan, extras, carFallback = 0, privateRules = {} }) {
  const round = (n) => Math.round((n + Number.EPSILON) * 100) / 100;
  salary = round(Number(salary) || 0);
  const monthOf = (v) => v instanceof Date ? v.toISOString().slice(0, 7) : String(v || "").slice(0, 7);
  const dateOf = (v) => v instanceof Date ? v.toISOString().slice(0, 10) : String(v || "").slice(0, 10);
  const fixed = new Map([["Affitto", round(Number(rent) || 0)], ...recurring.filter((r) => r.treatment === "Vincolata" && r.name !== "Benzina").map((r) => [r.name, round(Number(r.estimate) || 0)])]);
  const allocations = (extraPlan?.allocations || []).filter((a) => a.month === month2 && a.status !== "Annullato");
  const extraCommitted = extraPlan ? allocations.filter((a) => a.kind === "expense").reduce((n, a) => n + Number(a.amount_cents) / 100, 0) : extras.filter((e) => e.status !== "Annullato" && e.status !== "Previsto" && e.status !== "Anticipato" && e.start <= month2 && (e.repeat === "Annuale" || e.end >= month2)).reduce((n, e) => n + Number(e.quota || 0), 0) + carFallback;
  const grossAdvances = extraPlan ? allocations.filter((a) => a.kind === "budget_advance" && a.status === "Anticipato").reduce((n, a) => n + Number(a.amount_cents) / 100, 0) : extras.filter((e) => e.status === "Anticipato" && e.start <= month2 && e.end >= month2).reduce((n, e) => n + Number(e.quota || 0), 0);
  const reconciliation = octoberAdvanceReconciliation(movements, month2, todayDay, grossAdvances, privateRules);
  const advances = round(grossAdvances - reconciliation.returned);
  const linked = /* @__PURE__ */ new Map();
  for (const l of extraPlan?.links || []) if (l.role === "payment") linked.set(Number(l.movement_source_row), (linked.get(Number(l.movement_source_row)) || 0) + Number(l.attributed_cents || 0));
  const policies = new Map((extraPlan?.budgetPolicies || []).map((p) => [Number(p.movement_source_row), p]));
  const fixedPaid = /* @__PURE__ */ new Map();
  let freeCents = 0;
  for (const r of movements) {
    const amount = Number(r[3]) || 0, type = String(r[6]), category = String(r[5]), policy = policies.get(Number(r[19]));
    if (!["Revolut", "Trade Republic"].includes(String(r[4])) || r[7] !== "Eseguito" || dateOf(r[1]) > todayDay) continue;
    if (type !== "Spesa" && !(type === "Entrata" && /rimbors|refund|storno/i.test(category + " " + r[2]))) continue;
    if (reconciliation.covered.has(r)) continue;
    const mode = policy?.treatment || "auto";
    const covered = mode === "planned" || mode === "auto" && fixed.has(category);
    if (covered) {
      if (monthOf(r[1]) === month2) fixedPaid.set(category, (fixedPaid.get(category) || 0) - amount);
      continue;
    }
    if (mode === "savings" || mode === "recovery" || mode === "auto" && SAVINGS_CATEGORIES.includes(category)) continue;
    if (monthOf(r[1]) === month2) freeCents -= Math.round(amount * 100) + (amount < 0 ? Math.min(Math.round(-amount * 100), linked.get(Number(r[19])) || 0) : 0);
  }
  const settlements = [...fixedPaid].map(([name, paid]) => ({
    name,
    estimate: round(fixed.get(name) || 0),
    paid: round(paid),
    released: 0,
    excess: 0,
    savingsDifference: round(paid - (fixed.get(name) || 0))
  }));
  const recoveries = (extraPlan?.budgetPolicies || []).filter((p) => p.treatment === "recovery" && p.status === "Eseguito" && p.actual_date <= todayDay);
  const recoveryCents = recoveries.reduce((sum, p) => sum + (JSON.parse(p.recovery_json || "[]").find((q) => q.month === month2)?.amount_cents || 0), 0);
  const monthlyCommitted = round([...fixed.values()].reduce((n, v) => n + v, 0) + extraCommitted + advances + recoveryCents / 100);
  const monthlySpent = freeCents / 100;
  return {
    monthlySalary: round(salary),
    monthlyCommitted,
    monthlyAdvances: round(advances),
    monthlyAdvanceReturned: reconciliation.returned,
    monthlySpent,
    monthlyRemaining: round(salary - monthlyCommitted - monthlySpent),
    monthlyRecoveries: recoveryCents / 100,
    monthlyFixedSettlements: settlements,
    monthlyReleased: 0,
    monthlyAdvanceGross: round(grossAdvances),
    monthlyAdvanceCovered: round([...reconciliation.covered].reduce((n, r) => n - Number(r[3]), 0)),
    monthlyBudgetBreakdown: [
      ...[...fixed].filter(([, amount]) => amount !== 0).map(([name, amount]) => ({ name, amount: round(amount) })),
      { name: "Accantonamenti e straordinarie", amount: round(extraCommitted) },
      { name: "Anticipo netto", amount: round(advances) },
      ...recoveries.flatMap((p) => JSON.parse(p.recovery_json || "[]").filter((q) => q.month === month2).map((q) => ({ name: "Recupero \xB7 " + p.description, amount: q.amount_cents / 100 })))
    ]
  };
}
function computeFinance(book, year, month2, extraPlan, bankSnapshots = [], bankEvents = [], lightweight = false, privateRules = {}) {
  const TZ = "Europe/Rome";
  const APP_VERSION = "2026.10.09.os.11.63";
  const romeFormatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  });
  const Utilities = {
    formatDate(date2, timezone, pattern) {
      const bits = Object.fromEntries(
        romeFormatter.formatToParts(date2).filter((x) => x.type !== "literal").map((x) => [x.type, x.value])
      );
      return pattern.replace(
        /yyyy|MM|dd|HH|mm|M/g,
        (x) => ({
          yyyy: bits.year,
          MM: bits.month,
          dd: bits.day,
          HH: bits.hour,
          mm: bits.minute,
          M: String(Number(bits.month))
        })[x]
      );
    }
  };
  const now = /* @__PURE__ */ new Date();
  year = boundedInteger_(
    year,
    2024,
    2035,
    Number(Utilities.formatDate(now, TZ, "yyyy"))
  );
  month2 = boundedInteger_(
    month2,
    1,
    12,
    Number(Utilities.formatDate(now, TZ, "M"))
  );
  const budget = book.getSheetByName("Budget").getRange("A1:O24").getValues();
  const assets = book.getSheetByName("Patrimonio").getRange("A1:H10").getValues();
  const extrasRows = book.getSheetByName("Straordinarie").getRange("A1:K500").getValues();
  const trProof = book.getSheetByName("Estratto TR verificato").getRange("A1:A1").getValues()[0][0] || null;
  const payslipRows = book.getSheetByName("Cedolini").getRange("A1:N500").getValues();
  const payrollRows = book.getSheetByName("Riconciliazione stipendi").getRange("A2:H100").getValues();
  const recurringRows = book.getSheetByName("Storico ricorrenti").getRange("A2:E200").getValues();
  const balanceRow = book.getSheetByName("Saldi operativi").getRange("A2:D2").getValues()[0];
  const assetHistoryRows = book.getSheetByName("Storico patrimonio").getRange("A2:D500").getValues();
  const sheet = book.getSheetByName("Movimenti");
  const movements = sheet.getRange(2, 1, Math.max(1, sheet.getLastRow() - 1), 23).getValues();
  const key = ym_(year, month2);
  const todayDay = Utilities.formatDate(now, TZ, "yyyy-MM-dd");
  const extras = extrasRows.slice(1).map((r, i) => ({ r, row: i + 2 })).filter((x) => x.r[0]).map(({ r, row }) => ({
    row,
    name: String(r[0]),
    total: number_(r[1]),
    start: monthOf_(r[2]),
    months: number_(r[3]),
    quota: number_(r[4]),
    end: monthOf_(r[5]),
    status: String(r[6] || ""),
    account: String(r[7] || ""),
    paidAt: monthOf_(r[8]),
    note: String(r[9] || ""),
    repeat: String(r[10] || "No")
  }));
  let salary = number_(budget[1][14]);
  let salaryWindow = null;
  const rent = rentEstimate(number_(budget[2][14]), key, extraPlan?.rentSplit);
  const car = number_(budget[3][14]);
  let revolut = number_(budget[5][14]);
  const utilitySettings = book.getSheetByName("Stime utenze").getRange("A1:A1").getValues()[0][0] || {};
  const baseRecurring = budget.slice(1, 7).map((r) => ({
    name: String(r[0]),
    estimate: number_(r[1]),
    treatment: String(r[2])
  }));
  if (extraPlan?.condominiumSettings) {
    baseRecurring.push({ name: "Condominio", estimate: 0, treatment: "Vincolata" });
    utilitySettings.Condominio = extraPlan.condominiumSettings;
  }
  const nextUtilityMonth = new Date(Date.UTC(year, month2, 1)).toISOString().slice(0, 7);
  const nextUtilityEstimates = utilityEstimates(baseRecurring, movements, nextUtilityMonth, todayDay, utilitySettings);
  const recurring = utilityEstimates(baseRecurring, movements, key, todayDay, utilitySettings).map((r) => ({
    ...r,
    nextEstimate: r.estimateSource ? nextUtilityEstimates.find((x) => x.name === r.name)?.estimate : void 0
  }));
  const reserved = recurring.filter((r) => r.treatment === "Vincolata").reduce((sum, r) => sum + r.estimate, 0);
  let baseFree = revolut - reserved;
  const annualCostDefaults = budget.slice(2, 5).map((r) => ({
    name: String(r[7]),
    monthly: number_(r[8]),
    yearly: number_(r[9])
  }));
  const yearly = Array.from({ length: 12 }, (_, i) => ({
    budgetCommitments: 0,
    monthlyRemaining: 0,
    month: ym_(year, i + 1),
    income: 0,
    incomePayslip: 0,
    spent: 0,
    commitments: 0,
    spendable: baseFree,
    hasRecords: false,
    carCommitments: 0,
    otherCommitments: 0,
    advanceOffset: 0,
    grossAdvanceOffset: 0,
    extraCommitments: 0,
    net: 0
  }));
  function isSalaryMovement(r) {
    const text = [r[2], r[11], r[12]].join(" ").toLowerCase().replace(/[^a-z0-9]/g, "");
    return new RegExp(privateRules.salaryPattern || "stipendio", "i").test(text) || ["Reddito", "Stipendio"].includes(String(r[5]));
  }
  const categories = {};
  const incomeSources = {};
  const monthlyCategories = Object.fromEntries(
    yearly.map((y) => [y.month, {}])
  );
  const selectedTransactions = [];
  const candidates = [];
  let pending = 0, unmatched = 0, funded = 0, prepaid = 0, futureFunded = 0;
  const fundedRows = /* @__PURE__ */ new Set();
  const today = Utilities.formatDate(now, TZ, "yyyy-MM");
  const balanceDate = dateIso_(balanceRow[2]);
  const balanceAt = (account, day2) => {
    if (day2 > todayDay) return null;
    const anchor = bankSnapshots.filter((s) => s.account === account && s.as_of_day <= day2).sort((a, b) => a.as_of_day.localeCompare(b.as_of_day) || a.id - b.id).at(-1);
    if (!anchor) {
      if (account === "Trade Republic" && trProof && !trProof.conflicts?.length && day2 >= trProof.from)
        return Math.round(
          movements.filter(
            (r) => String(r[4]) === account && String(r[7]) === "Eseguito" && dateIso_(r[1]) >= trProof.from && dateIso_(r[1]) <= day2
          ).reduce(
            (n, r) => n + Math.round(number_(r[3]) * 100),
            trProof.opening
          )
        ) / 100;
      return null;
    }
    const cents2 = bankEvents.filter(
      (e) => e.account === account && e.id > anchor.event_watermark && e.day <= day2 && !(e.absorbed_snapshot_id && anchor.id >= e.absorbed_snapshot_id)
    ).reduce((sum, e) => sum + e.delta_cents, anchor.amount_cents);
    return Math.round(cents2) / 100;
  };
  const currentRevolut = balanceAt("Revolut", todayDay) ?? number_(balanceRow[1]);
  const currentAssets = balanceAt("Trade Republic", todayDay) ?? number_(assets[1][1]);
  const monthEnd = new Date(Date.UTC(year, month2, 0)).toISOString().slice(0, 10);
  const selectedDay = monthEnd > todayDay ? key === today ? todayDay : null : monthEnd;
  for (let movementIndex = 0; movementIndex < movements.length; movementIndex++) {
    const row = movements[movementIndex];
    if (!row[2]) continue;
    const actual = monthOf_(row[1]);
    const competence = monthOf_(row[15]) || monthOf_(row[0]);
    const amount = number_(row[3]);
    const account = String(row[4] || "");
    const category = String(row[5] || "Altro");
    const type = String(row[6] || "");
    const status = String(row[7] || "");
    const counterpart = String(row[10] || "");
    if (type === "Da verificare") pending++;
    if (type === "Trasferimento" && (!counterpart || counterpart === "Altro"))
      unmatched++;
    if (status === "Eseguito" && type === "Trasferimento" && account === "Trade Republic" && counterpart === "Revolut" && amount < 0) {
      if (competence === key) {
        funded -= amount;
        fundedRows.add(number_(row[19]));
        if (actual && actual < key) prepaid -= amount;
      }
      if (actual === key && competence && competence > key)
        futureFunded -= amount;
    }
    const cashflowMonth = actual || String(row[20] || "");
    if (["Trade Republic", "Revolut"].includes(account) && cashflowMonth && cashflowMonth.slice(0, 4) === String(year) && status === "Eseguito") {
      const m = Number(cashflowMonth.slice(5, 7)) - 1;
      if ((type === "Entrata" || isSalaryMovement(row)) && amount > 0) {
        yearly[m].income += amount;
        yearly[m].hasRecords = true;
        const salaryMovement = isSalaryMovement(row);
        const source = salaryMovement ? "Stipendio" : /interessi/i.test(category) ? "Interessi" : /rimbors/i.test(category) ? "Rimborsi" : "Altre entrate";
        incomeSources[source] = (incomeSources[source] || 0) + amount;
      }
      if (type === "Spesa" && amount < 0) {
        yearly[m].spent -= amount;
        yearly[m].hasRecords = true;
        const flowCategory = normalizedCategory(row);
        monthlyCategories[cashflowMonth][flowCategory] = (monthlyCategories[cashflowMonth][flowCategory] || 0) - amount;
        if (cashflowMonth === key)
          categories[flowCategory] = (categories[flowCategory] || 0) - amount;
      }
    }
    if (status === "Eseguito" && type === "Spesa" && amount <= -180 && actual && actual.slice(0, 4) === String(year) && !(String(row[9]) === "S\xEC" && number_(row[8]) > 1) && !/prestito a yousra/i.test(String(row[11] || "")) && !/AUTOSERVICE MB|KLARNA|SWAPPIE/i.test(String(row[2])) && !/^(Affitto|Utenze|Palestra|Abbonamenti)$/i.test(category)) {
      const importId = String(row[14] || "");
      const registeredExtra = extras.some(
        (e) => e.status !== "Annullato" && (importId && e.note.includes(importId) || e.total === -amount && e.start === actual && String(row[2]).length >= 5 && e.name.toLowerCase().includes(String(row[2]).toLowerCase()))
      );
      if (!registeredExtra)
        candidates.push({
          date: dateIso_(row[1]),
          name: String(row[2]),
          amount: -amount,
          category,
          account
        });
    }
    if (actual === key && status === "Eseguito") {
      selectedTransactions.push({
        row: number_(row[19]),
        date: dateIso_(row[1]),
        name: String(row[2]),
        amount,
        account,
        category,
        displayCategory: normalizedCategory(row),
        type,
        status,
        counterpart
      });
    }
  }
  const payroll = payrollRows.filter((r) => r[0] instanceof Date).map((r) => ({
    month: monthOf_(r[0]),
    competence: String(r[1]),
    amount: number_(r[2]),
    bank: number_(r[3]),
    internal: number_(r[4]),
    status: String(r[5]),
    source: String(r[6]),
    note: String(r[7])
  }));
  const creditedSalary = /* @__PURE__ */ new Map();
  for (const row of movements) {
    if (String(row[4]) !== "Trade Republic" || String(row[7]) !== "Eseguito" || String(row[6]) !== "Entrata" && !isSalaryMovement(row) || number_(row[3]) <= 0)
      continue;
    if (!isSalaryMovement(row)) continue;
    const creditMonth = monthOf_(row[1]);
    if (creditMonth)
      creditedSalary.set(
        creditMonth,
        (creditedSalary.get(creditMonth) || 0) + number_(row[3])
      );
  }
  for (const item of payroll) {
    if (item.status === "Ricostruito" && !creditedSalary.has(item.month) && item.amount > 0)
      creditedSalary.set(item.month, item.amount);
  }
  const latestMonth = today < key ? today : key;
  const salaryMonths = Array.from({ length: 12 }, (_, i) => {
    const d = new Date(
      Date.UTC(
        Number(latestMonth.slice(0, 4)),
        Number(latestMonth.slice(5, 7)) - i - 1,
        1
      )
    );
    return d.toISOString().slice(0, 7);
  });
  if (salaryMonths.every((m) => creditedSalary.has(m))) {
    salary = Math.round(
      salaryMonths.reduce((sum, m) => sum + creditedSalary.get(m), 0) / 12 * 100
    ) / 100;
    salaryWindow = {
      from: salaryMonths[11],
      to: salaryMonths[0],
      months: 12,
      source: "accrediti e cedolini ricostruiti"
    };
  }
  const isAutoReserve = (e) => e.repeat === "Annuale" && /^(Assicurazione auto|Bollo auto|Manutenzione auto)\b/i.test(e.name);
  const planMonth = (monthKey) => (extraPlan?.allocations || []).filter(
    (a) => a.month === monthKey && a.status !== "Annullato" && !(a.status === "Pagato" && a.paid_date && monthKey <= String(a.paid_date).slice(0, 7))
  );
  const planAuto = (a) => /^(Assicurazione auto|Bollo auto|Manutenzione auto)\b/i.test(a.name);
  const hasAutoSchedule = extras.some(isAutoReserve);
  const activeExtras = (item) => extras.filter(
    (e) => (e.status === "Programmato" || e.status === "Anticipato") && e.start && e.start <= item.month && (e.repeat === "Annuale" || e.end >= item.month)
  );
  for (const item of yearly) {
    const active2 = activeExtras(item), monthly = planMonth(item.month);
    item.carCommitments = extraPlan ? monthly.filter((a) => a.kind === "expense" && planAuto(a)).reduce((sum, a) => sum + a.amount_cents / 100, 0) : hasAutoSchedule ? active2.filter(isAutoReserve).reduce((sum, e) => sum + e.quota, 0) : car;
    item.otherCommitments = extraPlan ? monthly.filter((a) => a.kind === "expense" && !planAuto(a)).reduce((sum, a) => sum + a.amount_cents / 100, 0) : active2.filter((e) => !isAutoReserve(e)).reduce((sum, e) => sum + e.quota, 0);
    item.advanceOffset = extraPlan ? monthly.filter(
      (a) => a.kind === "budget_advance" && a.status === "Anticipato"
    ).reduce((sum, a) => sum + a.amount_cents / 100, 0) : 0;
    item.grossAdvanceOffset = item.advanceOffset;
    item.advanceOffset -= octoberAdvanceReconciliation(movements, item.month, todayDay, item.advanceOffset, privateRules).returned;
    item.extraCommitments = item.carCommitments + item.otherCommitments;
    item.commitments = rent + item.carCommitments + utilityEstimates(baseRecurring, movements, item.month, todayDay, utilitySettings).filter((r) => r.treatment === "Vincolata").reduce((n, r) => n + r.estimate, 0) + item.otherCommitments;
    item.spendable = salary - item.commitments - item.advanceOffset;
    item.net = item.income - item.spent;
  }
  selectedTransactions.sort((a, b) => b.date.localeCompare(a.date));
  const absorbedNow = extras.filter((e) => e.status === "Anticipato" && e.start === key).reduce((sum, e) => sum + e.total, 0);
  const absorbedFuture = extras.filter((e) => e.status === "Anticipato" && e.start > key).reduce((sum, e) => sum + e.total, 0);
  const allowedRecurring = [
    "Elettricit\xE0",
    "Gas",
    "Acqua",
    "Palestra",
    "Abbonamenti",
    "Benzina"
  ];
  const bankHistory = movements.filter(
    (r) => r[1] instanceof Date && r[6] === "Spesa" && r[7] === "Eseguito" && allowedRecurring.includes(String(r[5])) && number_(r[3]) < 0
  ).map((r) => ({
    date: dateIso_(r[1]),
    name: String(r[5]),
    paid: -number_(r[3]),
    note: String(r[11] || ""),
    months: Math.max(1, number_(r[8]))
  }));
  const welfare = recurringRows.filter((r) => String(r[1]) === "Benzina welfare").map((r) => ({
    date: dateIso_(r[0]),
    name: "Benzina welfare",
    paid: number_(r[2]),
    note: String(r[3] || ""),
    months: 0
  }));
  const history = bankHistory.concat(welfare).sort((a, b) => b.date.localeCompare(a.date));
  const averages = recurring.map((r) => {
    const rows = bankHistory.filter((h) => h.name === r.name);
    return {
      name: r.name,
      count: rows.length,
      mean: rows.length ? rows.reduce((sum, h) => sum + h.paid, 0) / rows.reduce((sum, h) => sum + h.months, 0) : null
    };
  });
  const selected = yearly[month2 - 1];
  revolut = salary - rent - selected.carCommitments - selected.otherCommitments - selected.advanceOffset;
  baseFree = revolut - reserved;
  const advanceFundingOffset = extraPlan ? planMonth(key).filter(
    (a) => a.kind === "budget_advance" && a.status === "Anticipato"
  ).reduce(
    (sum, a) => sum + Math.min(
      a.amount_cents,
      (extraPlan.links || []).filter(
        (l) => l.cycle_id === a.cycle_id && l.role === "budget_advance" && fundedRows.has(l.movement_source_row)
      ).reduce((cents2, l) => cents2 + l.attributed_cents, 0)
    ) / 100,
    0
  ) : 0;
  const fundedOutsideAdvance = Math.max(0, funded - advanceFundingOffset);
  const annualCosts = hasAutoSchedule ? activeExtras(selected).filter(isAutoReserve).map((e) => ({ name: e.name, monthly: e.quota, yearly: e.total })) : annualCostDefaults;
  const reservedNames = [
    "Elettricit\xE0",
    "Gas",
    "Acqua",
    "Palestra",
    "Abbonamenti"
  ];
  const linkedPayments = new Set(
    (extraPlan?.links || []).filter((l) => l.role === "payment").map((l) => l.movement_source_row)
  );
  const coveredAdvanceRows = new Set([...octoberAdvanceReconciliation(movements, key, todayDay, selected.grossAdvanceOffset, privateRules).covered].map((r) => Number(r[19])));
  const rawUsedFree = selectedTransactions.filter(
    (t) => (t.account === "Revolut" || t.account === "Trade Republic") && (t.type === "Spesa" || t.type === "Entrata") && !linkedPayments.has(t.row) && !coveredAdvanceRows.has(Number(t.row)) && t.category !== "Affitto" && !reservedNames.includes(t.category) && !(t.type === "Entrata" && !/rimbors|refund|storno/i.test(t.category + " " + t.name))
  ).reduce((sum, t) => sum - t.amount, 0);
  const borrowedThisMonth = extras.filter(
    (e) => e.status === "Anticipato" && e.start > key && e.paidAt === key
  ).reduce((sum, e) => sum + e.total, 0);
  const usedFromFuture = Math.min(
    Math.max(0, rawUsedFree - selected.spendable),
    borrowedThisMonth
  );
  const usedFree = rawUsedFree;
  const commitmentCategories = [
    { name: "Affitto", amount: rent },
    { name: "Auto, accantonamento", amount: selected.carCommitments },
    ...recurring.filter((r) => r.treatment === "Vincolata").map((r) => ({ name: r.name, amount: r.estimate })),
    ...extraPlan ? planMonth(key).filter((a) => a.kind === "expense" && !planAuto(a)).map((a) => ({ name: a.name, amount: a.amount_cents / 100 })) : activeExtras(selected).filter((e) => !isAutoReserve(e)).map((e) => ({ name: e.name, amount: e.quota }))
  ].filter((x) => x.amount > 0);
  const currentRecurring = utilityEstimates(baseRecurring, movements, today, todayDay, utilitySettings);
  const currentSettlements = monthlyBudgetAmounts({
    salary,
    rent,
    recurring: currentRecurring,
    movements,
    month: today,
    todayDay,
    extraPlan,
    extras,
    privateRules
  }).monthlyFixedSettlements;
  const recurringCommitments = currentRecurring.filter((r) => r.treatment === "Vincolata" && r.name !== "Benzina").map((r) => {
    const settlement = currentSettlements.find((x) => x.name === r.name);
    return {
      name: r.name,
      estimate: r.estimate,
      paid: settlement?.paid || 0,
      remaining: settlement ? 0 : r.estimate
    };
  });
  const rentSettlement = currentSettlements.find((x) => x.name === "Affitto"), rentPaid = rentSettlement?.paid || 0;
  const currentExtraReserves = extraPlan ? planMonth(today).filter((a) => a.kind === "expense").reduce((n, a) => n + a.amount_cents / 100, 0) : activeExtras({ month: today }).reduce((n, e) => n + e.quota, 0);
  const currentCarFallback = !extraPlan && !hasAutoSchedule ? car : 0;
  const commitmentDetails = [
    ...recurringCommitments,
    { name: "Affitto", estimate: rent, paid: rentPaid, remaining: rentSettlement ? 0 : rent },
    {
      name: "Straordinarie e auto",
      estimate: currentExtraReserves + currentCarFallback,
      paid: 0,
      remaining: currentExtraReserves + currentCarFallback
    }
  ];
  const committedCurrent = Math.round(commitmentDetails.reduce((n, r) => n + r.remaining, 0) * 100) / 100;
  const currentSpendable = Math.round((currentAssets - committedCurrent) * 100) / 100;
  const monthlyBudget = monthlyBudgetAmounts({
    salary,
    rent,
    recurring,
    movements,
    month: key,
    todayDay,
    extraPlan,
    extras,
    privateRules,
    carFallback: !extraPlan && !hasAutoSchedule ? car : 0
  });
  if (lightweight)
    return {
      year,
      month: month2,
      key,
      today,
      appVersion: APP_VERSION,
      updatedAt: Utilities.formatDate(/* @__PURE__ */ new Date(), TZ, "dd/MM/yyyy HH:mm"),
      summary: {
        ...selected,
        ...monthlyBudget,
        budget: currentAssets,
        committedCurrent,
        recurringCommitments: commitmentDetails,
        remainingFree: currentSpendable,
        revolutBalance: currentRevolut,
        totalAssets: currentAssets,
        account: "Trade Republic",
        accountBalance: currentAssets,
        assets: currentAssets,
        balanceDate,
        assetDate: dateIso_(assets[1][2])
      },
      recurring,
      extras,
      transactions: selectedTransactions,
      candidates: [],
      extraPlan,
      categoryOptions: []
    };
  const goalCell = budget[12] && budget[12][14];
  const goal = goalCell === "" || goalCell === null || goalCell === void 0 ? null : number_(goalCell);
  const monthlySaving = Math.max(0, number_(budget[13] && budget[13][14]));
  const monthsRemaining = 12 - Number(Utilities.formatDate(now, TZ, "M"));
  const planning = {
    year: Number(Utilities.formatDate(now, TZ, "yyyy")),
    goal,
    monthlySaving,
    monthsRemaining,
    now: currentAssets,
    projection: currentAssets + monthlySaving * monthsRemaining
  };
  Object.assign(
    planning,
    planningAmounts(currentAssets, goal, monthlySaving, monthsRemaining)
  );
  const snapshotDay = dateIso_(assets[1][2]);
  const anchorBalance = number_(assets[1][1]);
  const trMovements = movements.map((r, i) => ({
    date: dateIso_(r[1]),
    amount: number_(r[3]),
    account: String(r[4]),
    status: String(r[7]),
    source: String(r[13]),
    row: i + 2
  })).filter(
    (r) => r.account === "Trade Republic" && r.status === "Eseguito" && r.date
  );
  const firstTrDate = trMovements.reduce(
    (min, r) => min && min < r.date ? min : r.date,
    ""
  );
  const snapshots = assetHistoryRows.filter((r) => r[0] instanceof Date && typeof r[1] === "number").map((r) => ({
    date: dateIso_(r[0]),
    month: monthOf_(r[0]),
    amount: number_(r[1]),
    source: String(r[2] || "Rilevazione")
  }));
  const wealthHistory = yearly.map((item) => {
    const following = new Date(
      Date.UTC(year, Number(item.month.slice(5)), 1)
    );
    const end = new Date(following.getTime() - 864e5).toISOString().slice(0, 10);
    const available = item.month <= today && firstTrDate && firstTrDate <= end;
    let estimate = null;
    if (available && snapshotDay) {
      if (end < snapshotDay)
        estimate = anchorBalance - trMovements.filter((r) => r.date > end && r.date <= snapshotDay).reduce((n, r) => n + r.amount, 0);
      else
        estimate = balanceAt(
          "Trade Republic",
          end > todayDay && item.month === today ? todayDay : end
        );
    }
    const measured = snapshots.filter((x) => x.month === item.month).sort((a, b) => b.date.localeCompare(a.date))[0];
    return {
      month: item.month,
      estimated: estimate,
      measured: measured ? measured.amount : null,
      measuredDate: measured?.date || ""
    };
  });
  function normalizedCategory(r) {
    return String(r[21] || r[5] || "Da classificare");
  }
  const italianMonths = [
    "gen",
    "feb",
    "mar",
    "apr",
    "mag",
    "giu",
    "lug",
    "ago",
    "set",
    "ott",
    "nov",
    "dic"
  ];
  const salaryHistory = payslipRows.flatMap((r) => {
    const match = String(r[0] || "").trim().toLowerCase().match(/^([a-z]{3})\s+(\d{2}|\d{4})$/);
    if (!match || !italianMonths.includes(match[1]) || r[1] === null || r[1] === "")
      return [];
    const y = match[2].length === 2 ? 2e3 + Number(match[2]) : Number(match[2]);
    const competence = ym_(y, italianMonths.indexOf(match[1]) + 1);
    if (competence > today) return [];
    return [
      {
        month: competence,
        base: number_(r[1]),
        additional: number_(r[5]),
        gross: number_(r[1]) + number_(r[5])
      }
    ];
  }).sort((a, b) => a.month.localeCompare(b.month));
  const payrollGross = salaryHistory.reduce((n, r) => n + r.gross, 0);
  const taxRefund = salaryHistory.some((r) => r.month.startsWith("2025-")) ? 930 : 0;
  const salaryHistoryTotal = payrollGross - taxRefund;
  const salaryHistoryYears = [
    ...new Set(salaryHistory.map((r) => r.month.slice(0, 4)))
  ].map((y) => ({
    year: Number(y),
    gross: salaryHistory.filter((r) => r.month.startsWith(y)).reduce((n, r) => n + r.gross, 0),
    refund: y === "2025" ? taxRefund : 0,
    salary: salaryHistory.filter((r) => r.month.startsWith(y)).reduce((n, r) => n + r.gross, 0) - (y === "2025" ? taxRefund : 0)
  }));
  const lifetimeMonths = /* @__PURE__ */ new Map(), lifetimeSources = {}, lifetimeExpenses = {}, incomeAudit = [], expenseAudit = [], investmentGroups = /* @__PURE__ */ new Map();
  for (const r of movements) {
    const day2 = dateIso_(r[1]), m = monthOf_(r[1]), amount = number_(r[3]), account = String(r[4]), type = String(r[6]);
    if (!day2 || day2 > todayDay || String(r[7]) !== "Eseguito") continue;
    if (!lifetimeMonths.has(m))
      lifetimeMonths.set(m, {
        month: m,
        income: 0,
        spent: 0,
        hasRecords: true
      });
    const item = lifetimeMonths.get(m);
    if (account === "Trade Republic" && type === "Investimento" && !(amount > 0 && isSalaryMovement(r))) {
      const text = String(r[2]), codes = [...text.matchAll(/\b[A-Z]{2}[A-Z0-9]{9}[0-9]\b/g)].map(
        (x) => x[0]
      ), isin = codes[0] || "Senza ISIN";
      const qtyMatch = text.match(/quantity:\s*([\d.]+)/i), qty = qtyMatch ? Number(qtyMatch[1]) : null;
      if (!investmentGroups.has(isin))
        investmentGroups.set(isin, {
          isin,
          bought: 0,
          sold: 0,
          buyQty: 0,
          sellQty: 0,
          invalid: false,
          lastDay: day2,
          rows: []
        });
      const g = investmentGroups.get(isin);
      g.lastDay = g.lastDay > day2 ? g.lastDay : day2;
      g.rows.push({ date: day2, name: text, amount, quantity: qty });
      if (amount < 0) {
        g.bought -= amount;
        g.buyQty += qty || 0;
      } else {
        g.sold += amount;
        g.sellQty += qty || 0;
      }
      if (codes.length !== 1 || qty === null || !Number.isFinite(qty) || qty <= 0 || /buy trade|savings plan|ordine d'acquisto/i.test(text) && amount > 0 || /sell trade/i.test(text) && amount < 0)
        g.invalid = true;
    }
    if (account === "Trade Republic" && (type === "Entrata" || isSalaryMovement(r)) && amount > 0) {
      const source = isSalaryMovement(r) ? "Stipendio" : /rimbors/i.test(String(r[5]) + " " + r[2]) ? "Rimborsi" : /interess|interest|dividend/i.test(String(r[5]) + " " + r[2]) ? "Interessi" : "Altre entrate";
      if (source !== "Stipendio" || !salaryHistory.some((p) => p.month === m)) {
        item.income += amount;
        lifetimeSources[source] = (lifetimeSources[source] || 0) + amount;
      }
      incomeAudit.push({ date: day2, name: String(r[2]), amount, source });
    }
    const internal = type === "Trasferimento" && (/Revolut|Trade Republic|IsyBank|EasyBank/i.test(String(r[10])) || new RegExp(privateRules.ownerPattern || "a^", "i").test(String(r[2])));
    if (amount < 0 && ["Revolut", "Trade Republic"].includes(account) && ["Spesa", "Trasferimento"].includes(type) && !internal) {
      item.spent -= amount;
      const cat = normalizedCategory(r);
      lifetimeExpenses[cat] = (lifetimeExpenses[cat] || 0) - amount;
      expenseAudit.push({
        row: number_(r[19]),
        date: day2,
        name: String(r[2]),
        amount: -amount,
        category: cat,
        account,
        estimated: false
      });
    }
  }
  if (salaryHistory.length) {
    lifetimeSources.Stipendio = (lifetimeSources.Stipendio || 0) + salaryHistoryTotal;
    lifetimeSources["Rimborso 730"] = taxRefund;
    for (const r of salaryHistory) {
      if (!lifetimeMonths.has(r.month))
        lifetimeMonths.set(r.month, {
          month: r.month,
          income: 0,
          spent: 0,
          hasRecords: true
        });
      lifetimeMonths.get(r.month).income += r.gross;
    }
  }
  for (const g of investmentGroups.values()) {
    const prices = g.rows.filter((r) => r.quantity > 0 && r.amount !== 0).map((r) => Math.abs(r.amount) / r.quantity);
    if (prices.length > 1 && Math.max(...prices) / Math.min(...prices) > 10)
      g.invalid = true;
  }
  const investmentAudit = [...investmentGroups.values()].map((g) => ({
    ...g,
    net: Math.round((g.sold - g.bought) * 100) / 100,
    reconciled: !g.invalid && g.buyQty > 0 && Math.abs(g.buyQty - g.sellQty) <= Math.max(1e-4, g.buyQty * 1e-6)
  }));
  const investmentTotals = investmentAudit.reduce(
    (t, g) => ({
      bought: t.bought + g.bought,
      sold: t.sold + g.sold,
      net: t.net + g.net
    }),
    { bought: 0, sold: 0, net: 0 }
  );
  const investmentConfirmed = investmentAudit.filter((g) => g.reconciled).reduce((n, g) => n + g.net, 0);
  const investmentCashRows = movements.filter(
    (r) => String(r[4]) === "Trade Republic" && String(r[6]) === "Investimento" && String(r[7]) === "Eseguito" && dateIso_(r[1]) <= todayDay
  );
  const investmentCashNet = investmentCashRows.reduce(
    (n, r) => n + Math.round(number_(r[3]) * 100),
    0
  ) / 100;
  if (trProof && !trProof.conflicts?.length) {
    for (const r of investmentCashRows) {
      const m = lifetimeMonths.get(monthOf_(r[1]));
      if (m) m.investmentCashNet = (m.investmentCashNet || 0) + number_(r[3]);
    }
    if (investmentCashNet > 0)
      lifetimeSources["Investimenti - netto cassa"] = investmentCashNet;
    if (investmentCashNet < 0)
      lifetimeExpenses["Investimenti - netto cassa"] = -investmentCashNet;
  } else {
    for (const g of investmentAudit.filter((g2) => g2.reconciled)) {
      const m = lifetimeMonths.get(g.lastDay.slice(0, 7));
      if (m) {
        if (g.net > 0) m.income += g.net;
        else m.spent -= g.net;
      }
      if (g.net > 0)
        lifetimeSources["Utili investimenti - parziale"] = (lifetimeSources["Utili investimenti - parziale"] || 0) + g.net;
      if (g.net < 0)
        lifetimeExpenses["Perdite investimenti - parziale"] = (lifetimeExpenses["Perdite investimenti - parziale"] || 0) - g.net;
    }
  }
  const lifetimeSeries = [...lifetimeMonths.values()].sort((a, b) => a.month.localeCompare(b.month)).map((item) => {
    const end = new Date(
      Date.UTC(
        Number(item.month.slice(0, 4)),
        Number(item.month.slice(5)),
        0
      )
    ).toISOString().slice(0, 10);
    let wealth = null;
    const target = end > todayDay ? todayDay : end;
    const recorded = snapshots.filter((x) => x.month === item.month && x.date <= target).sort((a, b) => a.date.localeCompare(b.date)).at(-1);
    if (recorded) wealth = recorded.amount;
    if (trProof || bankSnapshots.some(
      (x) => x.account === "Trade Republic" && x.as_of_day <= target
    ))
      wealth = balanceAt("Trade Republic", target);
    if (item.month === today) wealth = currentAssets;
    const revolut2 = balanceAt("Revolut", target);
    const liquidWealth = item.month === today ? Math.round((currentAssets + currentRevolut) * 100) / 100 : Number.isFinite(wealth) && Number.isFinite(revolut2) ? Math.round((wealth + revolut2) * 100) / 100 : null;
    return { ...item, wealth, liquidWealth };
  });
  const lifetime = {
    from: lifetimeSeries[0]?.month || today,
    to: today,
    series: lifetimeSeries,
    income: Object.values(lifetimeSources).reduce((n, v) => n + v, 0),
    spent: Object.values(lifetimeExpenses).reduce((n, v) => n + v, 0),
    sources: Object.entries(lifetimeSources).map(([name, amount]) => ({
      name,
      amount
    })),
    expenses: Object.entries(lifetimeExpenses).map(([name, amount]) => ({ name, amount, estimated: false })).sort((a, b) => b.amount - a.amount),
    investmentCashNet,
    statement: trProof ? {
      from: trProof.from,
      to: trProof.to,
      opening: trProof.opening / 100,
      closing: trProof.closing / 100,
      incoming: trProof.incoming / 100,
      outgoing: trProof.outgoing / 100,
      rows: trProof.rows.length,
      corrections: trProof.fixes.length,
      conflicts: trProof.conflicts || [],
      refundCorrections: trProof.classifications?.length || 0,
      cashflow: trProof.cashflow
    } : null,
    salaryHistory,
    salaryHistoryYears,
    salaryHistoryTotal,
    taxRefund,
    salaryHistoryBasis: salaryHistory.length ? "cedolini per competenza" : "accrediti TR",
    expenseAudit,
    investmentAudit,
    investmentTotals,
    investmentConfirmed,
    salaryAverageReview: taxRefund > 0 ? "Mese del rimborso 730 2025 da confermare; media da accrediti verificati conservata." : "",
    incomeAudit: incomeAudit.sort((a, b) => b.date.localeCompare(a.date))
  };
  const databaseCategories = book.getSheetByName("Categorie finanziarie").getRange("A1:A1").getValues()[0][0] || [];
  lifetime.expenseGroups = databaseCategories.map((c) => ({
    id: c.id,
    name: c.name,
    members: [...c.members],
    amount: 0
  }));
  const byDetail = /* @__PURE__ */ new Map();
  for (const r of movements)
    byDetail.set(normalizedCategory(r), number_(r[22]) || 10);
  for (const c of lifetime.expenses) {
    const group = lifetime.expenseGroups.find((g) => g.id === byDetail.get(c.name)) || lifetime.expenseGroups.find((g) => g.id === 10);
    if (!group) throw Error("Categorie finanziarie non inizializzate.");
    if (!group.members.includes(c.name)) group.members.push(c.name);
    group.amount += c.amount;
  }
  lifetime.expenseGroups = lifetime.expenseGroups.filter((g) => g.amount > 0).map((g) => ({
    ...g,
    percentage: lifetime.spent ? Math.round(g.amount / lifetime.spent * 100) : 0
  })).sort((a, b) => b.amount - a.amount);
  const bankAudit = ["Trade Republic", "Revolut"].map((account) => {
    const rows = movements.filter(
      (r) => String(r[4]) === account && String(r[7]) === "Eseguito" && dateIso_(r[1]) && dateIso_(r[1]) <= todayDay
    );
    const dates = rows.map((r) => dateIso_(r[1])).sort();
    return {
      account,
      from: dates[0] || null,
      to: dates.at(-1) || null,
      count: rows.length,
      rawNet: Math.round(rows.reduce((n, r) => n + number_(r[3]), 0) * 100) / 100,
      balance: account === "Trade Republic" ? currentAssets : currentRevolut
    };
  });
  const suspiciousTransfers = movements.filter(
    (r) => String(r[4]) === "Trade Republic" && String(r[6]) === "Trasferimento" && String(r[7]) === "Eseguito" && number_(r[3]) <= -2500
  ).map((r) => ({
    row: number_(r[19]),
    date: dateIso_(r[1]),
    name: String(r[2]),
    amount: number_(r[3]),
    counterpart: String(r[10])
  }));
  const creditedSalaryTotal = incomeAudit.filter((r) => r.source === "Stipendio").reduce((n, r) => n + r.amount, 0);
  const cashTotal = currentAssets;
  lifetime.reconciliation = {
    status: "incomplete",
    cashTotal,
    tradeRepublic: currentAssets,
    revolut: currentRevolut,
    recordedFlowDifference: Math.round((lifetime.income - lifetime.spent) * 100) / 100,
    unexplainedDifference: Math.round((lifetime.income - lifetime.spent - cashTotal) * 100) / 100,
    // Comparison only: not a balancing expense, opening balance, or investment loss.
    openingBalanceKnown: false,
    creditedSalaryTotal,
    payslipSalaryWithoutTrCredit: Math.round((salaryHistoryTotal - creditedSalaryTotal) * 100) / 100,
    tradeRepublicStatementVerified: !!trProof && !trProof.conflicts?.length,
    missingAccounts: [
      "IsyBank / EasyBank: movimenti storici non disponibili"
    ],
    bankAudit,
    suspiciousTransfers
  };
  const monthlyBreakdowns = Object.fromEntries(
    yearly.map((item) => {
      const all = Object.entries(monthlyCategories[item.month] || {}).filter((x) => x[1] > 0).sort((a, b) => b[1] - a[1]);
      const total = all.reduce((n, x) => n + x[1], 0), top = all.slice(0, 5), other = all.slice(5).reduce((n, x) => n + x[1], 0);
      if (other) top.push(["Altre", other]);
      let position = 0;
      const items = top.map(([name, amount]) => {
        const start = position;
        position += total ? amount / total * 100 : 0;
        return {
          name,
          amount,
          start,
          end: position,
          bar: top[0]?.[1] ? Math.round(amount / top[0][1] * 100) : 0
        };
      });
      const commitments = [
        { name: "Affitto", amount: rent },
        { name: "Auto, accantonamento", amount: item.carCommitments },
        ...recurring.filter((r) => r.treatment === "Vincolata").map((r) => ({ name: r.name, amount: r.estimate })),
        ...extraPlan ? planMonth(item.month).filter((a) => a.kind === "expense" && !planAuto(a)).map((a) => ({ name: a.name, amount: a.amount_cents / 100 })) : activeExtras(item).filter((e) => !isAutoReserve(e)).map((e) => ({ name: e.name, amount: e.quota }))
      ].filter((x) => x.amount > 0);
      return [
        item.month,
        { total, items, commitments, commitmentTotal: item.commitments }
      ];
    })
  );
  for (const item of yearly) {
    const policy = monthlyBudgetAmounts({
      salary,
      rent: rentEstimate(number_(budget[2][14]), item.month, extraPlan?.rentSplit),
      recurring: utilityEstimates(baseRecurring, movements, item.month, todayDay, utilitySettings),
      movements,
      month: item.month,
      todayDay,
      extraPlan,
      extras,
      privateRules,
      carFallback: hasAutoSchedule ? 0 : car
    });
    item.budgetCommitments = policy.monthlyCommitted;
    item.monthlyRemaining = policy.monthlyRemaining;
  }
  const yearTotal = yearly.reduce(
    (o, m) => ({
      income: o.income + m.income,
      incomePayslip: o.incomePayslip + m.incomePayslip,
      spent: o.spent + m.spent,
      net: o.net + m.net,
      commitments: o.commitments + (m.budgetCommitments ?? m.commitments),
      spendable: 0
    }),
    {
      income: 0,
      incomePayslip: 0,
      spent: 0,
      net: 0,
      commitments: 0,
      spendable: 0
    }
  );
  return {
    year,
    month: month2,
    key,
    appVersion: APP_VERSION,
    updatedAt: Utilities.formatDate(/* @__PURE__ */ new Date(), TZ, "dd/MM/yyyy HH:mm"),
    summary: {
      ...selected,
      ...monthlyBudget,
      salary,
      salaryWindow,
      rent,
      car: selected.carCommitments,
      revolut,
      reserved,
      baseFree,
      funded,
      prepaid,
      advanceFundingOffset,
      fundedOutsideAdvance,
      toTransfer: Math.max(0, revolut - fundedOutsideAdvance),
      futureFunded,
      absorbedNow,
      absorbedFuture,
      futureAvailable: Math.max(0, futureFunded - absorbedFuture),
      rentAndCar: rent + selected.carCommitments,
      totalAssets: currentAssets,
      account: "Trade Republic",
      accountBalance: currentAssets,
      assets: currentAssets,
      assetMonthBalance: selectedDay ? balanceAt("Trade Republic", selectedDay) : null,
      assetDate: dateIso_(assets[1][2]),
      revolutBalance: currentRevolut,
      revolutMonthBalance: selectedDay ? balanceAt("Revolut", selectedDay) : null,
      balanceDate,
      usedFree,
      rawUsedFree,
      usedFromFuture,
      borrowedThisMonth,
      remainingBeforeAdvance: selected.spendable - rawUsedFree,
      budget: currentAssets,
      committedCurrent,
      recurringCommitments: commitmentDetails,
      remainingFree: currentSpendable
    },
    lifetime,
    yearly,
    wealthHistory,
    snapshots,
    planning,
    incomeSources: Object.entries(incomeSources).filter(([_, amount]) => amount > 0).map(([name, amount]) => ({ name, amount, estimated: false })).sort((a, b) => b.amount - a.amount),
    categories: Object.entries(categories).filter(([_, amount]) => amount > 0).map(([name, amount]) => ({ name, amount })).sort((a, b) => b.amount - a.amount),
    commitmentCategories,
    monthlyCategories,
    monthlyBreakdowns,
    yearTotal,
    today,
    candidates: candidates.sort((a, b) => b.amount - a.amount).slice(0, 16),
    transactions: selectedTransactions,
    recurring,
    annualCosts,
    extras,
    history,
    averages,
    payroll,
    quality: { pending, unmatched },
    dataNote: year === 2026 ? "Gennaio-marzo: gli accrediti IsyBank ricostruiti dai cedolini servono solo alla media di riferimento. I bonifici verso Trade Republic restano trasferimenti interni, non entrate reali." : ""
  };
  function ym_(year2, month3) {
    return String(year2) + "-" + ("0" + month3).slice(-2);
  }
  function boundedInteger_(value, min, max, fallback) {
    const n = Number(value);
    return Number.isInteger(n) && n >= min && n <= max ? n : fallback;
  }
  function number_(value) {
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
  }
  function monthOf_(date2) {
    return dateIso_(date2).slice(0, 7);
  }
  function dateIso_(date2) {
    return date2 instanceof Date && !Number.isNaN(date2.getTime()) ? date2.toISOString().slice(0, 10) : "";
  }
}
var PRIVATE_RULES_BLOB = { "identity": "6701beea61046c84a3a74b2d1000895ae7f00c1f17180088fdae30f09318637a", "iv": "h6hG/U/LaEvMdM+S", "ciphertext": "mjug8N0UqJLg3I0fTsSEE4PvjB1ag27tqquqoqOo7Nn6zPKc8R8veQd6SF6nWexmsTYdC3nlGkY+UNB3sEmUKAwKvfWZYmmNeiWpx0Oyctb8VB71NNPA0V5CmPNIUBHFCcUw2iH73aRUaZNH9x3BD73kDd2wrfVHASL4Q0H0/YSiaYql3UOyz051dHatY/n5zx8qvwLew5iK4QL+KoBGMfyfgPj51dcaOgQTtHJpCMSyrvOSaWjtcglCSmkDZKzCtuqPt8f7oU7iRPwyiOMZGIy0W45pRHQjijyVpg8uFcC88J7K7xQa8DQXPnwmwxrzE8JIY3va5teRoJZ7yJBiCN2WTcyEiMBGItzFPRDiiHWUfq6URf7bH7vUBsDMDSZXovmS308gYQ738VOMb+NZF7zUe5qsdtt1eQbhgWj1o8FUmkV1XgtNJ02qyrD7NW/+OItxL72zlLUJe8a2KH6ba2LPO7ZDipDobiZErro2CJT2UTkiME2KpQrZRwLyUUHUyMMnCTgrD60ePKs/POMyZ2xqd3QtGQ4BUCyCdG3JIL8h1BH7JvpD+tpeOU9Cwouo5TsbNl5P6Z5BHcz0gf4M1V3MLOvVJkGYPLiNSLYJSc00ZDjt+pCcIKGDMecvDzUgra8C58y5/u82hrNZXOCtkHF7ty4vhFV/zxUtYGVCzqsnpvgLM27KHF96NwrT+etIYBx2MgTzu8M1gQmq+hsml4X1PzgBhSguX/l219roEEEyUYNa+Ik3/tim6gvmrcwiqDhne9xvTWLtgLnhHeLXyezqpSwfaK45HM4xtB5ECe/H7CpbiqljmSz7iw==" };
var privateRulesByDB = /* @__PURE__ */ new WeakMap();
async function privateRulesForProof(proof) {
  if (!proof.rows?.length) return {};
  const values = [...new Set((JSON.stringify(proof).match(/IT\d{2}[A-Z]\d{22}/gi) || []).map((s) => s.toUpperCase()))];
  const bytes = (s) => new TextEncoder().encode(s);
  for (const value of values) {
    const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes(value)));
    if ([...hash].map((b) => b.toString(16).padStart(2, "0")).join("") !== PRIVATE_RULES_BLOB.identity) continue;
    const key = await crypto.subtle.importKey("raw", await crypto.subtle.digest("SHA-256", bytes(value + "|LifeOS private rules v1")), "AES-GCM", false, ["decrypt"]);
    const decode = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(await crypto.subtle.decrypt({ name: "AES-GCM", iv: decode(PRIVATE_RULES_BLOB.iv) }, key, decode(PRIVATE_RULES_BLOB.ciphertext))));
  }
  throw Error("Configurazione storica non riconosciuta: conserva il database originale e usa il Worker dell\u2019archivio privato.");
}
var trRepairJobs = /* @__PURE__ */ new WeakMap();
async function ensureTrStatement(env) {
  if (!trRepairJobs.has(env.DB)) trRepairJobs.set(env.DB, (async () => {
    const found = await env.DB.prepare("SELECT values_json FROM source_rows WHERE sheet='Estratto TR verificato' AND row_number=1").first();
    const proof = found ? JSON.parse(found.values_json)?.[0] : null;
    if (proof?.version !== 2) throw Error("Riconciliazione storica mancante: ripristina la configurazione D1 esistente.");
    privateRulesByDB.set(env.DB, await privateRulesForProof(proof));
  })());
  try {
    await trRepairJobs.get(env.DB);
  } catch (error) {
    trRepairJobs.delete(env.DB);
    throw error;
  }
}
var FINANCE_MANUAL_CATEGORIES = [.../* @__PURE__ */ new Set([...platformContract.expenseCategories, ...platformContract.incomeCategories])];
var FINANCE_CATEGORY_SEED = {
  categories: [
    {
      id: 1,
      name: "Auto e trasporti",
      members: ["Auto", "Benzina", "Trasporti", "Pedaggi"]
    },
    {
      id: 2,
      name: "Casa",
      members: [
        "Affitto e ingresso casa",
        "Arredamento e casa",
        "Utenze",
        "Affitto",
        "Casa",
        "Acqua",
        "Gas",
        "Elettricita"
      ]
    },
    {
      id: 3,
      name: "Shopping e tecnologia",
      members: ["Shopping", "Elettronica"]
    },
    { id: 4, name: "Alimentari", members: ["Alimentari"] },
    { id: 5, name: "Ristorazione", members: ["Ristorazione"] },
    {
      id: 6,
      name: "Salute e benessere",
      members: ["Salute", "Palestra", "Cura personale", "Sport"]
    },
    {
      id: 7,
      name: "Tempo libero",
      members: ["Viaggi", "Svago", "Abbonamenti"]
    },
    {
      id: 8,
      name: "Trasferimenti a terzi",
      members: ["Trasferimenti a terzi", "Famiglia"]
    },
    {
      id: 9,
      name: "Imposte e commissioni",
      members: ["Imposte", "Imposte e servizi", "Commissioni", "Imposte e commissioni"]
    },
    {
      id: 10,
      name: "Da classificare",
      members: [
        "Da classificare",
        "Contanti",
        "Altro",
        "Stipendio",
        "Interessi",
        "Rimborsi"
      ]
    }
  ],
  rules: [
    {
      id: 1,
      pattern: "affitt|caparr|cauzion|contanti destinati alle spese di agenzia",
      label: "Affitto e ingresso casa"
    },
    {
      id: 2,
      pattern: "beyfin|\\besso\\b|\\bq8\\b|enilive|\\beni\\b|ip italiana petroli|ok petrol|desideri carburanti|new gas network",
      label: "Benzina"
    },
    {
      id: 3,
      pattern: "iris palest|iris societa sportiva|fitactive",
      label: "Palestra"
    },
    { id: 4, pattern: "etrurialucegas|regione.*utenze", label: "Utenze" },
    {
      id: 5,
      pattern: "laredoute|la.?redoute|maisons du|\\bikea\\b|\\bobi\\b|brico io|abain components",
      label: "Arredamento e casa"
    },
    {
      id: 6,
      pattern: "computer.?gross|media.?world|swappie|back.?market",
      label: "Elettronica"
    },
    {
      id: 7,
      pattern: "unomobile|uno.?mobile|iliad|\\btim\\b|chatgpt|signulous|linkedin|fastweb|google play|apple.com|goread|brazethemes|\\binwi\\b",
      label: "Abbonamenti"
    },
    { id: 8, pattern: "taptap", label: "Trasferimenti a terzi" },
    {
      id: 9,
      pattern: "cupsolidale|farmac|pharma|dr\\.?max|odontoiatr|receptor chem",
      label: "Salute"
    },
    { id: 10, pattern: "decathlon", label: "Sport" },
    {
      id: 11,
      pattern: "parrucch|salone 198|tmt parrucchiere",
      label: "Cura personale"
    },
    {
      id: 12,
      pattern: "trainline|trenitalia|flixbus|malta public transport|tussam|s.bahn|valletta ferry|\\bbolt\\b",
      label: "Trasporti"
    },
    {
      id: 13,
      pattern: "ipertosano|macelleria|jaouda market|supermarket|\\bspar\\b|pam panorama|\\bcondis\\b|berry pantry|arkadia foodstore",
      label: "Alimentari"
    },
    {
      id: 14,
      pattern: "aliexpress|sonny bono|alcott|zalando|vinted|duty.free|gold shop",
      label: "Shopping"
    },
    {
      id: 15,
      pattern: "bistrot|pizzer|pinsa|caff[e\\u00e8]|coffee|cornett|taverna|pastizzer|past[ie]cc|mc.?donald|illy spa|cioccolat|my chef|porca vacca|\\bvyta\\b|angolo divino|buffet empoli",
      label: "Ristorazione"
    },
    {
      id: 16,
      pattern: "aviation muse|real alc.zar|orto botanico|zoo berlin|planetice",
      label: "Svago"
    },
    {
      id: 17,
      pattern: "comune.*pagop|comune di san miniato|universita",
      label: "Imposte e servizi"
    },
    {
      id: 18,
      pattern: "autostrade|autoroutes|aspit|miser direz",
      label: "Pedaggi"
    },
    {
      id: 19,
      pattern: "imperiale moto|autogamma|carfax|autoservice|allianz|assicurazioni",
      label: "Auto"
    }
  ]
};
var categorySchemaJobs = /* @__PURE__ */ new WeakMap();
var movementCategoryFingerprint = (r) => [r.category, r.description, r.merchant, r.notes].map((x) => String(x || "")).join(String.fromCharCode(31));
async function ensureFinanceCategories(env) {
  await ensureTrStatement(env);
  if (!categorySchemaJobs.has(env.DB)) {
    const job = (async () => {
      if (await env.DB.prepare("SELECT value FROM os_meta WHERE key='finance_categories_ready_v2'").first()) return;
      await env.DB.batch([
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS financial_categories(id INTEGER PRIMARY KEY CHECK(id BETWEEN 1 AND 10),name TEXT NOT NULL UNIQUE,sort_order INTEGER NOT NULL)"
        ),
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS financial_category_mappings(detail_category TEXT PRIMARY KEY,category_id INTEGER NOT NULL REFERENCES financial_categories(id))"
        ),
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS financial_category_rules(id INTEGER PRIMARY KEY,pattern TEXT NOT NULL,detail_category TEXT NOT NULL,priority INTEGER NOT NULL)"
        ),
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS movement_financial_categories(movement_source_row INTEGER PRIMARY KEY REFERENCES movements(source_row) ON DELETE CASCADE,category_id INTEGER NOT NULL REFERENCES financial_categories(id),detail_category TEXT NOT NULL,source_category TEXT NOT NULL,source_fingerprint TEXT NOT NULL)"
        ),
        env.DB.prepare(
          "CREATE INDEX IF NOT EXISTS idx_movement_financial_category ON movement_financial_categories(category_id)"
        )
      ]);
      const seedState = await env.DB.prepare("SELECT COUNT(*) n FROM financial_categories").first();
      if (!seedState.n) await env.DB.batch([
        env.DB.prepare("INSERT OR IGNORE INTO financial_categories(id,name,sort_order) SELECT json_extract(value,'$.id'),json_extract(value,'$.name'),json_extract(value,'$.id') FROM json_each(?)").bind(JSON.stringify(FINANCE_CATEGORY_SEED.categories)),
        env.DB.prepare("INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) SELECT m.value,json_extract(c.value,'$.id') FROM json_each(?) c,json_each(c.value,'$.members') m").bind(JSON.stringify(FINANCE_CATEGORY_SEED.categories)),
        env.DB.prepare("INSERT OR IGNORE INTO financial_category_rules(id,pattern,detail_category,priority) SELECT json_extract(value,'$.id'),json_extract(value,'$.pattern'),json_extract(value,'$.label'),json_extract(value,'$.id') FROM json_each(?)").bind(JSON.stringify(FINANCE_CATEGORY_SEED.rules.map((r) => r.id === 1 && privateRulesByDB.get(env.DB)?.rentPattern ? { ...r, pattern: privateRulesByDB.get(env.DB).rentPattern } : r)))
      ]);
      await env.DB.batch([
        env.DB.prepare("INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) SELECT json_extract(value,'$[0]'),json_extract(value,'$[1]') FROM json_each(?)").bind(JSON.stringify([["Assicurazione", 1], ["Bollo", 1], ["Manutenzione auto", 1], ["Condominio", 2], ["Dentista", 6], ["Farmaci e visite", 6]])),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_rules_update AFTER UPDATE ON financial_category_rules BEGIN DELETE FROM movement_financial_categories; END"
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_rules_insert AFTER INSERT ON financial_category_rules BEGIN DELETE FROM movement_financial_categories; END"
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_rules_delete AFTER DELETE ON financial_category_rules BEGIN DELETE FROM movement_financial_categories; END"
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_mapping_update AFTER UPDATE ON financial_category_mappings BEGIN DELETE FROM movement_financial_categories WHERE detail_category=OLD.detail_category OR detail_category=NEW.detail_category; END"
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_mapping_insert AFTER INSERT ON financial_category_mappings BEGIN DELETE FROM movement_financial_categories WHERE detail_category=NEW.detail_category; END"
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_mapping_delete AFTER DELETE ON financial_category_mappings BEGIN DELETE FROM movement_financial_categories WHERE detail_category=OLD.detail_category; END"
        )
      ]);
      const categoryUpgrade = await env.DB.prepare(
        "SELECT value FROM os_meta WHERE key='finance_categories_1136'"
      ).first();
      if (!categoryUpgrade) {
        const edits = [];
        const upgrades = [
          [
            "veer g|a domani|la fortuna empoli|breasy|red garter|tokyo club|havana club|noa sardinian winery|ta zaren|briciole",
            "Ristorazione"
          ],
          ["el alamein", "Alimentari"],
          ["caddy.s", "Cura personale"],
          ["gamelife|tiktok", "Svago"],
          ["souvenir occitan|avolta", "Shopping"],
          ["abaco s[.]p[.]a|biglietteria piazza", "Trasporti"],
          ["rosa.?s garden", "Arredamento e casa"],
          ["dedem", "Shopping"]
        ];
        edits.push(env.DB.prepare("INSERT OR IGNORE INTO financial_category_rules(id,pattern,detail_category,priority) SELECT 113600+CAST(key AS INTEGER),json_extract(value,'$[0]'),json_extract(value,'$[1]'),70+CAST(key AS INTEGER) FROM json_each(?)").bind(JSON.stringify(upgrades)));
        edits.push(
          env.DB.prepare(
            "INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) VALUES ('Pagamenti non dettagliati',10)"
          )
        );
        edits.push(
          env.DB.prepare(
            "INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) VALUES ('Elettricit\xE0',2)"
          )
        );
        edits.push(
          env.DB.prepare(
            "UPDATE financial_categories SET name='Altre spese' WHERE id=10 AND name='Da classificare'"
          )
        );
        edits.push(
          env.DB.prepare(
            "DELETE FROM movement_financial_categories WHERE detail_category='Da classificare'"
          )
        );
        edits.push(
          env.DB.prepare(
            "INSERT INTO os_meta(key,value) VALUES ('finance_categories_1136','1')"
          )
        );
        await env.DB.batch(edits);
      }
      await env.DB.prepare("CREATE TABLE IF NOT EXISTS financial_reporting_adjustments(id TEXT PRIMARY KEY,label TEXT NOT NULL,amount_cents INTEGER NOT NULL CHECK(amount_cents>=0),as_of_day TEXT NOT NULL,method TEXT NOT NULL)").run();
      await env.DB.prepare("INSERT OR IGNORE INTO os_meta(key,value) VALUES ('finance_categories_ready_v2','1')").run();
    })();
    categorySchemaJobs.set(env.DB, job);
  }
  try {
    await categorySchemaJobs.get(env.DB);
  } catch (e) {
    categorySchemaJobs.delete(env.DB);
    throw e;
  }
  const [changed, rules, mappings] = await Promise.all([
    env.DB.prepare(
      `SELECT m.* FROM movements m LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row WHERE c.movement_source_row IS NULL OR c.source_fingerprint<>COALESCE(m.category,'')||char(31)||COALESCE(m.description,'')||char(31)||COALESCE(m.merchant,'')||char(31)||COALESCE(m.notes,'')`
    ).all(),
    env.DB.prepare(
      "SELECT * FROM financial_category_rules ORDER BY priority,id"
    ).all(),
    env.DB.prepare("SELECT * FROM financial_category_mappings").all()
  ]);
  if (!changed.results.length) return;
  const compiled = rules.results.map((r) => ({
    ...r,
    regex: new RegExp(r.pattern, "i")
  }));
  const map = new Map(
    mappings.results.map((r) => [r.detail_category, r.category_id])
  );
  const statements = [];
  for (const r of changed.results) {
    let detail = String(r.category || "Altro").trim();
    if (!String(r.notes || "").includes("[Categoria manuale]")) {
      const text = [r.description, r.merchant, r.notes].join(" ");
      const rule = compiled.find((x) => x.regex.test(text));
      if (rule) detail = rule.detail_category;
      else if (detail === "Casa") detail = "Arredamento e casa";
      else if (/^(Altro|Altre spese|Altri movimenti|Da classificare)$/i.test(detail))
        detail = "Pagamenti non dettagliati";
      if (/^(Apple|Google)$/i.test(String(r.description || "")) && Math.abs(Number(r.amount)) < 20)
        detail = "Abbonamenti";
    }
    statements.push([r.source_row, map.get(detail) || 10, detail, String(r.category || ""), movementCategoryFingerprint(r)]);
  }
  if (statements.length) await env.DB.prepare("INSERT OR REPLACE INTO movement_financial_categories(movement_source_row,category_id,detail_category,source_category,source_fingerprint) SELECT json_extract(value,'$[0]'),json_extract(value,'$[1]'),json_extract(value,'$[2]'),json_extract(value,'$[3]'),json_extract(value,'$[4]') FROM json_each(?)").bind(JSON.stringify(statements)).run();
}
function planningAmounts(now, goal, monthlySaving, monthsRemaining) {
  const base = goal === null ? 0 : Math.max(1, goal, now);
  return {
    now,
    goal,
    monthlySaving,
    monthsRemaining,
    projection: Math.round((now + monthlySaving * monthsRemaining) * 100) / 100,
    surplusNow: goal === null ? null : Math.max(0, now - goal),
    projectedSurplus: goal === null ? null : Math.max(0, now + monthlySaving * monthsRemaining - goal),
    covered: goal === null ? 0 : Math.max(0, Math.min(goal, now)) / base * 100,
    surplus: goal === null ? 0 : Math.max(0, now - goal) / base * 100,
    missing: goal === null ? null : Math.max(0, goal - now)
  };
}
function planningInputs(target, monthly) {
  const goal = target === "" || target === null ? null : Number(target), saving = Number(monthly);
  if (goal !== null && (!Number.isFinite(goal) || goal < 0 || goal > 1e6) || !Number.isFinite(saving) || saving < 0 || saving > 1e5)
    throw Error("Importi non validi.");
  return { goal, saving };
}
async function getPlanningProjection(env, target, monthly) {
  const { goal, saving } = planningInputs(target, monthly);
  const day2 = nowDay();
  const snap = await env.DB.prepare(
    "SELECT * FROM account_balance_snapshots WHERE account='Trade Republic' AND as_of_day<=? ORDER BY as_of_day DESC,id DESC LIMIT 1"
  ).bind(day2).first();
  let now;
  if (snap) {
    const events = await env.DB.prepare(
      "SELECT COALESCE(SUM(delta_cents),0) delta FROM account_balance_events WHERE account='Trade Republic' AND id>? AND day<=? AND NOT (absorbed_snapshot_id IS NOT NULL AND absorbed_snapshot_id<=?)"
    ).bind(snap.event_watermark, day2, snap.id).first();
    now = (snap.amount_cents + Number(events.delta)) / 100;
  } else {
    const row = await env.DB.prepare(
      "SELECT values_json FROM source_rows WHERE sheet='Patrimonio' AND row_number=2"
    ).first();
    if (!row) throw Error("Saldo TR non disponibile.");
    now = Number(JSON.parse(row.values_json)[1]);
  }
  return planningAmounts(now, goal, saving, 12 - Number(day2.slice(5, 7)));
}
var ALLOWED_RECURRING = [
  "Condominio",
  "Elettricit\xE0",
  "Gas",
  "Acqua",
  "Palestra",
  "Abbonamenti",
  "Benzina"
];
var MOVEMENT_COLUMNS = "source_row budget_date actual_date description amount account category movement_type status competence_months baseline counterparty_account notes merchant source_name import_id budget_month competence_end monthly_share actual_month transfer_id".split(
  " "
);
var EXTRAS_COLUMNS = "source_row name total start_month month_count monthly_share end_month status payment_account paid_date notes repeat_rule".split(
  " "
);
var CONFIG_PAGE = `<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Importa impostazioni</title><style>body{background:#000000;color:#f2f5f9;font:16px system-ui;margin:0;padding:25px}main{max-width:560px;margin:auto}button,input{font:inherit;padding:10px;margin:8px 0}p{line-height:1.5;color:#b5c3d0}</style><main><h1>Completa la migrazione</h1><p>I movimenti sono gi\xE0 nel database. Importa impostazioni, saldi, stipendi e storico dal file di configurazione. Questa operazione aggiorna le righe importate.</p><input type="file" id="file" accept=".json,application/json"><br><button id="send">Importa configurazione</button><p id="status"></p><a href="/">Apri app</a></main><script>document.querySelector('#send').onclick=async e=>{const s=document.querySelector('#status'),f=document.querySelector('#file').files[0];if(!f){s.textContent='Scegli il file JSON.';return}e.target.disabled=true;try{let rows=JSON.parse(await f.text());if(!Array.isArray(rows))throw Error('File non valido');for(let i=0;i<rows.length;i+=20){let r=await fetch('/api/import-config',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(rows.slice(i,i+20))});if(!r.ok)throw Error(await r.text());s.textContent='Righe importate: '+Math.min(i+20,rows.length)+'/'+rows.length}s.textContent='Configurazione importata. Apri app.'}catch(x){s.textContent='Errore: '+x.message}finally{e.target.disabled=false}}<\/script></html>`;
var LOGIN_PAGE = `<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#111111"><link rel="manifest" href="/manifest.webmanifest"><link rel="apple-touch-icon" href="/apple-touch-icon.png"><meta name="apple-mobile-web-app-capable" content="yes"><title>Life OS \xB7 Accesso</title><style>*{box-sizing:border-box}body{min-height:100dvh;display:grid;place-items:center;margin:0;background:#000000;color:#f0f4fa;font:16px system-ui;padding:18px}main{width:min(370px,100%);padding:27px;border:1px solid #344159;border-radius:18px;background:#1b2534}h1{margin:0 0 8px;font-size:24px}p{color:#b1bfd0;line-height:1.45}label{display:block;margin:16px 0 6px}input,button{width:100%;padding:13px;font:inherit;border-radius:9px}input{border:1px solid #54647c;background:#121d2b;color:white}button{border:0;margin-top:20px;background:#7790e6;color:#0e1623;font-weight:700}small{color:#ffaaa9}body{background:radial-gradient(ellipse at 50% 0%,#3d3d3d66,transparent 65%),#111111;color:#f3f3f1;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}main{background:#1c1c1c;border:1px solid #ffffff10;border-radius:28px;padding:30px}h1{font-size:32px;letter-spacing:-.04em}p,label{color:#a6a6a3;font-size:13px}input{background:#131313;border:1px solid #ffffff15;border-radius:14px;min-height:48px}button{border-radius:24px;min-height:48px;color:#fff;background:linear-gradient(145deg,#e9d9bb55,#7aaeff20),#447dc7c9;border:1px solid #e9d9bb55;box-shadow:inset 0 1px #ffffff25;font-weight:550}input:focus-visible,button:focus-visible{outline:2px solid #d6bd91;outline-offset:3px}small{color:#ff9da4}</style><main><h1>Life OS</h1><form id="login"><label>Nome utente</label><input name="user" autocomplete="username" value="nas" required><label>Password</label><input name="password" type="password" autocomplete="current-password" required><button>Accedi</button></form><p><small id="error"></small></p></main><script>document.querySelector('#login').onsubmit=async e=>{e.preventDefault();const f=e.target,b=f.querySelector('button'),box=document.querySelector('#error');b.disabled=true;box.textContent='';try{let r=await fetch('/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({user:f.elements.namedItem('user').value,password:f.elements.namedItem('password').value})});if(!r.ok)throw Error('Credenziali non valide.');location.href='/'}catch(x){box.textContent=x.message;b.disabled=false}}<\/script></html>`;
var noCache = {
  "cache-control": "no-store",
  "x-content-type-options": "nosniff"
};
var response = (value, status = 200) => Response.json(value, { status, headers: noCache });
var fail = (message, status = 400) => new Response(message, { status, headers: noCache });
var icon = (b64) => new Response(
  Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)),
  {
    headers: {
      "content-type": "image/png",
      "cache-control": "public, max-age=86400"
    }
  }
);
var encode64 = (x) => btoa(String.fromCharCode(...x)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
var decode64 = (x) => Uint8Array.from(
  atob(
    x.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(x.length / 4) * 4, "=")
  ),
  (c) => c.charCodeAt(0)
);
async function cookieKey(secret) {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
}
async function sessionCookie(secret) {
  const payload = encode64(
    new TextEncoder().encode(
      JSON.stringify({ exp: Date.now() + 30 * 864e5 })
    )
  );
  const signature = encode64(
    new Uint8Array(
      await crypto.subtle.sign(
        "HMAC",
        await cookieKey(secret),
        new TextEncoder().encode(payload)
      )
    )
  );
  return `liquidita_session=${payload}.${signature}; Path=/; Max-Age=2592000; Secure; HttpOnly; SameSite=Strict`;
}
async function validSession(req, secret) {
  const match = (req.headers.get("cookie") || "").match(
    /(?:^|;\s*)liquidita_session=([^;]+)/
  );
  if (!match || match[1].length > 512) return false;
  try {
    const [body, sig] = match[1].split(".");
    if (!body || !sig) return false;
    const payload = JSON.parse(new TextDecoder().decode(decode64(body)));
    if (!Number.isFinite(payload.exp) || payload.exp <= Date.now())
      return false;
    const expected = new Uint8Array(
      await crypto.subtle.sign(
        "HMAC",
        await cookieKey(secret),
        new TextEncoder().encode(body)
      )
    );
    const actual = decode64(sig);
    if (expected.length !== actual.length) return false;
    let diff = 0;
    for (let i = 0; i < expected.length; i++) diff |= expected[i] ^ actual[i];
    return diff === 0;
  } catch {
    return false;
  }
}
async function checkPassword(req, secret) {
  const value = req.headers.get("authorization") || "";
  if (!value.startsWith("Basic ")) return false;
  let raw;
  try {
    raw = atob(value.slice(6));
  } catch {
    return false;
  }
  const [user, ...parts] = raw.split(":");
  if (user !== "nas" || !parts.length) return false;
  let enc = new TextEncoder(), [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(parts.join(":"))),
    crypto.subtle.digest("SHA-256", enc.encode(secret))
  ]);
  let diff = 0, x = new Uint8Array(a), y = new Uint8Array(b);
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}
var date = (s) => s ? /* @__PURE__ */ new Date(
  s.length === 7 ? s + "-01T12:00:00Z" : s.length === 10 ? s + "T12:00:00Z" : s + "Z"
) : null;
var nowDay = () => new Intl.DateTimeFormat("sv-SE", {
  timeZone: "Europe/Rome",
  year: "numeric",
  month: "2-digit",
  day: "2-digit"
}).format(/* @__PURE__ */ new Date());
var planYear = (value) => {
  const y = Number(value);
  return Number.isInteger(y) && y >= 2024 && y <= 2035 ? y : Number(nowDay().slice(0, 4));
};
var validAmount = (value, max = 1e6) => {
  let n = Number(value);
  if (!Number.isFinite(n) || n <= 0 || n > max)
    throw Error("Importo non valido.");
  return n;
};
var validCents = (value) => {
  const n = validAmount(value), c = Math.round(n * 100);
  if (!Number.isSafeInteger(c) || c < 1 || Math.abs(c / 100 - n) > 1e-8)
    throw Error("Usa importi con massimo due decimali.");
  return c;
};
var validDate = (value) => {
  if (typeof value !== "string" || !/^20\d\d-\d\d-\d\d$/.test(value) || !Number.isFinite(new Date(value).getTime()) || new Date(value).toISOString().slice(0, 10) !== value)
    throw Error("Data non valida.");
  return value;
};
function recordToMovement(r) {
  return [
    date(r.budget_date),
    date(r.actual_date),
    r.description,
    r.amount,
    r.account,
    r.category,
    r.movement_type,
    r.status,
    r.competence_months,
    r.baseline,
    r.counterparty_account,
    r.notes,
    r.merchant,
    r.source_name,
    r.import_id,
    date(r.budget_month),
    r.competence_end,
    r.monthly_share,
    r.actual_month,
    r.source_row,
    r.cashflow_month || "",
    r.resolved_category || r.category,
    r.financial_category_id
  ];
}
function recordToExtra(r) {
  return [
    r.name,
    r.total,
    r.start_month,
    r.month_count,
    r.monthly_share,
    r.end_month,
    r.status,
    r.payment_account,
    r.paid_date,
    r.notes,
    r.repeat_rule
  ].map((v, i) => [2, 5, 8].includes(i) ? date(v) : v);
}
function sheetBook(config, movements, extras) {
  let sheets = /* @__PURE__ */ new Map();
  for (let r of config) {
    let rows = sheets.get(r.sheet) || [];
    rows[r.row_number - 1] = JSON.parse(r.values_json);
    sheets.set(r.sheet, rows);
  }
  sheets.set("Movimenti", [[], ...movements.map(recordToMovement)]);
  const extraGrid = [[]];
  for (const record of extras)
    extraGrid[Number(record.source_row) - 1] = recordToExtra(record);
  sheets.set("Straordinarie", extraGrid);
  for (let [name, indices] of [
    ["Patrimonio", [2]],
    ["Saldi operativi", [2]],
    ["Riconciliazione stipendi", [0]],
    ["Storico ricorrenti", [0]],
    ["Storico patrimonio", [0]]
  ]) {
    let rows = sheets.get(name) || [];
    for (let r of rows)
      if (r) {
        for (let i of indices)
          if (r[i] && typeof r[i] === "string" && /^20\d\d-\d\d-\d\d/.test(r[i]))
            r[i] = date(r[i]);
      }
  }
  return {
    getSheetByName(name) {
      let rows = sheets.get(name) || [];
      return {
        getLastRow() {
          return rows.length;
        },
        getRange(...args) {
          let first, start, width, height;
          if (typeof args[0] === "string") {
            let match = /^([A-Z]+)(\d+):([A-Z]+)(\d+)$/.exec(args[0]);
            if (!match) throw Error("Intervallo non supportato: " + args[0]);
            start = Number(match[2]);
            height = Number(match[4]) - start + 1;
            let column = (s) => [...s].reduce((v, c) => v * 26 + c.charCodeAt(0) - 64, 0);
            first = column(match[1]);
            width = column(match[3]) - first + 1;
          } else {
            [start, first, height, width] = args;
          }
          return {
            getValues: () => Array.from(
              { length: height },
              (_, i) => Array.from(
                { length: width },
                (_2, j) => rows[start + i - 1]?.[first + j - 1] ?? ""
              )
            )
          };
        }
      };
    }
  };
}
async function loadFinance(env, year, monthNumber, lightweight = false) {
  await ensureTrStatement(env);
  await ensureBudgetPolicies(env);
  if (!lightweight) await ensureFinanceCategories(env);
  const [m, e, c, snapshots, events, categoryRows, categoryMappings, utilityConfig] = await Promise.all([
    env.DB.prepare(
      lightweight ? "SELECT * FROM movements ORDER BY source_row" : "SELECT m.*,c.detail_category resolved_category,c.category_id financial_category_id FROM movements m LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row ORDER BY m.source_row"
    ).all(),
    env.DB.prepare("SELECT * FROM extraordinary ORDER BY source_row").all(),
    env.DB.prepare(
      "SELECT sheet,row_number,values_json FROM source_rows ORDER BY sheet,row_number"
    ).all(),
    env.DB.prepare(
      "SELECT * FROM account_balance_snapshots ORDER BY id"
    ).all(),
    env.DB.prepare("SELECT * FROM account_balance_events ORDER BY id").all(),
    lightweight ? Promise.resolve({ results: [] }) : env.DB.prepare(
      "SELECT * FROM financial_categories ORDER BY sort_order,id"
    ).all(),
    lightweight ? Promise.resolve({ results: [] }) : env.DB.prepare("SELECT * FROM financial_category_mappings").all(),
    env.DB.prepare("SELECT (SELECT value FROM os_meta WHERE key='utility_estimates_v1') value,(SELECT value FROM os_meta WHERE key='condominium_estimates_v1') condo,(SELECT value FROM os_meta WHERE key='rent_condominium_split_v1158') rent_split").first()
  ]);
  const config = [
    ...c.results,
    { sheet: "Stime utenze", row_number: 1, values_json: JSON.stringify([utilityConfig?.value ? JSON.parse(utilityConfig.value) : {}]) },
    {
      sheet: "Categorie finanziarie",
      row_number: 1,
      values_json: JSON.stringify([
        categoryRows.results.map((c2) => ({
          ...c2,
          members: categoryMappings.results.filter((m2) => m2.category_id === c2.id).map((m2) => m2.detail_category)
        }))
      ])
    }
  ];
  if (!config.some((r) => r.sheet === "Budget"))
    throw Error("Apri /setup e importa liquidita-4.0-config.json.");
  const plan = await getExtraPlan(env, planYear(year));
  plan.budgetPolicies = (await env.DB.prepare("SELECT p.*,m.description,m.amount,m.actual_date,m.status FROM movement_budget_policies p JOIN movements m ON m.source_row=p.movement_source_row").all()).results;
  const condo = utilityConfig?.condo;
  plan.condominiumSettings = condo ? JSON.parse(condo) : { base: 0, changes: [{ month: "2026-10", value: 25 }] };
  let rentSplit = utilityConfig?.rent_split ? { value: utilityConfig.rent_split } : null;
  const legacyRent = c.results.find((r) => r.sheet === "Budget" && Number(r.row_number) === 3);
  if (!rentSplit && legacyRent && Math.round(Number(JSON.parse(legacyRent.values_json)[14]) * 100) === 57500) {
    await env.DB.prepare("INSERT OR IGNORE INTO os_meta(key,value) SELECT 'rent_condominium_split_v1158',? WHERE EXISTS(SELECT 1 FROM source_rows WHERE sheet='Budget' AND row_number=3 AND ROUND(CAST(json_extract(values_json,'$[14]') AS REAL)*100)=57500)").bind(JSON.stringify({ fromMonth: "2026-10", sourceAmount: 575, rent: 550 })).run();
    rentSplit = await env.DB.prepare("SELECT value FROM os_meta WHERE key='rent_condominium_split_v1158'").first();
  }
  plan.rentSplit = rentSplit?.value ? JSON.parse(rentSplit.value) : null;
  const currentYear = Number(nowDay().slice(0, 4));
  if (planYear(year) !== currentYear) {
    const currentPlan = await getExtraPlan(env, currentYear);
    plan.allocations.push(...currentPlan.allocations);
  }
  const result = computeFinance(
    sheetBook(config, m.results, e.results),
    year,
    monthNumber,
    plan,
    snapshots.results,
    events.results,
    lightweight,
    privateRulesByDB.get(env.DB) || {}
  );
  attachSavingsPlanning(result, c.results, nowDay());
  result.forecastHistory = forecastCashHistory(m.results, plan, nowDay());
  if (!lightweight) {
    const y = Number(nowDay().slice(0, 4));
    const nextPlan = await getExtraPlan(env, y + 1);
    const cycles = new Map([...plan.allocations, ...nextPlan.allocations].map((a) => [a.cycle_id + ":" + a.month, a]));
    result.forecastPlan = { ...plan, allocations: [...cycles.values()] };
  }
  if (lightweight) return result;
  const gap = Math.max(
    0,
    Math.round(
      (result.lifetime.income - result.lifetime.spent - result.summary.totalAssets) * 100
    )
  );
  const adjustment2 = await env.DB.prepare(
    "INSERT INTO financial_reporting_adjustments(id,label,amount_cents,as_of_day,method) VALUES ('legacy_spending','Spese storiche non dettagliate',?,?, 'Stima autorizzata: redditi documentati meno spese registrate meno liquidita rilevata alla data della stima') ON CONFLICT(id) DO UPDATE SET id=excluded.id RETURNING *"
  ).bind(gap, (/* @__PURE__ */ new Date()).toISOString().slice(0, 10)).first();
  result.lifetime.recordedSpent = result.lifetime.spent;
  result.lifetime.historicalSpendingEstimate = {
    ...adjustment2,
    amount: adjustment2.amount_cents / 100
  };
  if (adjustment2.amount_cents > 0) {
    const amount = adjustment2.amount_cents / 100;
    result.lifetime.spent = Math.round((result.lifetime.spent + amount) * 100) / 100;
    result.lifetime.expenses.push({
      name: adjustment2.label,
      amount,
      estimated: true
    });
    const group = result.lifetime.expenseGroups.find((g) => g.id === 10) || result.lifetime.expenseGroups.find(
      (g) => g.members.includes("Pagamenti non dettagliati")
    );
    if (group) {
      group.amount = Math.round((group.amount + amount) * 100) / 100;
      group.members.push(adjustment2.label);
    }
    result.lifetime.expenseGroups.sort((a, b) => b.amount - a.amount);
    for (const group2 of result.lifetime.expenseGroups)
      group2.percentage = Math.round(
        group2.amount / result.lifetime.spent * 100
      );
    result.lifetime.expenseAudit.push({
      row: null,
      date: "Storico",
      name: adjustment2.label,
      amount,
      category: adjustment2.label,
      account: "Conti precedenti",
      estimated: true
    });
  }
  result.extraPlan = plan;
  result.categoryOptions = [...FINANCE_MANUAL_CATEGORIES];
  return result;
}
async function getFinanceRaw(env, offset) {
  await ensureTrStatement(env);
  const n = Number(offset);
  if (!Number.isInteger(n) || n < 0 || n > 1e5 || n % 50 !== 0)
    throw Error("Pagina non valida.");
  const movements = (await env.DB.prepare(
    "SELECT * FROM movements ORDER BY source_row LIMIT 50 OFFSET ?"
  ).bind(n).all()).results;
  return { movements };
}
async function getFinanceMeta(env) {
  await ensureTrStatement(env);
  const [count, extras, config, snapshots, events] = await Promise.all([
    env.DB.prepare("SELECT COUNT(*) AS total FROM movements").first(),
    env.DB.prepare("SELECT * FROM extraordinary ORDER BY source_row").all(),
    env.DB.prepare(
      "SELECT sheet,row_number,values_json FROM source_rows ORDER BY sheet,row_number"
    ).all(),
    env.DB.prepare("SELECT * FROM account_balance_snapshots ORDER BY id").all(),
    env.DB.prepare("SELECT * FROM account_balance_events ORDER BY id").all()
  ]);
  return {
    total: count.total,
    extras: extras.results,
    config: config.results,
    bankSnapshots: snapshots.results,
    bankEvents: events.results
  };
}
async function updateSheetRow(env, sheet, rowNumber, change) {
  const found = await env.DB.prepare(
    "SELECT values_json FROM source_rows WHERE sheet=? AND row_number=?"
  ).bind(sheet, rowNumber).first();
  if (!found)
    throw Error(
      "Configurazione non importata: " + sheet + " riga " + rowNumber
    );
  const values = JSON.parse(found.values_json);
  change(values);
  await env.DB.prepare(
    "UPDATE source_rows SET values_json=? WHERE sheet=? AND row_number=?"
  ).bind(JSON.stringify(values), sheet, rowNumber).run();
}
async function saveEstimate(env, name, value) {
  if (name === "Condominio") {
    const n2 = Number(value);
    if (!Number.isFinite(n2) || n2 < 0 || n2 > 1e3 || Math.abs(Math.round(n2 * 100) / 100 - n2) > 1e-8) throw Error("Stima non valida: usa massimo due decimali.");
    const stored = await env.DB.prepare("SELECT value FROM os_meta WHERE key='condominium_estimates_v1'").first();
    const settings = stored?.value ? JSON.parse(stored.value) : { base: 0, changes: [{ month: "2026-10", value: 25 }] }, month2 = nowDay().slice(0, 7);
    settings.changes = [...(settings.changes || []).filter((x) => x.month !== month2), { month: month2, value: Math.round(n2 * 100) / 100 }];
    await env.DB.prepare("INSERT INTO os_meta(key,value) VALUES ('condominium_estimates_v1',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value").bind(JSON.stringify(settings)).run();
    return true;
  }
  const index = {
    "Elettricit\xE0": 2,
    Gas: 3,
    Acqua: 4,
    Palestra: 5,
    Abbonamenti: 6,
    Benzina: 7
  }[name];
  if (!index) throw Error("Voce non valida.");
  let n = Number(value);
  if (!Number.isFinite(n) || n < 0 || n > 1e3 || Math.abs(Math.round(n * 100) / 100 - n) > 1e-8)
    throw Error("Stima non valida: usa massimo due decimali.");
  if (["Elettricit\xE0", "Gas", "Acqua"].includes(name)) {
    const stored = await env.DB.prepare("SELECT value FROM os_meta WHERE key='utility_estimates_v1'").first();
    const settings = stored?.value ? JSON.parse(stored.value) : {};
    const prior = await env.DB.prepare("SELECT values_json FROM source_rows WHERE sheet='Budget' AND row_number=?").bind(index).first();
    const config = settings[name] || { base: Number(prior ? JSON.parse(prior.values_json)[1] : n) || 0, changes: [] };
    const month2 = nowDay().slice(0, 7);
    config.changes = [...(config.changes || []).filter((x) => x.month !== month2), { month: month2, value: n }];
    settings[name] = config;
    const path = '$."' + name + '"', encoded = JSON.stringify(config);
    await env.DB.prepare("INSERT INTO os_meta(key,value) VALUES ('utility_estimates_v1',json_set('{}',?,json(?))) ON CONFLICT(key) DO UPDATE SET value=json_set(os_meta.value,?,json(?))").bind(path, encoded, path, encoded).run();
  } else await updateSheetRow(env, "Budget", index, (row) => row[1] = n);
  return true;
}
function insertedBalanceEvent(env, importId, absorbedId = null) {
  return env.DB.prepare(
    `INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row,absorbed_snapshot_id)
  SELECT account,substr(actual_date,1,10),CAST(ROUND(amount*100) AS INTEGER),source_row,?
  FROM movements WHERE import_id=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')`
  ).bind(absorbedId, importId);
}
async function getMovement(env, id) {
  if (!Number.isInteger(id) || id < 2) throw Error("Movimento non valido.");
  const row = await env.DB.prepare("SELECT * FROM movements WHERE source_row=?").bind(id).first();
  if (!row) throw Error("Movimento non trovato. Aggiorna la pagina.");
  await ensureBudgetPolicies(env);
  const policy = await env.DB.prepare("SELECT * FROM movement_budget_policies WHERE movement_source_row=?").bind(id).first();
  return { ...row, budgetTreatment: policy?.treatment || "auto", recoveryMonths: policy ? JSON.parse(policy.recovery_json).map((q) => q.month).join(", ") : "", recoveryAmount: policy ? JSON.parse(policy.recovery_json).reduce((n, q) => n + q.amount_cents, 0) / 100 : 0 };
}
async function findMirror(env, row) {
  if (row.transfer_id) {
    const pair = (await env.DB.prepare("SELECT * FROM movements WHERE transfer_id=?").bind(row.transfer_id).all()).results;
    const other = pair.find((x) => x.source_row !== row.source_row);
    if (pair.length !== 2 || !other || row.movement_type !== "Trasferimento" || other.movement_type !== "Trasferimento" || other.account !== row.counterparty_account || other.counterparty_account !== row.account || Math.abs(other.amount + row.amount) >= 5e-3)
      throw Error("Trasferimento non coerente: nessuna modifica applicata.");
    return other;
  }
  if (row.movement_type !== "Trasferimento" || row.source_name !== "App 4.0" || !row.counterparty_account)
    return null;
  const rows = (await env.DB.prepare(
    "SELECT * FROM movements WHERE source_row<>? AND transfer_id IS NULL AND movement_type='Trasferimento' AND source_name='App 4.0' AND account=? AND counterparty_account=? AND actual_date=? AND ABS(amount+?)<0.005"
  ).bind(
    row.source_row,
    row.counterparty_account,
    row.account,
    row.actual_date,
    row.amount
  ).all()).results;
  if (rows.length !== 1)
    throw Error(
      "Trasferimento storico ambiguo o incompleto: nessuna modifica applicata."
    );
  return rows[0];
}
async function saveMovementEdit(env, input) {
  const old = await getMovement(env, Number(input?.row));
  if (![
    "Spesa",
    "Entrata",
    "Trasferimento",
    "Investimento",
    "Da verificare"
  ].includes(old.movement_type))
    throw Error("Tipo storico non modificabile da questa schermata.");
  const type = String(input.type || "");
  if (![
    "Spesa",
    "Entrata",
    "Rimborso",
    "Trasferimento",
    "Investimento",
    "Da verificare"
  ].includes(type))
    throw Error("Tipo non valido.");
  const account = String(input.account || "");
  if (!["Revolut", "Trade Republic", "IsyBank"].includes(account))
    throw Error("Conto non valido.");
  let counterpart = type === "Trasferimento" ? String(input.counterpart || "") : "";
  if (type === "Trasferimento" && (!["Revolut", "Trade Republic", "IsyBank"].includes(counterpart) || counterpart === account))
    throw Error("Conto di destinazione non valido.");
  const name = String(input.name || "").trim().slice(0, 120), day2 = validDate(input.date), amount = validCents(input.amount) / 100;
  if (!name || day2 > nowDay()) throw Error("Descrizione o data non valida.");
  const months2 = Number(input.months ?? 1);
  if (!Number.isInteger(months2) || months2 < 1 || months2 > 12)
    throw Error("Mesi coperti non validi.");
  const category = type === "Trasferimento" ? "Altro" : String(input.category || "Altro").trim().slice(0, 60);
  const signed = type === "Rimborso" || type === "Entrata" ? amount : ["Investimento", "Da verificare", "Trasferimento", "Spesa"].includes(
    type
  ) && old.movement_type === type && old.amount > 0 && !String(old.notes || "").startsWith("Rimborso / restituzione:") ? amount : -amount;
  const end = new Date(
    Date.UTC(
      Number(day2.slice(0, 4)),
      Number(day2.slice(5, 7)) - 1 + months2,
      0
    )
  ).toISOString().slice(0, 7) + "-01";
  const mirror = await findMirror(env, old);
  const linked = (await env.DB.prepare(
    `SELECT DISTINCT cycle_id FROM extraordinary_movement_links
  WHERE movement_source_row IN (${mirror ? "?,?" : "?"})`
  ).bind(
    ...mirror ? [old.source_row, mirror.source_row] : [old.source_row]
  ).all()).results;
  if (linked.length && (account !== old.account || mirror && counterpart !== old.counterparty_account))
    throw Error(
      "Un conto \xE8 collegato a una straordinaria: scollega prima il movimento."
    );
  const settlement = linked.length ? await env.DB.prepare("SELECT * FROM extraordinary_settlements WHERE movement_source_row=?").bind(old.source_row).first() : null;
  if (linked.length) {
    const attributed = await env.DB.prepare("SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE movement_source_row=?").bind(old.source_row).first();
    const required = Number(attributed.n) - (settlement ? Math.min(settlement.actual_cents, settlement.planned_cents) : 0) + (settlement ? Math.min(Math.round(-signed * 100), settlement.planned_cents) : 0);
    if (type !== old.movement_type || signed >= 0 || Math.round(-signed * 100) < required) throw Error("Scollega il piano prima di ridurre l\u2019importo attribuito o cambiare il tipo.");
  }
  const query = "UPDATE movements SET actual_date=?,budget_date=?,description=?,amount=?,account=?,category=?,movement_type=?,counterparty_account=?,merchant=?,competence_months=?,budget_month=?,competence_end=?,monthly_share=?,actual_month=?,transfer_id=?,notes=? WHERE source_row=?";
  const sameSchedule = String(old.actual_date || "").slice(0, 10) === day2 && Number(old.competence_months || 1) === months2;
  const budgetMonth = sameSchedule && old.budget_month ? old.budget_month : day2.slice(0, 7) + "-01";
  const competenceEnd = sameSchedule && old.competence_end ? old.competence_end : end;
  const primary = env.DB.prepare(query).bind(
    day2,
    sameSchedule && old.budget_date ? old.budget_date : day2,
    name,
    signed,
    account,
    category,
    type === "Rimborso" ? "Spesa" : type,
    counterpart,
    name,
    months2,
    budgetMonth,
    competenceEnd,
    type === "Spesa" ? -signed / months2 : null,
    day2.slice(0, 7) + "-01",
    type === "Trasferimento" ? old.transfer_id : null,
    (type === "Rimborso" ? "Rimborso / restituzione: " : "") + String(old.notes || "").replace(/^Rimborso \/ restituzione:\s*/, ""),
    old.source_row
  );
  const policyInput = input.budgetTreatment === void 0 ? { ...input, budgetTreatment: type === "Spesa" ? old.budgetTreatment : "auto", recoveryMonths: old.recoveryMonths, recoveryAmount: Math.min(old.recoveryAmount || amount, amount) } : input;
  const policy = validatedBudgetPolicy(policyInput, amount, day2, type);
  if (policy.treatment === "recovery" && signed >= 0) throw Error("Un rimborso non pu\xF2 creare un recupero di spesa.");
  if (linked.length && policy.treatment === "recovery") throw Error("Questo movimento \xE8 gi\xE0 coperto da un piano. Scollegalo prima di creare un recupero.");
  const operations = [primary, budgetPolicyStatement(env, old.source_row, policy), env.DB.prepare("UPDATE movements SET notes=CASE WHEN instr(COALESCE(notes,''),'[Categoria manuale]')>0 THEN notes ELSE COALESCE(notes,'')||' [Categoria manuale]' END WHERE source_row=?").bind(old.source_row)];
  if (settlement) {
    const nextCents = Math.round(-signed * 100), attribute = Math.min(nextCents, settlement.planned_cents);
    const linkUpdate = env.DB.prepare("UPDATE extraordinary_movement_links SET attributed_cents=? WHERE cycle_id=? AND movement_source_row=?").bind(attribute, settlement.cycle_id, old.source_row);
    if (attribute <= Math.min(settlement.actual_cents, settlement.planned_cents)) operations.unshift(linkUpdate);
    else operations.push(linkUpdate);
    operations.push(env.DB.prepare("UPDATE extraordinary_settlements SET actual_cents=? WHERE movement_source_row=?").bind(nextCents, old.source_row));
  }
  const changed = [
    { old, next: { account, actual_date: day2, amount: signed } }
  ];
  if (mirror) {
    if (type === "Trasferimento") {
      operations.push(
        env.DB.prepare(query).bind(
          day2,
          day2,
          "Trasferimento da " + account,
          -signed,
          counterpart,
          "Altro",
          "Trasferimento",
          account,
          "Trasferimento da " + account,
          months2,
          budgetMonth,
          competenceEnd,
          null,
          day2.slice(0, 7) + "-01",
          old.transfer_id,
          mirror.notes || "",
          mirror.source_row
        )
      );
      changed.push({
        old: mirror,
        next: { account: counterpart, actual_date: day2, amount: -signed }
      });
    } else {
      operations.push(
        env.DB.prepare("DELETE FROM movements WHERE source_row=?").bind(
          mirror.source_row
        )
      );
      changed.push({ old: mirror, next: null });
    }
  } else if (type === "Trasferimento" && old.movement_type !== "Trasferimento") {
  }
  const balanceOperations = [];
  for (const item of changed) {
    balanceOperations.push(env.DB.prepare("INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row) SELECT account,substr(actual_date,1,10),-CAST(ROUND(amount*100) AS INTEGER),source_row FROM movements WHERE source_row=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')").bind(item.old.source_row));
    if (item.next && ["Revolut", "Trade Republic"].includes(item.next.account)) balanceOperations.push(env.DB.prepare("INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row) SELECT ?,?,?,source_row FROM movements WHERE source_row=? AND status='Eseguito'").bind(item.next.account, item.next.actual_date, Math.round(item.next.amount * 100), item.old.source_row));
  }
  operations.unshift(...balanceOperations);
  for (const link of linked)
    operations.push(
      env.DB.prepare(
        `UPDATE extraordinary SET status=(
   SELECT status FROM extraordinary_cycles WHERE id=?),paid_date=(
   SELECT MAX(m.actual_date) FROM extraordinary_movement_links l JOIN movements m
   ON m.source_row=l.movement_source_row WHERE l.cycle_id=?)
   WHERE source_row=(SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?)`
      ).bind(link.cycle_id, link.cycle_id, link.cycle_id)
    );
  await env.DB.batch(operations);
  return true;
}
async function deleteMovement(env, id) {
  const old = await getMovement(env, Number(id));
  const mirror = await findMirror(env, old);
  const rows = [old, ...mirror ? [mirror] : []];
  const linked = (await env.DB.prepare(
    `SELECT DISTINCT cycle_id FROM extraordinary_movement_links
   WHERE movement_source_row IN (${rows.map(() => "?").join(",")})`
  ).bind(...rows.map((r) => r.source_row)).all()).results;
  await env.DB.batch([
    // Reverse only rows that STILL exist, inside the same atomic batch as DELETE.
    // Two simultaneous delete requests must not credit the account twice.
    ...rows.map(
      (r) => env.DB.prepare(
        `INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row)
    SELECT account,substr(actual_date,1,10),-CAST(ROUND(amount*100) AS INTEGER),source_row
    FROM movements WHERE source_row=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')`
      ).bind(r.source_row)
    ),
    ...rows.map(
      (r) => env.DB.prepare(
        "DELETE FROM extraordinary_movement_links WHERE movement_source_row=?"
      ).bind(r.source_row)
    ),
    ...rows.map((r) => env.DB.prepare("DELETE FROM movement_budget_policies WHERE movement_source_row=?").bind(r.source_row)),
    ...rows.map((r) => env.DB.prepare("DELETE FROM extraordinary_settlements WHERE movement_source_row=?").bind(r.source_row)),
    ...rows.map(
      (r) => env.DB.prepare("DELETE FROM movements WHERE source_row=?").bind(
        r.source_row
      )
    ),
    ...linked.flatMap((x) => syncExtraStatusStatements(env, x.cycle_id)),
    ...linked.map(
      (x) => env.DB.prepare(
        `UPDATE extraordinary SET status=(
    SELECT status FROM extraordinary_cycles WHERE id=?),
    paid_date=(SELECT MAX(m.actual_date) FROM extraordinary_movement_links l
      JOIN movements m ON m.source_row=l.movement_source_row WHERE l.cycle_id=?)
    WHERE source_row=(SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?)`
      ).bind(x.cycle_id, x.cycle_id, x.cycle_id)
    )
  ]);
  return { deleted: mirror ? 2 : 1 };
}
var lifeSchemaJobs = /* @__PURE__ */ new WeakMap();
async function ensureLife(env) {
  if (!lifeSchemaJobs.has(env.DB))
    lifeSchemaJobs.set(env.DB, initializeLife(env));
  try {
    await lifeSchemaJobs.get(env.DB);
  } catch (error) {
    lifeSchemaJobs.delete(env.DB);
    throw error;
  }
}
async function initializeLife(env) {
  await env.DB.batch([
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_meta (key TEXT PRIMARY KEY,value TEXT NOT NULL)"
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_tasks (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,list_kind TEXT NOT NULL DEFAULT 'action',status TEXT NOT NULL DEFAULT 'todo',due_date TEXT,scheduled_date TEXT,notes TEXT NOT NULL DEFAULT '',import_key TEXT UNIQUE,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,completed_at TEXT)"
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_categories (key TEXT PRIMARY KEY,label TEXT NOT NULL COLLATE NOCASE UNIQUE,position INTEGER NOT NULL DEFAULT 0)"
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_shifts (day TEXT PRIMARY KEY,kind TEXT NOT NULL,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)"
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_events (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,day TEXT NOT NULL,start_time TEXT,end_time TEXT,location TEXT NOT NULL DEFAULT '',notes TEXT NOT NULL DEFAULT '',created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)"
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_event_repeat (event_id INTEGER PRIMARY KEY,frequency TEXT NOT NULL,until_day TEXT)"
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_routines (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,position INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)"
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_routine_checks (routine_id INTEGER NOT NULL,day TEXT NOT NULL,checked_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY(routine_id,day))"
    )
  ]);
  await env.DB.batch(
    [
      ["action", "Attivit\xE0", 0],
      ["wishlist", "Desideri", 1],
      ["games", "Giochi", 2],
      ["books", "Letture", 3]
    ].map(
      ([key, label, position]) => env.DB.prepare(
        "INSERT OR IGNORE INTO os_categories(key,label,position) SELECT ?,?,? WHERE NOT EXISTS (SELECT 1 FROM os_meta WHERE key='deleted_category:'||?)"
      ).bind(key, label, position, key)
    )
  );
  const routineColumns = (await env.DB.prepare("PRAGMA table_info(os_routines)").all()).results;
  if (!routineColumns.some((c) => c.name === "schedule_json")) {
    try {
      await env.DB.prepare("ALTER TABLE os_routines ADD COLUMN schedule_json TEXT").run();
    } catch (error) {
      if (!(await env.DB.prepare("PRAGMA table_info(os_routines)").all()).results.some((c) => c.name === "schedule_json")) throw error;
    }
  }
  const columns = (await env.DB.prepare("PRAGMA table_info(os_tasks)").all()).results;
  if (!columns.some((column) => column.name === "sort_order")) {
    try {
      await env.DB.prepare(
        "ALTER TABLE os_tasks ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0"
      ).run();
    } catch (error) {
      const fresh = (await env.DB.prepare("PRAGMA table_info(os_tasks)").all()).results;
      if (!fresh.some((column) => column.name === "sort_order")) throw error;
    }
  }
  await env.DB.batch([
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_event_occurrences(event_id INTEGER NOT NULL,day TEXT NOT NULL,status TEXT NOT NULL,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY(event_id,day))"
    ),
    env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_os_tasks_list_order ON os_tasks(list_kind,status,sort_order,id)"
    ),
    env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_os_events_day ON os_events(day)"
    )
  ]);
}
var validMonthKey = (s) => typeof s === "string" && /^20\d\d-(0[1-9]|1[0-2])$/.test(s);
var validClock = (s) => s === null || s === "" || typeof s === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(s);
async function lifeRead(env, focus) {
  await ensureLife(env);
  await env.DB.prepare(
    "DELETE FROM os_tasks WHERE status='done' AND completed_at IS NOT NULL AND strftime('%s',completed_at)<=strftime('%s','now','-5 days')"
  ).run();
  const base = validMonthKey(focus) ? focus : nowDay().slice(0, 7);
  const first = /* @__PURE__ */ new Date(base + "-01T12:00:00Z");
  const low = new Date(
    Date.UTC(first.getUTCFullYear(), first.getUTCMonth() - 1, 1)
  ).toISOString().slice(0, 10);
  const high = new Date(
    Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 2, 1)
  ).toISOString().slice(0, 10);
  const today = nowDay(), end = new Date(Date.parse(today + "T12:00:00Z") + 6 * 864e5).toISOString().slice(0, 10), clock = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Rome",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  }).format(/* @__PURE__ */ new Date());
  const [tasks, categories, shifts, events, routines, occurrences] = await Promise.all([
    env.DB.prepare(
      "SELECT * FROM os_tasks ORDER BY CASE status WHEN 'todo' THEN 0 WHEN 'waiting' THEN 1 ELSE 2 END,sort_order,id"
    ).all(),
    env.DB.prepare(
      "SELECT * FROM os_categories ORDER BY position,label"
    ).all(),
    env.DB.prepare(
      "SELECT * FROM os_shifts WHERE (day>=? AND day<?) OR day=? OR day=? ORDER BY day"
    ).bind(
      low,
      high,
      today,
      new Date(Date.parse(today + "T12:00:00Z") + 864e5).toISOString().slice(0, 10)
    ).all(),
    env.DB.prepare(
      "SELECT e.*,r.frequency,r.until_day FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.day<? ORDER BY e.day"
    ).bind(high).all(),
    env.DB.prepare(
      "SELECT r.id,r.title,r.position,r.schedule_json,CASE WHEN c.routine_id IS NULL THEN 0 ELSE 1 END AS checked FROM os_routines r LEFT JOIN os_routine_checks c ON c.routine_id=r.id AND c.day=? ORDER BY r.position,r.id"
    ).bind(today).all(),
    env.DB.prepare(
      "SELECT event_id,day,status FROM os_event_occurrences"
    ).all()
  ]);
  const all = await env.DB.prepare(
    "SELECT e.*,r.frequency,r.until_day FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.day<=?"
  ).bind(end).all();
  const next = new Date(Date.parse(end + "T12:00:00Z") + 864e5).toISOString().slice(0, 10);
  const statusMap = new Map(
    occurrences.results.map((o) => [o.event_id + ":" + o.day, o.status])
  );
  const state = (e) => ({
    ...e,
    occurrence_status: statusMap.get(e.id + ":" + e.day) || "open"
  });
  return {
    tasks: tasks.results,
    categories: categories.results,
    shifts: shifts.results,
    events: expandEvents(events.results, low, high).map(state).filter((e) => e.occurrence_status !== "skipped"),
    upcomingEvents: expandEvents(all.results, today, next).map(state).filter(
      (e) => e.occurrence_status === "open" && (e.day > today || !e.start_time || e.start_time >= clock)
    ).slice(0, 3),
    routines: routines.results.map(({ schedule_json, ...r }) => ({ ...r, schedule: habitSchedule(schedule_json == null ? void 0 : JSON.parse(schedule_json)) })),
    routineScheduleVersion: 1,
    today,
    month: base
  };
}
async function lifeAction(env, method, args) {
  const x = args[0];
  if (method === "getLifeData") return lifeRead(env, x);
  await ensureLife(env);
  if (method === "setRoutineCheck") {
    const id = Number(x?.id), checked = x?.checked;
    if (!Number.isInteger(id) || id < 1 || typeof checked !== "boolean")
      throw Error("Routine non valida.");
    if (x.day !== nowDay())
      throw Error(
        "\xC8 iniziato un nuovo giorno. Aggiorna la routine e riprova."
      );
    const routine = await env.DB.prepare("SELECT schedule_json FROM os_routines WHERE id=?").bind(id).first();
    if (!routine) throw Error("Abitudine non trovata.");
    if (checked && !habitDue({ schedule: habitSchedule(routine.schedule_json == null ? void 0 : JSON.parse(routine.schedule_json)) }, x.day)) throw Error("Questa abitudine non \xE8 prevista per oggi.");
    if (checked)
      await env.DB.prepare(
        "INSERT OR IGNORE INTO os_routine_checks(routine_id,day) VALUES (?,?)"
      ).bind(id, nowDay()).run();
    else
      await env.DB.prepare(
        "DELETE FROM os_routine_checks WHERE routine_id=? AND day=?"
      ).bind(id, nowDay()).run();
    return true;
  }
  if (method === "saveRoutine") {
    const title = String(x?.title || "").trim().slice(0, 60), id = Number(x?.id || 0);
    if (!title) throw Error("Inserisci un nome.");
    if (!Number.isInteger(id) || id < 0) throw Error("Routine non valida.");
    const schedule = x?.schedule === void 0 ? void 0 : JSON.stringify(habitSchedule(x.schedule));
    if (id) {
      const result = await env.DB.prepare(
        schedule === void 0 ? "UPDATE os_routines SET title=? WHERE id=?" : "UPDATE os_routines SET title=?,schedule_json=? WHERE id=?"
      ).bind(...schedule === void 0 ? [title, id] : [title, schedule, id]).run();
      if (result.meta.changes !== 1) throw Error("Routine non trovata.");
      return true;
    }
    const count = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM os_routines"
    ).first();
    if (count.n >= 100) throw Error("Massimo 100 abitudini.");
    await env.DB.prepare("INSERT INTO os_routines(title,position,schedule_json) VALUES (?,?,?)").bind(title, count.n, schedule ?? JSON.stringify(habitSchedule(void 0))).run();
    return true;
  }
  if (method === "deleteRoutine") {
    const id = Number(x);
    if (!Number.isInteger(id) || id < 1) throw Error("Routine non valida.");
    await env.DB.batch([
      env.DB.prepare("DELETE FROM os_routine_checks WHERE routine_id=?").bind(
        id
      ),
      env.DB.prepare("DELETE FROM os_routines WHERE id=?").bind(id)
    ]);
    return true;
  }
  if (method === "addCategory") {
    const label = String(x?.label || "").trim().slice(0, 40);
    if (!label) throw Error("Indica un nome per la categoria.");
    const duplicate = await env.DB.prepare(
      "SELECT key FROM os_categories WHERE label=? COLLATE NOCASE"
    ).bind(label).first();
    if (duplicate) throw Error("Questa categoria esiste gi\xE0.");
    const key = "custom-" + crypto.randomUUID(), position = (await env.DB.prepare(
      "SELECT COALESCE(MAX(position),0)+1 AS n FROM os_categories"
    ).first()).n;
    await env.DB.prepare(
      "INSERT INTO os_categories(key,label,position) VALUES (?,?,?)"
    ).bind(key, label, position).run();
    return { key, label };
  }
  if (method === "deleteCategory") {
    const key = String(x?.key || ""), destination = String(x?.destination || "");
    if (!key || key === destination) throw Error("Scegli una categoria diversa per le attivit\xE0.");
    const rows = (await env.DB.prepare("SELECT key FROM os_categories").all()).results;
    if (rows.length < 2 || !rows.some((r) => r.key === key) || !rows.some((r) => r.key === destination)) throw Error("Categoria non valida.");
    await env.DB.batch([
      env.DB.prepare("UPDATE os_tasks SET list_kind=? WHERE list_kind=?").bind(destination, key),
      env.DB.prepare("INSERT OR REPLACE INTO os_meta(key,value) VALUES (?, '1')").bind("deleted_category:" + key),
      env.DB.prepare("DELETE FROM os_categories WHERE key=?").bind(key)
    ]);
    return true;
  }
  if (method === "renameCategory") {
    const key = String(x?.key || ""), label = String(x?.label || "").trim().slice(0, 40);
    if (!label) throw Error("Indica un nome per la categoria.");
    const r = await env.DB.prepare(
      "UPDATE os_categories SET label=? WHERE key=?"
    ).bind(label, key).run();
    if (r.meta.changes !== 1) throw Error("Categoria non trovata.");
    return true;
  }
  if (method === "reorderCategories") {
    const keys = x?.keys, current = (await env.DB.prepare("SELECT key FROM os_categories").all()).results.map((r) => r.key);
    if (!Array.isArray(keys) || keys.length !== current.length || new Set(keys).size !== keys.length || keys.some((k) => !current.includes(k)))
      throw Error("Le categorie sono cambiate: ricarica e riprova.");
    await env.DB.batch(
      keys.map(
        (key, position) => env.DB.prepare("UPDATE os_categories SET position=? WHERE key=?").bind(
          position,
          key
        )
      )
    );
    return true;
  }
  if (method === "reorderTasks") {
    const category = String(x?.category || ""), ids = x?.ids;
    if (!Array.isArray(ids) || ids.length > 500 || !ids.every((id) => Number.isInteger(id) && id > 0) || new Set(ids).size !== ids.length)
      throw Error("Ordine non valido.");
    const rows = (await env.DB.prepare(
      "SELECT id FROM os_tasks WHERE list_kind=? AND status='todo' ORDER BY sort_order,id"
    ).bind(category).all()).results;
    if (rows.length !== ids.length || rows.some((r) => !ids.includes(r.id)))
      throw Error("La lista \xE8 cambiata. Aggiorna e riprova.");
    if (ids.length)
      await env.DB.batch(
        ids.map(
          (id, i) => env.DB.prepare(
            "UPDATE os_tasks SET sort_order=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND list_kind=? AND status='todo'"
          ).bind(i + 1, id, category)
        )
      );
    return true;
  }
  if (method === "deleteCompletedTasks") {
    const category = String(x?.category || "");
    if (!await env.DB.prepare("SELECT key FROM os_categories WHERE key=?").bind(category).first())
      throw Error("Categoria non trovata.");
    await env.DB.prepare(
      "DELETE FROM os_tasks WHERE list_kind=? AND status='done'"
    ).bind(category).run();
    return true;
  }
  if (method === "saveTask") {
    const title = String(x?.title || "").trim().slice(0, 160), notes = String(x?.notes || "").trim().slice(0, 1e3), kind = String(x?.list_kind || "action");
    if (!title || !await env.DB.prepare("SELECT key FROM os_categories WHERE key=?").bind(kind).first())
      throw Error("Attivit\xE0 o categoria non valida.");
    const due = x.due_date ? validDate(x.due_date) : null, scheduled = x.scheduled_date ? validDate(x.scheduled_date) : null;
    if (x.id) {
      const id = Number(x.id);
      if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
      const r = await env.DB.prepare(
        "UPDATE os_tasks SET title=?,list_kind=?,sort_order=CASE WHEN list_kind=? THEN sort_order ELSE (SELECT COALESCE(MAX(sort_order),0)+1 FROM os_tasks WHERE list_kind=?) END,notes=?,due_date=?,scheduled_date=?,updated_at=CURRENT_TIMESTAMP WHERE id=?"
      ).bind(title, kind, kind, kind, notes, due, scheduled, id).run();
      if (r.meta.changes !== 1) throw Error("Attivit\xE0 non trovata.");
      return true;
    }
    await env.DB.prepare(
      "INSERT INTO os_tasks(title,list_kind,notes,due_date,scheduled_date,sort_order) VALUES (?,?,?,?,?,(SELECT COALESCE(MAX(sort_order),0)+1 FROM os_tasks WHERE list_kind=?))"
    ).bind(title, kind, notes, due, scheduled, kind).run();
    return true;
  }
  if (method === "setTaskStatus") {
    const id = Number(x?.id), status = String(x?.status || "");
    if (!Number.isInteger(id) || id < 1 || !["todo", "waiting", "done"].includes(status))
      throw Error("Stato non valido.");
    const r = await env.DB.prepare(
      "UPDATE os_tasks SET status=?,completed_at=CASE WHEN ?='done' THEN COALESCE(completed_at,strftime('%Y-%m-%dT%H:%M:%SZ','now')) ELSE NULL END,updated_at=CURRENT_TIMESTAMP WHERE id=?"
    ).bind(status, status, id).run();
    if (r.meta.changes !== 1) throw Error("Attivit\xE0 non trovata.");
    return true;
  }
  if (method === "deleteTask") {
    const id = Number(x);
    if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
    await env.DB.prepare("DELETE FROM os_tasks WHERE id=?").bind(id).run();
    return true;
  }
  if (method === "paintShift") {
    const day2 = validDate(x?.day), kind = String(x?.kind || "");
    if (kind === "erase") {
      await env.DB.prepare("DELETE FROM os_shifts WHERE day=?").bind(day2).run();
      return true;
    }
    if (!["morning", "afternoon", "night", "holiday", "rest"].includes(kind))
      throw Error("Turno non valido.");
    await env.DB.prepare(
      "INSERT INTO os_shifts(day,kind) VALUES (?,?) ON CONFLICT(day) DO UPDATE SET kind=excluded.kind,updated_at=CURRENT_TIMESTAMP"
    ).bind(day2, kind).run();
    return true;
  }
  if (method === "saveEvent") {
    const title = String(x?.title || "").trim().slice(0, 140), day2 = validDate(x?.day), start = x?.start_time || null, end = x?.end_time || null;
    if (!title || !validClock(start) || !validClock(end) || end && !start)
      throw Error("Evento o orario non valido.");
    const place = String(x?.location || "").trim().slice(0, 160), notes = String(x?.notes || "").trim().slice(0, 1e3);
    const frequency = x.frequency || "none", until = x.until_day ? validDate(x.until_day) : null;
    if (!["none", "weekly", "monthly", "yearly"].includes(frequency) || until && until < day2)
      throw Error("Ricorrenza o data finale non valida.");
    if (x.id) {
      const id = Number(x.id);
      if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
      const old = await env.DB.prepare(
        "SELECT e.day,r.frequency FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.id=?"
      ).bind(id).first();
      if (!old) throw Error("Evento non trovato.");
      if (old.day !== day2 || old.frequency !== frequency) {
        const exceptions = await env.DB.prepare(
          "SELECT COUNT(*) AS n FROM os_event_occurrences WHERE event_id=?"
        ).bind(id).first();
        if (exceptions.n)
          throw Error(
            "Questa serie ha occorrenze segnate: per conservare la storia usa Modifica da qui o riaprile prima di cambiare la regola."
          );
      }
      await env.DB.batch([
        env.DB.prepare(
          "UPDATE os_events SET title=?,day=?,start_time=?,end_time=?,location=?,notes=?,updated_at=CURRENT_TIMESTAMP WHERE id=?"
        ).bind(title, day2, start, end, place, notes, id),
        env.DB.prepare(
          "INSERT INTO os_event_repeat(event_id,frequency,until_day) VALUES (?,?,?) ON CONFLICT(event_id) DO UPDATE SET frequency=excluded.frequency,until_day=excluded.until_day"
        ).bind(id, frequency, until)
      ]);
      return true;
    }
    await env.DB.batch([
      env.DB.prepare(
        "INSERT INTO os_events(title,day,start_time,end_time,location,notes) VALUES (?,?,?,?,?,?)"
      ).bind(title, day2, start, end, place, notes),
      env.DB.prepare(
        "INSERT INTO os_event_repeat(event_id,frequency,until_day) VALUES (last_insert_rowid(),?,?)"
      ).bind(frequency, until)
    ]);
    return true;
  }
  if (method === "setEventOccurrence") {
    const id = Number(x?.id), day2 = validDate(x?.day), status = String(x?.status || "");
    if (!Number.isInteger(id) || id < 1 || !["open", "done", "skipped"].includes(status))
      throw Error("Occorrenza non valida.");
    const event = await env.DB.prepare(
      "SELECT e.*,r.frequency,r.until_day FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.id=?"
    ).bind(id).first();
    const next = new Date(Date.parse(day2 + "T12:00:00Z") + 864e5).toISOString().slice(0, 10);
    if (!event || !expandEvents([event], day2, next).some((e) => e.day === day2))
      throw Error("Questa occorrenza non esiste.");
    if (status === "open")
      await env.DB.prepare(
        "DELETE FROM os_event_occurrences WHERE event_id=? AND day=?"
      ).bind(id, day2).run();
    else
      await env.DB.prepare(
        "INSERT INTO os_event_occurrences(event_id,day,status) VALUES (?,?,?) ON CONFLICT(event_id,day) DO UPDATE SET status=excluded.status,updated_at=CURRENT_TIMESTAMP"
      ).bind(id, day2, status).run();
    return true;
  }
  if (method === "splitEventSeries") {
    const id = Number(x?.id), from = validDate(x?.split_from), day2 = validDate(x?.day);
    if (!Number.isInteger(id) || id < 1) throw Error("Serie non valida.");
    const original = await env.DB.prepare(
      "SELECT e.*,r.frequency,r.until_day FROM os_events e JOIN os_event_repeat r ON r.event_id=e.id WHERE e.id=?"
    ).bind(id).first();
    if (!original || !["weekly", "monthly", "yearly"].includes(original.frequency))
      throw Error("La ricorrenza non esiste.");
    const following = new Date(Date.parse(from + "T12:00:00Z") + 864e5).toISOString().slice(0, 10);
    const instances = expandEvents([original], original.day, following);
    if (!instances.some((e) => e.day === from))
      throw Error("La data scelta non appartiene alla serie.");
    const previous = instances.filter((e) => e.day < from).at(-1)?.day || "";
    if (day2 <= previous)
      throw Error("La nuova data deve seguire la precedente occorrenza.");
    const title = String(x?.title || "").trim().slice(0, 140), start = x?.start_time || null, end = x?.end_time || null;
    const frequency = String(x?.frequency || "none"), until = x?.until_day ? validDate(x.until_day) : null;
    if (!title || !validClock(start) || !validClock(end) || end && !start || !["none", "weekly", "monthly", "yearly"].includes(frequency) || until && until < day2)
      throw Error("Nuova scadenza non valida.");
    const futureExceptions = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM os_event_occurrences WHERE event_id=? AND day>=?"
    ).bind(id, from).first();
    if (futureExceptions.n)
      throw Error(
        "Ci sono occorrenze gi\xE0 completate o saltate da questa data: riaprile prima di modificare la serie."
      );
    const oldEnd = new Date(Date.parse(from + "T12:00:00Z") - 864e5).toISOString().slice(0, 10);
    const place = String(x?.location || "").trim().slice(0, 160), notes = String(x?.notes || "").trim().slice(0, 1e3);
    await env.DB.batch([
      env.DB.prepare(
        "UPDATE os_event_repeat SET until_day=? WHERE event_id=?"
      ).bind(oldEnd, id),
      env.DB.prepare(
        "INSERT INTO os_events(title,day,start_time,end_time,location,notes) VALUES (?,?,?,?,?,?)"
      ).bind(title, day2, start, end, place, notes),
      env.DB.prepare(
        "INSERT INTO os_event_repeat(event_id,frequency,until_day) VALUES (last_insert_rowid(),?,?)"
      ).bind(frequency, until)
    ]);
    return true;
  }
  if (method === "deleteEvent") {
    const id = Number(x);
    if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
    await env.DB.batch([
      env.DB.prepare("DELETE FROM os_event_occurrences WHERE event_id=?").bind(
        id
      ),
      env.DB.prepare("DELETE FROM os_event_repeat WHERE event_id=?").bind(id),
      env.DB.prepare("DELETE FROM os_events WHERE id=?").bind(id)
    ]);
    return true;
  }
  throw Error("Operazione non disponibile.");
}
async function saveTransaction(env, input) {
  await ensureBudgetPolicies(env);
  if (!input || !["Spesa", "Entrata", "Rimborso", "Trasferimento"].includes(input.type))
    throw Error("Tipo non valido.");
  const closingTransfer = input.type === "Trasferimento" && input.account === "Revolut" && input.counterpart === "Trade Republic";
  if (input.account !== "Trade Republic" && !closingTransfer)
    throw Error("Il conto operativo \xE8 Trade Republic.");
  if (input.type === "Trasferimento" && !closingTransfer)
    throw Error("\xC8 disponibile solo il trasferimento finale da Revolut a Trade Republic.");
  let amount = validCents(input.amount) / 100, day2 = validDate(input.date), name = String(input.name || "").trim().slice(0, 120);
  if (day2 > nowDay()) throw Error("Per spese future usa Straordinarie.");
  if (!name) throw Error("Indica una descrizione.");
  const policy = validatedBudgetPolicy(input, amount, day2, input.type);
  const requestId = String(input.requestId || crypto.randomUUID());
  if (!/^[a-zA-Z0-9-]{8,80}$/.test(requestId)) throw Error("Identificativo richiesta non valido.");
  const fingerprint2 = JSON.stringify({ type: input.type, amount, day: day2, name, account: input.account, category: input.category || "Altro", months: input.months || 1, counterpart: input.counterpart || "", note: input.note || "", snapshot: !!input.includedInSnapshot, policy });
  const previous = await env.DB.prepare("SELECT fingerprint FROM finance_write_requests WHERE id=?").bind(requestId).first();
  if (previous) {
    if (previous.fingerprint !== fingerprint2) throw Error("Richiesta gi\xE0 usata con dati diversi. Riapri il modulo.");
    return true;
  }
  let covered = Number(input.months ?? 1);
  if (!Number.isInteger(covered) || covered < 1 || covered > 12)
    throw Error("Mesi coperti non validi.");
  if (input.type === "Trasferimento" && (!["Revolut", "Trade Republic"].includes(input.counterpart) || input.counterpart === input.account))
    throw Error("Indica un altro conto.");
  let absorbedId = null;
  if (input.includedInSnapshot) {
    if (input.type === "Trasferimento")
      throw Error(
        "Per un trasferimento usa i due conti, non la spunta dello snapshot."
      );
    const snapshot = await env.DB.prepare(
      "SELECT id,as_of_day FROM account_balance_snapshots WHERE account=? ORDER BY as_of_day DESC,id DESC LIMIT 1"
    ).bind(input.account).first();
    if (!snapshot || day2 > snapshot.as_of_day)
      throw Error("Questa data non \xE8 precedente al saldo rilevato.");
    absorbedId = snapshot.id;
  }
  let signed = ["Spesa", "Trasferimento"].includes(input.type) ? -amount : amount;
  let category = input.type === "Trasferimento" ? "Altro" : String(input.category || "Altro").trim().slice(0, 60);
  let actual = day2.slice(0, 7), start = day2.slice(0, 7) + "-01";
  let end = new Date(
    Date.UTC(
      Number(day2.slice(0, 4)),
      Number(day2.slice(5, 7)) - 1 + covered,
      0
    )
  ).toISOString().slice(0, 7) + "-01";
  let r = {
    budget_date: day2,
    actual_date: day2,
    description: name,
    amount: signed,
    account: input.account,
    category,
    movement_type: input.type === "Rimborso" ? "Spesa" : input.type,
    status: "Eseguito",
    competence_months: covered,
    baseline: "No",
    counterparty_account: input.type === "Trasferimento" ? input.counterpart : "",
    notes: (input.type === "Rimborso" ? "Rimborso / restituzione: " : "") + String(input.note || "").slice(0, 200) + " [Categoria manuale]",
    merchant: name,
    source_name: "App 4.0",
    import_id: "APP-" + requestId,
    budget_month: start,
    competence_end: end,
    monthly_share: input.type === "Spesa" ? amount / covered : null,
    actual_month: start,
    transfer_id: input.type === "Trasferimento" ? crypto.randomUUID() : null
  };
  const claim = env.DB.prepare("INSERT OR IGNORE INTO finance_write_requests(id,fingerprint) VALUES (?,?)").bind(requestId, fingerprint2);
  const insertOnce = (movement) => env.DB.prepare(`INSERT INTO movements (source_row,${MOVEMENT_COLUMNS.slice(1).join(",")}) SELECT MAX((SELECT COALESCE(MAX(source_row),1) FROM movements),(SELECT COALESCE(MAX(movement_source_row),1) FROM account_balance_events))+1,${MOVEMENT_COLUMNS.slice(1).map(() => "?").join(",")} WHERE NOT EXISTS (SELECT 1 FROM movements WHERE import_id=?) AND EXISTS (SELECT 1 FROM finance_write_requests WHERE id=? AND fingerprint=?)`).bind(...MOVEMENT_COLUMNS.slice(1).map((k) => movement[k] ?? null), movement.import_id, requestId, fingerprint2);
  const eventOnce = (id, snapshot = null) => env.DB.prepare(`INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row,absorbed_snapshot_id) SELECT account,substr(actual_date,1,10),CAST(ROUND(amount*100) AS INTEGER),source_row,? FROM movements m WHERE import_id=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic') AND NOT EXISTS(SELECT 1 FROM account_balance_events WHERE movement_source_row=m.source_row)`).bind(snapshot, id);
  const ops = [claim, insertOnce(r), eventOnce(r.import_id, absorbedId)];
  if (input.type === "Trasferimento") {
    const other = { ...r, description: "Trasferimento da " + input.account, amount, account: input.counterpart, category: "Altro", counterparty_account: input.account, import_id: r.import_id + "-PAIR", monthly_share: null };
    ops.push(insertOnce(other), eventOnce(other.import_id));
  } else {
    ops.push(env.DB.prepare("INSERT OR IGNORE INTO movement_budget_policies(movement_source_row,treatment,recovery_json) SELECT source_row,?,? FROM movements WHERE import_id=?").bind(policy.treatment, JSON.stringify(policy.recovery), r.import_id));
  }
  await env.DB.batch(ops);
  const committed = await env.DB.prepare("SELECT fingerprint FROM finance_write_requests WHERE id=?").bind(requestId).first();
  if (committed.fingerprint !== fingerprint2) throw Error("Richiesta gi\xE0 usata con dati diversi. Riapri il modulo.");
  return true;
}
async function getExtraPlan(env, year) {
  await ensureBudgetPolicies(env);
  const y = planYear(year);
  await env.DB.batch([
    env.DB.prepare(
      `WITH RECURSIVE requested(y) AS
    (SELECT ? UNION ALL SELECT y+1 FROM requested WHERE y<?)
    INSERT OR IGNORE INTO extraordinary_cycles
      (extraordinary_source_row,start_month,end_month,total_cents,kind,status)
    SELECT e.source_row,
      substr(date(e.start_month,'+'||(12*(requested.y-CAST(substr(e.start_month,1,4) AS INTEGER)))||' months'),1,7),
      substr(date(e.end_month,'+'||(12*(requested.y-CAST(substr(e.start_month,1,4) AS INTEGER)))||' months'),1,7),
      CAST(ROUND(e.total*100) AS INTEGER),'expense','Programmato'
    FROM extraordinary e,requested
    WHERE e.repeat_rule='Annuale' AND e.status!='Annullato'
      AND requested.y>=CAST(substr(e.start_month,1,4) AS INTEGER)`
    ).bind(y - 1, y),
    env.DB.prepare(
      `WITH RECURSIVE seq(n) AS
    (SELECT 0 UNION ALL SELECT n+1 FROM seq WHERE n<11)
    INSERT OR IGNORE INTO extraordinary_allocations(cycle_id,month,amount_cents)
    SELECT c.id,substr(date(c.start_month||'-01','+'||seq.n||' months'),1,7),
      CAST(c.total_cents/12 AS INTEGER)+CASE WHEN seq.n<c.total_cents%12 THEN 1 ELSE 0 END
    FROM extraordinary_cycles c JOIN extraordinary e ON e.source_row=c.extraordinary_source_row,seq
    WHERE e.repeat_rule='Annuale' AND c.start_month>=? AND c.start_month<?`
    ).bind(y - 1 + "-01", y + 1 + "-01")
  ]);
  const [allocations, ledger] = await Promise.all([
    env.DB.prepare(
      `SELECT a.cycle_id,a.month,a.amount_cents,c.kind,c.status,e.name,
    c.extraordinary_source_row,c.start_month,c.end_month,c.total_cents,e.payment_account,e.paid_date FROM extraordinary_allocations a
    JOIN extraordinary_cycles c ON c.id=a.cycle_id
    JOIN extraordinary e ON e.source_row=c.extraordinary_source_row
    WHERE a.month>=? AND a.month<? ORDER BY a.month,e.name`
    ).bind(y + "-01", y + 1 + "-01").all(),
    env.DB.prepare(`SELECT
      (SELECT json_group_array(json_object('cycle_id',l.cycle_id,'movement_source_row',l.movement_source_row,'attributed_cents',l.attributed_cents,'role',l.role,'actual_date',m.actual_date,'account',m.account,'amount',m.amount)) FROM extraordinary_movement_links l JOIN movements m ON m.source_row=l.movement_source_row) links,
      (SELECT json_group_array(json_object('cycle_id',cycle_id,'movement_source_row',movement_source_row,'planned_cents',planned_cents,'actual_cents',actual_cents)) FROM extraordinary_settlements) settlements`).first()
  ]);
  return { allocations: allocations.results, links: JSON.parse(ledger.links), settlements: JSON.parse(ledger.settlements) };
}
async function getExtraCycle(env, id) {
  await ensureBudgetPolicies(env);
  if (!Number.isInteger(id) || id < 1) throw Error("Ciclo non valido.");
  const cycle = await env.DB.prepare(
    "SELECT * FROM extraordinary_cycles WHERE id=?"
  ).bind(id).first();
  if (!cycle)
    throw Error(
      "Ciclo straordinario non trovato. Applica prima la migrazione."
    );
  return cycle;
}
async function getExtraCycleDetail(env, id) {
  const cycle = await getExtraCycle(env, id);
  const [extra, linked] = await Promise.all([
    env.DB.prepare(
      "SELECT name,notes,payment_account,repeat_rule FROM extraordinary WHERE source_row=?"
    ).bind(cycle.extraordinary_source_row).first(),
    env.DB.prepare(
      "SELECT COALESCE(SUM(attributed_cents),0) total FROM extraordinary_movement_links WHERE cycle_id=?"
    ).bind(id).first()
  ]);
  if (!extra) throw Error("Voce straordinaria non trovata.");
  return {
    ...cycle,
    name: extra.name,
    notes: extra.notes,
    account: extra.payment_account,
    repeat: extra.repeat_rule,
    linked_cents: linked.total
  };
}
async function updateExtraPlan(env, input) {
  const id = Number(input?.cycleId);
  if (!Number.isSafeInteger(id) || id < 1) throw Error("Ciclo non valido.");
  const cycle = await getExtraCycleDetail(env, id);
  const cents2 = validCents(input?.amount), start = String(input?.month || ""), end = String(input?.endMonth || "");
  if (!/^20\d\d-(0[1-9]|1[0-2])$/.test(start) || !/^20\d\d-(0[1-9]|1[0-2])$/.test(end))
    throw Error("Mese non valido.");
  const months2 = (Number(end.slice(0, 4)) - Number(start.slice(0, 4))) * 12 + Number(end.slice(5)) - Number(start.slice(5)) + 1;
  if (months2 < 1 || months2 > 60) throw Error("Durata non valida.");
  if (cents2 < Number(cycle.linked_cents))
    throw Error(
      "Il totale non pu\xF2 essere inferiore ai pagamenti gi\xE0 collegati."
    );
  const annual = cycle.repeat === "Annuale";
  if (annual && (start !== cycle.start_month || months2 !== 12))
    throw Error(
      "Per un ciclo annuale puoi modificare il totale; il periodo resta quello della ricorrenza."
    );
  const name = String(input?.name || "").trim().slice(0, 100);
  const account = String(input?.account || "");
  if (!name || (cycle.kind === "budget_advance" ? account !== cycle.account : !["Revolut", "Trade Republic"].includes(account)))
    throw Error("Voce o conto non valido.");
  const note = String(input?.note || "").slice(0, 200);
  const shares = Array.from(
    { length: months2 },
    (_, i) => Math.floor(cents2 / months2) + (i < cents2 % months2 ? 1 : 0)
  );
  const allocations = shares.map((amount, i) => {
    const date2 = new Date(
      Date.UTC(Number(start.slice(0, 4)), Number(start.slice(5)) - 1 + i, 1)
    );
    return env.DB.prepare(
      "INSERT INTO extraordinary_allocations(cycle_id,month,amount_cents) VALUES (?,?,?)"
    ).bind(id, date2.toISOString().slice(0, 7), amount);
  });
  const operations = [
    env.DB.prepare(
      "UPDATE extraordinary_cycles SET start_month=?,end_month=?,total_cents=? WHERE id=?"
    ).bind(start, end, cents2, id),
    env.DB.prepare(
      "DELETE FROM extraordinary_allocations WHERE cycle_id=?"
    ).bind(id),
    ...allocations
  ];
  if (!annual)
    operations.push(
      env.DB.prepare(
        `UPDATE extraordinary SET name=?,total=?,start_month=?,month_count=?,monthly_share=?,end_month=?,payment_account=?,notes=? WHERE source_row=?`
      ).bind(
        name,
        cents2 / 100,
        start + "-01",
        months2,
        cents2 / 100 / months2,
        end + "-01",
        account,
        note,
        cycle.extraordinary_source_row
      )
    );
  else
    operations.push(
      env.DB.prepare(
        "UPDATE extraordinary SET name=?,payment_account=?,notes=? WHERE source_row=?"
      ).bind(name, account, note, cycle.extraordinary_source_row)
    );
  operations.push(
    ...annual ? syncExtraStatusStatements(env, id).slice(0, 1) : syncExtraStatusStatements(env, id)
  );
  await env.DB.batch(operations);
  return { cycleId: id, months: months2, total_cents: cents2 };
}
function syncExtraStatusStatements(env, cycleId) {
  return [
    env.DB.prepare(
      `UPDATE extraordinary_cycles SET status=CASE
   WHEN status='Annullato' THEN 'Annullato'
   WHEN EXISTS(SELECT 1 FROM extraordinary_settlements s JOIN movements m ON m.source_row=s.movement_source_row WHERE s.cycle_id=extraordinary_cycles.id) THEN 'Pagato'
   WHEN (SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=?)
     >=total_cents THEN CASE WHEN kind='budget_advance' THEN 'Anticipato' ELSE 'Pagato' END
   WHEN status IN ('Pagato','Anticipato','Da riconciliare') THEN 'Da riconciliare'
   ELSE status END WHERE id=?`
    ).bind(cycleId, cycleId),
    env.DB.prepare(
      `UPDATE extraordinary SET status=(SELECT status FROM extraordinary_cycles WHERE id=?),
   paid_date=(SELECT MAX(m.actual_date) FROM extraordinary_movement_links l
     JOIN movements m ON m.source_row=l.movement_source_row WHERE l.cycle_id=?)
   WHERE source_row=(SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?)`
    ).bind(cycleId, cycleId, cycleId)
  ];
}
async function linkExtraMovement(env, input) {
  const cycleId = Number(input?.cycleId), movementId = Number(input?.movementId);
  const cents2 = validCents(input?.amount);
  if (!Number.isInteger(cycleId) || !Number.isInteger(movementId) || !Number.isSafeInteger(cents2))
    throw Error("Collegamento non valido.");
  const cycle = await getExtraCycle(env, cycleId);
  const movement = await getMovement(env, movementId);
  if (movement.status !== "Eseguito" || Number(movement.amount) >= 0 || movement.movement_type !== (cycle.kind === "budget_advance" ? "Trasferimento" : "Spesa") || !["Trade Republic", "Revolut"].includes(movement.account)) throw Error("Movimento non compatibile con il piano.");
  if (movement.budgetTreatment === "recovery") throw Error("Il movimento ha gi\xE0 un recupero: rimuovilo prima di collegare il piano.");
  const existing = await env.DB.prepare("SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE movement_source_row=?").bind(movementId).first();
  const paid = await env.DB.prepare("SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE cycle_id=?").bind(cycleId).first();
  if (["Annullato", "Pagato"].includes(cycle.status) || cents2 + Number(existing.n) > Math.round(-movement.amount * 100) || cents2 + Number(paid.n) > cycle.total_cents) throw Error("Importo gi\xE0 attribuito o superiore al residuo del piano.");
  const role = cycle.kind === "budget_advance" ? "budget_advance" : "payment";
  const result = await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO extraordinary_movement_links
   (cycle_id,movement_source_row,attributed_cents,role)
   SELECT ?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM extraordinary_movement_links WHERE cycle_id=? AND movement_source_row=?)
   AND (SELECT CAST(ROUND(-amount*100) AS INTEGER) FROM movements WHERE source_row=?)-(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE movement_source_row=?)>=?
   AND (SELECT total_cents FROM extraordinary_cycles WHERE id=? AND status NOT IN ('Annullato','Pagato'))-(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=?)>=?
   AND NOT EXISTS(SELECT 1 FROM movement_budget_policies WHERE movement_source_row=? AND treatment='recovery')`
    ).bind(cycleId, movementId, cents2, role, cycleId, movementId, movementId, movementId, cents2, cycleId, cycleId, cents2, movementId),
    ...syncExtraStatusStatements(env, cycleId)
  ]);
  if (result[0].meta.changes !== 1) throw Error("Il movimento o il piano \xE8 cambiato: ricarica prima di collegarlo.");
  return true;
}
async function unlinkExtraMovement(env, input) {
  const cycleId = Number(input?.cycleId), movementId = Number(input?.movementId);
  if (!Number.isInteger(cycleId) || !Number.isInteger(movementId))
    throw Error("Collegamento non valido.");
  await getExtraCycle(env, cycleId);
  await env.DB.batch([
    env.DB.prepare(
      "DELETE FROM extraordinary_movement_links WHERE cycle_id=? AND movement_source_row=?"
    ).bind(cycleId, movementId),
    env.DB.prepare("DELETE FROM extraordinary_settlements WHERE cycle_id=? AND movement_source_row=?").bind(cycleId, movementId),
    ...syncExtraStatusStatements(env, cycleId)
  ]);
  return true;
}
async function recordExtraPayment(env, input) {
  const cycleId = Number(input?.cycleId), cycle = await getExtraCycle(env, cycleId);
  if (cycle.kind !== "expense" || cycle.status === "Annullato")
    throw Error("Questa voce non \xE8 pagabile.");
  const cents2 = validCents(input?.amount), amount = cents2 / 100, day2 = validDate(input?.date);
  const linked = (await env.DB.prepare(
    "SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE cycle_id=?"
  ).bind(cycleId).first()).n;
  if (cycle.status === "Pagato" || linked >= cycle.total_cents) {
    const prior = await env.DB.prepare("SELECT actual_cents FROM extraordinary_settlements WHERE cycle_id=?").bind(cycleId).first();
    if (prior && prior.actual_cents !== cents2) throw Error("Questo ciclo \xE8 gi\xE0 pagato con un importo diverso. Correggi il movimento esistente.");
    return { alreadyPaid: true };
  }
  const expectedRemaining = cycle.total_cents - linked, attributed = Math.min(cents2, expectedRemaining);
  if (day2 > nowDay()) throw Error("La data del pagamento \xE8 futura.");
  const account = String(input?.account || ""), name = String(input?.name || "").trim().slice(0, 120);
  if (account !== "Trade Republic" || !name)
    throw Error("Conto o descrizione non validi.");
  const extra = await env.DB.prepare(
    "SELECT name FROM extraordinary WHERE source_row=?"
  ).bind(cycle.extraordinary_source_row).first();
  const month2 = day2.slice(0, 7) + "-01", importId = "APP-" + crypto.randomUUID();
  const r = {
    budget_date: day2,
    actual_date: day2,
    description: name,
    amount: -amount,
    account,
    category: "Straordinarie",
    movement_type: "Spesa",
    status: "Eseguito",
    competence_months: 1,
    baseline: "No",
    counterparty_account: "",
    notes: "Pagamento " + extra.name,
    merchant: name,
    source_name: "App 4.0",
    import_id: importId,
    budget_month: month2,
    competence_end: month2,
    monthly_share: amount,
    actual_month: month2
  };
  const columns = MOVEMENT_COLUMNS.slice(1);
  const insert = env.DB.prepare(
    `INSERT INTO movements (source_row,${columns.join(",")})
   SELECT MAX((SELECT COALESCE(MAX(source_row),1) FROM movements),(SELECT COALESCE(MAX(movement_source_row),1) FROM account_balance_events))+1,${columns.map(() => "?").join(",")} WHERE EXISTS (SELECT 1 FROM extraordinary_cycles c WHERE c.id=? AND c.status NOT IN ('Annullato','Pagato') AND NOT EXISTS(SELECT 1 FROM extraordinary_settlements WHERE cycle_id=c.id) AND c.total_cents-(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=c.id)=?)`
  ).bind(...columns.map((k) => r[k] ?? null), cycleId, expectedRemaining);
  const batch = await env.DB.batch([
    insert,
    insertedBalanceEvent(env, importId),
    env.DB.prepare(
      `INSERT INTO extraordinary_movement_links
   (cycle_id,movement_source_row,attributed_cents,role)
   SELECT ?,source_row,?,'payment' FROM movements WHERE import_id=?`
    ).bind(cycleId, attributed, importId),
    env.DB.prepare("INSERT OR IGNORE INTO extraordinary_settlements(cycle_id,movement_source_row,planned_cents,actual_cents) SELECT ?,source_row,?,? FROM movements WHERE import_id=?").bind(cycleId, expectedRemaining, cents2, importId),
    ...syncExtraStatusStatements(env, cycleId),
    env.DB.prepare(
      "UPDATE extraordinary SET payment_account=? WHERE source_row=? AND EXISTS(SELECT 1 FROM movements WHERE import_id=?)"
    ).bind(account, cycle.extraordinary_source_row, importId)
  ]);
  if (batch[0].meta.changes !== 1) {
    const current = await env.DB.prepare("SELECT c.status,c.total_cents,(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=c.id) linked_cents FROM extraordinary_cycles c WHERE c.id=?").bind(cycleId).first();
    if (!current || current.status === "Annullato" || current.status !== "Pagato" && current.linked_cents < current.total_cents) throw Error("Il piano \xE8 cambiato durante il pagamento. Aggiorna la pagina e verifica l\u2019importo prima di riprovare.");
    const prior = await env.DB.prepare("SELECT actual_cents FROM extraordinary_settlements WHERE cycle_id=?").bind(cycleId).first();
    if (prior && prior.actual_cents !== cents2) throw Error("Questo ciclo \xE8 gi\xE0 pagato con un importo diverso. Correggi il movimento esistente.");
    return { alreadyPaid: true };
  }
  return { movementId: batch[0].meta.last_row_id };
}
async function saveExtra(env, input) {
  await ensureBudgetPolicies(env);
  let name = String(input?.name || "").trim().slice(0, 100), cents2 = validCents(input?.amount), total = cents2 / 100, start = String(input?.month || ""), end = String(input?.endMonth || "");
  if (!/^20\d\d-(0[1-9]|1[0-2])$/.test(start) || !/^20\d\d-(0[1-9]|1[0-2])$/.test(end) || !name)
    throw Error("Voce o mese non valido.");
  let months2 = (Number(end.slice(0, 4)) - Number(start.slice(0, 4))) * 12 + Number(end.slice(5)) - Number(start.slice(5)) + 1;
  if (months2 < 1 || months2 > 60) throw Error("Durata non valida.");
  if (!["Previsto", "Programmato", "Annullato"].includes(input.status) || input.account !== "Trade Republic")
    throw Error(
      "Crea la voce come Programmato; per Pagato o Anticipato collega un movimento."
    );
  if (input.repeat === "Annuale" && months2 !== 12)
    throw Error("Annuale richiede 12 mesi inclusi.");
  let value = {
    name,
    total,
    start_month: start + "-01",
    month_count: months2,
    monthly_share: total / months2,
    end_month: end + "-01",
    status: input.status,
    payment_account: input.account,
    paid_date: null,
    notes: String(input.note || "").slice(0, 200),
    repeat_rule: input.repeat === "Annuale" ? "Annuale" : "No"
  };
  const requestId = String(input.requestId || crypto.randomUUID());
  if (!/^[a-zA-Z0-9-]{8,80}$/.test(requestId)) throw Error("Identificativo richiesta non valido.");
  const fingerprint2 = JSON.stringify(value), previous = await env.DB.prepare("SELECT * FROM finance_extra_requests WHERE id=?").bind(requestId).first();
  if (previous) {
    if (previous.fingerprint !== fingerprint2) throw Error("Richiesta gi\xE0 usata con dati diversi. Riapri il modulo.");
    return { row: previous.source_row };
  }
  const columns = EXTRAS_COLUMNS.slice(1);
  await env.DB.batch([
    env.DB.prepare(`INSERT INTO extraordinary(source_row,${columns.join(",")}) SELECT MAX((SELECT COALESCE(MAX(source_row),1) FROM extraordinary),(SELECT COALESCE(MAX(source_row),1) FROM finance_extra_requests))+1,${columns.map(() => "?").join(",")} WHERE NOT EXISTS(SELECT 1 FROM finance_extra_requests WHERE id=?)`).bind(...columns.map((k) => value[k] ?? null), requestId),
    env.DB.prepare("INSERT OR IGNORE INTO finance_extra_requests(id,source_row,fingerprint) SELECT ?,MAX(source_row),? FROM extraordinary WHERE NOT EXISTS(SELECT 1 FROM finance_extra_requests WHERE id=?)").bind(requestId, fingerprint2, requestId),
    env.DB.prepare("INSERT OR IGNORE INTO extraordinary_cycles(extraordinary_source_row,start_month,end_month,total_cents,kind,status) SELECT source_row,?,?,?,'expense',? FROM finance_extra_requests WHERE id=? AND fingerprint=?").bind(start, end, cents2, input.status, requestId, fingerprint2),
    env.DB.prepare(`WITH RECURSIVE seq(n) AS (SELECT 0 UNION ALL SELECT n+1 FROM seq WHERE n+1<?)
      INSERT OR IGNORE INTO extraordinary_allocations(cycle_id,month,amount_cents)
      SELECT c.id,substr(date(?,'+'||seq.n||' months'),1,7),CAST(?/? AS INTEGER)+CASE WHEN seq.n<?%? THEN 1 ELSE 0 END
      FROM extraordinary_cycles c JOIN finance_extra_requests r ON r.source_row=c.extraordinary_source_row,seq WHERE r.id=? AND r.fingerprint=? AND c.start_month=?`).bind(months2, start + "-01", cents2, months2, cents2, months2, requestId, fingerprint2, start)
  ]);
  const result = await env.DB.prepare("SELECT * FROM finance_extra_requests WHERE id=?").bind(requestId).first();
  if (result.fingerprint !== fingerprint2) throw Error("Richiesta gi\xE0 usata con dati diversi. Riapri il modulo.");
  return { row: result.source_row };
}
async function setExtraStatus(env, row, previous, next, paidDate) {
  if (!Number.isInteger(row) || row < 2 || !["Previsto", "Programmato", "Pagato", "Anticipato", "Annullato"].includes(
    next
  ))
    throw Error("Stato non valido.");
  if (next === "Pagato" || next === "Anticipato")
    throw Error(
      "Per segnare pagata o anticipata una voce, collega il movimento bancario."
    );
  const cycle = await env.DB.prepare(
    "SELECT id FROM extraordinary_cycles WHERE extraordinary_source_row=? ORDER BY id DESC LIMIT 1"
  ).bind(row).first();
  if (!cycle) throw Error("Applica prima la migrazione delle straordinarie.");
  const linked = await env.DB.prepare(
    "SELECT 1 FROM extraordinary_movement_links WHERE cycle_id=? LIMIT 1"
  ).bind(cycle.id).first();
  if (linked)
    throw Error(
      "La voce ha movimenti collegati: scollegali prima di cambiarne lo stato."
    );
  const result = await env.DB.batch([
    env.DB.prepare(
      "UPDATE extraordinary SET status=? WHERE source_row=? AND status=?"
    ).bind(next, row, previous),
    env.DB.prepare(
      "UPDATE extraordinary_cycles SET status=? WHERE id=? AND status=?"
    ).bind(next, cycle.id, previous)
  ]);
  if (result[0].meta.changes !== 1 || result[1].meta.changes !== 1)
    throw Error("La voce \xE8 stata modificata: ricarica la pagina.");
  return true;
}
async function markExtraPaid(env, input) {
  const c = await getExtraCycleDetail(env, Number(input?.cycleId));
  if (c.status === "Pagato" || c.linked_cents >= c.total_cents)
    return { alreadyPaid: true };
  return recordExtraPayment(env, {
    cycleId: c.id,
    amount: (c.total_cents - c.linked_cents) / 100,
    account: "Trade Republic",
    name: c.name,
    date: nowDay()
  });
}
async function cancelExtraCycle(env, input) {
  const c = await getExtraCycleDetail(env, Number(input?.cycleId));
  await env.DB.batch([
    env.DB.prepare(
      "UPDATE extraordinary_cycles SET status='Annullato' WHERE id=?"
    ).bind(c.id),
    ...c.repeat === "Annuale" ? [] : [
      env.DB.prepare(
        "UPDATE extraordinary SET status='Annullato' WHERE source_row=?"
      ).bind(c.extraordinary_source_row)
    ]
  ]);
  return true;
}
async function deleteExtraPlan(env, input) {
  const c = await getExtraCycleDetail(env, Number(input?.cycleId));
  const linked = await env.DB.prepare(
    "SELECT 1 FROM extraordinary_movement_links l JOIN extraordinary_cycles c ON c.id=l.cycle_id WHERE c.extraordinary_source_row=? LIMIT 1"
  ).bind(c.extraordinary_source_row).first();
  if (linked)
    throw Error(
      "I pagamenti sono nello storico: puoi annullare il piano, ma non eliminarlo."
    );
  if (c.status !== "Annullato")
    throw Error("Annulla la voce prima di eliminarla.");
  await env.DB.batch([
    env.DB.prepare(
      "DELETE FROM extraordinary_allocations WHERE cycle_id IN (SELECT id FROM extraordinary_cycles WHERE extraordinary_source_row=?)"
    ).bind(c.extraordinary_source_row),
    env.DB.prepare(
      "DELETE FROM extraordinary_cycles WHERE extraordinary_source_row=?"
    ).bind(c.extraordinary_source_row),
    env.DB.prepare("DELETE FROM extraordinary WHERE source_row=?").bind(
      c.extraordinary_source_row
    )
  ]);
  return true;
}
async function classifyMovement(env, id, category) {
  id = Number(id);
  category = String(category || "").trim();
  if (!Number.isSafeInteger(id) || id < 1 || !category || category.length > 80)
    throw Error("Categoria non valida.");
  const current = await env.DB.prepare(
    "SELECT source_row FROM movements WHERE source_row=?"
  ).bind(id).first();
  if (!current) throw Error("Movimento non trovato.");
  await env.DB.prepare(
    "UPDATE movements SET category=?,notes=CASE WHEN instr(COALESCE(notes,''),'[Categoria manuale]')>0 THEN notes ELSE COALESCE(notes,'')||' [Categoria manuale]' END WHERE source_row=?"
  ).bind(category, id).run();
  return true;
}
async function getFinanceCategoryPeriod(env, last, count) {
  if (typeof last !== "string" || !/^20\d\d-(0[1-9]|1[0-2])$/.test(last) || ![3, 6, 12].includes(count)) throw Error("Periodo categorie non valido.");
  const [year, number] = last.split("-").map(Number), first = new Date(Date.UTC(year, number - count, 1)).toISOString().slice(0, 7);
  await ensureFinanceCategories(env);
  const result = await env.DB.prepare(`SELECT substr(m.actual_date,1,7) month,COALESCE(c.detail_category,NULLIF(m.category,''),'Altro') name,SUM(CAST(ROUND(-m.amount*100) AS INTEGER)) cents
    FROM movements m LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row
    WHERE m.account IN ('Trade Republic','Revolut') AND m.status='Eseguito' AND m.movement_type='Spesa' AND m.amount<0
      AND m.actual_date>=? AND m.actual_date<?
    GROUP BY substr(m.actual_date,1,7),COALESCE(c.detail_category,NULLIF(m.category,''),'Altro')`).bind(first + "-01", new Date(Date.UTC(year, number, 1)).toISOString().slice(0, 10)).all();
  const months2 = Array.from({ length: count }, (_, i) => new Date(Date.UTC(year, number - count + i, 1)).toISOString().slice(0, 7));
  return { version: 1, months: months2.map((month2) => ({ month: month2, categories: result.results.filter((r) => r.month === month2).map((r) => ({ name: r.name, amount: Number(r.cents) / 100 })) })) };
}
async function writeAction(env, method, args) {
  if ([
    "getLifeData",
    "addCategory",
    "renameCategory",
    "deleteCategory",
    "reorderCategories",
    "reorderTasks",
    "deleteCompletedTasks",
    "saveTask",
    "setEventOccurrence",
    "splitEventSeries",
    "setTaskStatus",
    "deleteTask",
    "paintShift",
    "saveEvent",
    "deleteEvent",
    "setRoutineCheck",
    "saveRoutine",
    "deleteRoutine"
  ].includes(method))
    return lifeAction(env, method, args);
  switch (method) {
    case "getFinanceCategoryPeriod":
      return getFinanceCategoryPeriod(env, args[0], args[1]);
    case "getFinanceCategoryOptions":
      await ensureFinanceCategories(env);
      return [...FINANCE_MANUAL_CATEGORIES];
    case "classifyMovement":
      return classifyMovement(env, args[0], args[1]);
    case "getMovement":
      return getMovement(env, Number(args[0]));
    case "editMovement":
      return saveMovementEdit(env, args[0]);
    case "deleteMovement":
      return deleteMovement(env, args[0]);
    case "saveTransaction":
      return saveTransaction(env, args[0]);
    case "saveRecurringPayment": {
      let x = args[0];
      if (!ALLOWED_RECURRING.includes(x?.name)) throw Error("Voce non valida.");
      return saveTransaction(env, {
        type: "Spesa",
        account: x.account || "Trade Republic",
        amount: x.amount,
        name: x.name,
        category: x.name,
        date: x.date,
        note: x.note,
        months: x.months ?? 1,
        requestId: x.requestId
      });
    }
    case "markExtraPaid":
      return markExtraPaid(env, args[0]);
    case "cancelExtraCycle":
      return cancelExtraCycle(env, args[0]);
    case "deleteExtraPlan":
      return deleteExtraPlan(env, args[0]);
    case "saveExtra":
      return saveExtra(env, args[0]);
    case "setExtraStatus":
      return setExtraStatus(env, Number(args[0]), args[1], args[2], args[3]);
    case "getExtraPlan":
      return getExtraPlan(env, args[0]);
    case "getExtraCycleDetail":
      return getExtraCycleDetail(env, Number(args[0]));
    case "updateExtraPlan":
      return updateExtraPlan(env, args[0]);
    case "linkExtraMovement":
      return linkExtraMovement(env, args[0]);
    case "unlinkExtraMovement":
      return unlinkExtraMovement(env, args[0]);
    case "recordExtraPayment":
      return recordExtraPayment(env, args[0]);
    case "saveEstimate":
      return saveEstimate(env, args[0], args[1]);
    case "savePlanningSettings": {
      const { goal: target, saving: monthly } = planningInputs(args[0], args[1]);
      const existing = await env.DB.prepare(
        "SELECT row_number,values_json FROM source_rows WHERE sheet='Budget' AND row_number IN (13,14)"
      ).all();
      const rows = new Map(
        existing.results.map((r) => [r.row_number, JSON.parse(r.values_json)])
      );
      const statements = [
        [13, target],
        [14, monthly]
      ].map(([rowNumber, value]) => {
        const row = rows.get(rowNumber) || Array(15).fill("");
        row[14] = value;
        return env.DB.prepare(
          "INSERT INTO source_rows(sheet,row_number,values_json) VALUES ('Budget',?,?) ON CONFLICT(sheet,row_number) DO UPDATE SET values_json=excluded.values_json"
        ).bind(rowNumber, JSON.stringify(row));
      });
      if (args.length >= 3) {
        const savingsTarget = Number(args[2]);
        if (!Number.isFinite(savingsTarget) || savingsTarget <= 0 || savingsTarget > 1e6) throw Error("Obiettivo non valido.");
        statements.push(env.DB.prepare("INSERT INTO source_rows(sheet,row_number,values_json) VALUES ('LifeOS Settings',1,?) ON CONFLICT(sheet,row_number) DO UPDATE SET values_json=excluded.values_json").bind(JSON.stringify([Math.round(savingsTarget * 100) / 100])));
      }
      await env.DB.batch(statements);
      return true;
    }
    case "saveRevolutSnapshot":
      throw Error("Revolut \xE8 un conto storico. Aggiorna il saldo Trade Republic.");
    case "saveAssetBalance":
      throw Error("Il saldo si aggiorna attraverso i movimenti; la modifica manuale \xE8 disattivata.");
    default:
      throw Error("Operazione non disponibile.");
  }
}
var runtime_generated_default = {
  async fetch(request, env, ctx) {
    const url = new URL(request.url), path = url.pathname;
    if (request.method === "GET" && path === "/apple-touch-icon.png")
      return icon(ICON_180);
    if (request.method === "GET" && path === "/favicon.png")
      return icon(ICON_64);
    if (request.method === "GET" && path === "/manifest.webmanifest")
      return Response.json(
        {
          name: "Life OS",
          short_name: "Life OS",
          start_url: "/",
          scope: "/",
          display: "standalone",
          background_color: "#0c0c0e",
          theme_color: "#0c0c0e",
          icons: [
            {
              src: "/apple-touch-icon.png?v=1146growth",
              sizes: "180x180",
              type: "image/png"
            }
          ]
        },
        {
          headers: {
            "content-type": "application/manifest+json",
            "cache-control": "public, max-age=86400"
          }
        }
      );
    const accessEmail = String(env.ACCESS_EMAIL || "").trim().toLowerCase();
    if (accessEmail) {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(accessEmail))
        return fail("Configura ACCESS_EMAIL con il tuo indirizzo Google.", 503);
      if (!ctx?.access)
        return fail(
          "Attiva Cloudflare Access su questo Worker e accedi con Google.",
          403
        );
      let identity;
      try {
        identity = await ctx.access.getIdentity();
      } catch {
        return fail("Identit\xE0 Cloudflare Access non disponibile.", 403);
      }
      if (String(identity?.email || "").toLowerCase() !== accessEmail)
        return fail("Questo account Google non \xE8 autorizzato.", 403);
    } else {
      if (request.method === "GET" && path === "/login")
        return new Response(LOGIN_PAGE, {
          headers: {
            ...noCache,
            "content-type": "text/html; charset=utf-8",
            "x-frame-options": "DENY",
            "content-security-policy": "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'"
          }
        });
      if (!env.APP_PASSWORD || env.APP_PASSWORD.length < 24)
        return fail(
          "Configura il Secret APP_PASSWORD di almeno 24 caratteri.",
          503
        );
      if (request.method === "POST" && path === "/auth/login") {
        if (request.headers.get("origin") !== url.origin)
          return fail("Origine non valida.", 403);
        if (Number(request.headers.get("content-length") || 0) > 2e3)
          return fail("Richiesta troppo grande.", 413);
        let input;
        try {
          input = await request.json();
        } catch {
          return fail("JSON non valido.", 400);
        }
        if (input?.user !== "nas" || typeof input.password !== "string" || input.password.length > 1e3 || input.password !== env.APP_PASSWORD)
          return fail("Credenziali non valide.", 401);
        return new Response("{}", {
          headers: {
            ...noCache,
            "content-type": "application/json",
            "set-cookie": await sessionCookie(env.APP_PASSWORD)
          }
        });
      }
      if (!await validSession(request, env.APP_PASSWORD) && !await checkPassword(request, env.APP_PASSWORD)) {
        if (request.method === "GET")
          return new Response(null, {
            status: 302,
            headers: { ...noCache, location: "/login" }
          });
        return fail("Sessione scaduta. Riapri l\u2019app e accedi.", 401);
      }
    }
    if (!env.DB) return fail("Aggiungi il binding D1 con nome DB.", 503);
    if (request.method === "GET") {
      if (path === "/")
        return new Response(APP_HTML, {
          headers: {
            ...noCache,
            "content-type": "text/html; charset=utf-8",
            "x-frame-options": "DENY",
            "content-security-policy": "default-src 'self' data:; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://api.open-meteo.com"
          }
        });
      if (path === "/setup")
        return new Response(CONFIG_PAGE, {
          headers: {
            ...noCache,
            "content-type": "text/html; charset=utf-8",
            "x-frame-options": "DENY",
            "content-security-policy": "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'"
          }
        });
      return fail("Non trovato.", 404);
    }
    if (request.method !== "POST") return fail("Metodo non disponibile.", 405);
    if (request.headers.get("origin") !== url.origin)
      return fail("Origine non valida.", 403);
    if (path === "/api/import-config") {
      if (Number(request.headers.get("content-length") || 0) > 15e4)
        return fail("Blocco troppo grande.", 413);
      let rows;
      try {
        rows = await request.json();
      } catch {
        return fail("JSON non valido.", 400);
      }
      if (!Array.isArray(rows) || rows.length < 1 || rows.length > 20 || rows.some(
        (r) => !r || typeof r.sheet !== "string" || r.sheet.length > 60 || !Number.isInteger(r.row_number) || r.row_number < 1 || r.row_number > 5e3 || typeof r.values_json !== "string" || r.values_json.length > 1e5
      ))
        return fail("Dati non validi.", 400);
      await env.DB.prepare(
        "CREATE TABLE IF NOT EXISTS source_rows (sheet TEXT NOT NULL,row_number INTEGER NOT NULL,values_json TEXT NOT NULL,PRIMARY KEY(sheet,row_number))"
      ).run();
      await env.DB.batch(
        rows.map(
          (r) => env.DB.prepare(
            "INSERT OR REPLACE INTO source_rows(sheet,row_number,values_json) VALUES (?,?,?)"
          ).bind(r.sheet, r.row_number, r.values_json)
        )
      );
      return response({ imported: rows.length });
    }
    const method = path.startsWith("/api/") ? path.slice(5) : "";
    let args;
    try {
      args = await request.json();
    } catch {
      return fail("JSON non valido.", 400);
    }
    if (!Array.isArray(args) || args.length > 5)
      return fail("Argomenti non validi.", 400);
    try {
      if (method === "getPlanningProjection")
        return response(await getPlanningProjection(env, args[0], args[1]));
      if (method === "getFinanceData")
        return response(await loadFinance(env, args[0], args[1]));
      if (method === "getFinanceOverview" || method === "getFinanceExtras")
        return response(await loadFinance(env, args[0], args[1], true));
      if (method === "getFinanceRaw")
        return response(await getFinanceRaw(env, args[0]));
      if (method === "getFinanceMeta")
        return response(await getFinanceMeta(env));
      const result = await writeAction(env, method, args);
      if ([
        "classifyMovement",
        "editMovement",
        "deleteMovement",
        "saveTransaction",
        "saveRecurringPayment",
        "recordExtraPayment",
        "markExtraPaid",
        "setExtraStatus"
      ].includes(method))
        await ensureFinanceCategories(env);
      return response(result);
    } catch (e) {
      return fail(String(e.message || e), 400);
    }
  }
};

// backend/plans/engine.mjs
var PlanError = class extends Error {
  constructor(message, status = 422) {
    super(message);
    this.status = status;
  }
};
var fail2 = (message) => {
  throw new PlanError(message);
};
var kinds = ["advance", "goal", "fund", "fixed", "estimated", "recovery"];
function month(value) {
  if (typeof value !== "string" || !/^20\d\d-(0[1-9]|1[0-2])$/.test(value)) fail2("Scegli mese e anno validi.");
  return value;
}
function addMonth(value, count) {
  month(value);
  const [y, m] = value.split("-").map(Number), date2 = new Date(Date.UTC(y, m - 1 + count, 1));
  return date2.toISOString().slice(0, 7);
}
function months(first, last, limit = 240) {
  month(first);
  month(last);
  if (last < first) fail2("L\u2019ultimo mese precede il primo.");
  const count = (Number(last.slice(0, 4)) - Number(first.slice(0, 4))) * 12 + Number(last.slice(-2)) - Number(first.slice(-2)) + 1;
  if (count > limit) fail2("Il piano finito pu\xF2 coprire al massimo 240 mesi; per un fondo usa Senza scadenza.");
  return Array.from({ length: count }, (_, i) => addMonth(first, i));
}
function cents(value) {
  if (!Number.isSafeInteger(value) || value <= 0 || value > 1e8) fail2("Importo non valido.");
  return value;
}
function split(total, count) {
  cents(total);
  if (!Number.isInteger(count) || count < 1 || count > 240) fail2("Numero di mesi non valido.");
  return Array.from({ length: count }, (_, i) => Math.floor(total / count) + (i < total % count ? 1 : 0));
}
function day(value, today) {
  if (typeof value !== "string" || !/^20\d\d-(0[1-9]|1[0-2])-\d\d$/.test(value)) fail2("Data del pagamento non valida.");
  const parsed = /* @__PURE__ */ new Date(value + "T12:00:00Z");
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value || value > today) fail2("La data deve essere valida e non futura.");
  return value;
}
function newPlan(input, today, id) {
  const kind = input.kind, current = month(today.slice(0, 7));
  if (!kinds.includes(kind)) fail2("Scegli il tipo di piano.");
  const name = String(input.name ?? "").trim();
  if (!name || name.length > 120) fail2("Inserisci un nome di massimo 120 caratteri.");
  const first = month(input.startMonth);
  if (first < current) fail2("Le quote nuove possono iniziare dal mese corrente.");
  const finite = ["advance", "goal", "recovery"].includes(kind), last = finite ? month(input.endMonth) : null;
  const amount = cents(input.amountCents), interval = Number(input.intervalMonths ?? 1);
  const category = String(input.category ?? "Altro").trim();
  if (!category || category.length > 60) fail2("Categoria non valida.");
  if (!Number.isInteger(interval) || interval < 1 || interval > 12) fail2("Periodicit\xE0 non valida.");
  if (finite) months(first, last);
  const plan = {
    id,
    name,
    category,
    kind,
    amountCents: amount,
    startMonth: first,
    endMonth: last,
    intervalMonths: interval,
    createdDay: today,
    status: "active",
    stopAfter: null,
    closedMonth: null,
    rateChanges: []
  };
  if (kind === "advance") {
    plan.beneficiaryMonth = month(input.beneficiaryMonth);
    if (plan.beneficiaryMonth < current || plan.beneficiaryMonth >= first) fail2("Il mese beneficiario deve essere aperto e precedere i mesi di recupero.");
  }
  if (kind === "recovery") {
    plan.paymentDate = day(input.paymentDate, today);
    if (first < plan.paymentDate.slice(0, 7)) fail2("Il recupero non pu\xF2 precedere il pagamento.");
    plan.status = "pendingPayment";
  }
  return plan;
}
function contribution(plan, m) {
  month(m);
  if (plan.status === "cancelled" || plan.status === "pendingPayment") return 0;
  if (plan.kind === "advance") {
    if (m === plan.beneficiaryMonth) return -plan.amountCents;
  }
  if (m < plan.startMonth || plan.endMonth && m > plan.endMonth || plan.stopAfter && m > plan.stopAfter || plan.closedMonth && m > plan.closedMonth) return 0;
  if (plan.legacySchedule) return Number(plan.legacySchedule[m] ?? 0);
  if (["advance", "goal", "recovery"].includes(plan.kind)) {
    const range = months(plan.startMonth, plan.endMonth), i = range.indexOf(m);
    return i < 0 ? 0 : split(plan.amountCents, range.length)[i];
  }
  if (plan.kind === "fixed") {
    const anchor = plan.intervalAnchor ?? plan.startMonth;
    const delta = (Number(m.slice(0, 4)) - Number(anchor.slice(0, 4))) * 12 + Number(m.slice(-2)) - Number(anchor.slice(-2));
    let amount = plan.amountCents;
    for (const rate2 of plan.rateChanges ?? []) if (rate2.fromMonth <= m) amount = rate2.amountCents;
    return amount === 0 ? 0 : split(amount, plan.intervalMonths)[(delta % plan.intervalMonths + plan.intervalMonths) % plan.intervalMonths];
  }
  let rate = plan.amountCents;
  for (const change of plan.rateChanges ?? []) if (change.fromMonth <= m) rate = change.amountCents;
  return rate;
}
function adjustment(plans, m) {
  return -Object.values(plans).reduce((sum, p) => sum + contribution(p, m), 0) || 0;
}
function requestKey(value) {
  if (typeof value !== "string" || !/^[a-zA-Z0-9-]{8,80}$/.test(value)) fail2("Identificatore operazione non valido.");
  return value;
}
function initialState() {
  return { version: 1, plans: {}, payments: {}, commands: {} };
}
function fingerprint(input) {
  return JSON.stringify(Object.fromEntries(Object.entries(input).filter(([k]) => k !== "requestId").sort(([a], [b]) => a.localeCompare(b))));
}
function command(state, action, input, today) {
  const next = structuredClone(state), key = requestKey(input.requestId), signature = fingerprint({ action, ...input });
  if (next.commands[key]) {
    if (next.commands[key].signature !== signature) fail2("Questa operazione \xE8 gi\xE0 stata usata con dati diversi.");
    return { state: next, result: next.commands[key].result };
  }
  let result;
  if (action === "create") {
    const plan = newPlan(input, today, key);
    next.plans[key] = plan;
    if (plan.kind === "recovery") reservePayment(next, plan, { ...input, amountCents: plan.amountCents, date: plan.paymentDate }, today, key);
    result = { planId: key, paymentId: plan.kind === "recovery" ? key : null };
  } else {
    const plan = next.plans[input.planId];
    if (!plan) fail2("Piano non trovato.");
    if (action === "pay") {
      if (["advance", "recovery"].includes(plan.kind)) fail2("Questo piano non prevede un nuovo pagamento.");
      if (plan.status !== "active") fail2("Il piano non \xE8 attivo.");
      reservePayment(next, plan, input, today, key);
      result = { planId: plan.id, paymentId: key };
    } else if (action === "deletePayment") {
      const payment = next.payments[input.paymentId];
      if (!payment || payment.planId !== plan.id) fail2("Pagamento non trovato.");
      if (!["posted", "deleting", "deleted"].includes(payment.status)) fail2("Completa l\u2019operazione in sospeso prima di eliminare il pagamento.");
      if (Object.values(next.payments).some((p) => p.id !== payment.id && p.status !== "deleted" && p.movementId === payment.movementId)) fail2("Il movimento \xE8 condiviso con un altro pagamento.");
      if (payment.status !== "deleted") payment.status = "deleting";
      result = { planId: plan.id, paymentId: payment.id };
    } else if (action === "edit") {
      if (plan.status !== "active" || ["advance", "recovery"].includes(plan.kind)) fail2("Questo piano non \xE8 modificabile.");
      const amount = plan.kind === "goal" ? cents(input.amountCents) : input.amountCents, first = month(input.fromMonth ?? addMonth(today.slice(0, 7), 1));
      if (!Number.isSafeInteger(amount) || amount < 0 || amount > 1e8) fail2("Quota non valida.");
      if (first <= today.slice(0, 7) || first < plan.startMonth) fail2("Le modifiche possono decorrere soltanto da un mese futuro del piano.");
      if (plan.kind === "goal") {
        const last = month(input.endMonth), future = months(first, last);
        const oldFuture = plan.endMonth >= first ? months(first, plan.endMonth).reduce((n, m) => n + contribution(plan, m), 0) : 0;
        const matured = plan.amountCents - oldFuture, rest = Math.max(0, amount - matured);
        const schedule = { ...plan.legacySchedule ?? Object.fromEntries(months(plan.startMonth, plan.endMonth).map((m) => [m, contribution(plan, m)])) };
        for (const m of Object.keys(schedule)) if (m >= first) delete schedule[m];
        const shares = rest ? split(rest, future.length) : future.map(() => 0);
        future.forEach((m, i) => schedule[m] = shares[i]);
        plan.legacySchedule = schedule;
        plan.endMonth = last;
        plan.amountCents = amount;
      } else {
        plan.rateChanges = (plan.rateChanges ?? []).filter((c) => c.fromMonth !== first);
        plan.rateChanges.push({ fromMonth: first, amountCents: amount });
        plan.rateChanges.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
      }
      result = { planId: plan.id };
    } else if (action === "stop") {
      if (plan.status !== "active") fail2("Il piano non \xE8 attivo.");
      if (Object.values(next.payments).some((p) => p.planId === plan.id && ["pending", "deleting"].includes(p.status))) fail2("Completa il pagamento in sospeso prima di interrompere.");
      if (plan.kind === "advance") {
        if (plan.beneficiaryMonth < today.slice(0, 7)) fail2("L\u2019anticipo ha gi\xE0 inciso su un mese chiuso: non puoi cancellarne solo il recupero.");
        plan.status = "cancelled";
      } else {
        plan.status = "stopped";
        plan.stopAfter = today.slice(0, 7);
      }
      result = { planId: plan.id };
    } else fail2("Operazione sconosciuta.");
  }
  next.commands[key] = { signature, result };
  return { state: next, result };
}
function reservePayment(state, plan, input, today, id) {
  const amount = cents(input.amountCents), date2 = day(input.date, today), covered = Number(input.competenceMonths ?? 1);
  if (!Number.isInteger(covered) || covered < 1 || covered > 12) fail2("I mesi coperti devono essere tra 1 e 12.");
  const cycle = month(input.cycleMonth ?? date2.slice(0, 7));
  if (cycle > today.slice(0, 7)) fail2("Non puoi segnare pagata una scadenza futura.");
  if (["fixed", "estimated"].includes(plan.kind) && cycle < plan.startMonth) fail2("La scadenza precede l\u2019inizio del piano.");
  const settlement = ["goal", "recovery"].includes(plan.kind) ? "once" : ["fixed", "estimated"].includes(plan.kind) ? cycleKey(plan, cycle) : id;
  const existingMovementId = input.movementId === void 0 ? null : Number(input.movementId);
  if (existingMovementId !== null && (!Number.isSafeInteger(existingMovementId) || existingMovementId < 2)) fail2("Movimento non valido.");
  if (existingMovementId && Object.values(state.payments).some((p) => p.movementId === existingMovementId || p.existingMovementId === existingMovementId)) fail2("Questo movimento \xE8 gi\xE0 collegato a un piano.");
  if (Object.values(state.payments).some((p) => p.planId === plan.id && p.status !== "deleted" && p.settlementKey === settlement)) fail2("Pagamento gi\xE0 registrato o in completamento.");
  let recovery = null;
  if (input.recoverDifference) {
    if (plan.kind !== "goal" || amount + Object.values(state.payments).filter((p) => p.planId === plan.id && p.status === "posted").reduce((n, p) => n + p.amountCents, 0) <= plan.amountCents) fail2("Il recupero riguarda soltanto l\u2019eccedenza di un obiettivo finito.");
    recovery = newPlan({
      kind: "goal",
      name: ("Recupero eccedenza \xB7 " + plan.name).slice(0, 120),
      amountCents: amount + Object.values(state.payments).filter((p) => p.planId === plan.id && p.status === "posted").reduce((n, p) => n + p.amountCents, 0) - plan.amountCents,
      startMonth: input.recoveryStartMonth,
      endMonth: input.recoveryEndMonth
    }, today, id + "-difference");
    recovery.kind = "recovery";
    recovery.sourcePaymentId = id;
  }
  state.payments[id] = {
    id,
    planId: plan.id,
    settlementKey: settlement,
    status: "pending",
    amountCents: amount,
    date: date2,
    cycleMonth: cycle,
    competenceMonths: covered,
    recovery,
    requestId: id,
    existingMovementId,
    cashName: input.originalName ? String(input.originalName).trim().slice(0, 120) : null
  };
}
function completePayment(state, id, movementId, today) {
  const next = structuredClone(state), payment = next.payments[id];
  if (!payment) fail2("Pagamento non trovato.");
  if (["posted", "deleting", "deleted"].includes(payment.status)) return next;
  if (!Number.isSafeInteger(movementId) || movementId <= 0) fail2("Il movimento bancario non \xE8 stato confermato.");
  const plan = next.plans[payment.planId];
  payment.status = "posted";
  payment.movementId = movementId;
  if (plan.kind === "goal") {
    plan.status = "closed";
    plan.closedMonth = today.slice(0, 7);
  }
  if (plan.kind === "recovery") plan.status = "active";
  if (payment.recovery) next.plans[payment.recovery.id] = payment.recovery;
  if (plan.kind === "estimated") {
    const history = Object.values(next.payments).filter((p) => p.planId === plan.id && p.status === "posted").sort((a, b) => a.date.localeCompare(b.date)).slice(-12);
    const amount = Math.round(history.reduce((sum, p) => sum + p.amountCents, 0) / history.reduce((sum, p) => sum + p.competenceMonths, 0));
    const fromMonth = addMonth(today.slice(0, 7), 1);
    plan.rateChanges = (plan.rateChanges ?? []).filter((c) => c.fromMonth !== fromMonth);
    plan.rateChanges.push({ fromMonth, amountCents: Math.max(1, amount) });
    plan.rateChanges.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
  }
  return next;
}
function cycleKey(plan, cycle) {
  if (plan.kind !== "fixed" || plan.intervalMonths === 1) return cycle;
  const anchor = plan.intervalAnchor ?? plan.startMonth, delta = (Number(cycle.slice(0, 4)) - Number(anchor.slice(0, 4))) * 12 + Number(cycle.slice(-2)) - Number(anchor.slice(-2));
  return addMonth(anchor, Math.floor(delta / plan.intervalMonths) * plan.intervalMonths);
}
function completePaymentDeletion(state, id, today) {
  const next = structuredClone(state), payment = next.payments[id];
  if (!payment) fail2("Pagamento non trovato.");
  if (payment.status === "deleted") return next;
  if (payment.status !== "deleting") fail2("Eliminazione non avviata.");
  payment.status = "deleted";
  payment.deletedDay = today;
  const plan = next.plans[payment.planId];
  if (plan.kind === "goal" && plan.status === "closed") {
    plan.status = "active";
    plan.closedMonth = null;
  }
  if (plan.kind === "recovery") plan.status = "cancelled";
  for (const linked of Object.values(next.plans)) if (linked.sourcePaymentId === id) linked.status = "cancelled";
  if (plan.kind === "estimated") {
    const history = Object.values(next.payments).filter((p) => p.planId === plan.id && p.status === "posted").sort((a, b) => a.date.localeCompare(b.date)).slice(-12);
    const rate = history.length ? Math.max(1, Math.round(history.reduce((n, p) => n + p.amountCents, 0) / history.reduce((n, p) => n + p.competenceMonths, 0))) : plan.amountCents;
    const fromMonth = addMonth(today.slice(0, 7), 1);
    plan.rateChanges = (plan.rateChanges ?? []).filter((c) => c.fromMonth !== fromMonth);
    plan.rateChanges.push({ fromMonth, amountCents: rate });
    plan.rateChanges.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
  }
  return next;
}
function balance(state, plan, throughMonth) {
  const last = throughMonth < plan.startMonth ? null : throughMonth;
  const saved = (throughMonth >= plan.startMonth ? Number(plan.openingBalanceCents ?? 0) : 0) + (last ? months(plan.startMonth, last, 1200).reduce((n, m) => n + Math.max(0, contribution(plan, m)), 0) : 0);
  const spent = Object.values(state.payments).filter((p) => p.planId === plan.id && ["posted", "deleting"].includes(p.status) && p.date.slice(0, 7) <= throughMonth && p.date.slice(0, 7) >= plan.startMonth).reduce((n, p) => n + p.amountCents, 0);
  return { contributedCents: saved, paidCents: spent, fundCents: plan.status === "active" && !["advance", "recovery"].includes(plan.kind) ? Math.max(0, saved - spent) : 0, fromGeneralSavingsCents: Math.max(0, spent - saved) };
}
function project(state, selectedMonth) {
  month(selectedMonth);
  return {
    version: 2,
    month: selectedMonth,
    adjustmentCents: adjustment(state.plans, selectedMonth),
    plans: Object.values(state.plans).map((p) => ({ ...p, outstandingCents: Math.max(0, p.amountCents - Object.values(state.payments).filter((x) => x.planId === p.id && ["posted", "deleting"].includes(x.status)).reduce((n, x) => n + x.amountCents, 0)), contributionCents: contribution(p, selectedMonth), ...balance(state, p, selectedMonth) })),
    payments: Object.values(state.payments).filter((p) => p.status !== "deleted").map(({ recovery, ...p }) => p)
  };
}

// backend/plans/legacy.mjs
var money = (n) => Math.round(Number(n || 0) * 100);
var utility = /* @__PURE__ */ new Set(["Elettricit\xE0", "Gas", "Acqua"]);
var active = (p) => p.status !== "Annullato";
function adoptLegacy(state, context, today) {
  const next = structuredClone(state), current = today.slice(0, 7);
  if (!next.legacyAdoption) {
    next.legacyAdoption = { version: 1, fromMonth: current };
    const fixed = [
      { name: "Affitto", estimate: context.overview.summary.monthlyBudgetBreakdown?.find((r) => r.name === "Affitto")?.amount ?? 0 },
      ...(context.overview.recurring ?? []).filter((r) => r.treatment === "Vincolata" && r.name !== "Benzina")
    ];
    for (const [index, r] of fixed.entries()) {
      if (!r.name || money(r.estimate) < 0) continue;
      const id = "legacy-recurring-" + index;
      next.plans[id] = {
        id,
        name: r.name,
        category: r.name,
        kind: utility.has(r.name) ? "estimated" : "fixed",
        amountCents: money(r.estimate),
        startMonth: current,
        endMonth: null,
        intervalMonths: 1,
        status: "active",
        createdDay: today,
        rateChanges: [],
        legacy: { type: "recurring", name: r.name, fromMonth: current }
      };
      if (utility.has(r.name) && Number.isFinite(r.nextEstimate) && money(r.nextEstimate) !== money(r.estimate))
        next.plans[id].rateChanges.push({ fromMonth: nextMonth(current), amountCents: money(r.nextEstimate) });
    }
    const bySource = /* @__PURE__ */ new Map();
    for (const cycle of context.cycles ?? []) {
      if (!active(cycle) || cycle.kind !== "expense") continue;
      const source = Number(cycle.extraordinary_source_row);
      if (!bySource.has(source)) bySource.set(source, []);
      bySource.get(source).push(cycle);
    }
    for (const [source, cycles] of bySource) {
      const ref = cycles.find((c) => c.start_month <= current && c.end_month >= current) ?? cycles.filter((c) => c.start_month <= current).at(-1) ?? cycles[0];
      const ids = new Set(cycles.map((c) => Number(c.id))), allocations = (context.allocations ?? []).filter((a) => ids.has(Number(a.cycle_id)));
      const links = (context.links ?? []).filter((l) => ids.has(Number(l.cycle_id)));
      const annual = ref.repeat_rule === "Annuale", fund = annual && /^Manutenzione auto\b/i.test(ref.name);
      const id = "legacy-extra-" + source, kind = fund ? "fund" : annual ? "fixed" : "goal";
      const schedule = Object.fromEntries(allocations.filter((a) => a.month >= current).map((a) => [a.month, Number(a.amount_cents)]));
      const prior = allocations.filter((a) => a.month < current).reduce((n, a) => n + Number(a.amount_cents), 0) - links.filter((l) => String(l.actual_date).slice(0, 7) < current).reduce((n, l) => n + Number(l.attributed_cents), 0);
      const amount = kind === "fund" ? schedule[current] ?? Math.round(ref.total_cents / 12) : Number(ref.total_cents);
      const closed = kind === "goal" && ref.status === "Pagato";
      next.plans[id] = {
        id,
        name: ref.name,
        category: fund ? "Manutenzione auto" : /assicura/i.test(ref.name) ? "Assicurazione" : /bollo/i.test(ref.name) ? "Bollo" : "Straordinarie",
        kind,
        amountCents: amount,
        startMonth: ref.start_month > current ? ref.start_month : current,
        endMonth: kind === "goal" ? ref.end_month : null,
        intervalMonths: annual && !fund ? 12 : 1,
        intervalAnchor: ref.start_month,
        createdDay: today,
        status: closed ? "closed" : "active",
        closedMonth: closed ? String(ref.paid_date || today).slice(0, 7) : null,
        rateChanges: [],
        openingBalanceCents: prior,
        legacySchedule: kind === "goal" ? schedule : void 0,
        legacy: { type: "extra", sourceRow: source, fromMonth: current }
      };
      for (const link of links) {
        const pid = "legacy-link-" + link.cycle_id + "-" + link.movement_source_row;
        if (next.payments[pid]) continue;
        const cycle = cycles.find((c) => Number(c.id) === Number(link.cycle_id));
        next.payments[pid] = {
          id: pid,
          planId: id,
          status: "posted",
          legacy: true,
          movementId: Number(link.movement_source_row),
          amountCents: Number(link.attributed_cents),
          date: String(link.actual_date).slice(0, 10),
          cycleMonth: cycle.start_month,
          competenceMonths: annual ? 12 : 1,
          settlementKey: kind === "goal" ? pid : kind === "fixed" ? cycleKey(next.plans[id], cycle.start_month) : pid
        };
      }
    }
  }
  for (const row of context.movements ?? []) {
    if (row.status !== "Eseguito" || row.movement_type !== "Spesa" || Number(row.amount) >= 0 || !["Trade Republic", "Revolut"].includes(row.account)) continue;
    if (Object.values(next.payments).some((p) => p.movementId === Number(row.source_row) || p.existingMovementId === Number(row.source_row) || "APP-" + p.requestId === row.import_id)) continue;
    const plan = Object.values(next.plans).find((p) => p.legacy?.type === "recurring" && p.category === row.category);
    if (!plan || String(row.actual_date).slice(0, 7) < plan.startMonth && plan.kind !== "estimated" || String(row.actual_date).slice(0, 10) > today || !["auto", "planned"].includes(row.treatment ?? "auto")) continue;
    const id = "legacy-cash-" + row.source_row;
    next.payments[id] = {
      id,
      planId: plan.id,
      status: "pending",
      legacy: true,
      amountCents: money(-row.amount),
      date: String(row.actual_date).slice(0, 10),
      cycleMonth: String(row.actual_date).slice(0, 7),
      competenceMonths: Math.max(1, Number(row.competence_months) || 1),
      settlementKey: cycleKey(plan, String(row.actual_date).slice(0, 7))
    };
    if (String(row.actual_date).slice(0, 7) < plan.startMonth) {
      next.payments[id].status = "posted";
      next.payments[id].movementId = Number(row.source_row);
      continue;
    }
    const completed = completePayment(next, id, Number(row.source_row), today);
    Object.assign(next, completed);
  }
  return next;
}
function nextMonth(m) {
  const [y, n] = m.split("-").map(Number);
  return new Date(Date.UTC(y, n, 1)).toISOString().slice(0, 7);
}
async function readLegacyContext(db, overview) {
  const [cycles, allocations, links, movements] = await Promise.all([
    db.prepare("SELECT c.*,e.name,e.repeat_rule,e.paid_date FROM extraordinary_cycles c JOIN extraordinary e ON e.source_row=c.extraordinary_source_row ORDER BY c.start_month,c.id").all(),
    db.prepare("SELECT * FROM extraordinary_allocations ORDER BY month,cycle_id").all(),
    db.prepare("SELECT l.*,m.actual_date FROM extraordinary_movement_links l JOIN movements m ON m.source_row=l.movement_source_row WHERE l.role='payment'").all(),
    db.prepare("SELECT m.*,p.treatment FROM movements m LEFT JOIN movement_budget_policies p ON p.movement_source_row=m.source_row WHERE m.movement_type='Spesa' AND m.amount<0 ORDER BY m.actual_date,m.source_row").all()
  ]);
  return { overview, cycles: cycles.results, allocations: allocations.results, links: links.results, movements: movements.results };
}
function replacement(base, view, current = false) {
  const adopted = view.plans.filter((p) => p.legacy && view.month >= p.legacy.fromMonth), names = new Set(adopted.filter((p) => p.legacy.type === "recurring").map((p) => p.legacy.name));
  const sources = new Set(adopted.filter((p) => p.legacy.type === "extra").map((p) => p.legacy.sourceRow));
  const allocations = (base.extraPlan?.allocations ?? []).filter((a) => a.month === view.month && a.kind === "expense" && active(a) && sources.has(Number(a.extraordinary_source_row)));
  if (current) return (base.summary.recurringCommitments ?? []).filter((r) => names.has(r.name)).reduce((n, r) => n + money(r.remaining), 0) + allocations.filter((a) => !(a.status === "Pagato" && a.paid_date && view.month <= String(a.paid_date).slice(0, 7))).reduce((n, a) => n + Number(a.amount_cents), 0);
  return (base.summary.monthlyBudgetBreakdown ?? []).filter((r) => names.has(r.name)).reduce((n, r) => n + money(r.amount), 0) + allocations.reduce((n, a) => n + Number(a.amount_cents), 0);
}
function hideAdoptedLegacy(base, view) {
  const sources = new Set(view.plans.filter((p) => p.legacy?.type === "extra").map((p) => p.legacy.sourceRow));
  for (const key of ["extraPlan", "forecastPlan"]) if (base[key]) base[key].allocations = base[key].allocations.filter((a) => !sources.has(Number(a.extraordinary_source_row)));
}

// backend/plans/service.mjs
var schemaJobs = /* @__PURE__ */ new WeakMap();
var D1PlanRepository = class {
  constructor(db) {
    this.db = db;
  }
  async initialize() {
    if (!schemaJobs.has(this.db)) schemaJobs.set(this.db, (async () => {
      try {
        if (await this.db.prepare("SELECT id FROM finance_plans_v2_state WHERE id=1").first()) return;
      } catch (error) {
        if (!String(error.message).includes("no such table")) throw error;
      }
      await this.db.prepare("CREATE TABLE IF NOT EXISTS finance_plans_v2_state (id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL, document TEXT NOT NULL)").run();
      await this.db.prepare("INSERT OR IGNORE INTO finance_plans_v2_state(id,revision,document) VALUES(1,0,?)").bind(JSON.stringify(initialState())).run();
    })());
    try {
      await schemaJobs.get(this.db);
    } catch (error) {
      schemaJobs.delete(this.db);
      throw error;
    }
  }
  async read() {
    const row = await this.db.prepare("SELECT revision,document FROM finance_plans_v2_state WHERE id=1").first();
    if (!row) throw new PlanError("Archivio piani non inizializzato.", 503);
    return { revision: row.revision, state: JSON.parse(row.document) };
  }
  async compareAndSet(revision, state) {
    const result = await this.db.prepare("UPDATE finance_plans_v2_state SET revision=revision+1,document=? WHERE id=1 AND revision=?").bind(JSON.stringify(state), revision).run();
    return result.meta.changes === 1;
  }
};
var PlanService = class {
  constructor(repository, cash, today) {
    this.repository = repository;
    this.cash = cash;
    this.today = today;
  }
  async change(transform) {
    for (let attempt = 0; attempt < 5; attempt++) {
      const { revision, state } = await this.repository.read(), next = transform(state);
      if (JSON.stringify(next.state) === JSON.stringify(state)) return next.result;
      if (await this.repository.compareAndSet(revision, next.state)) return next.result;
    }
    throw new PlanError("Un altro dispositivo sta aggiornando i piani. Riprova.", 409);
  }
  async execute(action, input) {
    const result = await this.change((state) => command(state, action, input, this.today));
    if (result.paymentId) await this.finish(result.paymentId);
    return result;
  }
  async finish(paymentId) {
    const { state } = await this.repository.read(), p = state.payments[paymentId];
    if (!p) throw new PlanError("Pagamento non trovato.", 404);
    if (["posted", "deleted"].includes(p.status)) return;
    if (p.status === "deleting") {
      await this.cash.remove(p);
      await this.change((current) => ({ state: completePaymentDeletion(current, paymentId, this.today), result: {} }));
      return;
    }
    const plan = state.plans[p.planId];
    const movementId = await this.cash.record({
      requestId: p.requestId,
      name: p.cashName || plan.name,
      category: plan.category,
      amountCents: p.amountCents,
      date: p.date,
      competenceMonths: p.competenceMonths,
      planId: p.planId,
      existingMovementId: p.existingMovementId
    });
    await this.change((current) => ({ state: completePayment(current, paymentId, movementId, this.today), result: {} }));
  }
  async view(month2) {
    const { state } = await this.repository.read();
    return project(state, month2);
  }
};

// backend/plans/worker-adapter.mjs
var METHODS = { saveFinancePlan: "create", recordFinancePlanPayment: "pay", stopFinancePlan: "stop", editFinancePlan: "edit", deleteFinancePlanPayment: "deletePayment" };
var readMethods = /* @__PURE__ */ new Set(["getFinanceOverview", "getFinanceData"]);
var protectedCash = /* @__PURE__ */ new Set(["editMovement", "deleteMovement"]);
var quickWrites = /* @__PURE__ */ new Set(["saveTransaction", "saveRecurringPayment", "saveEstimate"]);
var legacyWrites = /* @__PURE__ */ new Set(["recordExtraPayment", "markExtraPaid", "cancelExtraCycle", "deleteExtraPlan", "updateExtraPlan", "setExtraStatus", "linkExtraMovement", "unlinkExtraMovement"]);
function json(value, status = 200, extra = {}) {
  return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store", "X-LifeOS-Plans-Version": "2", ...extra } });
}
async function existingMovement(db, p, current) {
  const row = await db.prepare("SELECT m.*,p.treatment FROM movements m LEFT JOIN movement_budget_policies p ON p.movement_source_row=m.source_row WHERE m.source_row=?").bind(p.existingMovementId).first();
  const linked = await db.prepare("SELECT 1 FROM extraordinary_movement_links WHERE movement_source_row=? LIMIT 1").bind(p.existingMovementId).first();
  const autoSavings = ["Assicurazione", "Bollo", "Manutenzione auto", "Dentista", "Straordinarie"].includes(row?.category) && (!row.treatment || row.treatment === "auto");
  if (!row || linked || row.account !== "Trade Republic" || row.status !== "Eseguito" || row.movement_type !== "Spesa" || Math.round(-row.amount * 100) !== p.amountCents || String(row.actual_date).slice(0, 10) !== p.date || row.treatment === "recovery" || p.date.slice(0, 7) < current && row.treatment !== "savings" && !autoSavings)
    throw new PlanError("Il movimento non \xE8 collegabile: verifica conto, importo, data e trattamento dai risparmi.");
  return row;
}
function romeToday(now = /* @__PURE__ */ new Date()) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Rome", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(now).map((p) => [p.type, p.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}
function augmentFinance(base, view, currentView, currentBase = base) {
  const result = structuredClone(base), summary = result.summary;
  if (!summary || !Number.isFinite(summary.monthlyRemaining) || !Number.isFinite(summary.monthlyCommitted)) throw new PlanError("Contratto del budget non compatibile.", 502);
  const replaced = replacement(base, view), currentReplaced = replacement(currentBase, currentView, true);
  summary.monthlyRemaining += (view.adjustmentCents + replaced) / 100;
  summary.monthlyCommitted -= (view.adjustmentCents + replaced) / 100;
  summary.monthlyBudgetBreakdown = [...summary.monthlyBudgetBreakdown ?? [], ...view.plans.filter((p) => p.contributionCents !== 0).map((p) => ({ name: p.name, amount: p.contributionCents / 100, planId: p.id }))];
  const earmarked = currentView.plans.reduce((sum, p) => sum + p.fundCents, 0) / 100;
  if (Number.isFinite(summary.committedCurrent) && Number.isFinite(summary.budget)) {
    summary.committedCurrent = currentBase.summary.committedCurrent + earmarked - currentReplaced / 100;
    summary.remainingFree = summary.budget - summary.committedCurrent;
  }
  const names = new Set(view.plans.filter((p) => p.legacy?.type === "recurring" && view.month >= p.legacy.fromMonth).map((p) => p.name));
  const oldExtra = replaced - (base.summary.monthlyBudgetBreakdown ?? []).filter((r) => names.has(r.name)).reduce((n, r) => n + Math.round(r.amount * 100), 0);
  summary.monthlyBudgetBreakdown = summary.monthlyBudgetBreakdown.filter((r) => r.planId || !names.has(r.name)).map((r) => r.name === "Accantonamenti e straordinarie" ? { ...r, amount: r.amount - oldExtra / 100 } : r);
  hideAdoptedLegacy(result, view);
  const currentNames = new Set(currentView.plans.filter((p) => p.legacy?.type === "recurring").map((p) => p.name));
  const currentExtra = currentReplaced - (currentBase.summary.recurringCommitments ?? []).filter((r) => currentNames.has(r.name)).reduce((n, r) => n + Math.round(r.remaining * 100), 0);
  summary.recurringCommitments = [...(currentBase.summary.recurringCommitments ?? []).filter((r) => !currentNames.has(r.name)).map((r) => r.name === "Straordinarie e auto" ? { ...r, remaining: r.remaining - currentExtra / 100, estimate: r.estimate - currentExtra / 100 } : r), ...currentView.plans.filter((p) => p.fundCents || p.contributionCents > 0).map((p) => ({ name: p.name, estimate: p.contributionCents / 100, remaining: p.fundCents / 100, planId: p.id }))];
  for (const key of ["monthlyRemaining", "monthlyCommitted", "committedCurrent", "remainingFree"]) if (Number.isFinite(summary[key])) summary[key] = Math.round(summary[key] * 100) / 100;
  summary.monthlyBudgetBreakdown = summary.monthlyBudgetBreakdown.map((r) => ({ ...r, amount: Math.round(r.amount * 100) / 100 }));
  result.plansV2 = view;
  return result;
}
function withFinancePlans(base, { repositoryFactory = (env) => new D1PlanRepository(env.DB), clock = romeToday, cashFactory = null, recordTransaction = null } = {}) {
  return { async fetch(request, env, ctx) {
    const url = new URL(request.url), method = url.pathname.startsWith("/api/") ? url.pathname.slice(5) : "";
    if (!METHODS[method] && method !== "getMovement" && method !== "getFinancePlans" && method !== "resumeFinancePlanPayment" && !readMethods.has(method) && !protectedCash.has(method) && !legacyWrites.has(method) && method !== "getFinancePlanMovements" && !quickWrites.has(method)) return base.fetch(request, env, ctx);
    if (request.method !== "POST") return json({ error: "Metodo non consentito." }, 405);
    if (request.headers.get("Origin") !== url.origin) return json({ error: "Origine non consentita." }, 403);
    try {
      const body = await request.clone().text();
      if (body.length > 65536) throw new PlanError("Richiesta troppo grande.", 413);
      const args = JSON.parse(body);
      if (!Array.isArray(args) || args.length > 5) throw new PlanError("Parametri non validi.");
      const today = clock(), current = today.slice(0, 7), nativeV2 = request.headers.get("X-LifeOS-Plans-Version") === "2" || method.includes("FinancePlan");
      const forward = async (name, values) => {
        const headers = new Headers(request.headers);
        headers.delete("Content-Length");
        headers.set("Content-Type", "application/json");
        return base.fetch(new Request(new URL("/api/" + name, url), { method: "POST", headers, body: JSON.stringify(values) }), env, ctx);
      };
      const auth = readMethods.has(method) ? await base.fetch(request, env, ctx) : await forward("getFinanceOverview", [Number(current.slice(0, 4)), Number(current.slice(-2))]);
      if (auth.status !== 200 || !(auth.headers.get("Content-Type") ?? "").includes("application/json")) return new Response(auth.body, { status: auth.status === 200 ? 401 : auth.status, headers: auth.headers });
      const authorized = await auth.json();
      if (!authorized.summary || !Array.isArray(authorized.transactions)) throw new PlanError("Sessione non confermata.", 401);
      const repository = repositoryFactory(env);
      await repository.initialize();
      let currentBase = authorized;
      if (readMethods.has(method) && `${args[0]}-${String(args[1]).padStart(2, "0")}` !== current) {
        const response2 = await forward("getFinanceOverview", [Number(current.slice(0, 4)), Number(current.slice(-2))]);
        if (!response2.ok) throw new PlanError("Budget corrente non disponibile.", 503);
        currentBase = await response2.json();
      }
      const cash = cashFactory ? cashFactory({ forward }) : { async remove(p) {
        const row = await env.DB.prepare("SELECT amount,account,movement_type,status FROM movements WHERE source_row=?").bind(p.movementId).first();
        if (!row) return;
        if (row.movement_type !== "Spesa" || row.status !== "Eseguito" || Math.round(-Number(row.amount) * 100) !== p.amountCents)
          throw new PlanError("Importo del movimento e pagamento non coincidono. Nessun movimento \xE8 stato eliminato.", 409);
        const response2 = await forward("deleteMovement", [p.movementId]);
        if (!response2.ok) throw new PlanError("Eliminazione non confermata. Riprova da questo pagamento senza registrare una nuova spesa.", 503);
        const remaining = await env.DB.prepare("SELECT source_row FROM movements WHERE source_row=?").bind(p.movementId).first();
        if (remaining) throw new PlanError("Il movimento risulta ancora presente. Riprova l\u2019eliminazione.", 503);
      }, async record(p) {
        if (p.existingMovementId) {
          const row = await existingMovement(env.DB, p, current);
          await env.DB.prepare("INSERT INTO movement_budget_policies(movement_source_row,treatment,recovery_json) VALUES (?,'savings','[]') ON CONFLICT(movement_source_row) DO UPDATE SET treatment='savings',recovery_json='[]'").bind(row.source_row).run();
          return row.source_row;
        }
        const input = {
          requestId: p.requestId,
          name: p.name,
          amount: p.amountCents / 100,
          type: "Spesa",
          category: p.category ?? "Altro",
          date: p.date,
          account: "Trade Republic",
          months: p.competenceMonths,
          budgetTreatment: "savings",
          note: "Piano " + p.planId
        };
        let result;
        if (recordTransaction) result = await recordTransaction(env, input);
        else {
          const response2 = await forward("saveTransaction", [input]);
          if (response2.status !== 200) throw new PlanError("Pagamento non confermato. Riprova dalla stessa operazione.", 503);
          result = await response2.json();
        }
        let id = typeof result === "number" ? result : result?.movementId ?? result?.row;
        if (result === true) {
          const row = env.DB ? await env.DB.prepare("SELECT source_row,amount,actual_date,account,movement_type,status FROM movements WHERE import_id=?").bind("APP-" + p.requestId).first() : null;
          if (!row || row.account !== "Trade Republic" || row.movement_type !== "Spesa" || row.status !== "Eseguito" || String(row.actual_date).slice(0, 10) !== p.date || Math.round(Number(row.amount) * 100) !== -p.amountCents)
            throw new PlanError("Movimento non verificato nel registro. Riprendi questa operazione senza crearne una nuova.", 502);
          id = row.source_row;
        }
        if (!Number.isSafeInteger(id) || id <= 0) throw new PlanError("Il server deve confermare l\u2019identificatore del pagamento. Non ripetere con una nuova operazione.", 502);
        return id;
      } };
      const service = new PlanService(repository, cash, today);
      if (nativeV2 && env.DB && Array.isArray(currentBase.recurring) && currentBase.extraPlan) {
        const context = await readLegacyContext(env.DB, currentBase);
        await service.change((state) => ({ state: adoptLegacy(state, context, today), result: {} }));
      }
      if (method === "getMovement") {
        const response2 = await forward(method, args);
        if (!response2.ok) return response2;
        const row = await response2.json(), { state } = await repository.read();
        const payment = Object.values(state.payments).find((p) => p.status !== "deleted" && (p.movementId === Number(args[0]) || p.existingMovementId === Number(args[0])));
        return json(payment ? { ...row, financePlanId: payment.planId, financePlanPaymentId: payment.id } : row);
      }
      if (quickWrites.has(method)) {
        if (method === "saveTransaction" && args[0]?.type === "Spesa") {
          const input = args[0], mode = input.budgetTreatment ?? "auto";
          if (mode !== "savings") {
            if (!["auto", "ordinary"].includes(mode) || Number(input.months ?? 1) !== 1)
              throw new PlanError("Per ripartire una spesa o registrare un pagamento pianificato usa Piani.");
            args[0] = { ...input, months: 1, budgetTreatment: "ordinary" };
          }
          if (recordTransaction) return json(await recordTransaction(env, args[0]));
          return forward(method, args);
        }
        const { state } = await repository.read();
        if (method === "saveEstimate") {
          const plan = Object.values(state.plans).find((p) => p.legacy?.type === "recurring" && p.name === args[0]);
          if (plan) {
            await service.execute("edit", { requestId: crypto.randomUUID(), planId: plan.id, amountCents: Math.round(Number(args[1]) * 100), fromMonth: addMonth(current, 1) });
            return json(true);
          }
        } else if (method === "saveRecurringPayment") {
          const input = args[0] ?? {}, category = input.name;
          const candidates = Object.values(state.plans).filter((p) => ["fixed", "estimated"].includes(p.kind) && p.category === category && p.status === "active" && p.startMonth <= String(input.date).slice(0, 7));
          if (candidates.length === 1) {
            const value = Number(input.amount), cents2 = Math.round(value * 100);
            if (!Number.isFinite(value) || Math.abs(value - cents2 / 100) > 1e-8 || input.account && input.account !== "Trade Republic") throw new PlanError("Importo o conto non valido.");
            await service.execute("pay", { requestId: input.requestId ?? crypto.randomUUID(), planId: candidates[0].id, amountCents: cents2, date: input.date, cycleMonth: String(input.date).slice(0, 7), competenceMonths: input.months ?? 1, originalName: input.name });
            return json(true);
          }
        }
        if (recordTransaction && method === "saveTransaction") return json(await recordTransaction(env, args[0]));
        if (recordTransaction && method === "saveRecurringPayment" && ["Condominio", "Elettricit\xE0", "Gas", "Acqua", "Palestra", "Abbonamenti", "Benzina"].includes(args[0]?.name)) {
          const x = args[0];
          return json(await recordTransaction(env, { type: "Spesa", account: x.account || "Trade Republic", amount: x.amount, name: x.name, category: x.name, date: x.date, note: x.note, months: x.months ?? 1, requestId: x.requestId }));
        }
        return base.fetch(request, env, ctx);
      }
      if (method === "getFinancePlanMovements") {
        const selected2 = month(args[0] ?? current), { state } = await repository.read();
        const rows = await env.DB.prepare("SELECT m.*,p.treatment FROM movements m LEFT JOIN movement_budget_policies p ON p.movement_source_row=m.source_row WHERE m.account='Trade Republic' AND m.status='Eseguito' AND m.movement_type='Spesa' AND m.amount<0 AND substr(m.actual_date,1,7)=? AND m.actual_date<=? AND NOT EXISTS(SELECT 1 FROM extraordinary_movement_links l WHERE l.movement_source_row=m.source_row) ORDER BY m.actual_date DESC,m.source_row DESC LIMIT 100").bind(selected2, today).all();
        return json({ movements: rows.results.filter((r) => r.treatment !== "recovery" && !Object.values(state.payments).some((p) => p.movementId === r.source_row || p.existingMovementId === r.source_row) && (selected2 >= current || r.treatment === "savings" || (!r.treatment || r.treatment === "auto") && ["Assicurazione", "Bollo", "Manutenzione auto", "Dentista", "Straordinarie"].includes(r.category))).map((r) => ({ row: r.source_row, name: r.description, date: String(r.actual_date).slice(0, 10), amountCents: Math.round(-r.amount * 100) })) });
      }
      if (legacyWrites.has(method)) {
        const { state } = await repository.read(), cycleId = Number(args[0]?.cycleId);
        const source2 = method === "setExtraStatus" ? Number(args[0]) : (await env.DB.prepare("SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?").bind(cycleId).first())?.extraordinary_source_row;
        if (Object.values(state.plans).some((p) => p.legacy?.sourceRow === source2)) throw new PlanError("Questo piano \xE8 stato adottato: gestiscilo nella sezione Piani aggiornata.", 409);
        return base.fetch(request, env, ctx);
      }
      if (protectedCash.has(method)) {
        const movementId = Number(method === "deleteMovement" ? args[0] : args[0]?.row), { state } = await repository.read();
        const row = env.DB ? await env.DB.prepare("SELECT import_id FROM movements WHERE source_row=?").bind(movementId).first() : null;
        if (Object.values(state.payments).some((p) => p.movementId === movementId || p.existingMovementId === movementId || row?.import_id === "APP-" + p.requestId)) throw new PlanError("Movimento collegato a un piano: modifica o eliminazione diretta non consentita.", 409);
        return base.fetch(request, env, ctx);
      }
      if (method === "saveFinancePlan") {
        const name = String(args[0]?.name ?? "").trim().toLocaleLowerCase("it");
        const { state } = await repository.read();
        const adopted = Object.values(state.plans);
        const existing = [...(authorized.extraPlan?.allocations ?? []).filter((r) => !adopted.some((p) => p.legacy?.sourceRow === Number(r.extraordinary_source_row))), ...(authorized.recurring ?? []).filter((r) => !adopted.some((p) => p.legacy?.type === "recurring" && p.name === r.name)), ...adopted];
        if (existing.some((p) => p.id !== args[0]?.requestId && String(p.name ?? "").trim().toLocaleLowerCase("it") === name && !["Pagato", "Annullato", "closed", "cancelled", "stopped"].includes(p.status)))
          throw new PlanError("Esiste gi\xE0 un accantonamento precedente con questo nome. Gestiscilo da Piani: non verr\xE0 duplicato.");
      }
      if (method === "resumeFinancePlanPayment") {
        await service.finish(args[0]?.paymentId);
        return json({ ok: true });
      }
      if (method === "deleteFinancePlanPayment") {
        const { state } = await repository.read(), p = state.payments[args[0]?.paymentId];
        if (p?.status === "posted") {
          const row = await env.DB.prepare("SELECT amount,movement_type,status FROM movements WHERE source_row=?").bind(p.movementId).first();
          if (row && (row.movement_type !== "Spesa" || row.status !== "Eseguito" || Math.round(-Number(row.amount) * 100) !== p.amountCents))
            throw new PlanError("Importo del movimento e pagamento non coincidono. Nessun movimento \xE8 stato eliminato.", 409);
        }
      }
      if (METHODS[method] && args[0]?.movementId) await existingMovement(env.DB, { existingMovementId: Number(args[0].movementId), amountCents: args[0].amountCents, date: args[0].date ?? args[0].paymentDate }, current);
      if (METHODS[method]) {
        await service.execute(METHODS[method], args[0] ?? {});
        return json({ ok: true });
      }
      if (method === "getFinancePlans") return json(await service.view(args[0] ?? current));
      const selected = `${args[0] ?? current.slice(0, 4)}-${String(args[1] ?? current.slice(-2)).padStart(2, "0")}`;
      const raw = authorized;
      const view = await service.view(selected), currentView = selected === current ? view : await service.view(current);
      const source = auth.headers.get("X-LifeOS-Data-Source");
      return json(augmentFinance(raw, view, currentView, currentBase), 200, source ? { "X-LifeOS-Data-Source": source } : {});
    } catch (error) {
      return json({ error: error instanceof PlanError ? error.message : "Piani momentaneamente non disponibili." }, error instanceof PlanError ? error.status : error instanceof SyntaxError ? 400 : 503);
    }
  } };
}

// backend/worker/entry.mjs
var app = withFinancePlans(runtime_generated_default, { recordTransaction: (env, input) => saveTransaction(env, input) });
var entry_default = { async fetch(request, env, ctx) {
  if (env.NATIVE_DATA_MODE === "maintenance" && new URL(request.url).pathname.startsWith("/api/")) return new Response("Aggiornamento in corso. I movimenti locali restano conservati.", { status: 503, headers: { "Cache-Control": "no-store", "Retry-After": "30" } });
  const response2 = await app.fetch(request, env, ctx);
  if (!["shared", "maintenance"].includes(env.NATIVE_DATA_MODE)) return response2;
  const headers = new Headers(response2.headers);
  headers.set("X-LifeOS-Data-Source", env.NATIVE_DATA_MODE);
  return new Response(response2.body, { status: response2.status, statusText: response2.statusText, headers });
} };
export {
  entry_default as default
};
