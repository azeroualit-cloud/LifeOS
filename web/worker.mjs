
// LifeOS independent savings target v1
// LifeOS lightweight planning v2
function attachSavingsPlanning(result, config, day) {
  const cell = row => {
    const record = config.find(r => r.sheet === "Budget" && Number(r.row_number) === row);
    return record ? JSON.parse(record.values_json)[14] : null;
  };
  const rawGoal = cell(13), saving = Number(cell(14));
  result.planning ||= {
    year: Number(day.slice(0,4)),
    goal: rawGoal === null || rawGoal === "" || rawGoal === undefined ? null : Number(rawGoal),
    monthlySaving: Number.isFinite(saving) ? Math.max(0,saving) : 0,
    now: result.summary.budget,
  };
  const setting = config.find(r => r.sheet === "LifeOS Settings" && Number(r.row_number) === 1);
  const target = setting ? JSON.parse(setting.values_json)[0] : null;
  if (Number.isFinite(target) && target > 0) result.planning.savingsTarget = target;
  return result;
}
function forecastCashHistory(movements, plan, today) {
  const months = Array.from({length:6}, (_,i) => { const d=new Date(today.slice(0,7)+"-01T12:00:00Z"); d.setUTCMonth(d.getUTCMonth()-6+i); return d.toISOString().slice(0,7); });
  const linked = new Map();
  // Deduplicate linked amounts by movement, capped to its actual cash amount.
  for (const link of plan.links || []) if (link.role === 'payment') linked.set(Number(link.movement_source_row),(linked.get(Number(link.movement_source_row)) || 0)+Number(link.attributed_cents || 0)/100);
  return months.map(month => {
    const rows = movements.filter(r => r.account === 'Trade Republic' && r.status === 'Eseguito' && String(r.actual_date).slice(0,7) === month && String(r.actual_date).slice(0,10) < today);
    const net = rows.reduce((s,r) => s+Number(r.amount || 0),0);
    const extraPaid = rows.reduce((s,r) => s+(Number(r.amount)<0 ? Math.min(-Number(r.amount),linked.get(Number(r.source_row)) || 0) : 0),0);
    return {month,observed:rows.length>0,ordinaryNet:Math.round((net+extraPaid)*100)/100,extraPaid};
  });
}
/**
 * LIFE OS 11.63 - Cloudflare Worker module, D1 binding: DB.
 * Source of truth: this file; APP_HTML contains the JSON-serialized frontend.
 * Read LIFE-OS-PROJECT.md before changing balances, payments, migrations or authentication.
 * Never put credentials in this file. Never reset os_meta seed/migration markers.
 * Monetary invariant: summary.budget is the real balance; monthlyRemaining is a planning indicator.
 * Existing legacy schemas are required; additive Life OS and budget-policy migrations are idempotent.
 * Deploy this file as an ES-module Worker; retain existing D1 data and seed markers.
 */
// Liquidit\u00e0 4.0 - Cloudflare D1; build 2026.09.30.os.11.16
const ICON_180 = "iVBORw0KGgoAAAANSUhEUgAAALQAAAC0CAYAAAA9zQYyAAAACXBIWXMAAAsTAAALEwEAmpwYAAARqElEQVR4nO3daVhV1RoH8D7um+XQxtBMy0p5UtMebdDUVFJx1sp5As1MLb15r8qgIAooOKAMgTmPKAqO4EAOmaIxiPNw62qDt9JyKMuywd77rM3ZsM6EIOfstc4+/w/vd/dav/0+f9/9Ag8o1VRC4QwUk5zBA6L/ASicgQLQQIBGoKJDA4Fq+jNA5JDgElAqQAMBXgQFHRoIFJOfASKHBJeAUgEaCPAiKOjQQKCY/AwQOSS4BJQK0ECAF0FBhwYCxeRngMghwSWgVIAGArwICjo0ECgmPwNEDgkuAaUCNBDgRVDQoYFAMfkZIHJIcAkoFaCBAC+Cgg4NBIrJzwCRQ4JLQKkADQR4ERR0aCBQTH4GiBwSXAJKBWggwIugoEMDgWLyM0DkkOASUCpAAwFeBAUdGggUk58BIocEl4BSARoI8CIo6NBAoJj8DBA5JLgElArQQIAXQUGHBgLF5GeAyCHBJaBUgAYCvAgKOjQQKCY/A1NEjk7dB9Ge/V/S1uzztD6jkOKTt9HE4Hh6c/B4atK8LT1Yo6bwfyNKBejyIujaO5BOnf+bTpz7m46fvUtFZ+7SsdN/UeHJP6ngxJ+09+AVmpu4jXr1G0OP1HoCuKqZ9wUzDeiT5/6mE2f/puNn7lLR6b/o2Kli0Pkn/qS843/Qp0V/0NFjv9P+3Js0M3Y9NXvJX/i/G6UCdNmg72qgte586i8qsAL9uwY6t/AOHS64Q4fyf6OFqTn0QuuugFXNPC+XqTq0Vdw49Wcx6ON/UJ6lOx8p/J1yC+7Q4fzf6FDeb/TJp7/SwaO/UuyC7VT3mabCnwOlAjRD0KV3YLnixpHCOyWgP8n7jQ5++it9fPRXOnDkNmXtvUo9+44Fqmqe/WKZCPTdEtDO4sYRLm6UgD5ymw7k3qb9h3+hvYd+ocjZ6aTWflL4M6FU7wZtHTd00H9ooK3jxh2ruMFA78+9TfssoD/65GdasqaA6tRvLPy5UKqXgu4VaBc3CsqIG4ds4kYp6J810HsO3qJV6WfpqWdbCH82lOqNoIffX9w4ersY9OFfaJ+lO+cc/Jn2fHyLdh/4idZlfkb1GjQT/nwo1ftAO4sbDPSRY+WPGzkHb5WA3rn/J1q69iT51mso/BlRqpeBPn23jLhhP65zFjcY6N0f36JdFtDZ+36kuITd9GCNR4U/J0r1JtDF+dk6bljnZ+u4oYP+RQNtHTdu0a79P9HOfT9S9t4fKeujmzRs1Azhz4lSvQN0QK/hTuOG1ddBm7hxoIy4scvSnbP2/kg7PrpJW3dfo+dfDhD+rCjVi0Bb4ka+C+NG1t6bGujtOTcoeWkeVVFrCX9elOoFoO/j66AeNxjonE+cx43tOTdp254btHX3DXpj0CThz4tSzQ+6PMtIGmincaN0XKeD1uNGKejrtDbjEtXwrSf8mVGq2UGXfxnJOm5Y52fruKGDvqGB3rL7Om3eeZ3eHDxZ+DOjVJODrkTc0L8OavnZJm7s4OLGll0M9DVatvY8PaTWFv7cKNW8oO93GakicUMHnZF9jVr79xf+3CjV7KDvbxnJ9uugo7jBQG/edZ0yGeisazR52hrhz41STQq65/BKLyNZjeucxo3rlJnNQP9AaZnfUPVH6wp/dpRqPtCdew53GDdyK7iMxOdnZ3GDgd6U9QNt3PEDvdi2t/BnR6lmBe2aZSRncWOLHjd00Nu/p2GjooU/O0o1J+g8V38dzLlJ253EjU07ikFHzd0t/NlRqjeArvwyEv91kI8bGZa4kb79e1qe9rnwZ0epZgQ9zOXLSLb52SpuWEBv2HqV1DpPC39+lGo+0O5YRtpWRtxI3/Y9rd96lRo17yD8+VGqmUG7dhnJWdzYYAH9Yps+wp8fpZoRtHuWkfivg1ZxY9tVDXSb1wYJf36UajLQPYa5dRmpuDtfs4sbaVuuUscebwt/fpRqLtCdSkC7ZxmJz8983GCgA3qPEf78KNW8oB3+qgIXLCM5ihtpW654LOgqai2q+bgf1a7/HD3p9zLVb/QKNWoeQNV8PfvXDZsGtLuXkfi4scHSnddtvkIBveQF/Y/qNalug+bUssMQ6j0wnALHpND4kAyKiMuluORzNOeDCxSXfIFik89TbNJ5mp10jho29eypjYlAu3cZSQfNx41i0O8If369qjziS41bBNDrg6fT+OCNNCvxBMUv+pzmL/qc5qV+ptXclP/QHFYWzHEc5tmJAC0daHcuI1nn5ysa6M6CQdeoVZ9avxZIo8Yvptikk7Rw8UVasPi/FP8hKwvmRaWY5+qYNdDnte6sY56VeBYdWhbQRiwj6XFjvaU7r80UB/rpxm1oyKh4mpdylhKWXqKFSy5qxTAv4DDP1zGnlmKew2GOZZiTGOZzNCsBoCUD7d5lJNu4sTbzO0NBV/WpQ517TaDpcw5R4rIvKHHpJQ1zAo95sT1mR1GDz816d45hoJ9DhpYGtLuXkWzjhlGgH1JrUYeub9OshQWUtPwLSmKYl1ljdhg1UsuIGjaYWXeOSTgD0DJUxx7DDFtG4uPGmozvqHPPd9w6pfDv9g7FJRZR8vIvKYmVhrm0OzvDPP8euTnWDvNZil4I0HKA7j6s3HFjTyWXkfi44U7QTz3biqZM30EfrPiKkld8WQzaEeYK5eYLVlFDz80Mc8zCMxroBs+1F36fireP7XTQRiwj8XGDge7kYtAP+9Sm/oExlLzsojVmJ1GDz83xFRzR6blZxxy94DRAywLaqGWkNC5urN7kWtC1n2xCITOyKWXlV/QBKzvMXxRjLiNqzKvAiE7PzTrmKICWBfRQty8j8V8HS0F/6zLQLVr3ofjUM5Sy8msLZldGjfMOR3R8d2aYAVoi0EYtI/FxY5WLQPfsH6x1ZYZZ6842UcNdI7oYG8wz408hcsgH2r3LSAy0HjdWbawc6H9U96EBgTGUuuprSllVitk+arhnRBfNRQ2GGaBlAm3QMhIfNyoDmv2Ji8AxCRpmDbRdbnb/iC5a787xxaBnzEeHlga0UctIetxgoFdWAvSIcUmUuuqyBbM7cvOFe47o+KjBMM+Yf5IaNMHYTjjo10pA3+8y0o1yLyOtyfyOVrP8vPFbWpn+LXXqUXHQvQeE0qLVl+2ihtEjuiguajDMkfMAWg7Q3YYatozEx42V6d9UGHQr/8GlMcNh1DBuRDeTixo66GfQoeUAbdQyEh83VqR/Qx0rAPrpxq9Q8vJLXG4WO6KzxRw57wRAywfavctIWtzQQW9goEeXe8EoInY/pepRQ4IR3cx4a8zT5wK0PKANWkbSx3UsblQE9KCRsQ5zs8gR3QyuOzPMAC0RaKOWkfT8zOLG8nKCbtKic0nMkGlEN0PHbOnOEXOOI3LIBdr9y0glcYOBXv8/6th99D0/nkyLyZFyRBfJRY2IucctoNsJv0/F27ftNNAGLSPxcYOBfu0eoFt3HCbtiC7SglnvzuEALUf5dxtq2DKSDprFjWX3AM3+Ixgdf1TaEd10G8zhcUXo0PKANmYZqSRulAN0u4CRUo/opnNRg2GeFldETzdG5BAPuutQw5aR+LixLK1s0GHRe6Qe0UXomOcUFYOOLaJ6fi8Lv0/F2zM0A23UMhIfN5aWAbph01elH9FFcFGDdedpsceodv2mwu8ToEtAu38ZiY8bS9MuOwUdNDZR+hFdhA3mqbHHSK3TQDhKgO46xLBlJD5uLFnnGDRbDZ2fckr6EV24Deaps49RVZ/HhaME6K5DDFtGWsHFDWeg/Zp18IgRXbglN+uYp0QdJaW6j3CUAK2BNmYZiY8bxaDtf+F5n0HTPGJEN03vzrOPUdjsQnp74ibhIAFa+0/hEMOWkfS4sXTdZVq89jL5d7MHHRKZ7REjumklUaOQwmYVUr+ghcJBAnQ1lTqUgHb/MtJyLm44As3yc8KSzzxiRDeV686hswqpY89JwkECtAPQ7lxG4vPz4rVf24Fmv2DcU0Z0Uy2YWXcOnVVAzVsPFA4SoC2gDVlG2lAaN5asvUwfrrEH/ULbvh4zogvjMIfGFJDvE42FgwRoBrrLEMOWkfi44Qh0j37BHjOiC7NEDYZ53JQs4RgB2gq0MctIfNxwBHrgiFiPGNGFcd05JKaAeg6IEo4RoC2H0K7TAMOWkfi4sWj119rvbeYvInBskkeM6MI4zCEx+dSsVV/hGAHacggt2/UxbBmJjxuLVn9lB/qd95d7xIgu1JKbGeh/Rx6mqo969p9zM9VyUvOWXQxbRuLjhiPQE0LSPWJEF6p35+h86jM4TvgdAjR3CM8+39awZSQNtCVupK6yB/2vqVs8YkQXYokawdH55Nesk3CIAM0dgu8TDQ1ZRtK/Dn5YBuiJDLQHjOhCLJjHBWdpf/pCNESAtvlB1G17rhqyjMTnZ8egN0s/oguJKdAws2rpP1I4QoB2cAhL1hQZsoyk52eGmS0g2YJ+n4GWfEQXYsH8bvAuekitLRwhQDs4hIjoDYYsI/FxI2Xllw5Byz6iC2ago/Lo5faBwgECtJNDGBQUZsgyEh83GOj2tqDDMqUe0QVbuvOYSduoilpLOECAdnIILV7pVsllpCvlWkbS4sbqryhlVfECUvsu9qBlHtEFR+fTlJmfUkMTTTZMN4fW/xxaxo5v3L6MxMeNYtCjrEGHZko9oguOyqPu/WcKvy+ALschTIta7/ZlJD5uJDsA/c/QDGlHdMHRedp/BKv5muOroKk7NKtOPUa4fRlpkR43nIEOyZB2RDcpMpeeaeLZf5zeq0BXrfkYrc+85NplpDRHcUNf4P/CDvQEBlrCEd2UqDx6qd1w4XcE0BU8hJFjY+3iRqYLl5H4/My26to5AC3jiK7HgGjh2AD6Pg6hzlNNKCPrituWkVK5uOEI9HgNtFwjur5BifTgI77CsQF0Jbq0u5aR+LjB1kTbBdiC3iTViK5fULIp581ekaH1quFbj1akXXDLMpIeNxjoREeggzdJM6LrH5TkVZhNC5pVqw5vUkb2Dy5fRuLjhjPQMozour4Z7jUxwytAsxo9YYHLl5H4uMHWRG1Bvxe8UeiIblJkLrVoM1j42QO0Gw7hYZ9aFDU326XLSHzcSHAEespGYSO6cVN2UD2/lsJRAbSb83RcwgGXLSPxcaMY9Fv2oI0e0UXnU/f+M6hazbrCQYkuU0cOvXwef4Zi5u1xyTJSye/b0H7E6hK9agP63cnpho7o2Nac2b/+KQDtOH6Mn7yk0stIen4u/qkUx6CNGNFNCMuhVv4jqcoj3jXFUO5RXtGh+WrTcTAtXv2ZS+IG23u2BT1OA+2+Ed3E8H3UNmCs6X7SRHFReR1oVnWeeo4mha+/r2UkPm6wn0p5tbM9aHeM6N6akEYvvjqUHvapI/z8FInLK0Hr1ai5P4XO3FKhZSQdNIsbCxyAHstAu2hENynyY+reL5LqNnxJ+FkpHlJeDVqvJ/1eoIFBUZS4+PQ9l5FK44YT0JPSKzWimxC2k7r1jSC/5zt55YcRpZIF0DZ/+bXpS11pYFA0RcTtpZQVFx18HSyNGws+vEht7UBvKPeILjTmMAW9u5wCXg+mZi3fIJ/H/YSDUDy8ALqMw3nY5zFq2Kw9+XcbTW8MmU4jxqbQ+6EZNHn6TgqffYgiYg/TK/7WO8ZB7y2hyTP20sSp2fRe8GYa/f46Chq3lN4YOps69ppIL7YdRA2b+pvidzErEhZAS3AJKBWggQAvgoIODQSKyc8AkUOCS0CpAA0EeBEUdGggUEx+BogcElwCSgVoIMCLoKBDA4Fi8jNA5JDgElAqQAMBXgQFHRoIFJOfASKHBJeAUgEaCPAiKOjQQKCY/AwQOSS4BJQK0ECAF0FBhwYCxeRngMghwSWgVIAGArwICjo0ECgmPwNEDgkuAaUCNBDgRVDQoYFAMfkZIHJIcAkoFaCBAC+Cgg4NBIrJzwCRQ4JLQKkADQR4ERR0aCBQTH4GiBwSXAJKBWggwIugoEMDgWLyM0DkkOASUCpAAwFeBAUdGggUk58BIocEl4BSARoI8CIo6NBAoJj8DBA5JLgElOqyM/g/5liT8Xbdsy0AAAAASUVORK5CYII=";
const ICON_64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAACXBIWXMAAAsTAAALEwEAmpwYAAAGrElEQVR4nOWaeVRUZRjG75+jZWqCWmHHzMpKrahOZnZCE8PATD0nUFOYwSxBz8mTGgoiiGyyyuaCrCI7sgso+yL7jnsmi4KA7LjreTrfvTOXAUGd43C+2/DH8+fMPO9zf9993/fOZUQTp2Asi6FtgLYY2gZoi6FtgLYY2gZoi6FtgLYY2gZoi6FtgLYY2gZoi6FtgLYY2gZoi6FtgLYY2gZoi6FtQCUCWKi1Aq5ecTCzPAK91cZQ03h3bAWgt8YYlXVPUFb9CMWVD5Fb3A9zm0DMmD1/bASgu9oYFXVPUFr9CEUVD5Bfeh85RXeRktUBnZXGYyOA8trHKKl6iMLyB8gvuYfswrvIyO/HmZxerBObq3oAEpTVPGbxP1d2H3nF95B17g7S8/qRlt2L5PQuLFluqLoB/LhKwuNfUHofuUV3kVlwB2dz+5Ca1YPk9G6En6qHmsZs1Q2gpOoRj38Oj38fUjJ7kHS2C/GpnRBvcVDdAIrl8M+Ww/90RjcSz3YhLrUDgRFXMX7yVNULYPnPEhRVPOTxz+Lx70VyRjcSznQiNqUDUUntmPeltmoGUCiHf6YM/6weJKV3IT6tE6dO30ZkYjt012xTxQDEOFf2gMefnP+0nF6czuzh8Y9Jvo2IhDask+xXvQB0Voql+MvaXx9Ss2X4d7H4Rye1Izy+DcZb3V/6916dMh3qGh9g3CQ14QSQL53+Mgv62fPP4d/N4x+V2I6wuFYYmyoWwFuz5mORthgbNntgt00GDrhXwdHrIuw9L+CV16cJJ4C8IdPfAP6dLP6RCW0IjW2FxNTtud83bpI6Pl+4Ctv+joC77zW4HfsHLkeuwsnnMhy9L8HB8wLsDp0XTgA/rBQjl5/++rjpbwj+EfFtOHnqFiQmzw5g7hc6sHLKg6ffdRw6/i9fvPPhKzhIive6CDuPC7B1rxNQAD+JpfgPTH8D+Hew+IfHtSIk5hbEJq7DfscEtTdgILaDl/91ePpzxbsfuwbXo9LiydUn6JPiD52HjVutkAIwGoR/yjD4h8W24kRMC4y2PB3A5OkzsXNfPLwDG+DlXw8PUrwvKZ5c/Ssc+l6X2HNP0D/gXof9rjXCCiBryPQ3gP9tFv/Q2FsIjn46AHJH/8siBj6k+IB6eBD05c/94csc+p4Efa54G9daWLtUY7xQAli2wuip5SdBhj/b/lrZ8x8U1QzDPwYHsH6TM3yCGuEdUD/o3PPoS889h34di761Sw2snKuEFUDGMMtPjHT6I+0vJKYFQZEkABf+cx9rarNX3jugAZ6D0OeK59DnWh459wfcaln0rZyrYelUKawA0odZfqKl0x/B/0R0CwIjbmLj7wMB7LJK4NAnxftdf2bLk517gv4+pyrsdawQTgDaekYjLj9k+iP4B0c1IyD8JjZu5gKYPXcRfAIb2XP/Ii2PQ58r3vJgJfbYFr+0b5HyAjAccfmRx98/7AY2SANYs36fFP0Xa3kc+lzxFo4V2G6RLqwA0kZYfsj0J8PfL/QGfv3Nmf3MTst4hVoeOfcy9M0dymFoEiCcAJbqGY64/Mjjf/xkEx+Ak3eNQi2PLZ5cfYdy7LErw7JVZsIJQGuZwYjLD5n+ZPj7hjRh/SYn9qkQufKKtDwWfYcK7LEvw27bUrz/ibZwAtBcoDPi8sPh38zifyykkQ1govoMhVsei759OXbblcLULAXjJqsLJ4B35miOuPwER7Vw+Ic24eiJRqwzJgFoKNzyzKXom9mWYMES5f3ZwijjS8iDiZCoq8MuP2T68w+/Cd+TTTgS3IC10gAUaXnsubcnxZdi8/YYdnwWVAAicle3CBh2+QmMbIZfGIf/4aAGrJUcZANQpOWZS8/9DusCzPxwkdKKFykzgDmffsve/IYuPwERBP8bLP4+gfUwkAagSMsj597MphifLTRQavEiZb8fsMM86KnlRx5/svAYiLkAFGl5u/YXQvObtUovXqTsACZNmwFnn/xB0x+HfxOLP3nYoS8N4EVbnsmuRMz66LtRKV40Gm+IkP//zKyj+OlPHn8y8+sbObIBPK/l7bDOw2LdPzFhypujVrxotF6RIQ81tXSMYOOSJcWf2/dJ79c3dMRr6hrDtjxz+xKItwbh6+8lmDj17VEtfFQDEPFBqGHWnK+wVG8L++Bj0zZfLNE1Ya+q2NQP+mIX6P2yF1rLTfHevMVKbW+CCED0PxBD2wBtMbQN0BZD2wBtMbQN0BZD2wBtMbQN0BZD2wBtMbQN0BZD2wBtMbQN0BZD2wBtMbQN0BZD2wBt/QeTY5LZjN0p1QAAAABJRU5ErkJggg==";
const APP_HTML = "<!-- Life OS 11.46. Source of truth for UI; build.py embeds this file in the Worker.\nOne design system owns layout and components. Finance and Life OS logic are preserved. -->\n<!doctype html>\n<html lang=\"it\">\n  <head>\n    <meta charset=\"utf-8\" />\n    <script>\n      try {\n        document.documentElement.dataset.theme =\n          localStorage.getItem(\"life-theme\") ||\n          (matchMedia(\"(prefers-color-scheme: light)\").matches\n            ? \"light\"\n            : \"dark\");\n      } catch (e) {\n        document.documentElement.dataset.theme = \"dark\";\n      }\n    </script>\n    <meta\n      name=\"viewport\"\n      content=\"width=device-width, initial-scale=1, viewport-fit=cover\"\n    />\n\n    <title>Life OS</title>\n    <meta name=\"theme-color\" content=\"#0c0c0e\" />\n    <link rel=\"manifest\" href=\"/manifest.webmanifest\" />\n    <meta name=\"apple-mobile-web-app-capable\" content=\"yes\" />\n    <meta\n      name=\"apple-mobile-web-app-status-bar-style\"\n      content=\"black-translucent\"\n    />\n    <meta name=\"apple-mobile-web-app-title\" content=\"Life OS\" />\n    <link rel=\"icon\" type=\"image/png\" href=\"/favicon.png?v=1160periwinkle\" />\n    <link\n      rel=\"apple-touch-icon\"\n      sizes=\"180x180\"\n      href=\"/apple-touch-icon.png?v=1160periwinkle\"\n    />\n\n<style id=\"lifeos-design-system\">/* Life OS: one set of tokens, one layout, one component system. */\n:root {\n font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",sans-serif;font-size:14px;line-height:1.45;\n --os-bg:#0c0c0e;--os-panel:#171719;--os-panel-2:#222225;--ink:#f4f5f7;--muted:#a2a2a9;--line:#303034;--os-accent:#a5aeed;--os-focus:#a5aeed;--green:var(--os-accent);--red:#ee858e;\n --surface:var(--os-panel);--blue:var(--os-accent);--os-secondary:var(--muted);--os-border:var(--line);--os-text:var(--ink);\n --safe-top:env(safe-area-inset-top,0px);--safe-bottom:env(safe-area-inset-bottom,0px);--page-gutter:20px;--card-padding:20px;--card-radius:22px;--space:16px;--nav-height:72px;\n color-scheme:dark;background:var(--os-bg);color:var(--ink);\n}\nhtml[data-theme=\"light\"] {--os-bg:#f3f3f5;--os-panel:#fff;--os-panel-2:#e8e8ec;--ink:#202024;--muted:#64646d;--line:#dcdce1;--os-accent:#565f9c;--os-focus:#565f9c;--green:var(--os-accent);--red:#b53747;color-scheme:light;}\n*,*::before,*::after {box-sizing:border-box;} body {margin:0;background:var(--os-bg);color:var(--ink);-webkit-text-size-adjust:100%;}\nbutton,input,select,textarea {font:inherit;}button {cursor:pointer;color:inherit;touch-action:manipulation;-webkit-tap-highlight-color:transparent;}\nbutton {display:inline-flex;align-items:center;justify-content:center;gap:6px;min-height:40px;padding:9px 14px;background:transparent;border:1px solid var(--line);border-radius:12px;}\nbutton:disabled {opacity:.45;cursor:default;}button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible,summary:focus-visible {outline:2px solid var(--os-focus);outline-offset:3px;}\nbutton:hover {background:var(--os-panel-2);} button:active {opacity:.8;} a {color:var(--os-accent);} svg {display:block;}svg:not([width]) {max-width:100%;}\nh1,h2,h3,p {margin:0;}h1 {font-size:32px;line-height:1.15;letter-spacing:-1.2px;font-weight:750;}h2 {font-size:19px;line-height:1.3;letter-spacing:-.4px;}h3 {font-size:15px;line-height:1.4;}small {font-size:12px;color:var(--muted);}b,strong {font-weight:650;font-variant-numeric:tabular-nums;} summary {cursor:pointer;}summary::-webkit-details-marker {display:none;}summary {list-style:none;}\n.hidden,[hidden] {display:none!important;}.view {display:none;}.view.active {display:block;}.income,.positive {color:var(--green);}.outgo,.outgoings,.negative,.danger {color:var(--red);}.muted,.hint,.empty,.os-empty,.os-task-empty {color:var(--muted);}.hint {font-size:12px;margin-top:12px;}.empty,.os-empty,.os-task-empty {padding:16px 0;}\n.shell {display:grid;grid-template-columns:208px minmax(0,1fr);min-height:100svh;}.sidebar {position:sticky;top:0;height:100svh;display:flex;flex-direction:column;padding:28px 18px;border-right:1px solid var(--line);background:var(--os-panel);}\n.brand {display:flex;align-items:center;gap:10px;font-size:20px;font-weight:700;margin-bottom:32px;}.brand .mark,.brand .mark svg {width:28px;height:34px;}.nav {display:grid;gap:6px;}.nav button {justify-content:flex-start;border:0;gap:12px;min-height:48px;color:var(--muted);}.nav button.active {color:var(--os-accent);background:color-mix(in srgb,var(--os-accent) 12%,transparent);}.nav-symbol {width:22px;height:22px;flex:none;}.sidebar-foot {margin-top:auto;font-size:11px;color:var(--muted);}\nmain {width:100%;max-width:1140px;margin:0 auto;padding:32px 32px 104px;min-width:0;}.top {margin-bottom:20px;}.page-heading {display:flex;justify-content:space-between;align-items:center;gap:16px;min-height:44px;}.page-heading h1 {min-width:0;}.header-tools {display:flex;align-items:center;gap:8px;flex:none;}.theme-toggle {width:44px;height:44px;min-height:44px;padding:0;border-radius:50%;font-size:23px;line-height:1;}\n.header-meta {margin-top:10px;}.home-context {display:none;color:var(--muted);font-size:13px;}.dashboard-mode .home-context {display:block;}.header-meta:not(:has(.top-right:not(.hidden))):not(:has(.dashboard-mode)) {margin-top:0;}.dashboard-mode .header-meta {margin-top:8px;}body:not(.dashboard-mode) .header-meta:has(.top-right.hidden) {display:none;}\n.top-right {display:flex;align-items:center;justify-content:space-between;}.period {display:flex;align-items:center;gap:8px;width:210px;}.period button {width:32px;height:32px;min-height:32px;padding:0;border:0;font-size:23px;color:var(--muted);}.period strong {flex:1;text-align:center;font-size:13px;font-weight:550;}.sync {font-size:11px;color:var(--muted);}\n.page-actions:empty {display:none;}.os-more-menu {position:relative;}.os-more-menu summary {display:grid;place-items:center;width:40px;height:40px;border:1px solid var(--line);border-radius:50%;font-size:20px;color:var(--muted);}.os-more-menu summary svg {width:20px;height:20px;}.os-more-menu > div {position:absolute;top:48px;right:0;z-index:60;background:var(--os-panel);padding:8px;border:1px solid var(--line);border-radius:14px;box-shadow:0 12px 30px #0003;min-width:200px;}.os-more-menu > div button {display:flex;width:100%;justify-content:flex-start;border:0;white-space:nowrap;font-size:13px;}\n.finance-tabs,.os-category-tabs {display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:4px;border:1px solid var(--line);border-radius:17px;background:var(--os-panel);margin-bottom:16px;position:relative;}.finance-tabs::-webkit-scrollbar,.os-category-tabs::-webkit-scrollbar {display:none;}.finance-tabs button,.os-category-tabs button {border:0;flex:1;white-space:nowrap;padding:9px 12px;min-height:40px;color:var(--muted);font-size:13px;}.finance-tabs button.active,.os-category-tabs button.active {background:var(--os-panel-2);color:var(--os-accent);font-weight:650;}.os-category-tabs .add {position:sticky;right:0;flex:0 0 36px;min-width:36px;background:var(--os-panel);font-size:22px;}.os-category-tabs button:not(.add) {flex:0 0 auto;}\n.card,.os-card,.extra-card {background:var(--os-panel);border:1px solid var(--line);border-radius:var(--card-radius);min-width:0;}.pad,.os-card,.extra-card {padding:var(--card-padding);}.card-title,.os-topline,.overview-section-heading,.extra-card-head {display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:18px;}.card-title .actions,.actions,.chart-range {display:flex;align-items:center;gap:6px;}.save,.os-button.primary {background:var(--os-accent);color:var(--os-bg);border-color:transparent;font-weight:600;}.save:hover,.os-button.primary:hover {filter:brightness(1.06);}.ghost,.os-button {background:transparent;}.os-button:not(.primary),.os-row-action {border:0;color:var(--os-accent);padding:6px 8px;}.os-icon-button,.privacy-toggle,.os-wait,.os-drag-handle {width:36px;height:36px;min-height:36px;flex:none;padding:6px;border:0;border-radius:50%;color:var(--muted);}.privacy-toggle svg {width:22px;height:22px;}.os-icon-button {font-size:25px;}.privacy-toggle:hover {background:var(--os-panel-2);}\n.page-fab {position:fixed;right:24px;bottom:24px;z-index:35;}.page-fab .fab-button {display:grid;place-items:center;width:56px;height:56px;min-height:56px;padding:0;border-radius:50%;box-shadow:0 5px 18px #0004;border:0;}.fab-button svg {width:24px;height:24px;flex:none;}body:has(.modal-wrap:not(.hidden),dialog[open]) .page-fab {visibility:hidden;}\n.os-home {display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:var(--space);}.os-home-daygrid {display:grid;grid-template-columns:minmax(0,1fr) auto;gap:14px;}.os-home-daygrid > div {border-left:3px solid var(--shift-color,var(--os-accent));padding-left:12px;}.os-home-daygrid h2 {font-size:25px;margin-top:5px;}.os-shift-time {font-size:.7em;font-weight:550;white-space:nowrap;}.os-home-label,.os-home-tomorrow > span {display:block;font-size:12px;color:var(--muted);}.os-home-tomorrow {align-self:center;}.os-home-tomorrow strong {display:block;margin-top:5px;font-size:16px;}.os-routine {display:flex;gap:16px;margin-top:18px;padding-top:16px;border-top:1px solid var(--line);align-items:center;}.os-routine-head {flex:none;min-width:54px;}.os-routine-head > span {color:var(--muted);font-size:12px;display:block;}.os-routine-head b {display:block;}.os-routine-manage {padding:6px 0;border:0;min-height:32px;color:var(--os-accent);font-size:12px;}.os-routine-items {display:flex;gap:7px;flex-wrap:wrap;min-width:0;}.os-routine-check {gap:7px;padding:8px 10px;min-height:42px;font-size:13px;white-space:normal;}.os-routine-tick {display:grid;place-items:center;width:17px;height:17px;border:1.5px solid var(--muted);border-radius:5px;flex:none;line-height:1;}.os-routine-check.checked .os-routine-tick {background:var(--os-accent);border-color:var(--os-accent);color:var(--os-bg);}\n.os-home-agenda .os-topline h2 {color:var(--muted);}.os-home-agenda .os-topline .os-button {font-size:12px;white-space:nowrap;}.os-home-task {display:flex;align-items:center;gap:12px;padding:14px 0;min-height:58px;}.os-home-task + .os-home-task {border-top:1px solid var(--line);}.os-home-task-title {min-width:0;flex:1;text-align:left;justify-content:flex-start;padding:0;border:0;min-height:30px;font-size:16px;line-height:1.4;overflow-wrap:anywhere;}.os-check {display:grid;place-items:center;width:24px;height:24px;min-height:24px;padding:0;border-radius:50%;border:1.5px solid var(--muted);flex:none;}.os-check.checked {background:var(--os-accent);color:var(--os-bg);border-color:var(--os-accent);}.os-check.checked::after {content:'\u2713';font-size:14px;}\n.os-agenda-entry {display:flex;align-items:center;gap:8px;padding:12px 0;border-top:1px solid var(--line);}.os-agenda-row {display:flex;justify-content:flex-start;gap:12px;flex:1;min-width:0;border:0;text-align:left;padding:0;}.os-agenda-date {text-align:center;width:36px;flex:none;}.os-agenda-date b,.os-agenda-date small {display:block;}.os-agenda-title {flex:1;min-width:0;}.os-agenda-title small {display:block;margin-top:3px;}.os-agenda-done {font-size:11px;border:0;color:var(--os-accent);padding:4px;}.os-home-finance {align-self:start;}.os-home-money {display:grid;grid-template-columns:minmax(0,1fr) 36px;align-items:start;gap:12px;padding-bottom:18px;border-bottom:1px solid var(--line);}.os-money-primary {container-type:inline-size;}.os-money-primary small {display:block;margin-bottom:8px;}.os-money-primary strong {display:block;font-size:min(42px,calc(100cqw / var(--money-units,6)));line-height:1.1;letter-spacing:-1.3px;white-space:nowrap;}.os-home-submoney.large-amount {grid-template-columns:minmax(0,1fr);}.os-home-submoney {display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:20px;padding-top:16px;}.os-home-metric > span {display:block;font-size:12px;color:var(--muted);margin-bottom:6px;}.os-home-metric > b {display:block;font-size:18px;line-height:1.4;letter-spacing:0;white-space:nowrap;}.os-home-private {padding-right:0;}.os-home-money .privacy-toggle {position:static;}.os-home-private .privacy-toggle {position:absolute;right:-4px;top:12px;width:32px;height:32px;min-height:32px;}.os-home-prayer {grid-column:1/-1;}.os-sunline-meta {display:flex;justify-content:space-between;gap:10px;color:var(--muted);font-size:12px;}.os-sunline-meta strong {text-align:right;font-size:12px;}.os-home-times summary {color:var(--os-accent);font-size:12px;padding-top:10px;}.os-prayer-list {display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:12px;}.os-prayer {display:flex;justify-content:space-between;font-size:12px;gap:8px;}.os-prayer.next {color:var(--os-accent);}\n.os-category-page {padding:0 18px;}.os-task {display:grid;grid-template-columns:28px 26px minmax(0,1fr) 30px;gap:10px;align-items:center;min-height:72px;padding:16px 0;}.os-task + .os-task {border-top:1px solid var(--line);}.os-task-title {justify-content:flex-start;text-align:left;border:0;padding:0;min-height:24px;font-size:16px;line-height:1.45;overflow-wrap:anywhere;}.os-drag-handle {width:28px;min-height:44px;padding:0;cursor:grab;touch-action:none;user-select:none;-webkit-user-select:none;}.os-drag-handle svg {width:14px;height:22px;}.os-wait {width:30px;padding:5px;}.os-wait svg {width:17px;height:19px;}.os-task.is-dragging {opacity:.6;}.os-task-section {border-top:1px solid var(--line);padding-top:18px;}.os-task-section h3 {color:var(--muted);font-size:13px;margin-bottom:4px;font-weight:500;}.os-task-section .os-task {grid-template-columns:26px minmax(0,1fr) 30px;}.os-completed {border-top:1px solid var(--line);padding:16px 0;}.os-completed summary {font-size:13px;color:var(--muted);}.os-completed .os-task {grid-template-columns:26px minmax(0,1fr) 30px;}.os-task-delete,.os-delete-completed {font-size:12px;color:var(--red);border:0;}.due-badge {display:inline-block;font-size:10px;font-weight:500;color:var(--muted);margin-left:7px;}.due-badge.overdue {color:var(--red);}\n.os-month-header {display:grid;grid-template-columns:36px minmax(0,1fr) 36px;align-items:center;margin-bottom:16px;}.os-month-header h2 {text-align:center;text-transform:capitalize;font-size:22px;}.os-month-header button {border:0;min-height:36px;padding:0;font-size:25px;color:var(--muted);}.os-weekdays {display:grid;grid-template-columns:repeat(7,minmax(0,1fr));text-align:center;font-size:12px;color:var(--muted);margin-bottom:10px;}.os-days {display:grid;gap:6px;}.os-calendar-week {display:grid;grid-template-columns:repeat(7,minmax(0,1fr));padding:3px;background:var(--os-panel-2);border:1px solid var(--line);border-radius:13px;gap:2px;}.os-day {display:grid;grid-template-columns:1fr;grid-template-rows:20px 20px 12px;justify-items:center;align-items:center;align-content:center;gap:3px;width:100%;height:64px;min-height:64px;padding:5px 0;border:0;border-radius:9px;line-height:1;}.os-day b {grid-row:1;display:grid;place-items:center;width:24px;height:20px;line-height:20px;font-size:14px;color:var(--ink);}.os-day .os-shift {grid-row:2;font-size:12px;font-weight:700;width:calc(100% - 8px);max-width:48px;height:20px;display:flex;align-items:center;justify-content:center;border-radius:5px;background:var(--shift-color);color:#101215;}.os-day-mark {grid-row:3;display:grid;place-items:center;min-height:10px;height:10px;line-height:10px;font-size:10px;font-weight:600;color:var(--ink);}.os-day-mark.dot::after {content:'';width:3px;height:3px;border-radius:50%;background:currentColor;}.os-day.today b {background:var(--ink);color:var(--os-bg);border-radius:50%;}.os-day.selected {background:color-mix(in srgb,var(--os-accent) 18%,var(--os-panel));box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--os-accent) 45%,transparent);}.os-day.other {opacity:.45;}\n.os-calendar-week > .os-day:nth-child(n+6) {background:color-mix(in srgb,var(--os-panel-2) 86%,black);border-radius:0;}\n.os-calendar-week > .os-day:nth-child(n+6).selected {background:color-mix(in srgb,var(--os-accent) 18%,color-mix(in srgb,var(--os-panel-2) 86%,black));}.os-calendar-details {margin-top:20px;padding-top:18px;border-top:1px solid var(--line);}.os-calendar-details > h3 {margin-bottom:16px;}.os-mini {display:flex;align-items:center;justify-content:space-between;gap:10px;padding:12px 0;border-bottom:1px solid var(--line);}.os-mini > div:first-child {flex:1;min-width:0;}.os-mini small {display:block;}.os-mini:last-child {border:0;}.os-section-label {color:var(--muted);margin-top:16px;font-size:12px;}.os-event-options {position:relative;font-size:12px;}.os-event-options summary {padding:8px;color:var(--muted);}.os-event-options[open] button {display:block;}.os-tools-drawer {margin-top:16px;color:var(--muted);font-size:13px;}.os-palette-state {padding:12px 0;}.os-palette {display:flex;gap:8px;flex-wrap:wrap;}.os-palette button.active {border-color:var(--os-accent);background:var(--os-panel-2);}.os-palette-stop {margin-top:8px;}\n[data-kind=\"morning\"] {--shift-color:#b4c6e7;}[data-kind=\"afternoon\"] {--shift-color:#c6e0b4;}[data-kind=\"night\"] {--shift-color:#808080;}[data-kind=\"rest\"] {--shift-color:#f4b084;}[data-kind=\"holiday\"] {--shift-color:#ffff00;}html[data-theme=\"light\"] [data-kind=\"morning\"] {--shift-color:#b4c6e7;}html[data-theme=\"light\"] [data-kind=\"afternoon\"] {--shift-color:#c6e0b4;}html[data-theme=\"light\"] [data-kind=\"night\"] {--shift-color:#808080;}html[data-theme=\"light\"] [data-kind=\"rest\"] {--shift-color:#f4b084;}html[data-theme=\"light\"] [data-kind=\"holiday\"] {--shift-color:#ffff00;}\n.overview-essential {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);}.overview-essential > section:not(.overview-flow),.overview-flow > div {border:1px solid var(--line);background:var(--os-panel);border-radius:var(--card-radius);padding:var(--card-padding);}.overview-label {font-size:20px;color:var(--ink);line-height:1.25;font-weight:650;margin:0;}.overview-primary,.overview-accounts {container-type:inline-size;}.overview-balance {font-size:min(42px,calc(100cqw / var(--money-units,6)));line-height:1.1;font-weight:700;letter-spacing:-1.2px;white-space:nowrap;}.budget-equation {display:grid;grid-template-columns:minmax(0,1fr) auto minmax(0,1fr) auto minmax(0,1fr);align-items:baseline;gap:7px;margin-top:18px;padding-top:16px;border-top:1px solid var(--line);font-size:clamp(11px,3.3vw,15px);font-variant-numeric:tabular-nums;}.budget-equation span:nth-child(3) {text-align:center;}.budget-equation strong {text-align:right;}.budget-equation strong {margin-left:0;}.overview-section-heading {display:grid;grid-template-columns:minmax(0,1fr) 36px;align-items:center;gap:12px;min-height:36px;margin-bottom:18px;}.overview-section-heading h2 {font-size:20px;line-height:1.25;font-weight:650;margin:0;}.overview-primary .overview-section-heading {grid-template-columns:minmax(0,1fr);}.overview-total strong {font-size:min(42px,calc(100cqw / var(--money-units,6)));line-height:1.1;display:block;margin:0;white-space:nowrap;letter-spacing:-1.2px;}.overview-total small {display:block;}.overview-flow {grid-column:1/-1;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);}.overview-flow span {display:block;color:var(--muted);font-size:12px;margin-bottom:8px;}.overview-flow strong {font-size:25px;line-height:1.2;white-space:nowrap;}\n.budget-flow,.budget-charts {display:grid;gap:var(--space);}.budget-charts {grid-template-columns:repeat(2,minmax(0,1fr));}.budget-charts > .integrated-chart {grid-column:1/-1;}.budget-charts .flow-card {grid-column:auto;}.kv {display:grid;grid-template-columns:minmax(0,1fr) max-content;gap:12px;padding:12px 0;border-bottom:1px solid var(--line);}.kv > span {min-width:0;overflow-wrap:anywhere;}.kv > strong {white-space:nowrap;text-align:right;}.kv:last-child {border:0;}.kv.total {font-weight:650;}.daily-budget {display:grid;gap:6px;padding-top:16px;}.daily-budget > span {font-size:12px;color:var(--muted);}.daily-budget strong {font-size:24px;}.budget-settings {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);padding-top:20px;}.budget-settings-wrap > summary,.annual-card > summary,.budget-history summary {font-size:16px;font-weight:600;}.balance-settings-column {display:grid;gap:20px;align-content:start;}.edit-line {display:flex;justify-content:space-between;align-items:center;gap:12px;padding:14px 0;border-bottom:1px solid var(--line);}.edit-line small {display:block;margin-top:4px;}.edit-controls {display:flex;align-items:center;gap:8px;}.edit-input {width:100px;}.budget-detail-content {padding-top:18px;}.annual-row,.annual-head {display:grid;grid-template-columns:1fr repeat(6,minmax(0,1fr));gap:8px;padding:12px 0;border-top:1px solid var(--line);font-size:12px;}.annual-row.selected {color:var(--os-accent);}.annual-head {font-weight:600;color:var(--muted);}.planning-inputs {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;}.planning-inputs label {display:grid;gap:6px;font-size:12px;}.fund-meter {display:flex;height:7px;background:var(--os-panel-2);border-radius:7px;overflow:hidden;margin:18px 0 8px;}.fund-meter i {display:block;height:100%;background:var(--os-accent);}#fund-surplus {background:color-mix(in srgb,var(--os-accent) 40%,var(--os-panel-2));}.fund-labels {display:flex;justify-content:space-between;color:var(--muted);font-size:12px;}.projection-result {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;margin-top:18px;}.projection-result span,.projection-result small {display:block;color:var(--muted);font-size:12px;}.projection-result strong {font-size:24px;}.planning-actions {display:flex;gap:8px;flex-wrap:wrap;margin-top:18px;}.plan-row {display:flex;justify-content:space-between;gap:10px;padding:10px 0;border-top:1px solid var(--line);}\n.chart-scroll,.sankey-scroll,.table-scroll {overflow-x:auto;min-width:0;}.trend-svg,.sankey-svg {width:100%;height:auto;}.trend-svg text,.sankey-svg text {fill:var(--muted);font-size:11px;}.grid-line,.axis {stroke:var(--line);stroke-width:1;}.income-line,.income-path {stroke:var(--green);fill:none;stroke-width:2;}.spent-line,.spent-path {stroke:var(--red);fill:none;stroke-width:2;}.wealth-record-line,.wealth-estimate-line {stroke:var(--os-accent);fill:none;stroke-width:2;}.wealth-estimate-line {stroke-dasharray:4 4;}.wealth-dot {fill:var(--os-accent);}.chart-pair {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);}.flow-legend,.chart-values,.trend-values,.sankey-totals,.wealth-series {display:flex;gap:12px;flex-wrap:wrap;color:var(--muted);font-size:12px;}.flow-legend {margin-top:10px;}.flow-legend i {display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:5px;}.income-key,.spent-key {display:inline-flex;align-items:center;gap:5px;background:none;}.income-key::before,.spent-key::before {content:\"\";width:7px;height:7px;border-radius:50%;background:var(--green);}.spent-key::before {background:var(--red);}.chart-range button,.wealth-series button {min-height:30px;padding:4px 7px;font-size:11px;}.chart-range .active,.wealth-series .active {color:var(--os-accent);border-color:var(--os-accent);}.liquid-chart-heading {display:flex;justify-content:space-between;gap:8px;margin-bottom:12px;}.sankey-ribbon {opacity:.65;}.sankey-label {fill:var(--ink)!important;}.sankey-totals {margin-bottom:16px;}.expense-details {margin-top:14px;}.expense-category {padding:10px 0;border-top:1px solid var(--line);}.expense-category > summary {display:flex;justify-content:space-between;}.overview-recent-row {display:flex;justify-content:space-between;gap:8px;padding:8px 0;font-size:12px;}.quick-classify {font-size:11px;min-height:30px;padding:4px 7px;}\n.breakdown {display:grid;grid-template-columns:120px minmax(0,1fr);gap:16px;align-items:center;}.category-ring {position:relative;width:120px;height:120px;flex:none;}.category-ring svg {width:120px;height:120px;}.category-ring-label {position:absolute;inset:22%;display:flex;flex-direction:column;justify-content:center;align-items:center;pointer-events:none;}.category-ring-label small {font-size:10px;}.category-ring-label strong {font-size:13px;white-space:nowrap;}.category-legend {min-width:0;}.bar-row {display:grid;grid-template-columns:minmax(0,1fr) auto;gap:4px 8px;margin-bottom:12px;font-size:12px;}.bar-row span {overflow-wrap:anywhere;}.bar {grid-column:1/-1;height:4px;background:var(--os-panel-2);border-radius:3px;overflow:hidden;}.bar i {display:block;height:100%;}.category-swatch {display:inline-block;width:7px;height:7px;border-radius:50%;margin-right:5px;}.details-label {margin-top:18px;color:var(--muted);font-size:12px;}.small-arrow {width:28px;height:30px;min-height:30px;border:0;padding:0;font-size:20px;}.category-month {font-size:12px;color:var(--muted);white-space:nowrap;}\n.filters {display:flex;gap:10px;margin-bottom:18px;}.filters .search {flex:1;min-width:0;}.tabular {border-collapse:collapse;width:100%;font-size:13px;}.tabular th {color:var(--muted);font-size:11px;text-align:left;font-weight:500;}.tabular td,.tabular th {padding:12px 8px;border-bottom:1px solid var(--line);}.tabular th:first-child,.tabular td:first-child {padding-left:0;}.tabular .num {text-align:right;white-space:nowrap;}.tx-description-row {display:flex;justify-content:space-between;gap:12px;}.tx-description-text small {display:block;}.tx-actions {display:flex;gap:6px;}.tx-actions button {min-height:30px;font-size:11px;padding:4px 6px;}.movement-list {display:none;}.movement-more {margin-top:16px;}.extra-grid {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;}.extra-toolbar {display:none;}.extra-card-head {display:grid;grid-template-columns:minmax(0,1fr) max-content;align-items:baseline;}.extra-card-head h3 {min-width:0;overflow-wrap:anywhere;}.extra-card-head strong {white-space:nowrap;font-size:18px;}.extra-metadata {display:flex;justify-content:space-between;color:var(--muted);font-size:12px;gap:8px;margin-bottom:18px;}.extra-card-controls {display:flex;gap:8px;flex-wrap:wrap;}.extra-card-controls button {font-size:12px;}.extra-state-row {display:flex;align-items:center;gap:8px;flex:1;}.state-tag {font-size:11px;border-radius:6px;background:var(--os-panel-2);padding:5px 8px;color:var(--muted);}.extra-pay-action {color:var(--os-accent);border:0;}.extra-info {padding-top:12px;}\ninput,select,textarea {display:block;width:100%;min-height:42px;padding:10px 12px;border:1px solid var(--line);border-radius:10px;background:var(--os-panel-2);color:var(--ink);min-width:0;}textarea {min-height:84px;resize:vertical;}input[type=checkbox] {width:18px;min-height:18px;}input::placeholder,textarea::placeholder {color:var(--muted);}.modal-wrap {position:fixed;inset:0;z-index:100;display:flex;align-items:center;justify-content:center;padding:24px;background:#0008;overflow-y:auto;}.modal {background:var(--os-panel);border:1px solid var(--line);border-radius:24px;padding:24px;width:min(600px,100%);max-height:calc(100svh - 48px);overflow-y:auto;}.modal-top {display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:22px;}.modal-top h2 {font-size:22px;}.os-form,.form-grid {display:grid;grid-template-columns:1fr 1fr;gap:14px;}.os-form label,.form-grid label {display:grid;gap:6px;font-size:12px;color:var(--muted);}.os-form .wide,.form-grid .full,.form-grid .wide {grid-column:1/-1;}.form-actions {position:sticky;bottom:0;background:var(--os-panel);padding-top:12px;padding-bottom:4px;z-index:2;}\n.form-actions,.os-form-actions {grid-column:1/-1;display:flex;justify-content:flex-end;gap:8px;margin-top:10px;}.os-form-error {grid-column:1/-1;color:var(--red);font-size:13px;}.os-inline-event {margin-top:18px;border-top:1px solid var(--line);padding-top:16px;}.os-routine-manager > div {display:flex;align-items:center;gap:8px;padding:10px 0;border-bottom:1px solid var(--line);}.os-routine-manager span {flex:1;}.os-routine-manager button {font-size:11px;min-height:30px;padding:4px 7px;}.os-routine-dialog > p {color:var(--muted);font-size:12px;margin-bottom:12px;}.os-routine-dialog form {margin-top:16px;}.category-order {padding-top:12px;}.category-order > div {display:flex;align-items:center;gap:6px;padding:8px 0;}.category-order span {flex:1;}\n.errorbox {background:color-mix(in srgb,var(--red) 10%,var(--os-panel));border:1px solid var(--red);color:var(--red);padding:12px;border-radius:12px;margin-bottom:16px;}.loading-overlay {position:fixed;inset:0;z-index:80;display:grid;place-items:center;background:#0004;}.loading-panel {display:grid;gap:12px;justify-items:center;background:var(--os-panel);border:1px solid var(--line);border-radius:20px;padding:28px;}.loading-spinner {width:24px;height:24px;border:2px solid var(--line);border-top-color:var(--os-accent);border-radius:50%;animation:spin .8s linear infinite;}@keyframes spin {to {transform:rotate(360deg);}}\n@media(max-width:760px) {\n :root {--card-padding:18px;--space:14px;}.shell {display:block;min-height:100svh;}.sidebar {position:fixed;inset:auto 14px calc(12px + var(--safe-bottom));height:var(--nav-height);width:auto;max-width:520px;margin:0 auto;padding:5px;border:1px solid var(--line);border-radius:36px;z-index:40;background:color-mix(in srgb,var(--os-panel) 90%,transparent);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);}.brand,.sidebar-foot {display:none;}.nav {display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:2px;width:100%;height:100%;}.nav button {display:flex;flex-direction:column;justify-content:center;gap:5px;padding:4px 2px;min-height:0;border-radius:30px;font-size:11px;line-height:1.2;}.nav-symbol {width:22px;height:22px;}\n main {padding:calc(22px + var(--safe-top)) var(--page-gutter) calc(164px + var(--safe-bottom));max-width:600px;margin:0 auto;}.top {margin-bottom:18px;}.page-heading {gap:10px;}.header-tools {gap:6px;}h1 {font-size:30px;}.theme-toggle {width:40px;height:40px;min-height:40px;font-size:22px;}.os-more-menu summary {width:36px;height:36px;font-size:18px;}.sync {display:none;}.period {width:190px;gap:4px;}.header-meta {margin-top:10px;}.page-fab {right:20px;bottom:calc(100px + var(--safe-bottom));}.page-fab .fab-button {width:56px;height:56px;min-height:56px;}\n .os-home {grid-template-columns:minmax(0,1fr);}.os-home-daygrid h2 {font-size:24px;}.os-routine {gap:12px;}.os-routine-items {gap:6px;}.os-routine-check {font-size:12px;padding:8px;}.os-money-primary strong {font-size:min(40px,calc(100cqw / var(--money-units,6)));}.os-home-submoney {gap:14px;}.os-home-metric > b {font-size:18px;}.os-sunline-meta {font-size:11px;}.os-sunline-meta strong {font-size:11px;}.os-prayer-list {grid-template-columns:repeat(2,minmax(0,1fr));}\n .os-category-page {padding:0 14px;}.os-task {gap:8px;grid-template-columns:28px 24px minmax(0,1fr) 26px;min-height:68px;padding:16px 0;}.os-task-title {font-size:15px;}.os-wait {width:26px;}.os-drag-handle {width:16px;}.os-category-tabs button {padding:9px 11px;}.os-month-header {margin-bottom:16px;}.os-month-header h2 {font-size:21px;}.os-calendar-week {gap:0;padding:2px;}.os-calendar-details {margin-top:18px;}\n .overview-essential {grid-template-columns:minmax(0,1fr);}.overview-balance,.overview-total strong {font-size:min(42px,calc(100cqw / var(--money-units,6)));}.budget-equation {font-size:clamp(11px,3.3vw,14px);gap:6px;}.overview-flow strong {font-size:clamp(16px,4.8vw,24px);}.overview-flow.large-amount {grid-template-columns:minmax(0,1fr);}.budget-charts,.budget-settings,.extra-grid,.chart-pair {grid-template-columns:minmax(0,1fr);}.budget-charts .flow-card {grid-column:auto;}.daily-budget strong {font-size:23px;}.annual-row,.annual-head {min-width:480px;grid-template-columns:1fr repeat(5,minmax(0,1fr));}.annual-card .budget-detail-content {overflow-x:auto;}.card-title {flex-wrap:wrap;}.card-title h2 {font-size:18px;}.tr-category-card .card-title {flex-wrap:nowrap;}.breakdown {grid-template-columns:110px minmax(0,1fr);gap:12px;}.category-ring,.category-ring svg {width:110px;height:110px;}.category-ring-label strong {font-size:12px;}\n .mobile-ledger > table {display:none;}.movement-list {display:block;}.movement-compact {display:grid;grid-template-columns:42px minmax(0,1fr) auto;gap:8px 12px;padding:16px 0;border-bottom:1px solid var(--line);align-items:start;}.movement-compact time {font-size:11px;color:var(--muted);}.movement-main strong {font-size:14px;overflow-wrap:anywhere;}.movement-main small {display:block;font-size:11px;margin-top:4px;}.movement-compact > b {white-space:nowrap;font-size:13px;}.movement-tools {grid-column:2/-1;display:flex;justify-content:flex-end;gap:4px;}.movement-tools button {width:30px;height:30px;min-height:30px;padding:5px;border:0;}.movement-tools svg {width:17px;height:17px;}.filters {flex-wrap:wrap;}.filters .search {flex-basis:100%;}.filters select {width:100%;}.edit-line {flex-wrap:wrap;}.edit-controls {width:100%;}.edit-input {flex:1;}\n .modal-wrap {align-items:flex-end;padding:calc(12px + var(--safe-top)) 0 0;}.modal {border-radius:24px 24px 0 0;max-height:calc(100svh - 12px - var(--safe-top));padding:22px 20px calc(22px + var(--safe-bottom));width:100%;}.os-form,.form-grid {gap:12px;}.os-form label,.form-grid label {font-size:12px;}input,select,textarea {font-size:16px;}.desktop-only {display:none;}\n}\n@media(max-width:360px) { :root {--page-gutter:14px;--card-padding:14px;}h1 {font-size:28px;}.os-home-daygrid h2 {font-size:22px;}.os-home-submoney {gap:10px;}.os-home-metric > b {font-size:16px;}.os-home-private {padding-right:0;}.budget-equation {font-size:12px;gap:5px;}.breakdown {grid-template-columns:1fr;}.category-ring {justify-self:center;}.os-sunline-meta {flex-direction:column;}.os-sunline-meta strong {text-align:left;}.os-form,.form-grid {grid-template-columns:1fr;}.os-form label,.form-grid label {grid-column:1/-1;} }\n.header-tools .page-fab {position:static;z-index:auto;}.header-tools .page-fab .fab-button {width:44px;height:44px;min-height:44px;border:1px solid var(--line);box-shadow:none;color:var(--os-accent);background:var(--os-panel-2);}.header-tools .theme-toggle {width:44px;height:44px;min-height:44px;}.header-tools .os-more-menu summary {width:44px;height:44px;}\n@media(prefers-reduced-motion:reduce) {*,*::before,*::after {animation:none!important;transition:none!important;scroll-behavior:auto!important;}}\n\n.os-category-navigation {display:grid;grid-template-columns:minmax(0,1fr) 40px;gap:8px;margin-bottom:16px;align-items:stretch;}.os-category-navigation .os-category-tabs {margin:0;}.os-category-add {width:40px;padding:0;border-radius:14px;background:var(--os-panel);font-size:22px;}.finance-tabs button {flex:1 1 0;min-width:0;padding:9px 6px;font-size:12px;}\n@media(max-width:760px) {.os-routine {display:block;}.os-routine-head {display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:7px;}.os-routine-head > span {display:flex;gap:6px;align-items:baseline;}.os-routine-head b {display:inline;}.os-routine-head .os-routine-manage {min-height:28px;padding:0;}.os-routine-items {display:grid;grid-template-columns:repeat(3,minmax(0,1fr));}.os-routine-check {justify-content:center;min-width:0;padding:8px 5px;overflow-wrap:anywhere;}.os-home-task {padding:12px 0;}}\n\n@media(min-width:761px) {.os-home-day-dashboard {grid-column:1;grid-row:1;}.os-home-finance {grid-column:2;grid-row:1;}.os-home-agenda {grid-column:1/-1;grid-row:2;}.os-home-prayer {grid-row:3;}}\n@media(max-width:760px) {.os-home > .os-card {padding:16px;}.os-home .os-topline {margin-bottom:10px;}.os-home-task {min-height:48px;padding:10px 0;}.os-home .os-routine {margin-top:14px;padding-top:12px;}.os-home .os-routine-head .os-routine-manage {min-height:24px;}}\n\n.os-day .os-shift.no-shift {background:transparent;}\n.os-day-mark.event-count {min-width:18px;height:12px;line-height:12px;border-radius:4px;background:var(--os-panel);color:var(--ink);font-size:10px;font-weight:600;}\nhtml[data-theme=\"light\"] .os-day .os-shift {color:#101215;}html[data-theme=\"light\"] .os-day[data-kind=\"night\"] .os-shift {color:#fff;}\n.budget-calculation {min-width:0;border-top:1px solid var(--line);margin-top:16px;padding-top:14px;}\n.card > .budget-calculation {border-top:0;margin-top:0;}\n.budget-calculation > summary {display:flex;align-items:center;justify-content:space-between;gap:12px;cursor:pointer;font-weight:500;list-style:none;min-height:28px;}\n.budget-calculation > summary::after {content:\"+\";color:var(--muted);font-size:20px;}\n.budget-calculation[open] > summary::after {content:\"\u2212\";}\n.overview-essential > .budget-calculation {grid-column:1/-1;margin:0;border:1px solid var(--line);border-radius:var(--card-radius);padding:var(--card-padding);background:var(--os-panel);}\n.os-home-money .os-money-primary {width:100%;}.os-home-money .privacy-toggle {margin-left:auto;}\n.category-order > div {display:flex;gap:6px;flex-wrap:wrap;align-items:center;}.category-order > div > span {flex:1;min-width:80px;overflow-wrap:anywhere;}\n\n.overview-analysis-grid {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space);margin-top:var(--space);}\n.overview-analysis-grid > .integrated-chart {grid-column:1/-1;}\n.overview-analysis-grid .wealth-chart-card {order:-1;}\n.overview-analysis-grid > .annual-card {grid-column:1/-1;}\n.overview-analysis-grid > * {min-width:0;}\n.os-day .os-shift:not(.no-shift) {background:var(--shift-color);box-shadow:none;}\nhtml:not([data-theme=\"light\"]) [data-kind=\"morning\"] {--shift-color:#6191bd;}\nhtml:not([data-theme=\"light\"]) [data-kind=\"afternoon\"] {--shift-color:#659b72;}\nhtml:not([data-theme=\"light\"]) [data-kind=\"night\"] {--shift-color:#50545b;}\nhtml:not([data-theme=\"light\"]) [data-kind=\"rest\"] {--shift-color:#ce916d;}\nhtml:not([data-theme=\"light\"]) [data-kind=\"holiday\"] {--shift-color:#d7bf52;}\n\n.os-day[data-kind=\"night\"] .os-shift,.os-day .os-shift[data-kind=\"night\"] {color:#fff;}\n@media(max-width:760px) {.overview-analysis-grid {grid-template-columns:minmax(0,1fr);}.overview-analysis-grid > .annual-card,.overview-analysis-grid > .integrated-chart {grid-column:auto;}}\n</style>\n  <style id=\"native-web-parity\">\n/* Web parity with native 0.9.0. Shift palette and data contracts are unchanged. */\n:root {--os-bg:#0b0b0b;--os-panel:#131313;--os-panel-2:#272729;--ink:#f4f4f5;--muted:#adadad;--os-accent:#40a6ff;--os-focus:#40a6ff;--green:#8cbaa1;--red:#d4928f;--card-radius:24px;font-size:17px;}\nhtml[data-theme=\"light\"] {--os-accent:#005cc2;--os-focus:#005cc2;--green:#387354;--red:#a14947;}\nbutton,input,select,summary {min-height:44px;}small,.hint {font-size:13px;}h2 {font-size:17px;}button {transition:opacity .18s,background-color .16s,transform .18s;}button:active:not(:disabled) {transform:scale(.985);opacity:.75;}\n.finance-tabs {display:none!important;}.finance-open {max-width:720px;margin-inline:auto;}.finance-heading {display:flex;align-items:center;justify-content:space-between;gap:16px;}.finance-heading>button {border:0;}.finance-hero {padding:32px 0 24px;text-align:center;}.finance-hero h2 {color:var(--muted);font-weight:500;}.finance-value {display:block;font-size:clamp(32px,7vw,56px);line-height:1.2;letter-spacing:-1.5px;margin:12px 0;overflow-wrap:anywhere;}.finance-hero p {font-size:15px;}.finance-account {display:flex;align-items:center;flex-wrap:wrap;gap:12px;padding:16px 0 24px;}.finance-account>div {flex:1;min-width:0;}.finance-account h2 {color:var(--muted);font-size:15px;font-weight:500;}.finance-account strong {font-size:28px;overflow-wrap:anywhere;}.finance-account>small {flex-basis:100%;}.finance-actions {display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px;padding:8px 0 32px;}.finance-actions button {display:flex;flex-direction:column;border:0;padding:0;min-width:0;background:transparent;}.finance-actions span {display:grid;place-items:center;width:56px;height:56px;border-radius:50%;background:var(--os-panel-2);font-size:28px;border:1px solid var(--line);}.finance-recent {padding-top:16px;}.finance-movement {display:flex;width:100%;justify-content:space-between;gap:16px;text-align:left;border:0;border-radius:0;border-bottom:1px solid var(--line);padding:16px 0;background:transparent;}.finance-movement>span {min-width:0;}.finance-movement strong {display:block;overflow-wrap:anywhere;}.finance-movement small {display:block;}.finance-movement>b {flex-shrink:0;font-size:15px;}\n:is(#budget,#analysis,#extras,#movements) .card {background:transparent;border:0;border-radius:0;padding:20px 0;border-bottom:1px solid var(--line);}.overview-analysis-grid,.chart-pair {gap:24px;}.os-calendar-week {background:transparent;border:0;border-top:1px solid var(--line);border-radius:0;padding:8px 0;gap:0;}.os-days {gap:0;}.os-day {height:64px;min-height:64px;background:transparent;border-radius:0;}.os-calendar-week>.os-day:nth-child(n+6),.os-calendar-week>.os-day:nth-child(n+6).selected,.os-day.selected {background:transparent;box-shadow:none;}.os-day b {width:26px;height:26px;border-radius:50%;font-size:15px;}.os-day.today b {background:transparent;color:var(--ink);outline:1px solid var(--muted);}.os-day.selected b {background:var(--os-accent);color:var(--os-bg);outline:0;}.os-day .os-shift {border-radius:6px;height:20px;}.os-day-mark {color:var(--shift-color,var(--muted));}.os-calendar-week>.os-day:nth-child(n+6):not(.selected) b {color:var(--muted);}#calendar>.os-card {background:transparent;border:0;padding:0;}.os-calendar-details {padding-top:24px;}.os-month-header h2 {font-size:26px;}.os-home-week .os-day {background:transparent;}\n@supports ((backdrop-filter:blur(20px)) or (-webkit-backdrop-filter:blur(20px))) {.theme-toggle,.fab-button {background:color-mix(in srgb,var(--os-panel-2) 72%,transparent);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);}}\n@media(max-width:760px) {.nav {background:color-mix(in srgb,var(--os-panel) 90%,transparent);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);}main {padding-inline:20px;}.overview-analysis-grid,.chart-pair {grid-template-columns:minmax(0,1fr);}.finance-hero {padding-top:24px;}.os-day {min-height:58px;height:58px;}}\n.header-tools .page-fab {position:static;z-index:auto;}.header-tools .page-fab .fab-button {width:44px;height:44px;min-height:44px;border:1px solid var(--line);box-shadow:none;color:var(--os-accent);background:var(--os-panel-2);}.header-tools .theme-toggle {width:44px;height:44px;min-height:44px;}.header-tools .os-more-menu summary {width:44px;height:44px;}\n.os-task.done {background:transparent;opacity:1;}.os-task.done .os-task-title {color:var(--muted);text-decoration:none;}.os-task.done .os-check {background:var(--os-accent);border-color:var(--os-accent);color:var(--os-bg);}\n.os-task-section .os-task {grid-template-columns:26px minmax(0,1fr) 44px;}.os-task-section .os-task:has(.os-drag-handle) {grid-template-columns:28px 26px minmax(0,1fr) 44px;}.os-wait,.os-task-delete {width:44px;min-height:44px;padding:0;}\n@media(prefers-reduced-motion:reduce) {*,*::before,*::after {animation:none!important;transition:none!important;scroll-behavior:auto!important;}}\n</style></head>\n  <body class=\"dashboard-mode\">\n    <div class=\"shell\">\n      <aside class=\"sidebar\">\n        <div class=\"brand\">\n          <span class=\"mark\"><svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 116\" aria-hidden=\"true\"><defs><linearGradient id=\"growthMint\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\"><stop stop-color=\"#d3d8ff\"/><stop offset=\"1\" stop-color=\"#8d98dc\"/></linearGradient><linearGradient id=\"growthTeal\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\"><stop stop-color=\"#a5aeed\"/><stop offset=\"1\" stop-color=\"#6977bf\"/></linearGradient></defs><path d=\"M8 6 C26 6 40 20 40 38 L40 110 C20 110 8 99 8 79 Z\" fill=\"url(#growthMint)\"/><path d=\"M44 110 L44 82 C44 58 65 40 94 40 L94 66 C94 92 74 110 44 110 Z\" fill=\"url(#growthTeal)\"/></svg></span>\n          <span>Life OS</span>\n        </div>\n        <nav class=\"nav\" aria-label=\"Navigazione principale\">\n          <button data-view=\"today\" class=\"active\">\n            <svg\n              class=\"nav-symbol\"\n              viewBox=\"0 0 24 24\"\n              fill=\"none\"\n              stroke=\"currentColor\"\n              stroke-width=\"1.8\"\n              stroke-linecap=\"round\"\n              stroke-linejoin=\"round\"\n              aria-hidden=\"true\"\n            >\n              <path d=\"m3 10 9-7 9 7v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z\" />\n              <path d=\"M9 21v-7h6v7\" /></svg\n            >Dashboard\n          </button>\n          <button data-view=\"tasks\">\n            <svg\n              class=\"nav-symbol\"\n              viewBox=\"0 0 24 24\"\n              fill=\"none\"\n              stroke=\"currentColor\"\n              stroke-width=\"1.8\"\n              stroke-linecap=\"round\"\n              stroke-linejoin=\"round\"\n              aria-hidden=\"true\"\n            >\n              <rect x=\"4\" y=\"4\" width=\"16\" height=\"16\" rx=\"3\" />\n              <path d=\"m8 12 3 3 5-6\" /></svg\n            >Attivit\u00e0\n          </button>\n          <button data-view=\"calendar\">\n            <svg\n              class=\"nav-symbol\"\n              viewBox=\"0 0 24 24\"\n              fill=\"none\"\n              stroke=\"currentColor\"\n              stroke-width=\"1.8\"\n              stroke-linecap=\"round\"\n              stroke-linejoin=\"round\"\n              aria-hidden=\"true\"\n            >\n              <rect x=\"3\" y=\"5\" width=\"18\" height=\"16\" rx=\"2\" />\n              <path d=\"M7 3v4M17 3v4M3 10h18M8 14h2M14 14h2M8 18h2\" /></svg\n            >Calendario\n          </button>\n          <button data-view=\"overview\">\n            <svg\n              class=\"nav-symbol\"\n              viewBox=\"0 0 24 24\"\n              fill=\"none\"\n              stroke=\"currentColor\"\n              stroke-width=\"1.8\"\n              stroke-linecap=\"round\"\n              stroke-linejoin=\"round\"\n              aria-hidden=\"true\"\n            >\n              <rect x=\"3\" y=\"5\" width=\"18\" height=\"14\" rx=\"3\" />\n              <path d=\"M3 10h18M7 15h4\" /></svg\n            >Finanza\n          </button>\n        </nav>\n        <div class=\"sidebar-foot\">\n          <span id=\"sync-side\">Caricamento...</span\n          ><span id=\"version-side\" hidden></span>\n        </div>\n      </aside>\n      <main>\n        <header class=\"top\">\n          <div class=\"page-heading\"><h1 id=\"page-title\">Life OS</h1><div class=\"header-tools\"><div id=\"page-actions\" class=\"page-actions\" aria-label=\"Azioni pagina\"></div><div id=\"page-fab\" class=\"page-fab\"></div><button class=\"theme-toggle\" type=\"button\" aria-label=\"Cambia tema\" title=\"Cambia tema\"></button></div></div>\n          <div class=\"header-meta\"><div class=\"home-context\"><span id=\"home-weather\">Meteo \u2014</span></div><div class=\"top-right hidden\"><div class=\"period\"><button id=\"prev-month\" aria-label=\"Mese precedente\">\u2039</button><strong id=\"period-label\">...</strong><button id=\"next-month\" aria-label=\"Mese successivo\">\u203a</button></div><div class=\"sync\" id=\"sync-top\"></div></div></div>\n        </header>\n        <nav\n          id=\"finance-tabs\"\n          class=\"finance-tabs hidden\"\n          aria-label=\"Sezioni finanza\"\n        >\n          <button data-view=\"overview\">Finanza</button><button data-view=\"analysis\">Analisi</button>\n        </nav>\n        <div id=\"error\" class=\"errorbox hidden\" role=\"alert\"></div>\n        <div\n          id=\"loading\"\n          class=\"loading-overlay\"\n          role=\"status\"\n          aria-live=\"polite\"\n        >\n          <div class=\"loading-panel\">\n            <div class=\"loading-spinner\" aria-hidden=\"true\"></div>\n            <strong>Caricamento\u2026</strong>\n          </div>\n        </div>\n        <section id=\"today\" class=\"view active\"></section>\n        <section id=\"tasks\" class=\"view\"></section>\n        <section id=\"calendar\" class=\"view\"></section>\n        <section id=\"overview\" class=\"view\"></section>\n        <section id=\"movements\" class=\"view\"></section>\n\n        <section id=\"budget\" class=\"view\"></section><section id=\"analysis\" class=\"view\"></section><section id=\"extras\" class=\"view\"></section>\n      </main>\n    </div>\n    <div id=\"dialog\" class=\"modal-wrap hidden\"></div>\n    <div id=\"life-dialog\" class=\"modal-wrap hidden\"></div>\n    <script>\n      /** Trasporto JSON same-origin con timeout; nessun retry automatico delle scritture. */\n      async function workerRequest(method, args) {\n        // A stalled read must not trap navigation. Never automatically retry writes:\n        // a dropped response does not prove the server rolled the operation back.\n        const controller = new AbortController(),\n          timer = setTimeout(() => controller.abort(), 20000);\n        try {\n          const r = await fetch(\"/api/\" + method, {\n            method: \"POST\",\n            headers: { \"content-type\": \"application/json\" },\n            body: JSON.stringify(args),\n            signal: controller.signal,\n          });\n          if (!r.ok)\n            throw Error(\n              r.status === 401\n                ? \"Sessione scaduta. Riapri l\u2019app e accedi.\"\n                : (await r.text()).slice(0, 400),\n            );\n          if (\n            !(r.headers.get(\"content-type\") || \"\").includes(\"application/json\")\n          )\n            throw Error(\"Sessione non disponibile. Riapri l\u2019app e accedi.\");\n          return await r.json();\n        } catch (error) {\n          if (error.name === \"AbortError\")\n            throw Error(\n              method.startsWith(\"get\")\n                ? \"Connessione lenta. Riprova a caricare la schermata.\"\n                : \"Risposta non ricevuta. Aggiorna e verifica il salvataggio prima di riprovare.\",\n            );\n          throw error;\n        } finally {\n          clearTimeout(timer);\n        }\n      }\n      window.google = {\n        script: {\n          run: new Proxy(\n            {},\n            {\n              get(_target, name) {\n                if (\n                  name === \"withSuccessHandler\" ||\n                  name === \"withFailureHandler\"\n                )\n                  return (callback) => {\n                    const runner = {\n                      success: name === \"withSuccessHandler\" ? callback : null,\n                      failure: name === \"withFailureHandler\" ? callback : null,\n                    };\n                    const proxy = new Proxy(runner, {\n                      get(obj, key) {\n                        if (key === \"withSuccessHandler\")\n                          return (cb) => {\n                            obj.success = cb;\n                            return proxy;\n                          };\n                        if (key === \"withFailureHandler\")\n                          return (cb) => {\n                            obj.failure = cb;\n                            return proxy;\n                          };\n                        return (...args) =>\n                          workerRequest(String(key), args)\n                            .then((v) => obj.success?.(v))\n                            .catch((e) => obj.failure?.(e));\n                      },\n                    });\n                    return proxy;\n                  };\n              },\n            },\n          ),\n        },\n      };\n    </script>\n\n    <script>\n      /* Offline solar calculation for Empoli. Angles and minute adjustments are Nas's settings.\n   Solar position follows the public PrayTimes formulas; no network or location access. */\n      const osPrayerConfig = Object.freeze({\n        latitude: 43.7179,\n        longitude: 10.9478,\n        timeZone: \"Europe/Rome\",\n        fajrAngle: 14.5,\n        ishaAngle: 14.8,\n        asrFactor: 1,\n        adjustments: {\n          fajr: 0,\n          sunrise: -2,\n          dhuhr: 1,\n          asr: 1,\n          maghrib: 2,\n          isha: 0,\n        },\n      });\n      const osDeg = Math.PI / 180;\n\n      /** Calcolo astronomico locale per Empoli; restituisce orari, senza geolocalizzazione o richieste. */\n      function osPrayerTimes(day, config = osPrayerConfig) {\n        if (!/^\\d{4}-\\d{2}-\\d{2}$/.test(day)) throw Error(\"Data non valida\");\n        const [y, m, d] = day.split(\"-\").map(Number),\n          lat = config.latitude,\n          lon = config.longitude;\n        const jd = Date.UTC(y, m - 1, d) / 86400000 + 2440587.5 - lon / 360;\n        const norm = (x, n) => ((x % n) + n) % n;\n        const sin = (x) => Math.sin(x * osDeg),\n          cos = (x) => Math.cos(x * osDeg),\n          tan = (x) => Math.tan(x * osDeg);\n\n        /** Declinazione solare ed equazione del tempo per il giorno giuliano corrente. */\n        function sun(t) {\n          const D = jd + t / 24 - 2451545,\n            g = norm(357.529 + 0.98560028 * D, 360),\n            q = norm(280.459 + 0.98564736 * D, 360);\n          const L = norm(q + 1.915 * sin(g) + 0.02 * sin(2 * g), 360),\n            e = 23.439 - 0.00000036 * D;\n          const RA = norm(Math.atan2(cos(e) * sin(L), cos(L)) / osDeg / 15, 24);\n          return { decl: Math.asin(sin(e) * sin(L)) / osDeg, eqt: q / 15 - RA };\n        }\n\n        /** Mezzogiorno solare normalizzato sulle 24 ore. */\n        function noon(t) {\n          return norm(12 - sun(t).eqt, 24);\n        }\n\n        /** Converte un angolo solare in ora; restituisce NaN se non esiste un attraversamento. */\n        function angleTime(angle, t, before) {\n          const decl = sun(t).decl,\n            den = cos(decl) * cos(lat);\n          const ratio = (-sin(angle) - sin(decl) * sin(lat)) / den;\n          if (!Number.isFinite(ratio) || Math.abs(ratio) > 1) return NaN;\n          const delta =\n            Math.acos(Math.max(-1, Math.min(1, ratio))) / osDeg / 15;\n          return noon(t) + (before ? -delta : delta);\n        }\n\n        /** Calcola il tempo pomeridiano dal fattore d\u2019ombra configurato. */\n        function asr(t) {\n          const decl = sun(t).decl,\n            alt =\n              -Math.atan(1 / (config.asrFactor + tan(Math.abs(lat - decl)))) /\n              osDeg;\n          return angleTime(alt, t, false);\n        }\n        let times = {\n          fajr: 5,\n          sunrise: 6,\n          dhuhr: 12,\n          asr: 13,\n          maghrib: 18,\n          isha: 18,\n        };\n        for (let i = 0; i < 2; i++) {\n          const t = Object.fromEntries(\n            Object.entries(times).map(([k, v]) => [k, v / 24]),\n          );\n          times = {\n            fajr: angleTime(config.fajrAngle, t.fajr, true),\n            sunrise: angleTime(0.833, t.sunrise, true),\n            dhuhr: noon(t.dhuhr),\n            asr: asr(t.asr),\n            maghrib: angleTime(0.833, t.maghrib, false),\n            isha: angleTime(config.ishaAngle, t.isha, false),\n          };\n        }\n        const noonUtc = new Date(Date.UTC(y, m - 1, d, 12)),\n          parts = new Intl.DateTimeFormat(\"en-GB\", {\n            timeZone: config.timeZone,\n            hour: \"2-digit\",\n            minute: \"2-digit\",\n            hourCycle: \"h23\",\n          }).formatToParts(noonUtc);\n        const hour = Number(parts.find((p) => p.type === \"hour\")?.value),\n          minute = Number(parts.find((p) => p.type === \"minute\")?.value);\n        const utcOffset = hour + minute / 60 - 12;\n        return Object.fromEntries(\n          Object.entries(times).map(([key, value]) => {\n            if (!Number.isFinite(value))\n              return [key, { minutes: NaN, label: \"\u2014\" }];\n            const minutes = norm(\n              Math.round(\n                (value + utcOffset - lon / 15) * 60 +\n                  (config.adjustments[key] || 0),\n              ),\n              1440,\n            );\n            return [\n              key,\n              {\n                minutes,\n                label:\n                  String(Math.floor(minutes / 60)).padStart(2, \"0\") +\n                  \":\" +\n                  String(minutes % 60).padStart(2, \"0\"),\n              },\n            ];\n          }),\n        );\n      }\n\n      /** Markup degli orari locali; conserva lo stato del dettaglio aperto. */\n      function osPrayerCard(day, now = new Date(), expanded = false) {\n        const times = osPrayerTimes(day),\n          current = Object.fromEntries(\n            new Intl.DateTimeFormat(\"en-GB\", {\n              timeZone: osPrayerConfig.timeZone,\n              hour: \"2-digit\",\n              minute: \"2-digit\",\n              hourCycle: \"h23\",\n            })\n              .formatToParts(now)\n              .filter((p) => p.type === \"hour\" || p.type === \"minute\")\n              .map((p) => [p.type, Number(p.value)]),\n          );\n        const currentDay = now.toLocaleDateString(\"sv-SE\", {\n            timeZone: osPrayerConfig.timeZone,\n          }),\n          minute = current.hour * 60 + current.minute;\n        const prayers = [\n          [\"fajr\", \"Prima dell\u2019alba\"],\n          [\"sunrise\", \"Alba\"],\n          [\"dhuhr\", \"Mezzogiorno\"],\n          [\"asr\", \"Pomeriggio\"],\n          [\"maghrib\", \"Tramonto\"],\n          [\"isha\", \"Notte\"],\n        ];\n        const next =\n          currentDay === day\n            ? prayers.find(([key]) => times[key].minutes > minute)\n            : null;\n        const lead = next\n          ? \"Prossimo \u00b7 \" + next[1] + \" \" + times[next[0]].label\n          : \"Ciclo di oggi\";\n        return `<div class=\"os-sunline\" aria-label=\"Fasi del giorno a Empoli\"><div class=\"os-sunline-meta\"><span>Empoli \u00b7 alba ${times.sunrise.label}</span><strong>${lead}</strong></div><details class=\"os-home-times\" data-home-times ${expanded ? \"open\" : \"\"}><summary>Tutti gli orari</summary><div class=\"os-prayer-list\">${prayers.map(([key, label]) => `<div class=\"os-prayer ${next?.[0] === key ? \"next\" : \"\"}\"><span>${label}</span><time>${times[key].label}</time></div>`).join(\"\")}</div></details></div>`;\n      }\n\n      const life = {\n        data: null,\n        finance: null,\n        financeError: false,\n        month: new Date()\n          .toLocaleDateString(\"sv-SE\", { timeZone: \"Europe/Rome\" })\n          .slice(0, 7),\n        selected: null,\n        tool: null,\n        busy: false,\n        undo: null,\n        paintQueue: Promise.resolve(),\n        routineQueue: Promise.resolve(),\n        routinePending: 0,\n        routineRevision: 0,\n        editingEvent: null,\n        creatingEvent: false,\n        editingSplitFrom: null,\n        category: \"action\",\n        weather: null,\n        weatherAt: 0,\n        timesOpen: false,\n        reorder: false,\n        paletteOpen: false,\n        readRevision: 0,\n        paintRevision: 0,\n      };\n      const osSafe = (v) =>\n        String(v ?? \"\").replace(\n          /[&<>\"']/g,\n          (c) =>\n            ({\n              \"&\": \"&amp;\",\n              \"<\": \"&lt;\",\n              \">\": \"&gt;\",\n              '\"': \"&quot;\",\n              \"'\": \"&#39;\",\n            })[c],\n        );\n      const osShift = {\n        morning: \"06\u201314\",\n        afternoon: \"14\u201322\",\n        night: \"22\u201306\",\n        holiday: \"Ferie\",\n        rest: \"Riposo\",\n      };\n      const osShiftInitial = {\n        morning: \"M\",\n        afternoon: \"P\",\n        night: \"N\",\n        holiday: \"F\",\n        rest: \"R\",\n      };\n      const osDate = (v) =>\n        new Date(v + \"T12:00:00Z\").toLocaleDateString(\"it-IT\", {\n          day: \"numeric\",\n          month: \"long\",\n          year: \"numeric\",\n          timeZone: \"UTC\",\n        });\n      const osNextDay = (v) =>\n        new Date(Date.parse(v + \"T12:00:00Z\") + 86400000)\n          .toISOString()\n          .slice(0, 10);\n\n      /** Adatta gli argomenti variadici Life OS al protocollo RPC array. */\n      async function osRequest(method, ...args) {\n        return workerRequest(method, args);\n      }\n\n      /** Mostra un errore leggibile senza nascondere la navigazione. */\n      function osError(err) {\n        const box = document.getElementById(\"error\");\n        box.textContent = \"Operazione non riuscita: \" + (err.message || err);\n        box.classList.remove(\"hidden\");\n        window.scrollTo({ top: 0, behavior: \"smooth\" });\n      }\n      // Keep the latest month/request; an older network response must never replace it.\n\n      /** Carica il mese richiesto; gli errori restano recuperabili dalla UI. */\n      async function loadLifeOS() {\n        try {\n          await osRefresh();\n        } catch (e) {\n          osError(e);\n        }\n      }\n\n      /** Azione principale flottante; opzioni secondarie vicino al titolo. */\n      function osPageActions() {\n        const view = state.view, active = life.data?.categories.find(c => c.key === life.category);\n        let action = 'data-new-transaction=\"Spesa\"', label = 'Aggiungi spesa', secondary = '';\n        if (view === 'tasks') {\n          action = 'data-life-task=\"new\"'; label = 'Aggiungi attivit\u00e0';\n          secondary = `<details class=\"os-more-menu\"><summary aria-label=\"Opzioni categoria\" title=\"Opzioni categoria\"><svg viewBox=\"0 0 24 24\" fill=\"currentColor\" aria-hidden=\"true\"><circle cx=\"5\" cy=\"12\" r=\"1.7\"/><circle cx=\"12\" cy=\"12\" r=\"1.7\"/><circle cx=\"19\" cy=\"12\" r=\"1.7\"/></svg></summary><div><button data-life-rename-category=\"${osSafe(active?.key || \"action\")}\">Rinomina categoria</button><button data-life-reorder aria-pressed=\"${life.reorder}\">${life.reorder ? \"Fine riordino\" : \"Riordina attivit\u00e0\"}</button><button data-life-category>Gestisci categorie</button></div></details>`;\n        } else if (view === 'calendar') {\n          action = 'data-life-event=\"new\"'; label = 'Aggiungi evento';\n        } else if (['overview','movements','budget','extras'].includes(view)) {\n          if (view === 'extras') { action = 'data-new-extra=\"1\"'; label = 'Aggiungi straordinaria'; }\n          secondary = '<details class=\"os-more-menu\"><summary aria-label=\"Altre azioni\" title=\"Altre azioni\"><svg viewBox=\"0 0 24 24\" fill=\"currentColor\" aria-hidden=\"true\"><circle cx=\"5\" cy=\"12\" r=\"1.7\"/><circle cx=\"12\" cy=\"12\" r=\"1.7\"/><circle cx=\"19\" cy=\"12\" r=\"1.7\"/></svg></summary><div><button data-new-transaction=\"Entrata\">+ Entrata</button><button data-new-extra=\"1\">+ Straordinaria</button><button data-new-transaction=\"Trasferimento\">Trasferimento finale da Revolut</button></div></details>';\n        }\n        document.getElementById('page-actions').innerHTML = secondary;\n        document.getElementById('page-fab').innerHTML = `<button type=\"button\" class=\"os-button primary fab-button\" ${action} aria-label=\"${label}\" title=\"${label}\"><svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" aria-hidden=\"true\"><path d=\"M12 5v14M5 12h14\"/></svg></button>`;\n      }\n\n      /** Ricrea solo la vista Life OS attiva; non eseguire su ogni clic generico. */\n      function renderLifeOS() {\n        osPageActions();\n        if (!life.data) return;\n        osUpdateHeader();\n        const view = typeof state !== \"undefined\" ? state.view : \"today\";\n        if (view === \"today\")\n          document.getElementById(\"today\").innerHTML = osToday();\n        if (view === \"tasks\")\n          document.getElementById(\"tasks\").innerHTML = osTasks();\n        if (view === \"calendar\") {\n          document.getElementById(\"calendar\").innerHTML = osCalendar();\n          document.body.dataset.calendarRows = Math.ceil(\n            document.querySelectorAll(\".os-day\").length / 7,\n          );\n          document.body.style.setProperty(\n            \"--calendar-rows\",\n            document.body.dataset.calendarRows,\n          );\n        }\n      }\n\n      /** Aggiorna la sintesi finanziaria della home per il mese corrente a Roma. */\n      async function osLoadHomeFinance() {\n        try {\n          const day = new Date().toLocaleDateString(\"sv-SE\", {\n            timeZone: \"Europe/Rome\",\n          });\n          const fresh = await osRequest(\n            \"getFinanceOverview\",\n            Number(day.slice(0, 4)),\n            Number(day.slice(5, 7)),\n          );\n          life.finance = fresh;\n          life.financeError = false;\n          if (life.data) document.getElementById(\"today\").innerHTML = osToday();\n        } catch (e) {\n          life.financeError = true;\n          if (life.data) document.getElementById(\"today\").innerHTML = osToday();\n        }\n      }\n\n      /** Aggiorna il meteo nell\u2019intestazione, senza ricreare la pagina. */\n      function osUpdateHeader() {\n        if (typeof document === \"undefined\") return;\n        document.getElementById(\"home-weather\").textContent = osWeatherText();\n      }\n\n      /** Etichetta meteo compatta da dati gi\u00e0 caricati. */\n      function osWeatherText() {\n        const w = life.weather;\n        if (!w) return \"Meteo \u2014\";\n        const condition = [0].includes(w.code)\n          ? \"sereno\"\n          : [1, 2].includes(w.code)\n            ? \"poco nuvoloso\"\n            : [3].includes(w.code)\n              ? \"nuvoloso\"\n              : [45, 48].includes(w.code)\n                ? \"nebbia\"\n                : [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99].includes(\n                      w.code,\n                    )\n                  ? \"pioggia\"\n                  : \"meteo\";\n        const rain = w.rain ? ` \u00b7 pioggia ${w.rain}` : ` \u00b7 ${condition}`;\n        return Math.round(w.temp) + \" \u00b0C\" + rain;\n      }\n\n      /** Meteo facoltativo con timeout breve e intervallo minimo di 30 minuti. */\n      async function osLoadWeather() {\n        if (life.weatherAt && Date.now() - life.weatherAt < 30 * 60000) return;\n        life.weatherAt = Date.now();\n        const controller = new AbortController(),\n          timer = setTimeout(() => controller.abort(), 6000);\n        try {\n          const url =\n            \"https://api.open-meteo.com/v1/forecast?latitude=43.7179&longitude=10.9478&current=temperature_2m,weather_code&hourly=rain,precipitation_probability&forecast_hours=18&timezone=Europe%2FRome\";\n          const response = await fetch(url, { signal: controller.signal });\n          if (!response.ok) throw Error(\"Meteo non disponibile\");\n          const data = await response.json(),\n            temp = Number(data.current?.temperature_2m);\n          if (!Number.isFinite(temp)) throw Error(\"Temperatura assente\");\n          const now = new Intl.DateTimeFormat(\"sv-SE\", {\n            timeZone: \"Europe/Rome\",\n            year: \"numeric\",\n            month: \"2-digit\",\n            day: \"2-digit\",\n            hour: \"2-digit\",\n            minute: \"2-digit\",\n            hourCycle: \"h23\",\n          })\n            .format(new Date())\n            .replace(\" \", \"T\");\n          const times = data.hourly?.time || [],\n            amounts = data.hourly?.rain || [],\n            prob = data.hourly?.precipitation_probability || [];\n          const i = times.findIndex(\n            (t, j) =>\n              t >= now && Number(amounts[j]) >= 0.1 && Number(prob[j]) >= 40,\n          );\n          const rain =\n            i < 0\n              ? \"\"\n              : times[i].slice(0, 10) === now.slice(0, 10)\n                ? times[i].slice(11, 16)\n                : \"domani \" + times[i].slice(11, 16);\n          life.weather = {\n            temp,\n            code: Number(data.current.weather_code),\n            rain,\n          };\n        } catch {\n          life.weather = null;\n        } finally {\n          clearTimeout(timer);\n          osUpdateHeader();\n          if (life.data) document.getElementById(\"today\").innerHTML = osToday();\n        }\n      }\n\n      /** Markup dashboard: routine, oggi/domani, tre attivit\u00e0, eventi e saldi. */\n      function osToday() {\n        const d = life.data,\n          day = d.today,\n          shift = d.shifts.find((s) => s.day === day),\n          tomorrow = d.shifts.find((s) => s.day === osNextDay(day));\n        const tasks = d.tasks.filter(\n            (t) => t.status === \"todo\" && t.list_kind === \"action\",\n          ),\n          waiting = d.tasks.filter(\n            (t) => t.status === \"waiting\" && t.list_kind === \"action\",\n          ),\n          upcoming = (d.upcomingEvents || []).slice(0, 3);\n        const habits = d.routines || [],\n          complete = habits.filter((h) => h.checked).length;\n        const finance = life.finance?.summary;\n        const shiftLabel = (v) =>\n          v\n            ? {\n                morning: 'Mattina',\n                afternoon:\n                  'Pomeriggio',\n                night: 'Notte',\n                holiday: \"Ferie\",\n                rest: \"Riposo\",\n              }[v.kind] || osShift[v.kind]\n            : \"Nessun turno\";\n        const featured =\n          upcoming\n            .map(\n              (ev) =>\n                `<div class=\"os-agenda-entry\"><button class=\"os-agenda-row\" data-life-event=\"${ev.id}\"><span class=\"os-agenda-date\"><b>${new Date(ev.day + \"T12:00:00Z\").toLocaleDateString(\"it-IT\", { day: \"2-digit\", timeZone: \"UTC\" })}</b><small>${new Date(ev.day + \"T12:00:00Z\").toLocaleDateString(\"it-IT\", { month: \"short\", timeZone: \"UTC\" })}</small></span><span class=\"os-agenda-title\"><span class=\"os-home-agenda-name\">${osSafe(ev.title)}${osDueBadge(ev.day, ev.occurrence_status)}</span><small>${ev.start_time || \"Tutto il giorno\"}${ev.location ? \" \u00b7 \" + osSafe(ev.location) : \"\"}</small></span><span class=\"os-agenda-arrow\" aria-hidden=\"true\">\u203a</span></button><button type=\"button\" class=\"os-agenda-done\" data-life-occurrence=\"${ev.id}:${ev.day}:done\" aria-label=\"Segna fatta ${osSafe(ev.title)}\">Fatto</button></div>`,\n            )\n            .concat(\n              tasks\n                .slice(0, Math.max(0, 3 - upcoming.length))\n                .map(\n                  (t) =>\n                    `<div class=\"os-home-task\"><button class=\"os-check\" data-life-complete=\"${t.id}\" aria-label=\"Completa ${osSafe(t.title)}\"></button><button class=\"os-home-task-title\" data-life-task=\"${t.id}\">${osSafe(t.title)}${osDueBadge(t.due_date || t.scheduled_date, t.status)}</button></div>`,\n                ),\n            )\n            .slice(0, 3)\n            .join(\"\") || '<p class=\"os-empty\">Nessun evento o attivit\u00e0.</p>';\n        const routine = habits\n          .map(\n            (h) =>\n              `<button type=\"button\" class=\"os-routine-check ${h.checked ? \"checked\" : \"\"}\" data-life-routine=\"${h.id}\" aria-pressed=\"${!!h.checked}\" aria-label=\"${h.checked ? \"Annulla\" : \"Completa\"} ${osSafe(h.title)}\"><span class=\"os-routine-tick\" aria-hidden=\"true\">${h.checked ? \"\u2713\" : \"\"}</span>${osSafe(h.title)}</button>`,\n          )\n          .join(\"\");\n        const exactMoney = (n) =>\n          new Intl.NumberFormat(\"it-IT\", {\n            style: \"currency\",\n            currency: \"EUR\",\n            useGrouping: \"always\",\n          }).format(n);\n        return `<div class=\"os-home\">\n    <section class=\"os-card os-day-dashboard\" aria-label=\"La giornata\"><div class=\"os-home-daygrid\"><div data-kind=\"${shift?.kind || \"\"}\"><span class=\"os-home-label\">Oggi</span><h2>${shiftLabel(shift)}</h2></div><div class=\"os-home-tomorrow\" data-kind=\"${tomorrow?.kind || \"\"}\"><span>Domani</span><strong>${shiftLabel(tomorrow)}</strong></div></div>\n      <div class=\"os-routine\"><div class=\"os-routine-head\"><span>Routine <b>${complete}/${habits.length}</b></span><button type=\"button\" class=\"os-routine-manage\" data-life-routine-manage>Gestisci</button></div><div class=\"os-routine-items\">${routine || '<button class=\"os-home-routine-add\" data-life-routine-manage>Aggiungi routine</button>'}</div></div>\n    </section>\n    <section class=\"os-card os-home-agenda\"><div class=\"os-topline\"><h2>In evidenza</h2><button class=\"os-button\" data-life-nav=\"tasks\">Tutte le attivit\u00e0</button></div>${featured}</section>\n    <section class=\"os-card os-home-finance\" aria-label=\"Denaro\">\n      ${finance ? `<div class=\"os-home-money\"><div class=\"os-money-primary\" style=\"--money-units:${exactMoney(finance.monthlyRemaining).length*0.62}\"><small>Budget del mese</small><strong>${state.assetsVisible ? exactMoney(finance.monthlyRemaining) : \"\u2022\u2022\u2022\u2022 \u20ac\"}</strong></div>${privacyButton()}</div><div class=\"os-home-submoney ${Math.abs(finance.budget)>=100000 || Math.abs(finance.monthlyCommitted)>=100000?\"large-amount\":\"\"}\"><div class=\"os-home-metric\"><span>Impegnato</span><b>${exactMoney(finance.monthlyCommitted)}</b></div><div class=\"os-home-metric os-home-private\"><span>Saldo</span><b>${state.assetsVisible ? exactMoney(finance.budget) : \"\u2022\u2022\u2022\u2022 \u20ac\"}</b></div></div>` : life.financeError ? '<p class=\"os-empty\">Saldo non disponibile.</p><button class=\"os-button\" data-life-nav=\"overview\">Riprova in Finanza</button>' : '<p class=\"os-empty\" role=\"status\">Caricamento\u2026</p>'}\n    </section>\n    <section class=\"os-card os-home-prayer\"><div class=\"os-solar-inline\">${osPrayerCard(day, new Date(), life.timesOpen)}</div></section>\n  </div>`;\n      }\n\n      /** Apre il foglio di gestione delle routine; non modifica le spunte. */\n      function osManageRoutines() {\n        const d = document.getElementById(\"life-dialog\");\n        d.innerHTML = `<div class=\"modal os-dialog os-routine-dialog\" role=\"dialog\" aria-modal=\"true\" aria-label=\"Routine\"><div class=\"os-topline\"><div><h2>Routine</h2></div><button class=\"os-icon-button\" data-life-close aria-label=\"Chiudi\">\u00d7</button></div><p>Le spunte si azzerano ogni giorno.</p><div class=\"os-routine-manager\">${(life.data.routines || []).map((h) => `<div><span>${osSafe(h.title)}</span><button data-life-routine-edit=\"${h.id}\" aria-label=\"Rinomina ${osSafe(h.title)}\">Rinomina</button><button data-life-routine-delete=\"${h.id}\" aria-label=\"Elimina ${osSafe(h.title)}\">Elimina</button></div>`).join(\"\")}</div><form id=\"os-routine-form\" class=\"os-form\"><input type=\"hidden\" name=\"record_id\" value=\"\"><label class=\"wide\">Nome *<input name=\"title\" maxlength=\"60\" required placeholder=\"Es. Acqua\" autocomplete=\"off\"></label><div class=\"os-form-actions\"><button class=\"os-button primary\" type=\"submit\">Aggiungi</button></div></form></div>`;\n        d.classList.remove(\"hidden\");\n      }\n\n      /** Scadenza esplicita Domani/Oggi/Scaduto; nessun badge per completate. */\n      function osDueBadge(day, status) {\n        if (!day || status === \"done\" || !life.data) return \"\";\n        const today = life.data.today;\n        let label = \"\",\n          kind = \"\";\n        if (day < today) {\n          label = \"Scaduto\";\n          kind = \"overdue\";\n        } else if (day === today) {\n          label = \"Oggi\";\n          kind = \"today\";\n        } else if (day === osNextDay(today)) {\n          label = \"Domani\";\n          kind = \"tomorrow\";\n        }\n        return label\n          ? `<span class=\"due-badge due-${kind}\">${label}</span>`\n          : \"\";\n      }\n\n      /** Riga attivit\u00e0; escaping obbligatorio per titolo e attributi utente. */\n      function osTaskRow(t) {\n        const waiting = (t.status === \"done\" ? t.section_status : t.status) === \"waiting\";\n        return `<div class=\"os-task ${t.status === \"done\" ? \"done\" : \"\"}\" data-life-drag-row=\"${t.id}\">${t.status === \"todo\" ? `<button type=\"button\" class=\"os-drag-handle\" data-life-drag-handle=\"${t.id}\" aria-label=\"Riordina ${osSafe(t.title)}. Trascina o usa Alt pi\u00f9 freccia su o gi\u00f9\" title=\"Trascina per riordinare\"><svg viewBox=\"0 0 20 24\" width=\"16\" height=\"22\" fill=\"currentColor\" aria-hidden=\"true\"><circle cx=\"6\" cy=\"5\" r=\"1.4\"/><circle cx=\"14\" cy=\"5\" r=\"1.4\"/><circle cx=\"6\" cy=\"12\" r=\"1.4\"/><circle cx=\"14\" cy=\"12\" r=\"1.4\"/><circle cx=\"6\" cy=\"19\" r=\"1.4\"/><circle cx=\"14\" cy=\"19\" r=\"1.4\"/></svg></button>` : \"\"}<button class=\"os-check\" data-life-status=\"${t.id}:${t.status === \"done\" ? (t.section_status === \"waiting\" ? \"waiting\" : \"todo\") : \"done\"}\" aria-label=\"${t.status === \"done\" ? \"Riapri\" : \"Completa\"} ${osSafe(t.title)}\">${t.status === \"done\" ? \"\u2713\" : \"\"}</button><button class=\"os-task-title\" data-life-task=\"${t.id}\">${osSafe(t.title)}${osDueBadge(t.due_date || t.scheduled_date, t.status)}</button>${t.status !== \"done\" ? `<button class=\"os-wait ${waiting ? \"waiting\" : \"\"}\" data-life-status=\"${t.id}:${waiting ? \"todo\" : \"waiting\"}\" title=\"${waiting ? \"Riporta in Da fare\" : \"Metti in attesa\"}\" aria-label=\"${waiting ? \"Riporta in Da fare\" : \"Metti in attesa\"} ${osSafe(t.title)}\" aria-pressed=\"${waiting}\"><svg viewBox=\"0 0 24 24\" width=\"19\" height=\"19\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.7\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M6 3h12M6 21h12M7 3v4c0 2 2 3 5 5-3 2-5 3-5 5v4M17 3v4c0 2-2 3-5 5 3 2 5 3 5 5v4\"/></svg></button>` : `<button class=\"os-task-delete\" data-life-delete-task=\"${t.id}\" aria-label=\"Elimina ${osSafe(t.title)}\" title=\"Elimina attivit\u00e0\"><svg viewBox=\"0 0 24 24\" width=\"18\" height=\"18\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M4 7h16M10 4h4M6 7l1 13h10l1-13M10 11v5M14 11v5\"/></svg></button>`}</div>`;\n      }\n\n      /** Lista della categoria selezionata; azioni secondarie nel menu Opzioni. */\n      function osTasks() {\n        const d = life.data;\n        if (!d.categories.some((c) => c.key === life.category))\n          life.category = d.categories[0]?.key || \"action\";\n        const active = d.categories.find((c) => c.key === life.category),\n          items = d.tasks.filter((t) => t.list_kind === life.category),\n          todo = items.filter((t) => t.status === \"todo\" || (t.status === \"done\" && t.section_status !== \"waiting\")).sort((a,b) => Number(a.status === \"done\") - Number(b.status === \"done\") || a.sort_order - b.sort_order || a.id - b.id),\n          waiting = items.filter((t) => t.status === \"waiting\" || (t.status === \"done\" && t.section_status === \"waiting\")).sort((a,b) => Number(a.status === \"done\") - Number(b.status === \"done\") || a.sort_order - b.sort_order || a.id - b.id);\n        return `<div class=\"os-category-navigation\"><nav class=\"os-category-tabs\" aria-label=\"Categorie attivit\u00e0\">${d.categories.map((c) => `<button data-life-select-category=\"${osSafe(c.key)}\" class=\"${life.category === c.key ? \"active\" : \"\"}\" aria-current=\"${life.category === c.key ? \"page\" : \"false\"}\">${osSafe(c.label)}</button>`).join(\"\")}</nav><button data-life-category class=\"os-category-add\" aria-label=\"Aggiungi e ordina categorie\">+</button></div><div class=\"os-card os-category-page ${life.reorder ? \"is-reordering\" : \"\"}\"><section class=\"os-task-section\"><h3>Attivo</h3>${todo.length ? todo.map(osTaskRow).join(\"\") : '<p class=\"os-task-empty\">Nessuna attivit\u00e0 attiva.</p>'}</section>${waiting.length ? `<section class=\"os-task-section\"><h3>In attesa</h3>${waiting.map(osTaskRow).join(\"\")}</section>` : \"\"}</div>`;\n      }\n\n      /** Editor evento o serie; una modifica da qui passa split_from al server. */\n      function osEventForm() {\n        const ev = life.editingEvent\n          ? life.data.events.find((e) => e.id === life.editingEvent) ||\n            life.data.upcomingEvents?.find((e) => e.id === life.editingEvent)\n          : null;\n        if (!life.creatingEvent && !ev) return \"\";\n        return `<div class=\"os-inline-event\" id=\"os-event-editor\"><div class=\"os-topline\"><h3>${life.editingSplitFrom ? \"Modifica da qui\" : ev ? \"Modifica serie\" : \"Nuovo evento\"}</h3><button class=\"os-icon-button\" data-life-close aria-label=\"Chiudi modulo evento\">\u00d7</button></div><form id=\"life-form\" data-kind=\"event\" class=\"os-form\"><input type=\"hidden\" name=\"record_id\" value=\"${ev?.id || \"\"}\">${life.editingSplitFrom ? `<input type=\"hidden\" name=\"split_from\" value=\"${life.editingSplitFrom}\">` : \"\"}<label class=\"wide\">Titolo *<input name=\"title\" maxlength=\"140\" required value=\"${osSafe(ev?.title || \"\")}\"></label><label class=\"wide\">Giorno *<input type=\"date\" name=\"day\" required value=\"${life.editingSplitFrom || ev?.series_day || ev?.day || life.selected || life.data.today}\"></label><label>Inizio<input type=\"time\" name=\"start_time\" value=\"${ev?.start_time || \"\"}\"></label><label>Fine<input type=\"time\" name=\"end_time\" value=\"${ev?.end_time || \"\"}\"></label><label>Ripeti<select name=\"frequency\">${[\n          [\"none\", \"Mai\"],\n          [\"weekly\", \"Ogni settimana\"],\n          [\"monthly\", \"Ogni mese\"],\n          [\"yearly\", \"Ogni anno\"],\n        ]\n          .map(\n            ([v, t]) =>\n              `<option value=\"${v}\" ${(ev?.frequency || \"none\") === v ? \"selected\" : \"\"}>${t}</option>`,\n          )\n          .join(\n            \"\",\n          )}</select></label><label>Fino al (facoltativo)<input type=\"date\" name=\"until_day\" value=\"${ev?.until_day || \"\"}\"></label><p class=\"hint wide\">${life.editingSplitFrom ? \"Le occorrenze precedenti restano invariate.\" : \"Modifica tutte le occorrenze. Nei mesi pi\u00f9 corti: ultimo giorno disponibile.\"}</p><label class=\"wide\">Luogo<input name=\"location\" maxlength=\"160\" value=\"${osSafe(ev?.location || \"\")}\"></label><label class=\"wide\">Note<textarea name=\"notes\" maxlength=\"1000\">${osSafe(ev?.notes || \"\")}</textarea></label><div class=\"os-form-error hidden\" role=\"alert\"></div><div class=\"os-form-actions\">${ev ? `<button class=\"os-button danger\" type=\"button\" data-life-delete-event=\"${ev.id}\">Elimina</button>` : \"\"}<button class=\"os-button primary\" type=\"button\" data-life-save onclick=\"osSubmit(this.form);return false\">Salva evento</button></div></form></div>`;\n      }\n\n      /** Calendario luned\u00ec-domenica, giorni adiacenti e dettagli solo su selezione. */\n      function osCalendar() {\n        const [year, month] = life.month.split(\"-\").map(Number),\n          first = new Date(Date.UTC(year, month - 1, 1)),\n          days = new Date(Date.UTC(year, month, 0)).getUTCDate(),\n          offset = (first.getUTCDay() + 6) % 7,\n          shiftMap = new Map(life.data.shifts.map((s) => [s.day, s.kind])),\n          events = life.data.events.filter((e) => e.day === life.selected),\n          tasks = life.data.tasks.filter(\n            (t) =>\n              t.status !== \"done\" &&\n              (t.scheduled_date === life.selected ||\n                t.due_date === life.selected),\n          ),\n          shift = shiftMap.get(life.selected);\n        const eventCounts = new Map(),\n          taskDays = new Set();\n        for (const event of life.data.events)\n          eventCounts.set(event.day, (eventCounts.get(event.day) || 0) + 1);\n        for (const task of life.data.tasks)\n          if (task.status !== \"done\") {\n            if (task.scheduled_date) taskDays.add(task.scheduled_date);\n            if (task.due_date) taskDays.add(task.due_date);\n          }\n        let cells = \"\";\n        for (let i = 0; i < Math.ceil((offset + days) / 7) * 7; i++) {\n          const n = i - offset + 1,\n            date = new Date(Date.UTC(year, month - 1, n)),\n            day = date.toISOString().slice(0, 10),\n            kind = shiftMap.get(day),\n            dayEventCount = eventCounts.get(day) || 0,\n            hasTask = taskDays.has(day);\n          if (i % 7 === 0) cells += '<div class=\"os-calendar-week\">';\n          cells += `<button class=\"os-day ${date.getUTCMonth() !== month - 1 ? \"other\" : \"\"} ${day === life.data.today ? \"today\" : \"\"} ${day === life.selected ? \"selected\" : \"\"}\" data-life-day=\"${day}\" data-kind=\"${kind || \"\"}\" aria-label=\"${osDate(day)}${kind ? \" \u00b7 \" + osShift[kind] : \"\"}${dayEventCount ? \" \u00b7 \" + dayEventCount + \" eventi\" : \"\"}${hasTask ? \" \u00b7 attivit\u00e0\" : \"\"}\" title=\"${day}${kind ? \" \u00b7 \" + osShift[kind] : \"\"}\"><b>${date.getUTCDate()}</b><span class=\"os-shift ${kind ? \"\" : \"no-shift\"}\">${kind ? osShiftInitial[kind] : \"\"}</span><span class=\"os-day-mark ${dayEventCount ? \"event-count\" : hasTask ? \"dot\" : \"\"}\" aria-hidden=\"true\">${dayEventCount ? dayEventCount : \"\"}</span></button>`;\n          if (i % 7 === 6) cells += \"</div>\";\n        }\n        document.body.style.setProperty(\n          \"--calendar-rows\",\n          Math.ceil((offset + days) / 7),\n        );\n        return `<div class=\"os-card\"><div class=\"os-month-header\"><button data-life-month=\"-1\" aria-label=\"Mese precedente\">\u2039</button><h2>${first.toLocaleDateString(\"it-IT\", { month: \"long\", year: \"numeric\", timeZone: \"UTC\" })}</h2><button data-life-month=\"1\" aria-label=\"Mese successivo\">\u203a</button></div><div class=\"os-weekdays\">${[\"Lun\", \"Mar\", \"Mer\", \"Gio\", \"Ven\", \"Sab\", \"Dom\"].map((x) => `<span>${x}</span>`).join(\"\")}</div><div class=\"os-days\">${cells}</div>${life.selected ? `<div class=\"os-calendar-details\">` : \"\"}${life.selected ? `<h3>${osDate(life.selected)}${shift ? \" \u00b7 \" + osShift[shift] : \"\"}</h3>${events.length ? events.map((e) => `<div class=\"os-mini\"><div><strong>${osSafe(e.title)}</strong><small>${e.start_time || \"Tutto il giorno\"}${e.end_time ? \"\u2013\" + e.end_time : \"\"}${e.location ? \" \u00b7 \" + osSafe(e.location) : \"\"}${e.occurrence_status === \"done\" ? \" \u00b7 Fatto\" : \"\"}</small></div><button class=\"os-row-action\" data-life-occurrence=\"${e.id}:${e.day}:${e.occurrence_status === \"done\" ? \"open\" : \"done\"}\">${e.occurrence_status === \"done\" ? \"Riapri\" : \"Fatto\"}</button><details class=\"os-event-options\"><summary aria-label=\"Opzioni evento\">Opzioni</summary><button class=\"os-row-action\" data-life-occurrence=\"${e.id}:${e.day}:skipped\" aria-label=\"Elimina questa occorrenza\">Elimina questa</button>${e.frequency && e.frequency !== \"none\" ? `<button class=\"os-row-action\" data-life-split-event=\"${e.id}:${e.day}\">Modifica da qui</button>` : \"\"}<button class=\"os-row-action\" data-life-event=\"${e.id}\" aria-label=\"Modifica serie\">Modifica</button></details></div>`).join(\"\") : '<p class=\"os-empty\">Nessun evento.</p>'}${tasks.length ? '<div class=\"os-section-label\">Attivit\u00e0</div>' + tasks.map((t) => `<div class=\"os-mini\"><strong>${osSafe(t.title)}</strong><button class=\"os-row-action\" data-life-task=\"${t.id}\" aria-label=\"Modifica attivit\u00e0\">\u00b7\u00b7\u00b7</button></div>`).join(\"\") : \"\"}` : \"\"}${life.selected ? \"</div>\" : \"\"}${osEventForm()}</div><details class=\"os-palette-wrap os-tools-drawer\" ${life.paletteOpen || life.tool ? \"open\" : \"\"}><summary>Dipingi turni${life.tool ? \" \u00b7 \" + osSafe(osShift[life.tool] || life.tool) : \"\"}</summary><div class=\"os-palette-state\" role=\"status\">${life.tool ? `Pennello attivo: <strong>${osSafe(osShift[life.tool] || (life.tool === \"event\" ? \"Evento\" : \"Cancella\"))}</strong>` : \"Scegli un turno, poi tocca i giorni.\"}</div><div class=\"os-palette\" aria-label=\"Pennello calendario\">${Object.entries(\n          osShift,\n        )\n          .map(\n            ([key, val]) =>\n              `<button data-life-tool=\"${key}\" title=\"${val}\" aria-label=\"${val}\" class=\"${life.tool === key ? \"active\" : \"\"}\" aria-pressed=\"${life.tool === key}\">${osSafe(val)}</button>`,\n          )\n          .join(\n            \"\",\n          )}<button data-life-tool=\"event\" class=\"${life.tool === \"event\" ? \"active\" : \"\"}\" aria-pressed=\"${life.tool === \"event\"}\">+ Evento</button><button data-life-tool=\"erase\" class=\"${life.tool === \"erase\" ? \"active\" : \"\"}\" aria-pressed=\"${life.tool === \"erase\"}\">Cancella</button>${life.tool ? '<button class=\"os-palette-stop\" data-life-tool=\"none\" aria-label=\"Disattiva pennello\">Fine</button>' : \"\"}${life.undo ? '<button data-life-undo aria-label=\"Annulla ultimo turno\">\u21b6</button>' : \"\"}</div></details>`;\n      }\n\n      /** Accetta solo l\u2019ultima lettura del mese corrente; scarta risposte tardive. */\n      async function osRefresh() {\n        const revision = ++life.readRevision,\n          month = life.month;\n        const fresh = await osRequest(\"getLifeData\", month);\n        if (revision !== life.readRevision || month !== life.month) return;\n        life.data = fresh;\n        renderLifeOS();\n      }\n      // Serialize brush writes. Roll back only this day if no newer paint supersedes it.\n\n      /** Aggiornamento ottimistico del turno, scritture serializzate e recupero errore. */\n      function osPaint(day, kind) {\n        const previous =\n          life.data.shifts.find((s) => s.day === day)?.kind || null;\n        const revision = ++life.paintRevision;\n        ++life.readRevision;\n        life.data.shifts = life.data.shifts.filter((s) => s.day !== day);\n        if (kind !== \"erase\") life.data.shifts.push({ day, kind });\n        renderLifeOS();\n        life.paintQueue = life.paintQueue\n          .then(() => osRequest(\"paintShift\", { day, kind }))\n          .catch((err) => {\n            if (revision === life.paintRevision) {\n              life.data.shifts = life.data.shifts.filter((s) => s.day !== day);\n              if (previous) life.data.shifts.push({ day, kind: previous });\n              renderLifeOS();\n            }\n            osError(err);\n          });\n        return life.paintQueue;\n      }\n      // A successful write followed by a failed refresh is still a successful write.\n      // Do not restore stale data or invite a second submission in that case.\n\n      /** Mutex scritture Life OS; distingue errore di scrittura da errore di aggiornamento. */\n      async function osWrite(method, arg, optimistic) {\n        if (life.busy) return;\n        life.busy = true;\n        ++life.readRevision;\n        const previous = life.data ? structuredClone(life.data) : null;\n        try {\n          if (optimistic) {\n            optimistic();\n            renderLifeOS();\n          }\n          const result = await osRequest(method, arg);\n          try {\n            await osRefresh();\n          } catch (error) {\n            osError(\n              Error(\"Salvato. Aggiornamento non riuscito: \" + error.message),\n            );\n          }\n          return result;\n        } catch (error) {\n          life.data = previous;\n          renderLifeOS();\n          osError(error);\n        } finally {\n          life.busy = false;\n        }\n      }\n\n      /** Only direct draggable rows belong to the todo ordering contract. */\n      function osTodoOrderIds(parent) {\n        return [...parent.children]\n          .filter(row => row.matches(\"[data-life-drag-row]\") && row.querySelector(\"[data-life-drag-handle]\"))\n          .map(row => Number(row.dataset.lifeDragRow));\n      }\n\n      /** Salva l\u2019ordine completo delle attivit\u00e0 aperte della categoria. */\n      async function osCommitOrder(category, ids) {\n        if (life.busy) return;\n        await osWrite(\"reorderTasks\", { category, ids });\n      }\n      let osDrag = null;\n      document.addEventListener(\"pointerdown\", (e) => {\n        const handle = e.target.closest(\"[data-life-drag-handle]\");\n        if (!handle || (e.pointerType === \"mouse\" && e.button !== 0) || life.busy) return;\n        const row = handle.closest(\"[data-life-drag-row]\");\n        osDrag = {\n          handle,\n          row,\n          category: life.category,\n          startY: e.clientY,\n          active: false,\n        };\n        handle.setPointerCapture(e.pointerId);\n        e.preventDefault();\n      });\n      document.addEventListener(\"pointermove\", (e) => {\n        if (!osDrag) return;\n        const d = osDrag;\n        if (Math.abs(e.clientY - d.startY) > 5) d.active = true;\n        if (!d.active) return;\n        d.row.classList.add(\"is-dragging\");\n        const at = document\n          .elementFromPoint(e.clientX, e.clientY)\n          ?.closest(\"[data-life-drag-row]\");\n        if (\n          at &&\n          at !== d.row &&\n          at.parentElement === d.row.parentElement &&\n          at.querySelector(\"[data-life-drag-handle]\")\n        ) {\n          const midpoint = at.getBoundingClientRect().top + at.offsetHeight / 2;\n          at.parentElement.insertBefore(\n            d.row,\n            e.clientY < midpoint ? at : at.nextSibling,\n          );\n        }\n        if (e.clientY > innerHeight - 75) scrollBy(0, 15);\n        else if (e.clientY < 75) scrollBy(0, -15);\n        e.preventDefault();\n      });\n      document.addEventListener(\"pointercancel\", () => {\n        if (osDrag) {\n          osDrag.row.classList.remove(\"is-dragging\");\n          osDrag = null;\n          renderLifeOS();\n        }\n      });\n      document.addEventListener(\"pointerup\", (e) => {\n        if (!osDrag) return;\n        const d = osDrag;\n        osDrag = null;\n        d.row.classList.remove(\"is-dragging\");\n        if (!d.active) return;\n        const ids = osTodoOrderIds(d.row.parentElement);\n        osCommitOrder(d.category, ids);\n      });\n      document.addEventListener(\"keydown\", (e) => {\n        const handle = e.target.closest(\"[data-life-drag-handle]\");\n        if (!handle || !e.altKey || ![\"ArrowUp\", \"ArrowDown\"].includes(e.key))\n          return;\n        e.preventDefault();\n        const row = handle.closest(\"[data-life-drag-row]\"),\n          peer =\n            e.key === \"ArrowUp\"\n              ? row.previousElementSibling\n              : row.nextElementSibling;\n        if (\n          !peer?.matches(\"[data-life-drag-row]\") ||\n          !peer.querySelector(\"[data-life-drag-handle]\")\n        )\n          return;\n        const parent = row.parentElement;\n        parent.insertBefore(row, e.key === \"ArrowUp\" ? peer : peer.nextSibling);\n        const ids = osTodoOrderIds(parent);\n        osCommitOrder(life.category, ids).then(() =>\n          document\n            .querySelector(\n              '[data-life-drag-handle=\"' + row.dataset.lifeDragRow + '\"]',\n            )\n            ?.focus(),\n        );\n      });\n\n      /** Editor creazione/modifica attivit\u00e0, con valori HTML escapati. */\n      function osOpenTask(id) {\n        const t = life.data.tasks.find((t) => t.id === Number(id)),\n          d = document.getElementById(\"life-dialog\");\n        d.innerHTML = `<div class=\"modal os-dialog\" role=\"dialog\" aria-modal=\"true\"><div class=\"os-topline\"><h2>${t ? \"Modifica attivit\u00e0\" : \"Nuova attivit\u00e0\"}</h2><button class=\"os-icon-button\" data-life-close aria-label=\"Chiudi\">\u00d7</button></div><form id=\"life-form\" data-kind=\"task\" class=\"os-form\"><input type=\"hidden\" name=\"record_id\" value=\"${t?.id || \"\"}\"><label class=\"wide\">Titolo *<input name=\"title\" maxlength=\"160\" required value=\"${osSafe(t?.title || \"\")}\"></label><label>Categoria *<select name=\"list_kind\" required>${life.data.categories.map((c) => `<option value=\"${osSafe(c.key)}\" ${t?.list_kind === c.key || (!t && c.key === life.category) ? \"selected\" : \"\"}>${osSafe(c.label)}</option>`).join(\"\")}</select></label><label>In calendario<input type=\"date\" name=\"scheduled_date\" value=\"${osSafe(t?.scheduled_date || \"\")}\"></label><label>Scadenza<input type=\"date\" name=\"due_date\" value=\"${osSafe(t?.due_date || \"\")}\"></label><label class=\"wide\">Note<textarea name=\"notes\" maxlength=\"1000\">${osSafe(t?.notes || \"\")}</textarea></label><div class=\"os-form-actions\">${t && t.status !== \"done\" ? `<button class=\"os-button\" type=\"button\" data-life-status=\"${t.id}:${t.status === \"waiting\" ? \"todo\" : \"waiting\"}\">${t.status === \"waiting\" ? \"Riporta in Da fare\" : \"Metti in attesa\"}</button>` : \"\"}${t ? `<button class=\"os-button danger\" type=\"button\" data-life-delete-task=\"${t.id}\">Elimina</button>` : \"\"}<button class=\"os-button primary\" type=\"submit\">Salva</button></div></form></div>`;\n        d.classList.remove(\"hidden\");\n        if (!matchMedia(\"(pointer:coarse)\").matches)\n          d.querySelector(\"[name=title]\").focus();\n      }\n\n      /** Controlli Su/Gi\u00f9 per l\u2019ordine delle categorie; estremi disabilitati. */\n      function osCategoryOrder() {\n        return `<section class=\"category-order\"><h3>Ordine categorie</h3>${life.data.categories.map((c, i) => `<div><span>${osSafe(c.label)}</span><button type=\"button\" data-life-rename-category=\"${osSafe(c.key)}\">Modifica</button><button type=\"button\" data-category-order=\"${i}:-1\" ${i === 0 ? \"disabled\" : \"\"} aria-label=\"Sposta ${osSafe(c.label)} prima\">Su</button><button type=\"button\" data-category-order=\"${i}:1\" ${i === life.data.categories.length - 1 ? \"disabled\" : \"\"} aria-label=\"Sposta ${osSafe(c.label)} dopo\">Gi\u00f9</button></div>`).join(\"\")}</section>`;\n      }\n\n      /** Editor nome categoria e ordine; chiavi stabili indipendenti dall\u2019etichetta. */\n      function osOpenCategory(key) {\n        const current = key\n          ? life.data.categories.find((c) => c.key === key)\n          : null;\n        const d = document.getElementById(\"life-dialog\");\n        d.innerHTML = `<div class=\"modal os-dialog\" role=\"dialog\" aria-modal=\"true\"><div class=\"os-topline\"><h2>${current ? \"Rinomina categoria\" : \"Nuova categoria\"}</h2><button class=\"os-icon-button\" data-life-close aria-label=\"Chiudi\">\u00d7</button></div><form id=\"life-form\" data-kind=\"category\" class=\"os-form\"><input type=\"hidden\" name=\"key\" value=\"${osSafe(current?.key || \"\")}\"><label class=\"wide\">Nome *<input name=\"label\" maxlength=\"40\" required value=\"${osSafe(current?.label || \"\")}\"></label><div class=\"os-form-actions\"><button class=\"os-button primary\" type=\"submit\">${current ? \"Salva nome\" : \"Aggiungi categoria\"}</button></div></form>${current && life.data.categories.length>1 ? `<div class=\"os-form\"><label>Trasferisci attivit\u00e0 a<select name=\"categoryDestination\">${life.data.categories.filter(c=>c.key!==current.key).map(c=>`<option value=\"${osSafe(c.key)}\">${osSafe(c.label)}</option>`).join(\"\")}</select></label><button type=\"button\" class=\"os-button danger\" data-life-delete-category=\"${osSafe(current.key)}\">Elimina categoria</button></div>` : \"\"}${osCategoryOrder()}</div>`;\n        d.classList.remove(\"hidden\");\n        if (!matchMedia(\"(pointer:coarse)\").matches)\n          d.querySelector(\"[name=label]\").focus();\n      }\n\n      /** Seleziona l\u2019evento o l\u2019occorrenza e apre il relativo editor nel calendario. */\n      function osOpenEvent(id, splitFrom = null) {\n        life.editingSplitFrom = splitFrom;\n        life.editingEvent = id === \"new\" ? null : Number(id);\n        life.creatingEvent = id === \"new\";\n        if (life.editingEvent) {\n          const ev =\n            life.data.events.find((e) => e.id === life.editingEvent) ||\n            life.data.upcomingEvents?.find((e) => e.id === life.editingEvent);\n          if (ev) {\n            life.month = (splitFrom || ev.day).slice(0, 7);\n            life.selected = splitFrom || ev.day;\n          }\n        }\n        life.tool = \"event\";\n        setView(\"calendar\");\n        document\n          .getElementById(\"os-event-editor\")\n          ?.scrollIntoView({ behavior: \"smooth\", block: \"center\" });\n        document.querySelector(\"#os-event-editor [name=title]\")?.focus();\n      }\n\n      /** Chiude il foglio Life OS e termina la modifica evento. */\n      function osClose() {\n        document.getElementById(\"life-dialog\").classList.add(\"hidden\");\n        life.creatingEvent = false;\n        life.editingEvent = null;\n        life.editingSplitFrom = null;\n        if (life.tool === \"event\") life.tool = null;\n        renderLifeOS();\n      }\n      document.addEventListener(\"click\", (e) => {\n        const el = e.target.closest(\n          \"[data-life-reorder],[data-life-nav],[data-life-task],[data-life-event],[data-life-split-event],[data-life-category],[data-life-rename-category],[data-life-delete-category],[data-life-delete-completed],[data-life-select-category],[data-life-close],[data-life-save],[data-life-status],[data-life-complete],[data-life-delete-task],[data-life-delete-event],[data-life-occurrence],[data-life-month],[data-life-day],[data-life-tool],[data-life-undo],[data-life-routine],[data-life-routine-manage],[data-life-routine-edit],[data-life-routine-delete]\",\n        );\n        if (!el) return;\n        if (el.hasAttribute(\"data-life-routine\")) {\n          const id = Number(el.dataset.lifeRoutine),\n            habit = life.data.routines.find((h) => h.id === id);\n          if (!habit) return;\n          const checked = !habit.checked,\n            day = life.data.today;\n          habit.checked = checked ? 1 : 0;\n          life.routinePending++;\n          life.routineRevision++;\n          document.getElementById(\"today\").innerHTML = osToday();\n          life.routineQueue = life.routineQueue\n            .then(() => osRequest(\"setRoutineCheck\", { id, checked, day }))\n            .catch(osError)\n            .finally(async () => {\n              life.routinePending--;\n              if (!life.routinePending) {\n                const revision = life.routineRevision;\n                const fresh = await osRequest(\"getLifeData\", life.month);\n                if (revision === life.routineRevision) {\n                  life.data = fresh;\n                  renderLifeOS();\n                }\n              }\n            })\n            .catch(osError);\n          return;\n        }\n        if (el.hasAttribute(\"data-life-routine-manage\"))\n          return osManageRoutines();\n        if (el.hasAttribute(\"data-life-routine-edit\")) {\n          const h = life.data.routines.find(\n            (x) => x.id === Number(el.dataset.lifeRoutineEdit),\n          );\n          if (!h) return;\n          const form = document.getElementById(\"os-routine-form\");\n          form.elements.record_id.value = h.id;\n          form.elements.title.value = h.title;\n          form.querySelector(\"[type=submit]\").textContent = \"Salva nome\";\n          form.elements.title.focus();\n          return;\n        }\n        if (el.hasAttribute(\"data-life-routine-delete\")) {\n          if (!confirm(\"Eliminare questa voce e le sue spunte?\")) return;\n          return osWrite(\n            \"deleteRoutine\",\n            Number(el.dataset.lifeRoutineDelete),\n          ).then((saved) => {\n            if (saved) osManageRoutines();\n          });\n        }\n        if (el.hasAttribute(\"data-life-reorder\")) {\n          life.reorder = !life.reorder;\n          renderLifeOS();\n          return;\n        }\n        if (el.hasAttribute(\"data-life-nav\"))\n          return setView(el.dataset.lifeNav);\n        if (el.hasAttribute(\"data-life-task\"))\n          return osOpenTask(el.dataset.lifeTask);\n        if (el.hasAttribute(\"data-life-split-event\")) {\n          const [id, day] = el.dataset.lifeSplitEvent.split(\":\");\n          return osOpenEvent(id, day);\n        }\n        if (el.hasAttribute(\"data-life-event\"))\n          return osOpenEvent(el.dataset.lifeEvent);\n        if (el.hasAttribute(\"data-life-delete-category\")) {\n          const key=el.dataset.lifeDeleteCategory, destination=document.querySelector(\"[name=categoryDestination]\")?.value;\n          osWrite(\"deleteCategory\",{key,destination}).then(()=>osClose());return;\n        }\n        if (el.hasAttribute(\"data-life-category\")) return osOpenCategory();\n        if (el.hasAttribute(\"data-life-rename-category\"))\n          return osOpenCategory(el.dataset.lifeRenameCategory);\n        if (el.hasAttribute(\"data-life-delete-completed\")) {\n          if (confirm(\"Eliminare tutte le completate di questa categoria?\"))\n            return osWrite(\"deleteCompletedTasks\", {\n              category: el.dataset.lifeDeleteCompleted,\n            });\n          return;\n        }\n        if (el.hasAttribute(\"data-life-select-category\")) {\n          const top = window.scrollY,\n            left = document.querySelector(\".os-category-tabs\").scrollLeft;\n          life.category = el.dataset.lifeSelectCategory;\n          renderLifeOS();\n          document.querySelector(\".os-category-tabs\").scrollLeft = left;\n          window.scrollTo({ top, behavior: \"instant\" });\n          return;\n        }\n        if (el.hasAttribute(\"data-life-close\")) return osClose();\n        if (el.hasAttribute(\"data-life-save\")) {\n          if (!e.defaultPrevented) {\n            e.preventDefault();\n            osSubmit(el.closest(\"form\"));\n          }\n          return;\n        }\n        if (el.hasAttribute(\"data-life-status\")) {\n          const [id, status] = el.dataset.lifeStatus.split(\":\");\n          if (el.closest(\".os-dialog\")) osClose();\n          return osWrite(\"setTaskStatus\", { id: Number(id), status }, () => {\n            const t = life.data.tasks.find((t) => t.id === Number(id));\n            t.section_status = status === \"done\" ? (t.status === \"waiting\" ? \"waiting\" : t.section_status || \"todo\") : status;\n            t.status = status;\n            t.completed_at =\n              status === \"done\" ? new Date().toISOString() : null;\n          });\n        }\n        if (el.hasAttribute(\"data-life-complete\"))\n          return osWrite(\n            \"setTaskStatus\",\n            { id: Number(el.dataset.lifeComplete), status: \"done\" },\n            () => {\n              life.data.tasks.find(\n                (t) => t.id === Number(el.dataset.lifeComplete),\n              ).status = \"done\";\n            },\n          );\n        if (el.hasAttribute(\"data-life-delete-task\")) {\n          if (confirm(\"Eliminare questa attivit\u00e0?\")) {\n            osClose();\n            return osWrite(\"deleteTask\", Number(el.dataset.lifeDeleteTask));\n          }\n          return;\n        }\n        if (el.hasAttribute(\"data-life-occurrence\")) {\n          const [id, day, status] = el.dataset.lifeOccurrence.split(\":\");\n          if (\n            status === \"skipped\" &&\n            !confirm(\"Eliminare solo questa occorrenza?\")\n          )\n            return;\n          return osWrite(\"setEventOccurrence\", { id: Number(id), day, status });\n        }\n        if (el.hasAttribute(\"data-life-delete-event\")) {\n          if (confirm(\"Eliminare questo evento e tutte le sue ricorrenze?\")) {\n            osClose();\n            return osWrite(\"deleteEvent\", Number(el.dataset.lifeDeleteEvent));\n          }\n          return;\n        }\n        if (el.hasAttribute(\"data-life-tool\")) {\n          life.tool =\n            el.dataset.lifeTool === \"none\" || life.tool === el.dataset.lifeTool\n              ? null\n              : el.dataset.lifeTool;\n          if (life.tool !== \"event\") {\n            life.creatingEvent = false;\n            life.editingEvent = null;\n          }\n          return renderLifeOS();\n        }\n        if (el.hasAttribute(\"data-life-month\")) {\n          const [y, m] = life.month.split(\"-\").map(Number);\n          life.month = new Date(\n            Date.UTC(y, m - 1 + Number(el.dataset.lifeMonth), 1),\n          )\n            .toISOString()\n            .slice(0, 7);\n          life.selected = null;\n          life.creatingEvent = false;\n          life.editingEvent = null;\n          return loadLifeOS();\n        }\n        if (el.hasAttribute(\"data-life-day\")) {\n          const day = el.dataset.lifeDay,\n            old = life.data.shifts.find((s) => s.day === day)?.kind || null;\n          life.selected = day;\n          if (!life.tool) {\n            renderLifeOS();\n            return;\n          }\n          if (life.tool === \"event\") {\n            life.creatingEvent = true;\n            life.editingEvent = null;\n            renderLifeOS();\n            document\n              .getElementById(\"os-event-editor\")\n              ?.scrollIntoView({ behavior: \"smooth\", block: \"center\" });\n            return;\n          }\n          life.undo = { day, kind: old };\n          return osPaint(day, life.tool);\n        }\n        if (el.hasAttribute(\"data-life-undo\") && life.undo) {\n          const { day, kind } = life.undo;\n          life.undo = null;\n          return osPaint(day, kind || \"erase\");\n        }\n      });\n\n      /** Valida il form e invia una sola scrittura; evita il reinvio di eventi gi\u00e0 salvati. */\n      async function osSubmit(form) {\n        if (!form || form.getAttribute(\"id\") !== \"life-form\") return;\n        const formMessage = form.querySelector(\".os-form-error\");\n        if (!form.reportValidity()) {\n          if (formMessage) {\n            formMessage.textContent = \"Completa i campi indicati con *.\";\n            formMessage.classList.remove(\"hidden\");\n          }\n          return;\n        }\n        const values = Object.fromEntries(new FormData(form).entries()),\n          kind = form.dataset.kind;\n        if (values.record_id) values.id = Number(values.record_id);\n        delete values.record_id;\n        if (kind === \"category\") {\n          const saved = await osWrite(\n            values.key ? \"renameCategory\" : \"addCategory\",\n            { key: values.key, label: values.label },\n          );\n          if (saved) {\n            life.category = values.key || saved.key;\n            osClose();\n            renderLifeOS();\n          }\n          return;\n        }\n        if (kind === \"event\") {\n          if (form.dataset.saving === \"true\") return;\n          form.dataset.saving = \"true\";\n          const button = form.querySelector(\"[data-life-save]\"),\n            message = form.querySelector(\".os-form-error\");\n          let savedOnServer = form.dataset.saved === \"true\";\n          try {\n            if (values.end_time && !values.start_time)\n              throw Error(\"Indica anche l\u2019ora di inizio.\");\n            button.disabled = true;\n            button.textContent = \"Salvataggio\u2026\";\n            message.textContent = \"Salvataggio in corso\u2026\";\n            message.classList.add(\"is-pending\");\n            message.classList.remove(\"hidden\");\n            if (!savedOnServer) {\n              await osRequest(\n                values.split_from ? \"splitEventSeries\" : \"saveEvent\",\n                values,\n              );\n              savedOnServer = true;\n              form.dataset.saved = \"true\";\n            }\n            const eventMonth = values.day.slice(0, 7);\n            const fresh = await osRequest(\"getLifeData\", eventMonth);\n            life.month = eventMonth;\n            life.selected = values.day;\n            life.data = fresh;\n            life.creatingEvent = false;\n            life.editingEvent = null;\n            life.tool = null;\n            renderLifeOS();\n            document\n              .querySelector('[data-life-day=\"' + values.day + '\"]')\n              ?.scrollIntoView({ block: \"center\", behavior: \"smooth\" });\n            document.getElementById(\"error\").classList.add(\"hidden\");\n          } catch (err) {\n            message.textContent =\n              (savedOnServer\n                ? \"Evento salvato, aggiornamento non riuscito. Riprova ad aggiornare: \"\n                : \"Evento non salvato: \") + (err.message || err);\n            message.classList.remove(\"hidden\");\n            message.classList.remove(\"is-pending\");\n            button.disabled = false;\n            button.textContent = savedOnServer\n              ? \"Aggiorna calendario\"\n              : \"Salva evento\";\n          } finally {\n            delete form.dataset.saving;\n          }\n          return;\n        }\n        const saved = await osWrite(\"saveTask\", values);\n        if (saved) osClose();\n      }\n      document.addEventListener(\n        \"submit\",\n        (e) => {\n          if (e.target.getAttribute(\"id\") === \"life-form\") {\n            e.preventDefault();\n            osSubmit(e.target);\n          }\n          if (e.target.getAttribute(\"id\") === \"os-routine-form\") {\n            e.preventDefault();\n            if (!e.target.reportValidity()) return;\n            const values = new FormData(e.target),\n              title = values.get(\"title\"),\n              id = Number(values.get(\"record_id\") || 0);\n            osWrite(\"saveRoutine\", { title, id }).then((saved) => {\n              if (saved) osManageRoutines();\n            });\n          }\n        },\n        true,\n      );\n\n      /** Gestisce il cambio giorno a Roma senza moltiplicare i timer. */\n      function osRefreshClock() {\n        if (!life.data) return;\n        const today = new Date().toLocaleDateString(\"sv-SE\", {\n          timeZone: \"Europe/Rome\",\n        });\n        if (today !== life.data.today) {\n          life.month = today.slice(0, 7);\n          life.selected = null;\n          loadLifeOS();\n          osLoadHomeFinance();\n          osLoadWeather();\n          osUpdateHeader();\n          return;\n        }\n        const box = document.querySelector(\".os-solar-inline\");\n        if (box) box.innerHTML = osPrayerCard(today);\n        if (Date.now() - life.weatherAt >= 30 * 60000) osLoadWeather();\n      }\n      window.setInterval?.(osRefreshClock, 60000);\n      document.addEventListener(\"visibilitychange\", () => {\n        if (!document.hidden) {\n          osRefreshClock();\n          osLoadWeather();\n        }\n      });\n\n      document.addEventListener(\n        \"toggle\",\n        (e) => {\n          if (e.target.matches(\".os-tools-drawer\"))\n            life.paletteOpen = e.target.open;\n        },\n        true,\n      );\n      document.addEventListener(\"click\", async (e) => {\n        const b = e.target.closest(\"[data-category-order]\");\n        if (!b || life.busy) return;\n        const [i, delta] = b.dataset.categoryOrder.split(\":\").map(Number),\n          keys = life.data.categories.map((c) => c.key);\n        [keys[i], keys[i + delta]] = [keys[i + delta], keys[i]];\n        await osWrite(\"reorderCategories\", { keys });\n        const section = document.querySelector(\".category-order\");\n        if (section) section.outerHTML = osCategoryOrder();\n      });\n    </script>\n    <script>\n      // The finance month follows Rome even when the device is abroad.\n      const now = new Date(\n        new Date().toLocaleDateString(\"sv-SE\", { timeZone: \"Europe/Rome\" }) +\n          \"T12:00:00\",\n      );\n      const state = {\n        year: now.getFullYear(),\n        month: now.getMonth() + 1,\n        view: \"today\",\n        categoryMonth: now.getMonth() + 1,\n        data: null,\n        search: \"\",\n        type: \"Tutti\",\n        busy: false,\n        assetsVisible: true,\n        overviewCardsOpen: false,\n        overviewAnalysisOpen: false,\n        overviewPlanOpen: false,\n        loadedDetail: false,\n        loadRevision: 0,\n        movementLimit: 100,\n        planningDraft: null,\n        wealthSeries: \"total\",\n        budgetSettingsOpen: false,\n        budgetAnnualOpen: false,\n        budgetHistoryOpen: false,\n      };\n      const euroFormatter = new Intl.NumberFormat(\"it-IT\", {\n        style: \"currency\",\n        currency: \"EUR\",\n            useGrouping: \"always\",\n        maximumFractionDigits: 0,\n      });\n      const euro = (n) => euroFormatter.format(n || 0);\n      const exactEuroFormatter = new Intl.NumberFormat(\"it-IT\", {\n        style: \"currency\",\n        currency: \"EUR\",\n            useGrouping: \"always\",\n      });\n      const exactEuro = (n) => exactEuroFormatter.format(n || 0);\n      const privateAmount = (n) => (state.assetsVisible ? euro(n) : \"\u2022\u2022\u2022\u2022 \u20ac\");\n\n      /** Pulsante patrimonio con stato e nome accessibile coerenti. */\n      function privacyButton() {\n        const label = state.assetsVisible\n          ? \"Nascondi patrimonio\"\n          : \"Mostra patrimonio\";\n        const eye = state.assetsVisible\n          ? '<path d=\"M2 12s3.8-7 10-7 10 7 10 7-3.8 7-10 7-10-7-10-7Z\"/><circle cx=\"12\" cy=\"12\" r=\"3\"/>'\n          : '<path d=\"M3 3l18 18M10.6 5.1A10.8 10.8 0 0 1 12 5c6.2 0 10 7 10 7a16.7 16.7 0 0 1-3.2 3.9M6.2 6.2A16 16 0 0 0 2 12s3.8 7 10 7c1.6 0 3-.5 4.2-1.3M10.1 10.1a3 3 0 0 0 3.8 3.8\"/>';\n        return (\n          '<button type=\"button\" class=\"privacy-toggle\" data-toggle-assets aria-label=\"' +\n          label +\n          '\" title=\"' +\n          label +\n          '\" aria-pressed=\"' +\n          state.assetsVisible +\n          '\"><svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.7\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">' +\n          eye +\n          \"</svg></button>\"\n        );\n      }\n      const shortMonth = (key) =>\n        key\n          ? new Date(\n              +key.slice(0, 4),\n              +key.slice(5, 7) - 1,\n              1,\n            ).toLocaleDateString(\"it-IT\", { month: \"short\", year: \"2-digit\" })\n          : \"\u2014\";\n      const titleMonth = (year, month) =>\n        new Date(year, month - 1, 1).toLocaleDateString(\"it-IT\", {\n          month: \"long\",\n          year: \"numeric\",\n        });\n      const escapeHtml = (value) =>\n        String(value ?? \"\").replace(\n          /[&<>\"']/g,\n          (s) =>\n            ({\n              \"&\": \"&amp;\",\n              \"<\": \"&lt;\",\n              \">\": \"&gt;\",\n              '\"': \"&quot;\",\n              \"'\": \"&#39;\",\n            })[s],\n        );\n      const amountClass = (n) => (n < 0 ? \"negative\" : \"\");\n\n      /** Carica dati finanziari leggeri o completi in base alla vista; protegge da risposte obsolete. */\n      function load() {\n        document.getElementById(\"period-label\").textContent = titleMonth(\n          state.year,\n          state.month,\n        );\n        const revision = ++state.loadRevision,\n          detail = [\"overview\", \"movements\", \"budget\", \"analysis\"].includes(state.view),\n          method = detail\n            ? \"getFinanceData\"\n            : state.view === \"extras\"\n              ? \"getFinanceExtras\"\n              : \"getFinanceOverview\";\n        document.getElementById(\"error\").classList.add(\"hidden\");\n        document.getElementById(\"loading\").classList.remove(\"hidden\");\n        workerRequest(method, [state.year, state.month])\n          .then((data) => {\n            if (revision !== state.loadRevision) return;\n            state.data = data;\n            state.loadedDetail = detail;\n            document.getElementById(\"loading\").classList.add(\"hidden\");\n            render();\n            if (life.data && data.key === life.data.today.slice(0, 7)) {\n              life.finance = data;\n              document.getElementById(\"today\").innerHTML = osToday();\n            }\n          })\n          .catch((err) => {\n            if (revision !== state.loadRevision) return;\n            document.getElementById(\"loading\").classList.add(\"hidden\");\n            const box = document.getElementById(\"error\");\n            box.textContent = \"Lettura non riuscita: \" + err.message;\n            box.classList.remove(\"hidden\");\n          });\n      }\n\n      /** Unico punto di navigazione; aggiorna tab, layout e caricamento necessario. */\n      function setView(view) {\n\n        if (\n          ![\n            \"today\",\n            \"tasks\",\n            \"calendar\",\n            \"overview\",\n            \"movements\",\n            \"budget\",\n            \"analysis\",\n            \"extras\",\n          ].includes(view)\n        )\n          return;\n        const previousView = state.view;\n        // Invalidate an in-flight finance read when leaving its view, not on every click.\n        if (previousView !== view) {\n          ++state.loadRevision;\n          document.getElementById(\"loading\").classList.add(\"hidden\");\n        }\n        state.view = view;\n        document.body.classList.toggle(\"dashboard-mode\", view === \"today\");\n        document\n          .querySelectorAll(\".view\")\n          .forEach((x) => x.classList.toggle(\"active\", x.id === view));\n        document\n          .querySelectorAll(\"button[data-view]\")\n          .forEach((x) =>\n            x.classList.toggle(\"active\", x.dataset.view === view),\n          );\n        document.getElementById(\"page-title\").textContent = {\n          today: \"Life OS\",\n          tasks: \"Attivit\u00e0\",\n          calendar: \"Calendario\",\n          overview: \"Finanza\",\n          movements: \"Movimenti\",\n          budget: \"Budget\",\n          analysis: \"Analisi\",\n          extras: \"Straordinarie\",\n        }[view];\n        document\n          .getElementById(\"finance-tabs\")\n          .classList.toggle(\n            \"hidden\",\n            ![\"overview\", \"movements\", \"budget\", \"analysis\", \"budget\", \"extras\", \"analysis\"].includes(view),\n          );\n        document\n          .querySelector(\".top-right\")\n          .classList.toggle(\n            \"hidden\",\n            ![\"overview\", \"movements\", \"budget\", \"analysis\", \"budget\", \"extras\", \"analysis\"].includes(view),\n          );\n        document.body.dataset.view = view;\n        osPageActions();\n        if ([\"overview\", \"movements\", \"budget\", \"analysis\", \"budget\", \"extras\", \"analysis\"].includes(view)) {\n          if (\n            !state.data ||\n            state.data.year !== state.year ||\n            state.data.month !== state.month ||\n            ([\"overview\", \"movements\", \"budget\", \"analysis\"].includes(view) && !state.loadedDetail)\n          )\n            load();\n          else render();\n        }\n        document\n          .querySelector(\".nav [data-view=overview]\")\n          .classList.toggle(\n            \"active\",\n            [\"overview\", \"movements\", \"budget\", \"analysis\", \"budget\", \"extras\", \"analysis\"].includes(view),\n          );\n        document\n          .querySelectorAll(\".nav [data-view]\")\n          .forEach((button) =>\n            button.setAttribute(\n              \"aria-current\",\n              button.classList.contains(\"active\") ? \"page\" : \"false\",\n            ),\n          );\n        if (view !== \"calendar\") life.tool = null;\n        if ([\"today\", \"tasks\", \"calendar\"].includes(view)) {\n          renderLifeOS();\n          if (view === \"today\") osLoadHomeFinance();\n        }\n        window.scrollTo({ top: 0, behavior: \"instant\" });\n      }\n\n      /** Render finanziario limitato alla vista attiva; evita grafici nascosti costosi. */\n      function render() {\n        const d = state.data;\n        if (!d) return;\n        for (const id of [\"overview\", \"extras\", \"movements\", \"budget\", \"analysis\"])\n          if (id !== state.view) document.getElementById(id).innerHTML = \"\";\n        document.getElementById(\"sync-top\").textContent =\n          \"Aggiornato \" + d.updatedAt;\n        document.getElementById(\"sync-side\").textContent =\n          \"Aggiornato \" + d.updatedAt;\n        document.getElementById(\"version-side\").textContent =\n          \"Versione \" + (d.appVersion || \"precedente\");\n        if (state.view === \"overview\") {\n          document.getElementById(\"overview\").innerHTML = overview(d);\n\n        }\n        if (state.view === \"budget\" && state.loadedDetail) {\n          document.getElementById(\"budget\").innerHTML = monthlyBudgetDetails(d.summary) + overviewAnalysis(d);\n          updateProjection();\n        }\n        if (state.view === \"analysis\" && state.loadedDetail) document.getElementById(\"analysis\").innerHTML = categoryCard(d) + cashFlowChart(d);\n        if (state.view === \"extras\")\n          document.getElementById(\"extras\").innerHTML = extrasView(d);\n        if (state.view === \"movements\" && state.loadedDetail) renderMovements();\n      }\n\n      /** Tabella mensile annuale; gli importi patrimonio rispettano la modalit\u00e0 privacy. */\n      function annual(d) {\n        const format = (x) =>\n          '<div class=\"annual-row ' +\n          (x.month === d.key ? \"selected\" : \"\") +\n          '\" data-month=\"' +\n          x.month +\n          '\"><strong>' +\n          shortMonth(x.month) +\n          \"</strong><span>\" +\n          (x.hasRecords\n            ? (x.incomePayslip ? \"\u2248 \" : \"\") + euro(x.income)\n            : \"\u2014\") +\n          \"</span><span>\" +\n          (x.hasRecords ? euro(x.spent) : \"\u2014\") +\n          '</span><span class=\"desktop-only\">' +\n          (x.hasRecords ? euro(x.net) : \"\u2014\") +\n          '</span><span class=\"annual-wealth\">' +\n          (() => {\n            const w = (d.lifetime?.series || []).find(\n              (m) => m.month === x.month,\n            )?.wealth;\n            return Number.isFinite(w) ? privateAmount(w) : \"\u2014\";\n          })() +\n          \"</span><span>\" +\n          exactEuro(x.budgetCommitments ?? x.commitments) +\n          '</span><span class=\"emphasis ' +\n          (x.spendable < 0 ? \"bad\" : \"\") +\n          '\">' +\n          exactEuro(x.month === d.key ? d.summary.monthlyRemaining : (x.monthlyRemaining ?? x.spendable)) +\n          \"</span></div>\";\n        const t = d.yearTotal;\n        return (\n          '<div class=\"annual-head\"><span>Mese</span><span>Entrate</span><span>Uscite</span><span class=\"desktop-only\">Netto</span><span>Patrimonio</span><span>Impegni</span><span title=\"Mese corrente: residuo; mesi: libero dopo gli impegni\">Spendibile</span></div>' +\n          d.yearly.map(format).join(\"\") +\n          '<div class=\"annual-row total\"><strong>Anno</strong><span>' +\n          (t.incomePayslip ? \"\u2248 \" : \"\") +\n          euro(t.income) +\n          \"</span><span>\" +\n          euro(t.spent) +\n          '</span><span class=\"desktop-only\">' +\n          euro(t.net) +\n          \"</span><span>\u2014</span><span>\" +\n          euro(t.commitments) +\n          \"</span><span>\u2014</span></div>\"\n        );\n      }\n      // A monotone cubic spline keeps the curves smooth without inventing peaks.\n\n      /** Genera una curva SVG dai punti senza dipendenze esterne. */\n      function chartCurve(points) {\n        if (!points.length) return \"\";\n        const chunks = [];\n        let current = [];\n        const flush = () => {\n          if (!current.length) return;\n          if (current.length === 1) {\n            chunks.push(\"M\" + current[0].x + \" \" + current[0].y);\n            current = [];\n            return;\n          }\n          const slope = current\n            .slice(1)\n            .map((p, i) => (p.y - current[i].y) / (p.x - current[i].x));\n          const tangent = current.map((_, i) => {\n            if (i === 0) return slope[0];\n            if (i === current.length - 1) return slope[slope.length - 1];\n            return slope[i - 1] * slope[i] <= 0\n              ? 0\n              : (2 * slope[i - 1] * slope[i]) / (slope[i - 1] + slope[i]);\n          });\n          let path = \"M\" + current[0].x + \" \" + current[0].y;\n          for (let i = 0; i < current.length - 1; i++) {\n            const a = current[i],\n              b = current[i + 1],\n              dx = (b.x - a.x) / 3,\n              lo = Math.min(a.y, b.y),\n              hi = Math.max(a.y, b.y);\n            const c1 = Math.max(lo, Math.min(hi, a.y + tangent[i] * dx));\n            const c2 = Math.max(lo, Math.min(hi, b.y - tangent[i + 1] * dx));\n            path +=\n              \" C\" +\n              (a.x + dx).toFixed(1) +\n              \" \" +\n              c1.toFixed(1) +\n              \" \" +\n              (b.x - dx).toFixed(1) +\n              \" \" +\n              c2.toFixed(1) +\n              \" \" +\n              b.x +\n              \" \" +\n              b.y;\n          }\n          chunks.push(path);\n          current = [];\n        };\n        for (const point of points) {\n          if (point) current.push(point);\n          else flush();\n        }\n        flush();\n        return chunks.join(\" \");\n      }\n\n      /** Grafici entrate/uscite e liquidit\u00e0; nasconde dati privati quando richiesto. */\n      function cashFlowChart(d) {\n        const compact = window.matchMedia(\"(max-width:760px)\").matches,\n          limit = state.chartMonths ?? (compact ? 6 : 12),\n          series = limit ? d.lifetime.series.slice(-limit) : d.lifetime.series;\n        const W = compact ? 420 : 820,\n          H = compact ? 250 : 260,\n          L = 46,\n          R = W - 16,\n          T = 22,\n          B = H - 40;\n        const x = (i) => L + ((i + 0.5) * (R - L)) / series.length,\n          slot = (R - L) / series.length,\n          bw = Math.min(12, slot * 0.32);\n        const max =\n            Math.max(100, ...series.flatMap((m) => [m.income, m.spent])) * 1.1,\n          y = (v) => B - (v / max) * (B - T);\n        const grid = Array.from({ length: 4 }, (_, i) => (max * i) / 3)\n          .map(\n            (v) =>\n              '<line x1=\"' +\n              L +\n              '\" x2=\"' +\n              R +\n              '\" y1=\"' +\n              y(v) +\n              '\" y2=\"' +\n              y(v) +\n              '\" class=\"grid-line\"/><text x=\"' +\n              (L - 8) +\n              '\" y=\"' +\n              (y(v) + 4) +\n              '\" text-anchor=\"end\">' +\n              Math.round(v / 100) / 10 +\n              \"k</text>\",\n          )\n          .join(\"\");\n        const labels = series\n          .map((m, i) =>\n            i % Math.max(1, Math.ceil(series.length / (compact ? 4 : 8))) &&\n            i !== series.length - 1\n              ? \"\"\n              : '<text x=\"' +\n                x(i) +\n                '\" y=\"' +\n                (H - 12) +\n                '\" text-anchor=\"middle\">' +\n                shortMonth(m.month) +\n                \"</text>\",\n          )\n          .join(\"\");\n        const bars = series\n          .map((m, i) =>\n            [\"income\", \"spent\"]\n              .map(\n                (k, j) =>\n                  '<rect data-chart-month=\"' +\n                  m.month +\n                  '\" data-month=\"' +\n                  m.month +\n                  '\" data-series=\"' +\n                  k +\n                  '\" x=\"' +\n                  (x(i) + (j ? 1 : -bw - 1)) +\n                  '\" y=\"' +\n                  y(m[k]) +\n                  '\" width=\"' +\n                  bw +\n                  '\" height=\"' +\n                  Math.max(0, B - y(m[k])) +\n                  '\" rx=\"2\" fill=\"' +\n                  (j ? \"#ff9da4\" : \"var(--os-accent)\") +\n                  '\"><title>' +\n                  shortMonth(m.month) +\n                  \" \u00b7 \" +\n                  (j ? \"Uscite \" : \"Entrate \") +\n                  euro(m[k]) +\n                  \"</title></rect>\",\n              )\n              .join(\"\"),\n          )\n          .join(\"\");\n        const visible = state.assetsVisible,\n          totalMode = false;\n        const valueOf = (m) => (totalMode ? m.liquidWealth : m.wealth);\n        const known = series.filter((m) => Number.isFinite(valueOf(m)));\n        const wm = Math.max(100, ...known.map(valueOf)),\n          wl = Math.min(0, ...known.map(valueOf));\n        const wy = (v) => B - ((v - wl) / (wm - wl || 1)) * (B - T);\n        const path = chartCurve(\n          series.map((m, i) =>\n            Number.isFinite(valueOf(m)) ? { x: x(i), y: wy(valueOf(m)) } : null,\n          ),\n        );\n        const dots = known\n          .map(\n            (m) =>\n              `<circle cx=\"${x(series.indexOf(m))}\" cy=\"${wy(valueOf(m))}\" r=\"4\" class=\"wealth-dot\"><title>${shortMonth(m.month)} \u00b7 ${euro(valueOf(m))}</title></circle>`,\n          )\n          .join(\"\");\n        const wg = Array.from({ length: 4 }, (_, i) => wl + ((wm - wl) * i) / 3)\n          .map(\n            (v) =>\n              `<line x1=\"${L}\" x2=\"${R}\" y1=\"${wy(v)}\" y2=\"${wy(v)}\" class=\"grid-line\"/><text x=\"${L - 8}\" y=\"${wy(v) + 4}\" text-anchor=\"end\">${Math.round(v / 100) / 10}k</text>`,\n          )\n          .join(\"\");\n        const liquid = visible\n          ? known.length\n            ? `<div class=\"chart-scroll\"><svg class=\"trend-svg is-compact wealth-chart\" viewBox=\"0 0 ${W} ${H}\" role=\"img\" aria-label=\"Patrimonio\">${wg}<path class=\"wealth-record-line\" d=\"${path}\"/>${dots}${labels}</svg></div><p class=\"hint\">Dati verificati da ${shortMonth(known[0].month)}.</p>`\n            : '<p class=\"empty\">Nessun saldo verificato nel periodo.</p>'\n          : '<button type=\"button\" class=\"ghost\" data-toggle-assets>Mostra patrimonio</button>';\n        const wealthControls = \"\";\n        const selected =\n          series.find((m) => m.month === state.chartSelectedMonth) ||\n          series.at(-1);\n        const selectedValues = selected\n          ? '<div class=\"trend-values\"><b>' +\n            shortMonth(selected.month) +\n            \"</b><span>Entrate <strong>\" +\n            euro(selected.income) +\n            \"</strong></span><span>Uscite <strong>\" +\n            euro(selected.spent) +\n            \"</strong></span></div>\"\n          : \"\";\n        const controls =\n          '<div class=\"chart-range\" role=\"group\" aria-label=\"Periodo del grafico\">' +\n          [\n            [3, \"3 mesi\"],\n            [6, \"6 mesi\"],\n            [12, \"12 mesi\"],\n            [0, \"Tutto\"],\n          ]\n            .map(\n              ([n, label]) =>\n                '<button type=\"button\" data-chart-range=\"' +\n                n +\n                '\" aria-pressed=\"' +\n                (limit === n) +\n                '\">' +\n                label +\n                \"</button>\",\n            )\n            .join(\"\") +\n          \"</div>\";\n        const table = series\n          .map(\n            (m) =>\n              '<tr><th scope=\"row\">' +\n              shortMonth(m.month) +\n              \"</th><td>\" +\n              euro(m.income) +\n              \"</td><td>\" +\n              euro(m.spent) +\n              \"</td><td>\" +\n              (Number.isFinite(valueOf(m)) ? privateAmount(valueOf(m)) : \"\u2014\") +\n              \"</td></tr>\",\n          )\n          .join(\"\");\n        return (\n          '<div class=\"integrated-chart chart-pair\"><section class=\"card pad flow-card\"><div class=\"card-title\"><h2>Entrate e uscite</h2></div>' +\n          controls +\n          '<div class=\"flow-legend\"><span class=\"income-key\">Entrate</span><span class=\"spent-key\">Uscite</span></div><div class=\"chart-scroll\"><svg class=\"trend-svg is-compact\" viewBox=\"0 0 ' +\n          W +\n          \" \" +\n          H +\n          '\" role=\"img\" aria-label=\"Entrate e uscite mensili\">' +\n          grid +\n          bars +\n          labels +\n          \"</svg></div>\" +\n          selectedValues +\n          '</section><section class=\"card pad wealth-chart-card\"><div class=\"card-title liquid-chart-heading\"><div><h2>Patrimonio</h2><small>' +\n          \"Patrimonio\" +\n          \" \u00b7 \" +\n          privateAmount(totalMode ? d.summary.totalAssets : d.summary.assets) +\n          \"</small></div>\" +\n          privacyButton() +\n          \"</div>\" +\n          wealthControls +\n          liquid +\n          '<details class=\"chart-values\"><summary>Valori mensili</summary><div class=\"chart-scroll\"><table><thead><tr><th>Mese</th><th>Entrate</th><th>Uscite</th><th>Patrimonio</th></tr></thead><tbody>' +\n          table +\n          \"</tbody></table></div></details></section></div>\"\n        );\n      }\n\n      document.addEventListener(\"click\", (e) => {\n        const range = e.target.closest(\"[data-chart-range]\"),\n          month = e.target.closest(\"[data-chart-month]\"),\n          wealth = e.target.closest(\"[data-wealth-series]\");\n        if (!range && !month && !wealth) return;\n        if (wealth) state.wealthSeries = wealth.dataset.wealthSeries;\n        if (range) {\n          state.chartMonths = Number(range.dataset.chartRange);\n          state.chartSelectedMonth = null;\n        }\n        if (month) state.chartSelectedMonth = month.dataset.chartMonth;\n        const chart = document.querySelector(\"#analysis .integrated-chart\");\n        if (chart && state.data) chart.outerHTML = cashFlowChart(state.data);\n      });\n\n      /** Ripartizione spese storiche con dettaglio; le stime non alterano il saldo. */\n      function sankeyCard(d) {\n        const compact =\n          typeof window !== \"undefined\" &&\n          window.matchMedia(\"(max-width:760px)\").matches;\n        const income = Math.max(0, d.lifetime.income),\n          out = Math.max(0, d.lifetime.spent),\n          total = out;\n        if (!total)\n          return (\n            '<div class=\"card pad\"><h2>Cash flow \u00b7 ' +\n            d.year +\n            '</h2><p class=\"empty\">Nessun movimento disponibile.</p></div>'\n          );\n        const spent = Object.fromEntries(\n          d.lifetime.expenseGroups.map((x) => [x.name, x.amount]),\n        );\n        const cats = Object.entries(spent)\n            .filter((r) => r[1] > 0)\n            .sort((a, b) => b[1] - a[1]),\n          dest = cats;\n\n        const src = [[\"Spese registrate\", out]];\n\n        const colors = [\n          \"#ff9f0a\",\n          \"var(--os-accent)\",\n          \"#0a84ff\",\n          \"#bf5af2\",\n          \"#ff453a\",\n          \"#ffd60a\",\n          \"#64d2ff\",\n          \"#ff6482\",\n        ];\n\n        const sx = compact ? 86 : 174,\n          cx = compact ? 170 : 388,\n          dx = compact ? 268 : 650,\n          labelX = compact ? 279 : 669,\n          W = compact ? 400 : 920;\n        const gap = compact ? 28 : 24,\n          top = compact ? 28 : 42,\n          body = compact ? 150 : 200,\n          height =\n            body +\n            gap * (Math.max(src.length, dest.length) - 1) +\n            (compact ? 64 : 84);\n        const ribbon = (x0, y0, x1, y1, h, color) =>\n          '<path class=\"sankey-ribbon\" fill=\"' +\n          color +\n          '\" d=\"M' +\n          x0 +\n          \" \" +\n          y0 +\n          \" C\" +\n          (x0 + (x1 - x0) * 0.48) +\n          \" \" +\n          y0 +\n          \" \" +\n          (x1 - (x1 - x0) * 0.48) +\n          \" \" +\n          y1 +\n          \" \" +\n          x1 +\n          \" \" +\n          y1 +\n          \" L\" +\n          x1 +\n          \" \" +\n          (y1 + h) +\n          \" C\" +\n          (x1 - (x1 - x0) * 0.48) +\n          \" \" +\n          (y1 + h) +\n          \" \" +\n          (x0 + (x1 - x0) * 0.48) +\n          \" \" +\n          (y0 + h) +\n          \" \" +\n          x0 +\n          \" \" +\n          (y0 + h) +\n          ' Z\"/>';\n        let paths = \"\",\n          nodes = \"\",\n          labels = \"\",\n          sy = top,\n          cy = top + (gap * (Math.max(src.length, dest.length) - 1)) / 2;\n        const centralTop = cy;\n        src.forEach(([name, amount], i) => {\n          const h = (amount / total) * body,\n            color = name === \"Altre risorse nette\" ? \"#9aa9bd\" : \"#aeaeb2\";\n          paths += ribbon(sx, sy, cx, cy, h, color);\n          nodes +=\n            '<rect x=\"' +\n            (sx - 6) +\n            '\" y=\"' +\n            sy +\n            '\" width=\"6\" height=\"' +\n            Math.max(0.8, h) +\n            '\" rx=\"2\" fill=\"' +\n            color +\n            '\"/>';\n          labels +=\n            '<text x=\"' +\n            (sx - 11) +\n            '\" y=\"' +\n            (sy + h / 2 - 3) +\n            '\" text-anchor=\"end\" class=\"sankey-label\">' +\n            escapeHtml(\n              (compact && name === \"Spese registrate\"\n                ? \"Spese\"\n                : compact && name === \"Altre risorse nette\" ? \"Saldo precedente\" : name\n              ).slice(0, compact ? 14 : 25),\n            ) +\n            '</text><text x=\"' +\n            (sx - 11) +\n            '\" y=\"' +\n            (sy + h / 2 + 13) +\n            '\" text-anchor=\"end\" class=\"sankey-value\">' +\n            euro(amount) +\n            \"</text>\";\n          sy += h + gap;\n          cy += h;\n        });\n        let dy = top;\n        cy = centralTop;\n        dest.forEach(([name, amount], i) => {\n          const h = (amount / total) * body,\n            color =\n              name === \"Da riconciliare\"\n                ? \"#9aa9bd\"\n                : colors[i % colors.length];\n          paths += ribbon(cx + 8, cy, dx, dy, h, color);\n          nodes +=\n            '<rect x=\"' +\n            dx +\n            '\" y=\"' +\n            dy +\n            '\" width=\"6\" height=\"' +\n            Math.max(0.8, h) +\n            '\" rx=\"2\" fill=\"' +\n            color +\n            '\"/>';\n          labels +=\n            '<text x=\"' +\n            labelX +\n            '\" y=\"' +\n            (dy + h / 2 - 3) +\n            '\" class=\"sankey-label\">' +\n            escapeHtml(name.slice(0, compact ? 22 : 40)) +\n            '</text><text x=\"' +\n            labelX +\n            '\" y=\"' +\n            (dy + h / 2 + 13) +\n            '\" class=\"sankey-value\">' +\n            euro(amount) +\n            \" \u00b7 \" +\n            (d.lifetime.expenseGroups.find((g) => g.name === name)\n              ?.percentage || 0) +\n            \"%</text>\";\n          dy += h + gap;\n          cy += h;\n        });\n        return (\n          '<div class=\"card pad sankey-card\"><div class=\"card-title\"><div><div class=\"section-kicker\">STORICO \u00b7 ' +\n          shortMonth(d.lifetime.from) +\n          \" - \" +\n          shortMonth(d.lifetime.to) +\n          '</div><h2>Destinazione delle spese</h2></div><div class=\"sankey-totals\"><span>Entrate<b>' +\n          euro(income) +\n          \"</b></span><span>Spese<b>\" +\n          euro(out) +\n          '</b></span></div></div><div class=\"chart-scroll sankey-scroll\"><svg class=\"sankey-svg' +\n          (compact ? \" is-compact\" : \"\") +\n          '\" viewBox=\"0 0 ' +\n          W +\n          \" \" +\n          height +\n          '\" role=\"img\" aria-label=\"Ripartizione delle spese registrate; percentuali sul totale delle spese\">' +\n          paths +\n          nodes +\n          '<rect x=\"' +\n          cx +\n          '\" y=\"' +\n          centralTop +\n          '\" width=\"8\" height=\"' +\n          body +\n          '\" rx=\"3\" fill=\"#8e8e93\"/>' +\n          labels +\n          '</svg></div><div class=\"sankey-savings\">Patrimonio <strong>' +\n          privateAmount(d.summary.totalAssets) +\n          \"</strong>\" +\n          privacyButton() +\n          \"</div>\" +\n          '<details class=\"expense-details\"><summary>Dettaglio categorie</summary>' +\n          d.lifetime.expenseGroups\n            .map(\n              (c) =>\n                '<details class=\"expense-category\"><summary><span>' +\n                escapeHtml(c.name) +\n                \"</span><b>\" +\n                euro(c.amount) +\n                \"</b></summary>\" +\n                d.lifetime.expenseAudit\n                  .filter((r) => c.members.includes(r.category))\n                  .sort((a, b) => b.amount - a.amount)\n                  .map(\n                    (r) =>\n                      '<div class=\"overview-recent-row\"><time>' +\n                      escapeHtml(r.date) +\n                      \"</time><div><strong>\" +\n                      escapeHtml(r.name) +\n                      \"</strong><small>\" +\n                      escapeHtml(r.account) +\n                      \" \u00b7 \" +\n                      (r.estimated ? \"Stima\" : escapeHtml(r.category)) +\n                      \"</small>\" +\n                      (r.category === \"Da classificare\"\n                        ? quickClassify(r)\n                        : \"\") +\n                      \"</div><b>\" +\n                      euro(r.amount) +\n                      \"</b></div>\",\n                  )\n                  .join(\"\") +\n                \"</details>\",\n            )\n            .join(\"\") +\n          '</details><p class=\"hint\">Spese storiche stimate: ' +\n          euro(d.lifetime.historicalSpendingEstimate?.amount || 0) +\n          \" \u00b7 escluse dai saldi e dai totali mensili.</p></div>\"\n        );\n      }\n      document.addEventListener(\"change\", (e) => {\n        if(e.target.name === \"category\" && e.target.closest(\"#entry-form\")){syncUtilityFields();syncCommitmentHint();}\n        const wrap = e.target.closest(\".quick-classify\");\n        if (wrap && e.target.tagName === \"SELECT\")\n          wrap.querySelector(\"button\").disabled = !e.target.value;\n      });\n\n      // Compact manual catalog. Legacy values remain intact until explicitly reclassified.\n      const financeManualCategories = [\"Alimentari\", \"Ristorazione\", \"Casa\", \"Utenze\", \"Abbonamenti\", \"Auto\", \"Benzina\", \"Shopping\", \"Salute\", \"Svago\", \"Viaggi\", \"Altro\"];\n      const financeIncomeCategories = [\"Stipendio\", \"Interessi\", \"Rimborsi\", \"Altro\"];\n      function financialCommittedCategories() {\n        const recurring=state.data?.recurring || life.finance?.recurring || [];\n        return [...new Set([\"Affitto\", ...recurring.filter(r=>r.treatment===\"Vincolata\" && r.name!==\"Benzina\").map(r=>r.name).filter(Boolean)])];\n      }\n      function financeCategoryLabel(value) {\n        if(financialCommittedCategories().includes(value) || Object.values(financeDetailGroups).flat().includes(value))return value;\n        const key = String(value || \"\").normalize(\"NFD\").replace(/[\\u0300-\\u036f]/g, \"\").trim().toLowerCase();\n        const aliases = {\"affitto\": \"Casa\", \"affitto e ingresso casa\": \"Casa\", \"arredamento e casa\": \"Casa\", \"casa\": \"Casa\", \"acqua\": \"Utenze\", \"elettricita\": \"Utenze\", \"gas\": \"Utenze\", \"trasporti\": \"Auto\", \"pedaggi\": \"Auto\", \"elettronica\": \"Shopping\", \"palestra\": \"Salute\", \"sport\": \"Salute\", \"cura personale\": \"Salute\", \"famiglia\": \"Altro\", \"trasferimenti a terzi\": \"Altro\", \"imposte\": \"Altro\", \"imposte e servizi\": \"Altro\", \"commissioni\": \"Altro\", \"imposte e commissioni\": \"Altro\", \"da classificare\": \"Altro\", \"pagamenti non dettagliati\": \"Altro\", \"contanti\": \"Altro\", \"altre spese\": \"Altro\", \"altri movimenti\": \"Altro\"};\n        return aliases[key] || [...financeManualCategories, ...financeIncomeCategories].find(x => x.normalize(\"NFD\").replace(/[\\u0300-\\u036f]/g, \"\").toLowerCase() === key) || value;\n      }\n      const financeDetailGroups = {Casa:[\"Affitto\",\"Condominio\",\"Arredamento e casa\"],Utenze:[\"Elettricit\u00e0\",\"Gas\",\"Acqua\"],Auto:[\"Assicurazione\",\"Bollo\",\"Manutenzione auto\"],Salute:[\"Palestra\",\"Dentista\",\"Farmaci e visite\"]};\n      function categoryOptionsHtml(values,value=\"\"){\n        const current=financeCategoryLabel(value), option=x=>`<option value=\"${escapeHtml(x===current && value?value:x)}\" ${x===current?\"selected\":\"\"}>${escapeHtml(financeCategoryLabel(x))}</option>`;\n        const details=new Set(Object.values(financeDetailGroups).flat());\n        return values.filter(x=>!details.has(x)).map(option).join(\"\")+Object.entries(financeDetailGroups).map(([group,names])=>{const active=names.filter(x=>values.includes(x));return active.length?`<optgroup label=\"${escapeHtml(group)}\">${active.map(option).join(\"\")}</optgroup>`:\"\";}).join(\"\");\n      }\n      function financialCategoryOptions(type = \"Spesa\") {\n        return type === \"Entrata\" ? [...financeIncomeCategories] : [...new Set([...financeManualCategories,...financialCommittedCategories(),...Object.values(financeDetailGroups).flat()])];\n      }\n      document.addEventListener(\"change\", (e) => {\n        if (e.target.name !== \"type\" || !e.target.closest(\"#entry-form\")) return;\n        const form = e.target.form, category = form.elements.category;\n        if (!category) return;\n        const choices = financialCategoryOptions(e.target.value), label = financeCategoryLabel(category.value);\n        category.innerHTML = categoryOptionsHtml(choices);\n        category.value = choices.includes(label) ? label : \"Altro\";\n        syncUtilityFields();syncCommitmentHint();\n      });\n\n      /** Controllo per classificare un movimento storico, senza modificarne importo o conto. */\n      function quickClassify(r) {\n        return (\n          '<div class=\"quick-classify\" data-classify-row=\"' +\n          r.row +\n          '\"><select aria-label=\"Categoria di ' +\n          escapeHtml(r.name) +\n          '\"><option value=\"\" disabled selected>Scegli categoria</option>' +\n          financialCategoryOptions()\n            .map((x) => \"<option>\" + escapeHtml(x) + \"</option>\")\n            .join(\"\") +\n          '</select><button class=\"ghost\" type=\"button\" data-apply-category=\"' +\n          r.row +\n          '\" disabled>Applica</button></div>'\n        );\n      }\n\n      /** Obiettivi e proiezione risparmi; distinti dal budget operativo. */\n      function planningCard(d) {\n        const p = d.planning;\n        return (\n          '<div class=\"card pad planning-card\"><div class=\"card-title\"><h2>Fondo e fine anno</h2><small>' +\n          p.year +\n          \"</small></div>\" +\n          '<div class=\"planning-inputs\"><label>Fondo Emergenza \u20ac<input id=\"goal-input\" type=\"number\" min=\"0\" max=\"1000000\" step=\"0.01\" inputmode=\"decimal\" placeholder=\"Imposta la soglia\" value=\"' +\n          (state.planningDraft?.goal ?? (p.goal === null ? \"\" : p.goal)) +\n          '\"></label>' +\n          '<label>Risparmio mensile \u20ac<input id=\"saving-input\" type=\"number\" min=\"0\" max=\"100000\" step=\"0.01\" required inputmode=\"decimal\" value=\"' +\n          (state.planningDraft?.saving ?? p.monthlySaving) +\n          '\"></label><label>Obiettivo patrimonio \u20ac<input id=\"target-input\" type=\"number\" min=\"0.01\" max=\"1000000\" step=\"0.01\" inputmode=\"decimal\" value=\"' +\n          (state.planningDraft?.target ?? p.savingsTarget ?? '') + '\"></label></div>' +\n          '<div class=\"plan-row\"><span>Saldo</span><strong>' +\n          privateAmount(p.now) +\n          \"</strong></div>\" +\n          '<div class=\"plan-row\"><span>Oltre il fondo, oggi</span><strong id=\"surplus-now\">\u2014</strong></div>' +\n          '<div class=\"fund-meter\" role=\"progressbar\" aria-label=\"Copertura fondo\" aria-valuemin=\"0\" aria-valuemax=\"100\"><i id=\"fund-covered\"></i><i id=\"fund-surplus\"></i></div><div class=\"fund-labels\"><span id=\"fund-label\">Fondo da impostare</span><span id=\"surplus-label\"></span></div>' +\n          '<div class=\"projection-result\"><span>Al 31 dicembre \u00b7 ' +\n          p.monthsRemaining +\n          ' mesi</span><strong id=\"projected-total\">' +\n          privateAmount(p.projection) +\n          '</strong><small id=\"projected-surplus\">\u2014</small></div>' +\n          '<div class=\"planning-actions\"><button type=\"button\" class=\"save plan-save\" id=\"save-plan\">Salva</button><span id=\"planning-status\" role=\"status\" aria-live=\"polite\"></span></div><p class=\"hint\">Simulazione: saldo + risparmio mensile \u00d7 ' +\n          p.monthsRemaining +\n          \" mesi.</p></div>\"\n        );\n      }\n\n      /** Aggiorna i soli campi della proiezione, senza ricreare il form. */\n      function renderProjection(p) {\n        const set = (id, v) => {\n          const el = document.getElementById(id);\n          if (el) el.textContent = v;\n        };\n        if (!state.assetsVisible) {\n          set(\"surplus-now\", \"\u2022\u2022\u2022\u2022 \u20ac\");\n          set(\"projected-total\", \"\u2022\u2022\u2022\u2022 \u20ac\");\n          set(\"projected-surplus\", \"Patrimonio nascosto\");\n          set(\"fund-label\", \"Patrimonio nascosto\");\n          set(\"surplus-label\", \"\");\n          document\n            .querySelector(\".fund-meter\")\n            .removeAttribute(\"aria-valuenow\");\n          document.getElementById(\"fund-covered\").style.width = \"0%\";\n          document.getElementById(\"fund-surplus\").style.width = \"0%\";\n          return;\n        }\n        set(\"surplus-now\", p.surplusNow === null ? \"\u2014\" : euro(p.surplusNow));\n        set(\"projected-total\", euro(p.projection));\n        set(\n          \"projected-surplus\",\n          p.projectedSurplus === null\n            ? \"Imposta il fondo\"\n            : euro(p.projectedSurplus) + \" oltre il fondo\",\n        );\n        set(\n          \"fund-label\",\n          p.goal === null\n            ? \"Fondo da impostare\"\n            : p.missing > 0\n              ? \"Coperto \" + euro(p.now) + \" su \" + euro(p.goal)\n              : \"Fondo \" + euro(p.goal),\n        );\n        set(\n          \"surplus-label\",\n          p.goal === null\n            ? \"\"\n            : p.missing > 0\n              ? \"Mancano \" + euro(p.missing)\n              : \"Avanzano \" + euro(p.surplusNow),\n        );\n        document\n          .querySelector(\".fund-meter\")\n          .setAttribute(\"aria-valuenow\", Math.min(100, Math.round(p.covered)));\n        document.getElementById(\"fund-covered\").style.width = p.covered + \"%\";\n        document.getElementById(\"fund-surplus\").style.width = p.surplus + \"%\";\n      }\n\n      /** Local preview uses the reconciled TR balance already loaded in Finance.\n       * Input does not trigger database reads. Draft survives chart/theme redraws. */\n      function projectPlanning(p, goal, saving) {\n        const total =\n          Math.round((p.now + saving * p.monthsRemaining) * 100) / 100;\n        const base = Math.max(1, goal || 0, p.now);\n        return {\n          ...p,\n          goal,\n          monthlySaving: saving,\n          projection: total,\n          surplusNow:\n            goal === null\n              ? null\n              : Math.max(0, Math.round((p.now - goal) * 100) / 100),\n          projectedSurplus:\n            goal === null\n              ? null\n              : Math.max(0, Math.round((total - goal) * 100) / 100),\n          missing:\n            goal === null\n              ? null\n              : Math.max(0, Math.round((goal - p.now) * 100) / 100),\n          covered:\n            goal === null\n              ? 0\n              : (Math.max(0, Math.min(goal, p.now)) / base) * 100,\n          surplus: goal === null ? 0 : (Math.max(0, p.now - goal) / base) * 100,\n        };\n      }\n      function updateProjection() {\n        const p = state.data?.planning,\n          goal = document.getElementById(\"goal-input\"),\n          saving = document.getElementById(\"saving-input\");\n        if (!p || !goal || !saving) return;\n        state.planningDraft = { goal: goal.value, saving: saving.value, target: document.getElementById(\"target-input\")?.value ?? \"\" };\n        const valid = goal.validity.valid && saving.validity.valid;\n        document.getElementById(\"save-plan\").disabled = !valid || state.busy;\n        const status = document.getElementById(\"planning-status\");\n        status.textContent = valid ? \"\" : \"Importo non valido.\";\n        if (!valid) {\n          document.getElementById(\"projected-total\").textContent = \"\u2014\";\n          return;\n        }\n        renderProjection(\n          projectPlanning(\n            p,\n            goal.value === \"\" ? null : Number(goal.value),\n            Number(saving.value),\n          ),\n        );\n      }\n\n      /** Anello SVG proporzionale agli importi, indipendente dai CSS del vecchio donut. */\n      function categoryCard(d) {\n        const key = d.year + '-' + String(state.categoryMonth).padStart(2, '0');\n        const data = d.monthlyBreakdowns?.[key] || {};\n        const top = (Array.isArray(data.items) ? data.items : []).map(x => ({...x, amount:Number(x.amount)})).filter(x => Number.isFinite(x.amount) && x.amount > 0);\n        const total = top.reduce((sum,x) => sum + x.amount,0);\n        const colors = ['var(--os-accent)','#6e9cc1','#c79a58','#a788b8','#b9777b','#8b929b'];\n        let offset = 0;\n        const segments = top.map((x,i) => {\n          const share = x.amount / total * 100;\n          const segment = `<circle cx=\"60\" cy=\"60\" r=\"48\" pathLength=\"100\" fill=\"none\" stroke=\"${colors[i % colors.length]}\" stroke-width=\"12\" stroke-dasharray=\"${share} ${100-share}\" stroke-dashoffset=\"${-offset}\" transform=\"rotate(-90 60 60)\"><title>${escapeHtml(x.name)}: ${euro(x.amount)}</title></circle>`;\n          offset += share;\n          return segment;\n        }).join('');\n        const max = Math.max(0,...top.map(x => x.amount));\n        return `<div class=\"card pad tr-category-card\"><div class=\"card-title\"><h2>Uscite</h2><div class=\"actions\"><button class=\"small-arrow\" data-cat=\"-1\" aria-label=\"Mese precedente\">\u2039</button><span class=\"category-month\">${shortMonth(key)}</span><button class=\"small-arrow\" data-cat=\"1\" aria-label=\"Mese successivo\">\u203a</button></div></div>${total > 0 ? `<div class=\"breakdown\"><div class=\"category-ring\"><svg viewBox=\"0 0 120 120\" role=\"img\" aria-label=\"Uscite: ${euro(total)}\"><circle cx=\"60\" cy=\"60\" r=\"48\" fill=\"none\" stroke=\"var(--line)\" stroke-width=\"12\"/>${segments}</svg><div class=\"category-ring-label\"><small>Uscite</small><strong>${euro(total)}</strong></div></div><div class=\"category-legend\">${top.map((x,i) => `<div class=\"bar-row\"><span><i class=\"category-swatch\" style=\"background:${colors[i % colors.length]}\"></i>${escapeHtml(x.name)}</span><b>${euro(x.amount)}</b><div class=\"bar\"><i style=\"width:${x.amount/max*100}%;background:${colors[i % colors.length]}\"></i></div></div>`).join('')}</div></div>` : '<div class=\"empty\">Nessuna uscita registrata.</div>'}<div class=\"details-label\">Gi\u00e0 impegnato \u00b7 ${euro(Number(data.commitmentTotal)||0)}</div>${(Array.isArray(data.commitments)?data.commitments:[]).map(x => kv(x.name,x.amount)).join('')}</div>`;\n      }\n      const extraPriority = {\n        Programmato: 0,\n        Anticipato: 1,\n        Previsto: 2,\n        Annullato: 3,\n        Pagato: 4,\n      };\n\n      /** Ordine stabile delle straordinarie per stato e periodo. */\n      function orderedExtras(extras) {\n        return [...extras].sort(\n          (a, b) =>\n            (extraPriority[a.status] ?? 3) - (extraPriority[b.status] ?? 3) ||\n            a.row - b.row,\n        );\n      }\n\n      /** Mappa lo stato dominio in classe CSS controllata. */\n      function statusClass(status) {\n        return (\n          {\n            Programmato: \"scheduled\",\n            Previsto: \"planned\",\n            Anticipato: \"advance\",\n            Annullato: \"cancelled\",\n            Pagato: \"paid\",\n          }[status] || \"planned\"\n        );\n      }\n\n      /** Etichetta stato con testo escapato; non \u00e8 un comando di pagamento. */\n      function statusTag(status) {\n        return (\n          '<span class=\"state-tag state-' +\n          statusClass(status) +\n          '\">' +\n          escapeHtml(status) +\n          \"</span>\"\n        );\n      }\n\n\n\n      function monthlyBudgetDetails(s) {\n        const items = Array.isArray(s.monthlyBudgetBreakdown) ? s.monthlyBudgetBreakdown : [];\n        const line = (label,value) => `<div class=\"kv\"><span>${escapeHtml(label)}</span><strong>${exactEuro(value)}</strong></div>`;\n        return `<details class=\"budget-calculation\"><summary>Calcolo budget del mese</summary>\n          ${line(\"Media stipendio\",s.monthlySalary)}\n          ${items.map(x=>line(x.name,-x.amount)).join(\"\")}\n          ${line(\"Spese non gi\u00e0 coperte\",-s.monthlySpent)}\n          ${(s.monthlyFixedSettlements||[]).filter(r=>r.paid!==r.estimate).map(r=>`<div class=\"details-label\">${escapeHtml(r.name)}: previsti ${exactEuro(r.estimate)}, pagati ${exactEuro(r.paid)}. La differenza incide sul saldo, senza un secondo addebito al budget libero.</div>`).join(\"\")}\n          <div class=\"kv total\"><span>Budget del mese</span><strong>${exactEuro(s.monthlyRemaining)}</strong></div>\n          ${s.monthlyAdvanceReturned ? `<div class=\"details-label\">Anticipo: ${exactEuro(s.monthlyAdvanceGross)} \u2212 ${exactEuro(s.monthlyAdvanceReturned)} restituiti = ${exactEuro(s.monthlyAdvances)}.<br>Spese gi\u00e0 coperte: ${exactEuro(s.monthlyAdvanceCovered)}. Incluse nelle uscite, non sottratte di nuovo dal budget.</div>` : \"\"}\n        </details>`;\n      }\n\n      /** Panoramica essenziale: saldo Trade Republic, impegnato, spendibile, patrimonio e flussi TR. */\n      function overview(d) {\n        const s = d.summary, daily = dailyBudgetRange(s);\n        const recent = (d.transactions || []).slice(0, 3);\n        return `<div class=\"finance-open\"><div class=\"finance-heading\"><span></span><button data-view=\"analysis\">Analisi</button></div>\n        <section class=\"finance-hero\"><h2>Budget rimanente</h2><strong class=\"finance-value ${amountClass(s.monthlyRemaining)}\">${state.assetsVisible ? exactEuro(s.monthlyRemaining) : \"\u2022\u2022\u2022\u2022 \u20ac\"}</strong><p class=\"muted\">Al giorno \u00b7 ${state.assetsVisible ? exactEuro(daily.low) + \" \u2013 \" + exactEuro(daily.high) : \"\u2022\u2022\u2022\u2022 \u20ac\"}</p><small>${daily.days} giorni, oggi incluso</small></section>\n        <section class=\"finance-account\"><div><h2>Saldo attuale</h2><strong>${state.assetsVisible ? exactEuro(s.budget) : \"\u2022\u2022\u2022\u2022 \u20ac\"}</strong></div>${privacyButton()}<small>Saldo dell\u2019ultima sincronizzazione, distinto dal mese selezionato.</small></section>\n        <div class=\"finance-actions\"><button data-view=\"budget\"><span aria-hidden=\"true\">\u25f7</span>Budget</button><button data-view=\"extras\"><span aria-hidden=\"true\">\u22ef</span>Extra</button><button data-new-transaction=\"Spesa\"><span aria-hidden=\"true\">\uff0b</span>Spesa</button></div>\n        <section class=\"finance-recent\"><div class=\"finance-heading\"><h2>Ultimi movimenti</h2><button data-view=\"movements\">Vedi tutti</button></div>${recent.length ? recent.map(t => `<button class=\"finance-movement\" data-edit-movement=\"${Number(t.row)}\"><span><strong>${escapeHtml(t.name)}</strong><small>${escapeHtml(t.date || '')} \u00b7 ${escapeHtml(t.category || t.type || '')}</small></span><b class=\"${amountClass(t.amount)}\">${state.assetsVisible ? exactEuro(t.amount) : '\u2022\u2022\u2022\u2022 \u20ac'}</b></button>`).join('') : '<p class=\"empty\">Nessun movimento nel mese.</p>'}</section></div>`;\n      }\n\n      /** Riga chiave/importo; la linea di confine appartiene a una sola riga. */\n      function kv(label, value, extra = \"\") {\n        return `<div class=\"kv ${extra}\"><span>${escapeHtml(label)}</span><strong class=\"${amountClass(value)}\">${euro(value)}</strong></div>`;\n      }\n\n      /** Ricerca sull\u2019intero mese; render progressivo a gruppi e ripristino del cursore. */\n      function renderMovements() {\n        const d = state.data;\n        if (!d) return;\n        const q = state.search.toLocaleLowerCase(\"it-IT\");\n        const items = d.transactions.filter(\n          (t) =>\n            (state.type === \"Tutti\" || t.type === state.type) &&\n            (!q ||\n              (t.name + \" \" + t.category + \" \" + t.account)\n                .toLocaleLowerCase(\"it-IT\")\n                .includes(q)),\n        );\n        const target = document.getElementById(\"movements\");\n        const focus = document.activeElement?.id === \"transaction-search\";\n        const caret = focus ? document.activeElement.selectionStart : 0;\n        target.innerHTML = `<div class=\"card pad\"><div class=\"card-title\"><h2>${d.transactions.length} movimenti nel mese</h2></div><div class=\"filters\"><input class=\"search\" id=\"transaction-search\" placeholder=\"Cerca movimento\" value=\"${escapeHtml(state.search)}\" aria-label=\"Cerca movimento\"><select id=\"type-filter\" aria-label=\"Tipo movimento\">${[\"Tutti\", \"Spesa\", \"Entrata\", \"Trasferimento\", \"Investimento\", \"Da verificare\"].map((t) => `<option ${state.type === t ? \"selected\" : \"\"}>${t}</option>`).join(\"\")}</select></div><div class=\"table-scroll mobile-ledger\"><table class=\"tabular\"><thead><tr><th>Data</th><th>Movimento</th><th>Categoria</th><th>Conto</th><th>Importo</th></tr></thead><tbody>${items\n          .slice(0, state.movementLimit)\n          .map(\n            (t) =>\n              `<tr><td>${t.date ? new Date(t.date + \"T12:00\").toLocaleDateString(\"it-IT\", { day: \"2-digit\", month: \"short\" }) : \"\u2014\"}</td><td class=\"description\"><div class=\"tx-description-row\"><div class=\"tx-description-text\">${escapeHtml(t.name)}<small>${escapeHtml(t.type)}</small></div><div class=\"tx-actions\"><button type=\"button\" class=\"ghost\" data-edit-movement=\"${t.row}\" aria-label=\"Modifica movimento\">Modifica</button><button type=\"button\" class=\"ghost\" data-delete-movement=\"${t.row}\" aria-label=\"Elimina movimento\">Elimina</button></div></div></td><td data-label=\"Categoria\">${escapeHtml(t.category)}</td><td data-label=\"Conto\">${escapeHtml(t.account === \"Trade Republic\" ? \"Conto attuale\" : t.account)}</td><td class=\"num ${amountClass(t.amount)}\">${exactEuro(t.amount)}</td></tr>`,\n          )\n          .join(\"\")}</tbody></table><div class=\"movement-list\">${items\n          .slice(0, state.movementLimit)\n          .map(\n            (t) =>\n              `<div class=\"movement-compact\"><time>${t.date ? new Date(t.date + \"T12:00\").toLocaleDateString(\"it-IT\", { day: \"2-digit\", month: \"short\" }) : \"\u2014\"}</time><div class=\"movement-main\"><strong>${escapeHtml(t.name)}</strong><small>${escapeHtml(t.displayCategory || t.category || t.type)} \u00b7 ${escapeHtml(t.account === \"Trade Republic\" ? \"Conto attuale\" : t.account)}</small></div><b class=\"${amountClass(t.amount)}\">${exactEuro(t.amount)}</b><div class=\"movement-tools\"><button type=\"button\" data-edit-movement=\"${t.row}\" aria-label=\"Modifica ${escapeHtml(t.name)}\" title=\"Modifica\"><svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" aria-hidden=\"true\"><path d=\"m4 16 12-12 4 4-12 12-5 1zM14 6l4 4\"/></svg></button><button type=\"button\" data-delete-movement=\"${t.row}\" aria-label=\"Elimina ${escapeHtml(t.name)}\" title=\"Elimina\"><svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" aria-hidden=\"true\"><path d=\"M4 7h16M10 4h4M6 7l1 13h10l1-13M10 11v5M14 11v5\"/></svg></button></div></div>`,\n          )\n          .join(\n            \"\",\n          )}</div>${items.length ? \"\" : '<div class=\"empty\">Nessun movimento.</div>'}${items.length > state.movementLimit ? '<button type=\"button\" class=\"ghost movement-more\" data-movements-more>Mostra altri (' + (items.length - state.movementLimit) + \")</button>\" : \"\"}</div><p class=\"hint\">Trasferimenti interni esclusi dalle entrate e dalle uscite.</p></div>`;\n        if (focus) {\n          const box = document.getElementById(\"transaction-search\");\n          box.focus();\n          box.setSelectionRange(caret, caret);\n        }\n      }\n\n      /** Vista dettagliata con impegni, stime, saldi, storico e grafici differiti. */\n      function overviewAnalysis(d) {\n        const s = d.summary;\n        return `<div class=\"overview-analysis-grid\">\n          ${planningCard(d)}\n          <section class=\"card pad recurring-settings\"><div class=\"card-title\"><h2>Utenze e ricorrenti</h2></div>${d.recurring\n              .map((r) => {\n                const a = d.averages.find((x) => x.name === r.name),\n                  commitment = s.recurringCommitments.find(\n                    (x) => x.name === r.name,\n                  );\n                const note =\n                  r.name === \"Benzina\"\n                    ? \"Non impegnata\"\n                    : \"Residuo \" + exactEuro(commitment?.remaining || 0);\n                return `<div class=\"edit-line\"><div><b>${escapeHtml(r.name)}</b><small>${note}${r.estimateSource ? \" \u00b7 \" + escapeHtml(r.estimateSource) + \" \u00b7 Prossimo mese \" + exactEuro(r.nextEstimate) : \"\"}${a?.count ? \" \u00b7 Media \" + exactEuro(a.mean) : \"\"}</small></div><div class=\"edit-controls\"><input class=\"edit-input\" aria-label=\"Stima ${escapeHtml(r.name)}\" type=\"number\" min=\"0\" max=\"1000\" step=\"0.01\" inputmode=\"decimal\" value=\"${r.estimate}\" data-estimate=\"${escapeHtml(r.name)}\"><button class=\"save\" data-save-estimate=\"${escapeHtml(r.name)}\">Salva</button></div></div>`;\n              })\n              .join(\"\")}</section>\n        </div>`;\n      }\n\n      /** Range giornaliero esatto, senza arrotondare prima della divisione.\n       * Limite inferiore = budget mensile residuo / giorni; superiore = (media stipendio - spesi) / giorni.\n       * Include oggi: l\u2019ultimo giorno il divisore \u00e8 1, mai zero. Il mese \u00e8 quello attuale a Roma.\n       */\n      function dailyBudgetRange(summary, day = todayIso()) {\n        const [year, month, date] = day.split(\"-\").map(Number);\n        const days = Math.max(\n          1,\n          new Date(Date.UTC(year, month, 0)).getUTCDate() - date + 1,\n        );\n        return {\n          days,\n          low: summary.monthlyRemaining / days,\n          high: (summary.monthlySalary - summary.monthlySpent) / days,\n        };\n      }\n\n      /** Storico dettagliato in fondo a Budget, dopo grafici e impostazioni. */\n      function billsHistory(d) {\n        return `<section class=\"card pad budget-history\"><details data-budget-panel=\"budgetHistoryOpen\" ${state.budgetHistoryOpen ? \"open\" : \"\"}><summary>Storico pagamenti \u00b7 ${d.history.length}</summary><div class=\"budget-detail-content\"><div class=\"card-title\"><button class=\"save\" data-new-recurring=\"1\">+ Pagamento</button></div>${d.history.length ? '<div class=\"table-scroll\"><table class=\"tabular\"><thead><tr><th>Data</th><th>Voce</th><th>Pagato</th><th>Mesi</th><th>Nota</th></tr></thead><tbody>' + d.history.map((h) => \"<tr><td>\" + escapeHtml(h.date) + \"</td><td>\" + escapeHtml(h.name) + \"</td><td>\" + exactEuro(h.paid) + \"</td><td>\" + h.months + \"</td><td>\" + escapeHtml(String(h.note||\"\").replace(/ ?\\[Categoria manuale\\]/g,\"\")) + \"</td></tr>\").join(\"\") + \"</tbody></table></div>\" : '<p class=\"empty\">Nessun pagamento.</p>'}</div></details></section>`;\n      }\n\n      /** Carte straordinarie: stato, Segna pagato, Modifica e Annulla/Elimina. */\n      function extrasView(d) {\n        const cycles = new Map();\n        for (const a of d.extraPlan?.allocations || [])\n          if (a.month === d.key || !cycles.has(a.extraordinary_source_row))\n            cycles.set(a.extraordinary_source_row, a);\n        const sorted = orderedExtras(\n          d.extras.map((e) => ({\n            ...e,\n            status: cycles.get(e.row)?.status || e.status,\n          })),\n        );\n        return (\n          '<div class=\"extra-grid\">' +\n          (d.extraPlan?.budgetPolicies || []).filter(p=>p.treatment===\"recovery\").map(p=>`<article class=\"extra-card\"><div class=\"extra-card-head\"><h3>${escapeHtml(p.description)}</h3><strong>${exactEuro(JSON.parse(p.recovery_json).reduce((n,q)=>n+q.amount_cents,0)/100)}</strong></div><p class=\"hint\">Recupero dai risparmi \u00b7 nessuna nuova uscita</p><div class=\"extra-metadata\"><span>${JSON.parse(p.recovery_json).map(q=>`${shortMonth(q.month)}: ${exactEuro(q.amount_cents/100)}`).join(\" \u00b7 \")}</span></div><button class=\"ghost\" data-edit-movement=\"${p.movement_source_row}\">Modifica recupero</button></article>`).join(\"\") +\n          sorted\n            .map((e) => {\n              const c = cycles.get(e.row),\n                total = c ? c.total_cents / 100 : e.total;\n              const links = (d.extraPlan?.links || []).filter(\n                  (l) => l.cycle_id === c?.cycle_id,\n                ),\n                canDelete = e.status === \"Annullato\" && !links.length;\n              const settlement=(d.extraPlan?.settlements||[]).find(s=>s.cycle_id===c?.cycle_id), paidCents=links.reduce((n,l)=>n+l.attributed_cents,0)+Math.max(0,(settlement?.actual_cents||0)-(settlement?.planned_cents||0));\n              return (\n                '<article class=\"extra-card\"><div class=\"extra-card-head\"><h3>' +\n                escapeHtml(e.name) +\n                \"</h3><strong>\" +\n                exactEuro(total) +\n                '</strong></div><div class=\"extra-metadata\"><span>' +\n                shortMonth(c?.start_month || e.start) +\n                \" - \" +\n                shortMonth(c?.end_month || e.end) +\n                (e.repeat === \"Annuale\" ? \" \u00b7 Annuale\" : \"\") +\n                \"</span><span>\" +\n                escapeHtml(e.account===\"Trade Republic\"?\"Conto attuale\":e.account) +\n                '</span></div>' + (links.length?`<p class=\"hint extra-info\">Previsto ${exactEuro(total)} \u00b7 Pagato ${exactEuro(paidCents/100)}. Differenze sui risparmi.</p>`:\"\") + '<div class=\"extra-card-controls\">' +\n                (c?.kind === \"budget_advance\"\n                  ? statusTag(e.status)\n                  : '<div class=\"extra-state-row\">' +\n                    statusTag(e.status) +\n                    (!c || [\"Pagato\", \"Annullato\"].includes(e.status)\n                      ? \"\"\n                      : '<button type=\"button\" class=\"extra-pay-action\" data-extra-mark-paid=\"' +\n                        c.cycle_id +\n                        '\" aria-label=\"Segna ' +\n                        escapeHtml(e.name) +\n                        ' come pagato\">Segna pagato<span aria-hidden=\"true\"> \u2192</span></button>') +\n                    \"</div>\") +\n                (c && ![\"Pagato\",\"Annullato\"].includes(e.status) ? `<button class=\"ghost\" data-extra-link=\"${e.row}\">Collega movimento</button>` : \"\") +\n                '<button class=\"ghost\" data-extra-edit=\"' +\n                e.row +\n                '\">Modifica</button><button class=\"ghost\" data-extra-cancel=\"' +\n                (c?.cycle_id || \"\") +\n                '\" data-delete=\"' +\n                canDelete +\n                '\" ' +\n                (!c ? \"disabled\" : \"\") +\n                \">\" +\n                (canDelete ? \"Elimina\" : \"Annulla\") +\n                \"</button></div></article>\"\n              );\n            })\n            .join(\"\") +\n          \"</div>\"\n        );\n      }\n\n      /** Apre il foglio finanza; la gestione focus \u00e8 centralizzata. */\n      function financeRequestId(){return Array.from(crypto.getRandomValues(new Uint32Array(4)),x=>x.toString(16).padStart(8,\"0\")).join(\"-\");}\n      function modal(title, fields, kind) {\n        const box = document.getElementById(\"dialog\");\n        box.innerHTML =\n          '<div class=\"modal\" role=\"dialog\" aria-modal=\"true\" aria-label=\"' +\n          escapeHtml(title) +\n          '\"><div class=\"modal-top\"><h2>' +\n          title +\n          '</h2><button class=\"ghost\" data-close=\"1\" aria-label=\"Chiudi\">\u00d7</button></div><form id=\"entry-form\" data-kind=\"' +\n          kind +\n          '\"><div class=\"form-grid\">' +\n          fields + `<input type=\"hidden\" name=\"requestId\" value=\"${financeRequestId()}\">` +\n          '</div><p id=\"finance-form-error\" class=\"os-form-error hidden\" role=\"alert\"></p><div class=\"form-actions\"><button type=\"button\" class=\"ghost\" data-close=\"1\">Annulla</button><button type=\"submit\" class=\"save\">Salva</button></div></form></div>';\n        box.classList.remove(\"hidden\");\n        // iOS zooms and shifts a bottom sheet when an input is focused while opening.\n        if (\n          !window.matchMedia ||\n          !window.matchMedia(\"(pointer:coarse)\").matches\n        )\n          box.querySelector('input[name=\"amount\"]')?.focus();\n      }\n\n      /** Genera un input del form con escaping dei valori. */\n      function field(title, name, type, value = \"\", extra = \"\", cls = \"\") {\n        const mandatory = ![\"note\", \"paidDate\"].includes(name);\n        return (\n          '<label class=\"' +\n          cls +\n          '\">' +\n          title +\n          (mandatory ? \" *\" : \"\") +\n          '<input name=\"' +\n          name +\n          '\" type=\"' +\n          type +\n          '\" value=\"' +\n          escapeHtml(value) +\n          '\" ' +\n          extra +\n          (mandatory ? \" required\" : \"\") +\n          \"></label>\"\n        );\n      }\n\n      /** Genera una select del form preservando la scelta corrente. */\n      function select(title, name, values, value) {\n        if (name === \"category\")return \"<label>\"+title+' *<select name=\"category\" required>'+categoryOptionsHtml(values,value)+\"</select></label>\";\n        return (\n          \"<label>\" +\n          title +\n          ' *<select name=\"' +\n          name +\n          '\" required>' +\n          values\n            .map(\n              (x) =>\n                \"<option \" +\n                (x === value ? \"selected\" : \"\") +\n                \">\" +\n                escapeHtml(x) +\n                \"</option>\",\n            )\n            .join(\"\") +\n          \"</select></label>\"\n        );\n      }\n\n      function isUtilityCategory(category) {\n        return [\"Utenze\",\"Elettricit\u00e0\",\"Gas\",\"Acqua\"].includes(category);\n      }\n      function utilityFields(category=\"\",months=1) {\n        const active=isUtilityCategory(category),direct=active && category!==\"Utenze\";\n        return `<div class=\"full form-grid ${active?\"\":\"hidden\"}\" id=\"utility-fields\"><label class=\"${direct?\"hidden\":\"\"}\">Tipo utenza *<select name=\"utilityKind\" ${active && !direct?\"required\":\"disabled\"}><option value=\"\">Scegli</option>${[\"Elettricit\u00e0\",\"Gas\",\"Acqua\"].map(x=>`<option ${category===x?\"selected\":\"\"}>${x}</option>`).join(\"\")}</select></label><label class=\"${direct?\"full\":\"\"}\">Mesi coperti *<input name=\"utilityMonths\" type=\"number\" min=\"1\" max=\"12\" step=\"1\" value=\"${Number(months)||1}\" ${active?\"required\":\"disabled\"}></label></div>`;\n      }\n      function syncUtilityFields() {\n        const f=document.getElementById(\"entry-form\"),box=document.getElementById(\"utility-fields\");if(!box)return;\n        const category=f.elements.category.value,active=f.elements.type.value===\"Spesa\" && isUtilityCategory(category);\n        box.classList.toggle(\"hidden\",!active);box.querySelectorAll(\"select,input\").forEach(x=>{x.disabled=!active;x.required=active;});\n        const direct=active && category!==\"Utenze\",kind=f.elements.utilityKind;\n        kind.disabled=!active || direct;kind.required=active && !direct;\n        kind.closest(\"label\").classList.toggle(\"hidden\",direct);\n        f.elements.utilityMonths.closest(\"label\").classList.toggle(\"full\",direct);\n        if(direct)kind.value=category;\n      }\n      function commitmentHint(category=\"\") {\n        const d=state.data || life.finance, r=d?.recurring?.find(x=>x.name===category && x.treatment===\"Vincolata\");\n        const estimate=category===\"Affitto\" ? d?.summary?.rent : r?.estimate;\n        const text=estimate===undefined ? ([\"Assicurazione\",\"Bollo\",\"Manutenzione auto\",\"Dentista\",\"Straordinarie\"].includes(category)?\"Automatico: questa spesa incide sui risparmi. Puoi scegliere un recupero nei mesi successivi.\":\"Automatico: questa categoria incide sul budget libero, salvo un trattamento diverso.\") : `Previsti per ${category}: ${exactEuro(estimate)} al mese. La quota mensile \u00e8 gi\u00e0 sottratta dal budget. Il pagamento e le differenze incidono sul saldo, senza un secondo addebito al budget libero.`;\n        return `<p id=\"commitment-hint\" class=\"hint full ${text?\"\":\"hidden\"}\">${escapeHtml(text)}</p>`;\n      }\n      function syncCommitmentHint() {\n        const f=document.getElementById(\"entry-form\"),box=document.getElementById(\"commitment-hint\");if(!f || !box)return;\n        box.outerHTML=commitmentHint(f.elements.type.value===\"Spesa\" ? f.elements.category.value : \"\");\n      }\n\n      function budgetPolicyFields(r={}) {\n        const mode=r.budgetTreatment || \"auto\";\n        return `<div id=\"budget-policy-fields\" class=\"full form-grid\"><label class=\"full\">Trattamento budget<select name=\"budgetTreatment\">${[[\"auto\",\"Automatico dalla categoria\"],[\"ordinary\",\"Spesa ordinaria \u00b7 budget libero\"],[\"planned\",\"Pagamento pianificato \u00b7 gi\u00e0 impegnato\"],[\"savings\",\"Risparmi \u00b7 nessun recupero\"],[\"recovery\",\"Risparmi \u00b7 recupera nei mesi scelti\"]].map(([v,l])=>`<option value=\"${v}\" ${v===mode?\"selected\":\"\"}>${l}</option>`).join(\"\")}</select></label><label class=\"full ${mode===\"recovery\"?\"\":\"hidden\"}\" data-recovery-field>Mesi di recupero<input name=\"recoveryMonths\" value=\"${escapeHtml(r.recoveryMonths||\"\")}\" placeholder=\"2026-11, 2026-12, 2027-01\" ${mode===\"recovery\"?\"required\":\"disabled\"}></label><label class=\"full ${mode===\"recovery\"?\"\":\"hidden\"}\" data-recovery-field>Importo da recuperare \u20ac (vuoto = tutta la spesa)<input name=\"recoveryAmount\" type=\"number\" min=\"0.01\" step=\"0.01\" value=\"${r.recoveryAmount||\"\"}\" ${mode===\"recovery\"?\"\":\"disabled\"}></label><p class=\"hint full\" id=\"recovery-preview\"></p><p class=\"hint full\">Il saldo registra sempre l\u2019intera uscita. Il budget libero pu\u00f2 diventare negativo. Per una spesa annuale usa Segna pagato nel suo piano; per un movimento gi\u00e0 registrato usa Collega movimento.</p></div>`;\n      }\n      function syncBudgetPolicyFields(){\n        const f=document.getElementById(\"entry-form\"),box=document.getElementById(\"budget-policy-fields\");if(!box)return;\n        const expense=f.elements.type.value===\"Spesa\",recovery=expense && f.elements.budgetTreatment.value===\"recovery\";\n        box.classList.toggle(\"hidden\",!expense);f.elements.budgetTreatment.disabled=!expense;\n        box.querySelectorAll(\"[data-recovery-field]\").forEach(e=>{e.classList.toggle(\"hidden\",!recovery);e.querySelector(\"input\").disabled=!recovery;});\n        f.elements.recoveryMonths.required=recovery;\n        const out=document.getElementById(\"recovery-preview\");out.textContent=\"\";\n        if(recovery){const months=f.elements.recoveryMonths.value.split(\",\").map(x=>x.trim()).filter(Boolean).sort(),cents=Math.round(Number(f.elements.recoveryAmount.value || f.elements.amount.value)*100);\n          if(months.length && new Set(months).size===months.length && months.length<=60 && months.every(m=>/^20[2-3]\\d-(0[1-9]|1[0-2])$/.test(m)) && cents>0 && cents<=Math.round(Number(f.elements.amount.value)*100))out.textContent=months.map((m,i)=>`${shortMonth(m)}: ${exactEuro((Math.floor(cents/months.length)+(i<cents%months.length?1:0))/100)}`).join(\" \u00b7 \");\n        }\n      }\n      document.addEventListener(\"change\",e=>{if(e.target.closest(\"#entry-form\")){syncBudgetPolicyFields();}});\n      document.addEventListener(\"input\",e=>{if(e.target.closest(\"#budget-policy-fields\") || e.target.name===\"amount\")syncBudgetPolicyFields();});\n\n      /** Data civile usata dai form, nel fuso Europe/Rome. */\n      function todayIso() {\n        return new Date().toLocaleDateString(\"sv-SE\", {\n          timeZone: \"Europe/Rome\",\n        });\n      }\n\n      /** Form spesa/entrata/trasferimento; il trasferimento crea due righe coerenti. */\n      async function openTransaction(type = \"Spesa\") {\n        if (!financialCategoryOptions().length) {\n          try {\n            const categories = await workerRequest(\n              \"getFinanceCategoryOptions\",\n              [],\n            );\n            if (state.data) state.data.categoryOptions = categories;\n            if (life.finance) life.finance.categoryOptions = categories;\n          } catch (err) {\n            osError(err);\n            return;\n          }\n        }\n        const category = financialCategoryOptions(type);\n        const current = todayIso(),\n          chosen =\n            state.view === \"today\" ||\n            current.slice(0, 7) ===\n              state.year + \"-\" + String(state.month).padStart(2, \"0\")\n              ? current\n              : state.year + \"-\" + String(state.month).padStart(2, \"0\") + \"-01\";\n        modal(\n          \"Nuovo movimento\",\n          select(\n            \"Tipo\",\n            \"type\",\n            [\"Spesa\", \"Entrata\", \"Rimborso\", \"Trasferimento\"],\n            type,\n          ) +\n            field(\n              \"Importo \u20ac\",\n              \"amount\",\n              \"number\",\n              \"\",\n              'min=\"0.01\" max=\"1000000\" step=\"0.01\" inputmode=\"decimal\"',\n            ) +\n            field(\n              \"Descrizione\",\n              \"name\",\n              \"text\",\n              \"\",\n              'maxlength=\"120\" autocomplete=\"off\"',\n              \"full\",\n            ) +\n            '<input type=\"hidden\" name=\"account\" value=\"Trade Republic\">'  +\n            select(\n              \"Categoria\",\n              \"category\",\n              category,\n              type === \"Entrata\"\n                ? \"Stipendio\"\n                : type === \"Rimborso\"\n                  ? \"Trasferimenti a terzi\"\n                  : \"Altro\",\n            ) +\n            field(\"Data effettiva\", \"date\", \"date\", chosen) +\n            utilityFields() + commitmentHint() + budgetPolicyFields() +\n\n            '<label id=\"counterpart-box\" class=\"' +\n            (type === \"Trasferimento\" ? \"\" : \"hidden\") +\n            '\">Trasferimento finale da Revolut a<select name=\"counterpart\"><option>Trade Republic</option></select></label>' +\n            '<label class=\"full hidden\" id=\"already-snapshot-box\"><input type=\"checkbox\" name=\"includedInSnapshot\" value=\"yes\" style=\"display:inline-block;width:auto;margin-right:7px\">Gi\u00e0 inclusa nel saldo bancario rilevato</label>' +\n            '<p class=\"hint full\">Restituzione di un prestito: Rimborso. Rimborso esterno che vuoi conteggiare come entrata: Entrata \u2192 Rimborsi.</p>',\n          \"transaction\",\n        );\n        updateTransactionAccount();\n        updateSnapshotChoice();\n        syncBudgetPolicyFields();\n      }\n\n      /** Mostra l\u2019opzione gi\u00e0 incluso nel saldo soltanto per date e conti compatibili. */\n      function updateTransactionAccount() {\n        const form = document.getElementById(\"entry-form\");\n        if (form?.dataset.kind !== \"transaction\") return;\n        form.elements.account.value = form.elements.type.value === \"Trasferimento\" ? \"Revolut\" : \"Trade Republic\";\n      }\n      function updateSnapshotChoice() {\n        const form = document.getElementById(\"entry-form\"),\n          box = document.getElementById(\"already-snapshot-box\");\n        if (!form || !box) return;\n        const summary = state.data?.summary || life.finance?.summary;\n        const day = form.elements.date?.value,\n          account = form.elements.account?.value,\n          type = form.elements.type?.value;\n        const anchor =\n          account === \"Revolut\" ? summary?.balanceDate : summary?.assetDate;\n        const visible =\n          type !== \"Trasferimento\" && Boolean(day && anchor && day <= anchor);\n        box.classList.toggle(\"hidden\", !visible);\n        if (!visible) box.querySelector(\"input\").checked = false;\n      }\n\n      /** Recupera il movimento completo prima di consentirne la modifica. */\n      function openMovementEdit(row) {\n        if (state.busy) return;\n        google.script.run\n          .withSuccessHandler((r) => {\n            const categories = financialCategoryOptions(r.movement_type);\n            if (r.category && !categories.includes(financeCategoryLabel(r.category)))\n              categories.push(r.category);\n            const type =\n              r.movement_type === \"Spesa\" &&\n              String(r.notes || \"\").startsWith(\"Rimborso / restituzione:\")\n                ? \"Rimborso\"\n                : r.movement_type;\n            const allowed = [\n              \"Spesa\",\n              \"Entrata\",\n              \"Rimborso\",\n              \"Trasferimento\",\n              \"Investimento\",\n              \"Da verificare\",\n            ];\n            if (!allowed.includes(type)) {\n              alert(\"Questa tipologia storica non \u00e8 ancora modificabile.\");\n              return;\n            }\n            const accounts = [\"Revolut\", \"Trade Republic\", \"IsyBank\"];\n            modal(\n              \"Modifica movimento\",\n              '<input type=\"hidden\" name=\"row\" value=\"' +\n                r.source_row +\n                '\">' +\n                select(\"Tipo\", \"type\", allowed, type) +\n                field(\n                  \"Importo \u20ac\",\n                  \"amount\",\n                  \"number\",\n                  Math.abs(r.amount),\n                  'min=\"0.01\" max=\"1000000\" step=\"0.01\" inputmode=\"decimal\"',\n                ) +\n                field(\n                  \"Descrizione\",\n                  \"name\",\n                  \"text\",\n                  r.description || \"\",\n                  'maxlength=\"120\"',\n                  \"full\",\n                ) +\n                select(\"Conto\", \"account\", accounts, r.account) +\n                select(\"Categoria\", \"category\", categories, r.category) +\n                utilityFields(r.category,r.competence_months) + commitmentHint(r.category) + budgetPolicyFields(r) +\n                field(\n                  \"Data effettiva\",\n                  \"date\",\n                  \"date\",\n                  String(r.actual_date || r.budget_date || todayIso()).slice(\n                    0,\n                    10,\n                  ),\n                ) +\n                field(\n                  \"Mesi coperti\",\n                  \"months\",\n                  \"number\",\n                  r.competence_months || 1,\n                  'min=\"1\" max=\"12\" step=\"1\"',\n                ) +\n                '<label id=\"counterpart-box\" class=\"' +\n                (type === \"Trasferimento\" ? \"\" : \"hidden\") +\n                '\">Altro conto *<select name=\"counterpart\">' +\n                accounts\n                  .map(\n                    (a) =>\n                      \"<option \" +\n                      (r.counterparty_account === a ? \"selected\" : \"\") +\n                      \">\" +\n                      a +\n                      \"</option>\",\n                  )\n                  .join(\"\") +\n                \"</select></label>\" +\n                '<p class=\"hint full\">Dopo una correzione, verifica i saldi nel Budget.</p>',\n              \"movement-edit\",\n            );\n            syncBudgetPolicyFields();syncUtilityFields();syncCommitmentHint();\n          })\n          .withFailureHandler((err) => {\n            const box = document.getElementById(\"error\");\n            box.textContent = \"Lettura non riuscita: \" + (err.message || err);\n            box.classList.remove(\"hidden\");\n          })\n          .getMovement(row);\n      }\n\n      /** Registra una bolletta o un\u2019altra spesa ricorrente e i mesi coperti. */\n      function openRecurring() {\n        modal(\n          \"Registra pagamento\",\n          select(\n            \"Voce\",\n            \"name\",\n            [\n              \"Elettricit\u00e0\",\n              \"Gas\",\n              \"Acqua\",\n              \"Condominio\",\n              \"Palestra\",\n              \"Abbonamenti\",\n              \"Benzina\",\n            ],\n            \"Elettricit\u00e0\",\n          ) +\n            field(\n              \"Pagato \u20ac\",\n              \"amount\",\n              \"number\",\n              \"\",\n              'min=\"0.01\" max=\"2000\" step=\"0.01\" inputmode=\"decimal\"',\n            ) +\n            '<input type=\"hidden\" name=\"account\" value=\"Trade Republic\">' +\n            field(\"Data\", \"date\", \"date\", todayIso()) +\n            field(\n              \"Mesi coperti\",\n              \"months\",\n              \"number\",\n              1,\n              'min=\"1\" max=\"12\" step=\"1\"',\n            ) +\n            field(\"Nota\", \"note\", \"text\", \"\", 'maxlength=\"200\"', \"full\"),\n          \"recurring\",\n        );\n      }\n\n      /** Crea una pianificazione straordinaria; non implica pagamento. */\n      function openExtra(c) {\n        const date = c?.date || todayIso();\n        modal(\n          \"Nuova straordinaria\",\n          field(\n            \"Voce\",\n            \"name\",\n            \"text\",\n            c?.name || \"\",\n            'maxlength=\"100\"',\n            \"full\",\n          ) +\n            field(\n              \"Totale \u20ac\",\n              \"amount\",\n              \"number\",\n              c?.amount || \"\",\n              'min=\"0.01\" max=\"1000000\" step=\"0.01\" inputmode=\"decimal\"',\n            ) +\n            field(\"Dal mese\", \"month\", \"month\", date.slice(0, 7)) +\n            field(\"Al mese\", \"endMonth\", \"month\", date.slice(0, 7)) +\n            select(\"Ripeti\", \"repeat\", [\"No\", \"Annuale\"], \"No\") +\n            select(\n              \"Stato\",\n              \"status\",\n              [\"Previsto\", \"Programmato\"],\n              \"Programmato\",\n            ) +\n            '<input type=\"hidden\" name=\"account\" value=\"Trade Republic\">' +\n            field(\n              \"Nota\",\n              \"note\",\n              \"text\",\n              c\n                ? \"Da verificare: movimento gi\u00e0 registrato, nessuna nuova uscita\"\n                : \"\",\n              'maxlength=\"200\"',\n              \"full\",\n            ) +\n            '<p class=\"hint full\" id=\"extra-allocation-preview\"></p>',\n          \"extra\",\n        );\n        updateExtraPreview();\n      }\n\n      /** Anteprima quote, durata e totale prima di salvare il piano. */\n      function updateExtraPreview() {\n        const form = document.getElementById(\"entry-form\"),\n          out = document.getElementById(\"extra-allocation-preview\");\n        if (!form || !out) return;\n        const from = form.elements.month?.value,\n          to = form.elements.endMonth?.value,\n          amount = Number(form.elements.amount?.value);\n        const months =\n          from && to\n            ? (Number(to.slice(0, 4)) - Number(from.slice(0, 4))) * 12 +\n              Number(to.slice(5)) -\n              Number(from.slice(5)) +\n              1\n            : 0;\n        if (\n          !Number.isFinite(amount) ||\n          amount <= 0 ||\n          months < 1 ||\n          months > 60\n        ) {\n          out.textContent = \"\";\n          return;\n        }\n        const cents = Math.round(amount * 100),\n          base = Math.floor(cents / months),\n          remainder = cents % months;\n        out.textContent =\n          months +\n          \" \" +\n          (months === 1 ? \"mese\" : \"mesi\") +\n          \" \u00b7 \" +\n          exactEuro(base / 100) +\n          \" al mese\" +\n          (remainder\n            ? \" \u00b7 \" +\n              remainder +\n              \" \" +\n              (remainder === 1 ? \"mese riceve\" : \"mesi ricevono\") +\n              \" un centesimo in pi\u00f9\"\n            : \"\");\n      }\n\n      /** Trova il ciclo della straordinaria dal piano caricato. */\n      function extraCycle(row) {\n        const month =\n          String(state.year) + \"-\" + String(state.month).padStart(2, \"0\");\n        const options = (state.data?.extraPlan?.allocations || []).filter(\n          (a) => a.extraordinary_source_row === row,\n        );\n        return options.find((a) => a.month === month) || options[0];\n      }\n\n      /** Carica il dettaglio del ciclo prima di modificarne totale e periodo. */\n      function openExtraEdit(row) {\n        const c = extraCycle(row);\n        if (!c) {\n          const box = document.getElementById(\"error\");\n          box.textContent =\n            \"Seleziona un anno che contiene una quota di questa straordinaria.\";\n          box.classList.remove(\"hidden\");\n          return;\n        }\n        google.script.run\n          .withSuccessHandler((r) => {\n            const annual = r.repeat === \"Annuale\";\n            modal(\n              \"Modifica pianificazione\",\n              '<input type=\"hidden\" name=\"cycleId\" value=\"' +\n                r.id +\n                '\">' +\n                field(\n                  \"Voce\",\n                  \"name\",\n                  \"text\",\n                  r.name,\n                  'maxlength=\"100\"',\n                  \"full\",\n                ) +\n                field(\n                  \"Totale \u20ac\",\n                  \"amount\",\n                  \"number\",\n                  (r.total_cents / 100).toFixed(2),\n                  'min=\"0.01\" max=\"1000000\" step=\"0.01\" inputmode=\"decimal\"',\n                ) +\n                field(\n                  \"Dal mese\",\n                  \"month\",\n                  \"month\",\n                  r.start_month,\n                  annual ? \"readonly\" : \"\",\n                ) +\n                field(\n                  \"Al mese\",\n                  \"endMonth\",\n                  \"month\",\n                  r.end_month,\n                  annual ? \"readonly\" : \"\",\n                ) +\n                (r.kind === \"budget_advance\"\n                  ? '<input type=\"hidden\" name=\"account\" value=\"' +\n                    escapeHtml(r.account) +\n                    '\">'\n                  : '<input type=\"hidden\" name=\"account\" value=\"Trade Republic\">') +\n                field(\n                  \"Nota\",\n                  \"note\",\n                  \"text\",\n                  r.notes || \"\",\n                  'maxlength=\"200\"',\n                  \"full\",\n                ) +\n                '<p class=\"hint full\">' +\n                (annual ? \"Solo questo ciclo annuale. \" : \"\") +\n                \"I pagamenti registrati restano invariati.\" +\n                (r.linked_cents\n                  ? \" Gi\u00e0 collegato: \" + exactEuro(r.linked_cents / 100) + \".\"\n                  : \"\") +\n                \"</p>\" +\n                '<p class=\"hint full\" id=\"extra-allocation-preview\"></p>',\n              \"extra-edit\",\n            );\n            updateExtraPreview();\n          })\n          .withFailureHandler((err) => {\n            const box = document.getElementById(\"error\");\n            box.textContent = \"Lettura non riuscita: \" + (err.message || err);\n            box.classList.remove(\"hidden\");\n          })\n          .getExtraCycleDetail(c.cycle_id);\n      }\n\n      /** Editor compatibilit\u00e0 per il pagamento; il server impedisce doppi addebiti. */\n      function openExtraPayment(row) {\n        const e = state.data.extras.find((x) => x.row === row),\n          cycle = extraCycle(row);\n        if (!e || !cycle) return;\n        modal(\n          \"Registra pagamento\",\n          '<input type=\"hidden\" name=\"cycleId\" value=\"' +\n            cycle.cycle_id +\n            '\">' +\n            field(\n              \"Importo \u20ac\",\n              \"amount\",\n              \"number\",\n              ((cycle.total_cents-(state.data.extraPlan.links||[]).filter(l=>l.cycle_id===cycle.cycle_id).reduce((n,l)=>n+l.attributed_cents,0))/100).toFixed(2),\n              'min=\"0.01\" step=\"0.01\" inputmode=\"decimal\"',\n            ) +\n            field(\"Descrizione\", \"name\", \"text\", e.name, 'maxlength=\"120\"') +\n            '<input type=\"hidden\" name=\"account\" value=\"Trade Republic\">' +\n            field(\"Data pagamento\", \"date\", \"date\", todayIso()) +\n            '<p class=\"hint full\">La quota mensile resta nel piano; l\u2019importo effettivo incide sul saldo. Le differenze sono assorbite dai risparmi. Il pagamento chiude questo ciclo; i rinnovi annuali continuano.</p>',\n          \"extra-payment\",\n        );\n      }\n\n      /** Collega un movimento esistente senza crearne un altro; flusso storico compatibile. */\n      function openExtraLink(row) {\n        const e = state.data.extras.find((x) => x.row === row),\n          cycle = extraCycle(row);\n        if (!e || !cycle) return;\n        const type =\n          cycle.kind === \"budget_advance\" ? \"Trasferimento\" : \"Spesa\";\n        const choices = (state.data.transactions || []).filter(\n          (t) => t.status === \"Eseguito\" && t.type === type && t.amount < 0,\n        );\n        if (!choices.length) {\n          const box = document.getElementById(\"error\");\n          box.textContent =\n            \"Seleziona il mese del movimento nella barra superiore e riprova.\";\n          box.classList.remove(\"hidden\");\n          return;\n        }\n        const options = choices\n          .map(\n            (t) =>\n              '<option value=\"' +\n              t.row +\n              '\">' +\n              escapeHtml(t.date + \" \u00b7 \" + t.name + \" \u00b7 \" + euro(-t.amount)) +\n              \"</option>\",\n          )\n          .join(\"\");\n        modal(\n          \"Collega movimento esistente\",\n          '<input type=\"hidden\" name=\"cycleId\" value=\"' +\n            cycle.cycle_id +\n            '\">' +\n            '<label>Movimento *<select name=\"movementId\" required>' +\n            options +\n            \"</select></label>\" +\n            field(\n              \"Importo attribuito \u20ac\",\n              \"amount\",\n              \"number\",\n              e.total,\n              'min=\"0.01\" step=\"0.01\" inputmode=\"decimal\"',\n            ) +\n            '<p class=\"hint full\">Nessun nuovo addebito.</p>',\n          \"extra-link\",\n        );\n      }\n\n      /** Chiude il foglio finanziario; l\u2019observer restituisce il focus al controllo iniziale. */\n      function closeDialog() {\n        document.getElementById(\"dialog\").classList.add(\"hidden\");\n      }\n\n      /** Cambia mese finanziario entro l\u2019intervallo supportato e ricarica i dati. */\n      function moveMonth(delta) {\n        const date = new Date(state.year, state.month - 1 + delta, 1);\n        if (date.getFullYear() < 2024 || date.getFullYear() > 2035) return;\n        state.year = date.getFullYear();\n        state.month = date.getMonth() + 1;\n        state.categoryMonth = state.month;\n        load();\n      }\n\n      /** Cambia il mese del grafico categorie; attraversando l\u2019anno ricarica i dati. */\n      function moveCategory(delta) {\n        const date = new Date(state.year, state.categoryMonth - 1 + delta, 1);\n        if (date.getFullYear() !== state.year) {\n          state.year = date.getFullYear();\n          state.month = date.getMonth() + 1;\n          state.categoryMonth = state.month;\n          load();\n          return;\n        }\n        state.categoryMonth = date.getMonth() + 1;\n        render();\n      }\n\n      /** Invia la stima della voce selezionata; il server valida nome e intervallo. */\n      function saveEstimate(name) {\n        const input = [...document.querySelectorAll(\"[data-estimate]\")].find(\n          (e) => e.dataset.estimate === name,\n        );\n        if (input) submit(\"saveEstimate\", [name, input.value]);\n      }\n\n      /** Mutex finanziario; invalida dati vecchi e ripristina i pulsanti anche dopo errore. */\n      async function submit(method, args) {\n        if (state.busy) return false;\n        state.busy = true;\n        document.getElementById(\"error\").classList.add(\"hidden\");\n        document.getElementById(\"finance-form-error\")?.classList.add(\"hidden\");\n        const controls = [\n          ...document.querySelectorAll(\n            \"#dialog [type=submit],[data-extra-mark-paid],#save-plan,#goal-input,#saving-input\",\n          ),\n        ];\n        const formButton = document.querySelector(\"#dialog [type=submit]\"), formButtonLabel = formButton?.textContent;\n        if(formButton) {formButton.textContent=\"Salvataggio\u2026\";formButton.setAttribute(\"aria-busy\",\"true\");}\n        const disabled = controls.map((b) => b.disabled);\n        controls.forEach((b) => (b.disabled = true));\n        try {\n          await workerRequest(method, args);\n          if (method === \"savePlanningSettings\") {\n            state.planningDraft = null;\n            if (state.data?.planning) {\n              state.data.planning = projectPlanning(\n                state.data.planning,\n                args[0] === \"\" ? null : Number(args[0]),\n                Number(args[1]),\n              );\n              if (args.length > 2) state.data.planning.savingsTarget = Number(args[2]);\n              updateProjection();\n              const status = document.getElementById(\"planning-status\");\n              if (status) status.textContent = \"Salvato\";\n            }\n            return true;\n          }\n          closeDialog();\n          state.loadedDetail = false;\n          state.data = null;\n          life.finance = null;\n          if (\n            [\"overview\", \"budget\", \"movements\", \"extras\"].includes(state.view)\n          )\n            load();\n          if (state.view === \"today\") osLoadHomeFinance();\n          return true;\n        } catch (error) {\n          const box = document.getElementById(\"error\");\n          const planStatus =\n            method === \"savePlanningSettings\" &&\n            document.getElementById(\"planning-status\");\n          if (planStatus)\n            planStatus.textContent =\n              \"Salvataggio non riuscito: \" + error.message;\n          box.textContent = \"Salvataggio non riuscito: \" + error.message;\n          box.classList.remove(\"hidden\");\n          const formError=document.getElementById(\"finance-form-error\");if(formError && !document.getElementById(\"dialog\").classList.contains(\"hidden\")){formError.textContent=box.textContent;formError.classList.remove(\"hidden\");formError.scrollIntoView({block:\"nearest\"});}\n          return false;\n        } finally {\n          state.busy = false;\n          controls.forEach((b, i) => (b.disabled = disabled[i]));\n          if(formButton) {formButton.textContent=formButtonLabel;formButton.removeAttribute(\"aria-busy\");}\n        }\n      }\n      document.addEventListener(\"click\", (e) => {\n        if (e.target.closest(\"[data-toggle-assets]\")) {\n          const goal = document.getElementById(\"goal-input\")?.value,\n            saving = document.getElementById(\"saving-input\")?.value;\n          state.assetsVisible = !state.assetsVisible;\n          render();\n          if (life.data) document.getElementById(\"today\").innerHTML = osToday();\n          if (goal !== undefined && document.getElementById(\"goal-input\"))\n            document.getElementById(\"goal-input\").value = goal;\n          if (saving !== undefined && document.getElementById(\"saving-input\"))\n            document.getElementById(\"saving-input\").value = saving;\n          updateProjection();\n          return;\n        }\n        if (e.target.closest(\"[data-movements-more]\")) {\n          state.movementLimit += 100;\n          renderMovements();\n          return;\n        }\n        const classify = e.target.closest(\"[data-apply-category]\");\n        if (classify) {\n          const choice = classify\n            .closest(\".quick-classify\")\n            .querySelector(\"select\").value;\n          submit(\"classifyMovement\", [\n            Number(classify.dataset.applyCategory),\n            choice,\n          ]);\n          return;\n        }\n        // body[data-view] is layout state, NOT a navigation control. Matching it\n        // rebuilt the current screen after every click and destroyed open menus.\n        const nav = e.target.closest(\"button[data-view]\");\n        if (nav) {\n          setView(nav.dataset.view);\n          return;\n        }\n        if (e.target.closest(\"#prev-month\")) moveMonth(-1);\n        if (e.target.closest(\"#next-month\")) moveMonth(1);\n        const cat = e.target.closest(\"[data-cat]\");\n        if (cat) moveCategory(Number(cat.dataset.cat));\n        const row = e.target.closest(\".annual-row[data-month]\");\n        if (row) {\n          const [year, month] = row.dataset.month.split(\"-\").map(Number);\n          state.year = year;\n          state.month = month;\n          state.categoryMonth = month;\n          load();\n        }\n        const save = e.target.closest(\"[data-save-estimate]\");\n        if (save) saveEstimate(save.dataset.saveEstimate);\n        const tx = e.target.closest(\"[data-new-transaction]\");\n        if (tx) openTransaction(tx.dataset.newTransaction);\n        const edit = e.target.closest(\"[data-edit-movement]\");\n        if (edit) openMovementEdit(Number(edit.dataset.editMovement));\n        const del = e.target.closest(\"[data-delete-movement]\");\n        if (del) {\n          const id = Number(del.dataset.deleteMovement),\n            item = state.data?.transactions.find((t) => t.row === id);\n          if (\n            item &&\n            confirm(\n              \"Eliminare definitivamente \u00ab\" +\n                item.name +\n                \"\u00bb (\" +\n                exactEuro(item.amount) +\n                \")? Se \u00e8 un trasferimento creato nell\u2019app, verr\u00e0 eliminata anche la riga speculare.\",\n            )\n          )\n            submit(\"deleteMovement\", [id]);\n        }\n        if (e.target.closest(\"[data-new-extra]\")) openExtra();\n        const paid = e.target.closest(\"[data-extra-mark-paid]\");\n        if (paid) {\n          const cycle=(state.data?.extraPlan?.allocations || []).find(c=>c.cycle_id===Number(paid.dataset.extraMarkPaid));\n          if(cycle)openExtraPayment(cycle.extraordinary_source_row);\n          return;\n        }\n        const extraEdit = e.target.closest(\"[data-extra-edit]\");\n        if (extraEdit) openExtraEdit(Number(extraEdit.dataset.extraEdit));\n        const cancel = e.target.closest(\"[data-extra-cancel]\");\n        if (cancel) {\n          const cycleId = Number(cancel.dataset.extraCancel),\n            remove = cancel.dataset.delete === \"true\";\n          if (\n            confirm(\n              remove\n                ? \"Eliminare definitivamente la voce?\"\n                : \"Annullare questa pianificazione? Eventuali pagamenti restano nei Movimenti.\",\n            )\n          )\n            submit(remove ? \"deleteExtraPlan\" : \"cancelExtraCycle\", [\n              { cycleId },\n            ]);\n          return;\n        }\n        const extraPay = e.target.closest(\"[data-extra-pay]\");\n        if (extraPay) openExtraPayment(Number(extraPay.dataset.extraPay));\n        const extraLink = e.target.closest(\"[data-extra-link]\");\n        if (extraLink) openExtraLink(Number(extraLink.dataset.extraLink));\n        const candidate = e.target.closest(\"[data-candidate]\");\n        if (candidate)\n          openExtra({\n            name: candidate.dataset.candidate,\n            amount: candidate.dataset.amount,\n            date: candidate.dataset.date,\n            account: candidate.dataset.account,\n          });\n        if (e.target.closest(\"[data-new-recurring]\")) openRecurring();\n        if (e.target.closest(\"[data-close]\")) closeDialog();\n\n\n        if (e.target.closest(\"#save-plan\")) {\n          const inputs = [\n            document.getElementById(\"goal-input\"),\n            document.getElementById(\"saving-input\"),\n            document.getElementById(\"target-input\"),\n          ];\n          if (!inputs.every((input) => input.reportValidity())) return;\n          submit(\"savePlanningSettings\", [\n            document.getElementById(\"goal-input\").value,\n            document.getElementById(\"saving-input\").value,\n            ...(document.getElementById(\"target-input\").value ? [document.getElementById(\"target-input\").value] : []),\n          ]);\n        }\n      });\n      document.addEventListener(\"click\", (e) => {\n        if (e.target.closest(\"[data-open-analysis]\")) {\n          state.overviewAnalysisOpen = true;\n          document.querySelector(\"[data-overview-panel=analysis]\").open = true;\n          document\n            .querySelector(\"[data-overview-panel=analysis]\")\n            .scrollIntoView({ behavior: \"smooth\", block: \"start\" });\n        }\n      });\n      window\n        .matchMedia?.(\"(max-width:760px)\")\n        .addEventListener?.(\"change\", () => {\n          if (!state.data) return;\n          const sankey = document.querySelector(\"#overview .sankey-card\"),\n            trend = document.querySelector(\"#analysis .integrated-chart\");\n          if (sankey) sankey.outerHTML = sankeyCard(state.data);\n          if (trend) trend.outerHTML = cashFlowChart(state.data);\n        });\n      document.addEventListener(\n        \"toggle\",\n        (e) => {\n          if (e.target?.hasAttribute?.(\"data-home-times\"))\n            life.timesOpen = e.target.open;\n          const budgetPanel = e.target?.dataset?.budgetPanel;\n          if (\n            [\n              \"budgetSettingsOpen\",\n              \"budgetAnnualOpen\",\n              \"budgetHistoryOpen\",\n            ].includes(budgetPanel)\n          )\n            state[budgetPanel] = e.target.open;\n          const name = e.target?.dataset?.overviewPanel;\n          if (name === \"cards\") state.overviewCardsOpen = e.target.open;\n          if (name === \"analysis\") state.overviewAnalysisOpen = e.target.open;\n          if (name === \"plan\") state.overviewPlanOpen = e.target.open;\n        },\n        true,\n      );\n      document.addEventListener(\"input\", (e) => {\n        if (e.target.id === \"transaction-search\") {\n          state.search = e.target.value;\n          state.movementLimit = 100;\n          renderMovements();\n        }\n        if (\n          e.target.closest(\"#entry-form\") &&\n          [\"amount\", \"month\", \"endMonth\"].includes(e.target.name)\n        )\n          updateExtraPreview();\n        if (e.target.id === \"goal-input\" || e.target.id === \"saving-input\" || e.target.id === \"target-input\")\n          updateProjection();\n      });\n      document.addEventListener(\"change\", (e) => {\n        if (\n          e.target.closest(\"#entry-form\") &&\n          [\"date\", \"account\", \"type\"].includes(e.target.name)\n        )\n          updateSnapshotChoice();\n        if (e.target.id === \"type-filter\") {\n          state.type = e.target.value;\n          state.movementLimit = 100;\n          renderMovements();\n        }\n        if (e.target.matches(\"[data-extra-status]\")) {\n          e.target.className =\n            \"status-select state-tag state-\" + statusClass(e.target.value);\n          const row = Number(e.target.dataset.extraStatus),\n            previous = e.target.dataset.previous,\n            next = e.target.value;\n          if (next === \"Anticipato\" || next === \"Pagato\") {\n            e.target.value = previous;\n            e.target.className =\n              \"status-select state-tag state-\" + statusClass(previous);\n            if (next === \"Pagato\") openExtraPayment(row);\n            else openExtraLink(row);\n          } else if (next !== previous)\n            submit(\"setExtraStatus\", [row, previous, next]);\n        }\n        if (e.target.closest(\"#entry-form\") && e.target.name === \"type\") {\n          updateTransactionAccount();\n          updateSnapshotChoice();\n          document\n            .getElementById(\"counterpart-box\")\n            .classList.toggle(\"hidden\", e.target.value !== \"Trasferimento\");\n        }\n      });\n      document.addEventListener(\"invalid\", (e) => {\n        if (!e.target.closest(\"#entry-form\")) return;\n        const box = document.getElementById(\"finance-form-error\");\n        if (!box) return;\n        const label = e.target.closest(\"label\")?.childNodes[0]?.textContent?.trim() || \"Campo\";\n        box.textContent = label + \": \" + e.target.validationMessage;\n        box.classList.remove(\"hidden\");\n        e.target.scrollIntoView({block:\"center\"});\n      }, true);\n      document.addEventListener(\"submit\", (e) => {\n        if (e.target.id !== \"entry-form\") return;\n        e.preventDefault();\n        const f = e.target,\n          d = Object.fromEntries(new FormData(f).entries()),\n          kind = f.dataset.kind;\n        if (\n          (kind === \"transaction\" || kind === \"movement-edit\") &&\n          d.type === \"Trasferimento\" &&\n          d.account === d.counterpart\n        ) {\n          const box = document.getElementById(\"error\");\n          box.textContent = \"Scegli un conto di destinazione diverso.\";\n          box.classList.remove(\"hidden\");\n          return;\n        }\n        if((kind===\"transaction\"||kind===\"movement-edit\") && d.type!==\"Spesa\"){d.budgetTreatment=\"auto\";delete d.recoveryMonths;delete d.recoveryAmount;}\n        if(isUtilityCategory(d.category)){if(d.category===\"Utenze\")d.category=d.utilityKind;d.months=d.utilityMonths;}\n        if (kind === \"extra-payment\") return submit(\"recordExtraPayment\", [d]);\n        if (kind === \"extra-link\") return submit(\"linkExtraMovement\", [d]);\n        submit(\n          {\n            transaction: \"saveTransaction\",\n            \"movement-edit\": \"editMovement\",\n            recurring: \"saveRecurringPayment\",\n            extra: \"saveExtra\",\n            \"extra-edit\": \"updateExtraPlan\",\n          }[kind],\n          [d],\n        );\n      });\n      document.getElementById(\"period-label\").textContent = titleMonth(\n        state.year,\n        state.month,\n      );\n      document.getElementById(\"loading\").classList.add(\"hidden\");\n      loadLifeOS();\n      osLoadHomeFinance();\n      osLoadWeather();\n    </script>\n\n    <script>\n      (function () {\n        let previousFocus = null,\n          activeSheet = null,\n          lastOutsideFocus = null;\n        document.addEventListener(\"focusin\", (e) => {\n          if (!e.target.closest(\".modal-wrap\")) lastOutsideFocus = e.target;\n        });\n        document.addEventListener(\n          \"click\",\n          (e) => {\n            if (!activeSheet) {\n              const b = e.target.closest(\"button\");\n              if (b && !b.closest(\".modal-wrap\")) lastOutsideFocus = b;\n            }\n          },\n          true,\n        );\n        const wrappers = [\n          document.getElementById(\"dialog\"),\n          document.getElementById(\"life-dialog\"),\n        ];\n        const focusables = () =>\n          activeSheet\n            ? [\n                ...activeSheet.querySelectorAll(\n                  'button:not([disabled]),input:not([type=hidden]):not([disabled]),select:not([disabled]),textarea:not([disabled]),a[href],[tabindex=\"0\"]',\n                ),\n              ].filter((e) => e.getClientRects().length)\n            : [];\n        const observer = new MutationObserver(() => {\n          const next =\n            wrappers.find((w) => !w.classList.contains(\"hidden\")) || null;\n          if (next === activeSheet) return;\n          if (next) {\n            previousFocus =\n              lastOutsideFocus || document.querySelector(\".nav button.active\");\n            activeSheet = next;\n            document.querySelector(\".shell\").inert = true;\n            const title = next.querySelector(\"h2\");\n            if (title) title.setAttribute(\"tabindex\", \"-1\");\n            const initial = !matchMedia(\"(pointer:coarse)\").matches\n              ? next.querySelector(\"input[name=amount]\") || title\n              : title;\n            if (initial) initial.focus({ preventScroll: true });\n          } else {\n            activeSheet = null;\n            document.querySelector(\".shell\").inert = false;\n            if (previousFocus?.isConnected)\n              previousFocus.focus({ preventScroll: true });\n            previousFocus = null;\n          }\n        });\n        wrappers.forEach((w) =>\n          observer.observe(w, { attributes: true, attributeFilter: [\"class\"] }),\n        );\n        document.addEventListener(\"keydown\", (e) => {\n          if (!activeSheet) return;\n          if (e.key === \"Escape\") {\n            e.preventDefault();\n            activeSheet\n              .querySelector(\"[data-close],[data-life-close]\")\n              ?.click();\n            return;\n          }\n          if (e.key !== \"Tab\") return;\n          const list = focusables();\n          if (!list.length) {\n            e.preventDefault();\n            return;\n          }\n          const at = list.indexOf(document.activeElement);\n          if (e.shiftKey && at <= 0) {\n            e.preventDefault();\n            list.at(-1).focus();\n          } else if (!e.shiftKey && (at === list.length - 1 || at === -1)) {\n            e.preventDefault();\n            list[0].focus();\n          }\n        });\n        document.querySelectorAll(\"summary\").forEach((e) => (e.tabIndex = 0));\n        document.addEventListener(\"pointermove\", (e) => {\n          if (e.pointerType !== \"mouse\") return;\n          const control = e.target.closest(\".save,.os-button.primary,.sidebar\");\n          if (!control) return;\n          const r = control.getBoundingClientRect();\n          control.style.setProperty(\n            \"--light-x\",\n            Math.round(((e.clientX - r.left) / r.width) * 100) + \"%\",\n          );\n        });\n      })();\n\n      // Menus retain native summary semantics. One open menu, close outside or on Escape.\n      document.addEventListener(\"click\", (event) => {\n        const menu = event.target.closest(\".os-more-menu,.os-event-options\");\n        document\n          .querySelectorAll(\".os-more-menu[open],.os-event-options[open]\")\n          .forEach((other) => {\n            if (other !== menu || event.target.closest(\"button\"))\n              other.open = false;\n          });\n      });\n      document.addEventListener(\"keydown\", (event) => {\n        if (event.key !== \"Escape\" || event.defaultPrevented) return;\n        const menu = document.querySelector(\n          \".os-more-menu[open],.os-event-options[open]\",\n        );\n        if (menu) {\n          menu.open = false;\n          menu.querySelector(\"summary\").focus();\n          event.preventDefault();\n        }\n      });\n    </script>\n    <script>\n      (() => {\n        let scheduled = false;\n        const sync = () => {\n          scheduled = false;\n          document.querySelectorAll(\".nav button[data-view]\").forEach((b) => {\n            if (b.classList.contains(\"active\"))\n              b.setAttribute(\"aria-current\", \"page\");\n            else b.removeAttribute(\"aria-current\");\n          });\n          document\n            .querySelectorAll(\".os-category-tabs,.finance-tabs\")\n            .forEach((n) => {\n              const b = n.querySelector(\"button.active\");\n              if (b) {\n                const left = b.offsetLeft,\n                  right = left + b.offsetWidth;\n                if (left < n.scrollLeft) n.scrollLeft = left;\n                else if (right > n.scrollLeft + n.clientWidth)\n                  n.scrollLeft = right - n.clientWidth;\n              }\n            });\n        };\n        new MutationObserver(() => {\n          if (!scheduled) {\n            scheduled = true;\n            requestAnimationFrame(sync);\n          }\n        }).observe(document.querySelector(\".shell\"), {\n          subtree: true,\n          childList: true,\n          attributes: true,\n          attributeFilter: [\"class\"],\n        });\n        sync();\n      })();\n    </script>\n    <script>\n      (() => {\n        const b = document.querySelector(\".theme-toggle\");\n        const draw = () => {\n          const light = document.documentElement.dataset.theme === \"light\";\n          b.textContent = light ? \"\u25d0\" : \"\u25d1\";\n          b.setAttribute(\n            \"aria-label\",\n            light ? \"Attiva modalit\u00e0 scura\" : \"Attiva modalit\u00e0 chiara\",\n          );\n          document.querySelector('meta[name=\"theme-color\"]').content = light\n            ? \"#f3f3f5\"\n            : \"#0c0c0e\";\n        };\n        b.onclick = () => {\n          const theme =\n            document.documentElement.dataset.theme === \"light\"\n              ? \"dark\"\n              : \"light\";\n          document.documentElement.dataset.theme = theme;\n          try {\n            localStorage.setItem(\"life-theme\", theme);\n          } catch (e) {}\n          draw();\n        };\n        matchMedia(\"(prefers-color-scheme: light)\").addEventListener(\n          \"change\",\n          (e) => {\n            try {\n              if (localStorage.getItem(\"life-theme\")) return;\n            } catch (x) {}\n            document.documentElement.dataset.theme = e.matches\n              ? \"light\"\n              : \"dark\";\n            draw();\n          },\n        );\n        draw();\n      })();\n    </script>\n    <script>\n      (() => {\n        if (\n          /iPad|iPhone|iPod/.test(navigator.userAgent) ||\n          (navigator.platform === \"MacIntel\" && navigator.maxTouchPoints > 1)\n        )\n          return;\n        let start = 0,\n          target = null,\n          pulling = false;\n        const reduced = matchMedia(\"(prefers-reduced-motion: reduce)\");\n        /** Termina il rimbalzo artificiale sui dispositivi privi del comportamento iOS nativo. */\n        function reset() {\n          if (!target) return;\n          const node = target;\n          node.style.transition = reduced.matches\n            ? \"none\"\n            : \"translate 280ms cubic-bezier(.2,.8,.2,1)\";\n          node.style.translate = \"0 0\";\n          setTimeout(() => {\n            node.style.transition = \"\";\n            node.style.translate = \"\";\n          }, 300);\n          target = null;\n          pulling = false;\n        }\n        document.addEventListener(\n          \"touchstart\",\n          (e) => {\n            reset();\n            if (\n              e.touches.length !== 1 ||\n              reduced.matches ||\n              e.target.closest(\n                \"input,textarea,select,button,.os-drag-handle,.os-category-tabs,.finance-tabs,.chart-scroll,.os-routine-items,.modal-wrap\",\n              )\n            )\n              return;\n            start = e.touches[0].clientY;\n            target =\n              e.target.closest(\".view.active\") ||\n              document.querySelector(\"main\");\n          },\n          { passive: true },\n        );\n        document.addEventListener(\n          \"touchmove\",\n          (e) => {\n            if (!target || e.touches.length !== 1) return;\n            const delta = e.touches[0].clientY - start,\n              root = document.scrollingElement;\n            let node = e.target;\n            while (node && node !== document.body) {\n              if (\n                node.scrollHeight > node.clientHeight + 2 &&\n                getComputedStyle(node).overflowY.match(/auto|scroll/)\n              )\n                return;\n              node = node.parentElement;\n            }\n            const end = root.scrollHeight - root.clientHeight;\n            if (\n              (root.scrollTop <= 0 && delta > 0) ||\n              (root.scrollTop >= end - 1 && delta < 0)\n            ) {\n              pulling = true;\n              e.preventDefault();\n              target.style.transition = \"none\";\n              target.style.translate =\n                \"0 \" +\n                Math.sign(delta) *\n                  Math.min(62, 62 * (1 - Math.exp(-Math.abs(delta) / 150))) +\n                \"px\";\n            } else if (pulling) reset();\n          },\n          { passive: false },\n        );\n        document.addEventListener(\"touchend\", reset, { passive: true });\n        document.addEventListener(\"touchcancel\", reset, { passive: true });\n      })();\n    </script>\n  </body>\n</html>\n";

/** Reconciliation approved by Nas: October 2026 account transition only.
 * Requires the actual paired return and the original 900 EUR October advance.
 * Matches only the nine reviewed expenses; later/new expenses remain chargeable.
 * Does not modify movements, bank balances, income or the stored advance cycle.
 */
function octoberAdvanceReconciliation(movements, month, todayDay, grossAdvance) {
  const none = {returned:0, covered:new Set()};
  if(month!=="2026-10" || todayDay<"2026-10-08" || grossAdvance<900)return none;
  const day = r => r[1] instanceof Date ? r[1].toISOString().slice(0,10) : String(r[1]||"").slice(0,10);
  const cents = r => Math.round(Number(r[3])*100);
  const returnedLeg = (account, amount) => movements.some(r => day(r)==="2026-10-08" &&
    r[4]===account && r[6]==="Trasferimento" && r[7]==="Eseguito" && cents(r)===amount);
  if(!returnedLeg("Revolut",-24756) || !returnedLeg("Trade Republic",24756))return none;
  /** @type {Array<[string, number, string]>} */
  const reviewed = [
    ["2026-10-08",1504,"amazon"], ["2026-10-07",500,"pay4vend"],
    ["2026-10-06",8779,"timberland"], ["2026-10-05",1500,"taglio capelli"],
    ["2026-10-04",400,"poldo"], ["2026-10-04",500,"pay4vend"],
    ["2026-10-03",550,"mcdonald"], ["2026-10-03",700,"ottobit"],
    ["2026-10-02",4300,"eureka"]
  ];
  const covered = new Set();
  for(const [date,amount,name] of reviewed) {
    const row = movements.find(r => !covered.has(r) && day(r)===date && r[4]==="Revolut" &&
      r[6]==="Spesa" && r[7]==="Eseguito" && cents(r)===-amount &&
      String(r[2]||"").toLowerCase().includes(name));
    if(row)covered.add(row);
  }
  return {returned:247.56, covered};
}

/** Utility forecasts normalize prior bills by months covered; current-month estimates stay unchanged. */
function utilityEstimates(recurring,movements,month,todayDay,settings={}) {
  const utilities=new Set(["Elettricità","Gas","Acqua"]);
  const day=r=>r[1] instanceof Date?r[1].toISOString().slice(0,10):String(r[1]||"").slice(0,10);
  return recurring.map(r=>{
    if(!utilities.has(r.name) && r.name!=="Condominio")return {...r};
    const config=settings[r.name]||{}, changes=(config.changes||[]).filter(x=>x.month<=month).sort((a,b)=>a.month.localeCompare(b.month));
    const manual=changes.at(-1), base=manual?manual.value:(config.base??r.estimate);
    const history=(r.name==="Condominio"?[]:movements).filter(m=>m[5]===r.name && m[6]==="Spesa" && m[7]==="Eseguito" && Number(m[3])<0 &&
      ["Revolut","Trade Republic"].includes(m[4]) && day(m)<=todayDay && day(m).slice(0,7)<month &&
      (!manual || day(m).slice(0,7)>=manual.month)).sort((a,b)=>day(b).localeCompare(day(a))||Number(b[19])-Number(a[19])).slice(0,3);
    const months=history.reduce((n,m)=>n+Math.max(1,Number(m[8])||1),0);
    const estimate=history.length?Math.round(history.reduce((n,m)=>n-Number(m[3]),0)/months*100)/100:Number(base)||0;
    return {...r,estimate,estimateSource:history.length?"Media ultime "+history.length+" bollette":"Stima manuale",estimateSamples:history.length};
  });
}

/** User-confirmed split of the legacy 575 EUR housing estimate, effective October 2026.
 * A later explicit change to the source rent takes precedence; historical months stay intact. */
function rentEstimate(configuredRent,month,split) {
  return split && month>=split.fromMonth && Math.round(configuredRent*100)===Math.round(split.sourceAmount*100)
    ? Number(split.rent) : configuredRent;
}

const SAVINGS_CATEGORIES = ["Assicurazione","Bollo","Manutenzione auto","Dentista","Straordinarie"];
const budgetSchemaJobs = new WeakMap();
async function ensureBudgetPolicies(env) {
  if(!budgetSchemaJobs.has(env.DB))budgetSchemaJobs.set(env.DB,env.DB.batch([
    env.DB.prepare("CREATE TABLE IF NOT EXISTS movement_budget_policies(movement_source_row INTEGER PRIMARY KEY REFERENCES movements(source_row) ON DELETE CASCADE,treatment TEXT NOT NULL CHECK(treatment IN ('auto','ordinary','planned','savings','recovery')),recovery_json TEXT NOT NULL DEFAULT '[]')"),
    env.DB.prepare("CREATE TABLE IF NOT EXISTS finance_write_requests(id TEXT PRIMARY KEY,fingerprint TEXT NOT NULL)"),
    env.DB.prepare("CREATE TABLE IF NOT EXISTS finance_extra_requests(id TEXT PRIMARY KEY,source_row INTEGER NOT NULL,fingerprint TEXT NOT NULL)"),
    env.DB.prepare("CREATE TABLE IF NOT EXISTS extraordinary_settlements(cycle_id INTEGER PRIMARY KEY REFERENCES extraordinary_cycles(id) ON DELETE CASCADE,movement_source_row INTEGER NOT NULL REFERENCES movements(source_row) ON DELETE CASCADE,planned_cents INTEGER NOT NULL,actual_cents INTEGER NOT NULL)")
  ]));
  try {await budgetSchemaJobs.get(env.DB);} catch(error){budgetSchemaJobs.delete(env.DB);throw error;}
}
function validatedBudgetPolicy(input,amount,day,type) {
  const treatment=String(input.budgetTreatment || "auto");
  if(!["auto","ordinary","planned","savings","recovery"].includes(treatment))throw Error("Trattamento budget non valido.");
  if(type!=="Spesa" && treatment!=="auto")throw Error("Il trattamento budget è disponibile solo per le spese.");
  if(treatment!=="recovery")return {treatment,recovery:[]};
  const raw=Array.isArray(input.recoveryMonths)?input.recoveryMonths:String(input.recoveryMonths || "").split(",").map(v=>v.trim()).filter(Boolean);
  if(!raw.length || raw.length>60 || new Set(raw).size!==raw.length || raw.some(m=>!/^20[2-3]\d-(0[1-9]|1[0-2])$/.test(m) || m<day.slice(0,7)))throw Error("Scegli da 1 a 60 mesi distinti, dalla data della spesa in avanti (AAAA-MM).");
  const months=[...raw].sort(), total=validCents(input.recoveryAmount===undefined || input.recoveryAmount===null || input.recoveryAmount===""?amount:input.recoveryAmount);
  if(total>Math.round(amount*100))throw Error("Il recupero non può superare la spesa.");
  return {treatment,recovery:months.map((month,i)=>({month,amount_cents:Math.floor(total/months.length)+(i<total%months.length?1:0)}))};
}
function budgetPolicyStatement(env,row,policy) {
  return env.DB.prepare("INSERT INTO movement_budget_policies(movement_source_row,treatment,recovery_json) SELECT ?,?,? WHERE EXISTS(SELECT 1 FROM movements WHERE source_row=?) ON CONFLICT(movement_source_row) DO UPDATE SET treatment=excluded.treatment,recovery_json=excluded.recovery_json").bind(row,policy.treatment,JSON.stringify(policy.recovery),row);
}

/** Budget mensile: impegni pianificati e spese libere, distinti dal saldo bancario. */
function monthlyBudgetAmounts({salary,rent,recurring,movements,month,todayDay,extraPlan,extras,carFallback=0}) {
  const round = (n) => Math.round((n + Number.EPSILON)*100)/100;
  salary=round(Number(salary)||0);
  const monthOf = (v) => v instanceof Date ? v.toISOString().slice(0,7) : String(v || "").slice(0,7);
  const dateOf = (v) => v instanceof Date ? v.toISOString().slice(0,10) : String(v || "").slice(0,10);
  const fixed = new Map([["Affitto",round(Number(rent)||0)],...recurring
    .filter(r=>r.treatment==="Vincolata" && r.name!=="Benzina")
    .map(r=>[r.name,round(Number(r.estimate)||0)])]);
  const allocations = (extraPlan?.allocations || []).filter(a=>a.month===month && a.status!=="Annullato");
  const extraCommitted = extraPlan
    ? allocations.filter(a=>a.kind==="expense").reduce((n,a)=>n+Number(a.amount_cents)/100,0)
    : extras.filter(e=>e.status!=="Annullato" && e.status!=="Previsto" && e.status!=="Anticipato" && e.start<=month &&
        (e.repeat==="Annuale" || e.end>=month)).reduce((n,e)=>n+Number(e.quota || 0),0)+carFallback;
  const grossAdvances = extraPlan
    ? allocations.filter(a=>a.kind==="budget_advance" && a.status==="Anticipato").reduce((n,a)=>n+Number(a.amount_cents)/100,0)
    : extras.filter(e=>e.status==="Anticipato" && e.start<=month && e.end>=month).reduce((n,e)=>n+Number(e.quota || 0),0);
  const reconciliation = octoberAdvanceReconciliation(movements,month,todayDay,grossAdvances);
  const advances = round(grossAdvances-reconciliation.returned);
  const linked = new Map();
  for(const l of extraPlan?.links || [])if(l.role==="payment")linked.set(Number(l.movement_source_row),(linked.get(Number(l.movement_source_row))||0)+Number(l.attributed_cents||0));
  const policies = new Map((extraPlan?.budgetPolicies || []).map(p=>[Number(p.movement_source_row),p]));
  const fixedPaid = new Map();
  let freeCents = 0;
  for(const r of movements) {
    const amount=Number(r[3])||0, type=String(r[6]), category=String(r[5]), policy=policies.get(Number(r[19]));
    if(!["Revolut","Trade Republic"].includes(String(r[4])) || r[7]!=="Eseguito" || dateOf(r[1])>todayDay)continue;
    if(type!=="Spesa" && !(type==="Entrata" && /rimbors|refund|storno/i.test(category+" "+r[2])))continue;
    if(reconciliation.covered.has(r))continue;
    const mode=policy?.treatment || "auto";
    const covered=mode==="planned" || (mode==="auto" && fixed.has(category));
    if(covered) {
      if(monthOf(r[1])===month)fixedPaid.set(category,(fixedPaid.get(category)||0)-amount);
      continue;
    }
    if(mode==="savings" || mode==="recovery" || (mode==="auto" && SAVINGS_CATEGORIES.includes(category)))continue;
    if(monthOf(r[1])===month)freeCents-=Math.round(amount*100)+(amount<0?Math.min(Math.round(-amount*100),linked.get(Number(r[19]))||0):0);
  }
  const settlements=[...fixedPaid].map(([name,paid])=>({name,estimate:round(fixed.get(name)||0),paid:round(paid),
    released:0,excess:0,savingsDifference:round(paid-(fixed.get(name)||0))}));
  // Recovery quotas are planning entries, never additional cash movements.
  const recoveries=(extraPlan?.budgetPolicies || []).filter(p=>p.treatment==="recovery" && p.status==="Eseguito" && p.actual_date<=todayDay);
  const recoveryCents=recoveries.reduce((sum,p)=>sum+(JSON.parse(p.recovery_json || "[]").find(q=>q.month===month)?.amount_cents || 0),0);
  const monthlyCommitted=round([...fixed.values()].reduce((n,v)=>n+v,0)+extraCommitted+advances+recoveryCents/100);
  const monthlySpent=freeCents/100;
  return {monthlySalary:round(salary),monthlyCommitted,monthlyAdvances:round(advances),monthlyAdvanceReturned:reconciliation.returned,monthlySpent,
    monthlyRemaining:round(salary-monthlyCommitted-monthlySpent),monthlyRecoveries:recoveryCents/100,
    monthlyFixedSettlements:settlements,monthlyReleased:0,
    monthlyAdvanceGross:round(grossAdvances),
    monthlyAdvanceCovered:round([...reconciliation.covered].reduce((n,r)=>n-Number(r[3]),0)),
    monthlyBudgetBreakdown:[
      ...[...fixed].filter(([,amount])=>amount!==0).map(([name,amount])=>({name,amount:round(amount)})),
      {name:"Accantonamenti e straordinarie",amount:round(extraCommitted)},
      {name:"Anticipo netto",amount:round(advances)},
      ...recoveries.flatMap(p=>JSON.parse(p.recovery_json||"[]").filter(q=>q.month===month).map(q=>({name:"Recupero · "+p.description,amount:q.amount_cents/100})))
    ]};
}

/** Motore puro derivato dal foglio originale. Importi in euro; eventi/quote in centesimi. */
function computeFinance(
  book,
  year,
  month,
  extraPlan,
  bankSnapshots = [],
  bankEvents = [],
  lightweight = false,
) {
  const TZ = "Europe/Rome";
  const APP_VERSION = "2026.10.09.os.11.63";
  const romeFormatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const Utilities = {
    formatDate(date, timezone, pattern) {
      const bits = Object.fromEntries(
        romeFormatter
          .formatToParts(date)
          .filter((x) => x.type !== "literal")
          .map((x) => [x.type, x.value]),
      );
      return pattern.replace(
        /yyyy|MM|dd|HH|mm|M/g,
        (x) =>
          ({
            yyyy: bits.year,
            MM: bits.month,
            dd: bits.day,
            HH: bits.hour,
            mm: bits.minute,
            M: String(Number(bits.month)),
          })[x],
      );
    },
  };

  /** Calcola il modello della vista. Budget = saldo Trade Republic; spendibile = saldo - impegni residui. */
  
  const now = new Date();
  year = boundedInteger_(
    year,
    2024,
    2035,
    Number(Utilities.formatDate(now, TZ, "yyyy")),
  );
  month = boundedInteger_(
    month,
    1,
    12,
    Number(Utilities.formatDate(now, TZ, "M")),
  );
  const budget = book.getSheetByName("Budget").getRange("A1:O24").getValues();
  const assets = book
    .getSheetByName("Patrimonio")
    .getRange("A1:H10")
    .getValues();
  const extrasRows = book
    .getSheetByName("Straordinarie")
    .getRange("A1:K500")
    .getValues();
  const trProof =
    book
      .getSheetByName("Estratto TR verificato")
      .getRange("A1:A1")
      .getValues()[0][0] || null;
  const payslipRows = book
    .getSheetByName("Cedolini")
    .getRange("A1:N500")
    .getValues();
  const payrollRows = book
    .getSheetByName("Riconciliazione stipendi")
    .getRange("A2:H100")
    .getValues();
  const recurringRows = book
    .getSheetByName("Storico ricorrenti")
    .getRange("A2:E200")
    .getValues();
  const balanceRow = book
    .getSheetByName("Saldi operativi")
    .getRange("A2:D2")
    .getValues()[0];
  const assetHistoryRows = book
    .getSheetByName("Storico patrimonio")
    .getRange("A2:D500")
    .getValues();
  const sheet = book.getSheetByName("Movimenti");
  const movements = sheet
    .getRange(2, 1, Math.max(1, sheet.getLastRow() - 1), 23)
    .getValues();
  const key = ym_(year, month);
  const todayDay = Utilities.formatDate(now, TZ, "yyyy-MM-dd");
  const extras = extrasRows
    .slice(1)
    .map((r, i) => ({ r, row: i + 2 }))
    .filter((x) => x.r[0])
    .map(({ r, row }) => ({
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
      repeat: String(r[10] || "No"),
    }));
  let salary = number_(budget[1][14]);
  let salaryWindow = null;
  const rent = rentEstimate(number_(budget[2][14]),key,extraPlan?.rentSplit);
  const car = number_(budget[3][14]);
  let revolut = number_(budget[5][14]);
  const utilitySettings = book.getSheetByName("Stime utenze").getRange("A1:A1").getValues()[0][0] || {};
  const baseRecurring = budget.slice(1, 7).map((r) => ({
    name: String(r[0]),
    estimate: number_(r[1]),
    treatment: String(r[2]),
  }));
  if(extraPlan?.condominiumSettings){baseRecurring.push({name:"Condominio",estimate:0,treatment:"Vincolata"});utilitySettings.Condominio=extraPlan.condominiumSettings;}
  const nextUtilityMonth = new Date(Date.UTC(year,month,1)).toISOString().slice(0,7);
  const nextUtilityEstimates = utilityEstimates(baseRecurring,movements,nextUtilityMonth,todayDay,utilitySettings);
  const recurring = utilityEstimates(baseRecurring,movements,key,todayDay,utilitySettings).map(r=>({...r,
    nextEstimate:r.estimateSource?nextUtilityEstimates.find(x=>x.name===r.name)?.estimate:undefined}));
  const reserved = recurring
    .filter((r) => r.treatment === "Vincolata")
    .reduce((sum, r) => sum + r.estimate, 0);
  let baseFree = revolut - reserved;
  const annualCostDefaults = budget.slice(2, 5).map((r) => ({
    name: String(r[7]),
    monthly: number_(r[8]),
    yearly: number_(r[9]),
  }));
  const yearly = Array.from({ length: 12 }, (_, i) => ({
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
    net: 0,
  }));

  /** Riconosce gli accrediti stipendio storici senza includere i trasferimenti interni. */
  function isSalaryMovement(r) {
    const text = [r[2], r[11], r[12]]
      .join(" ")
      .toLowerCase()
      .replace(/[^a-z0-9]/g, "");
    return (
      /var4you|vareng|stipendio|it65d0103037830000004004166/.test(text) ||
      ["Reddito", "Stipendio"].includes(String(r[5]))
    );
  }
  const categories = {};
  const incomeSources = {};
  const monthlyCategories = Object.fromEntries(
    yearly.map((y) => [y.month, {}]),
  );
  const selectedTransactions = [];
  const candidates = [];
  let pending = 0,
    unmatched = 0,
    funded = 0,
    prepaid = 0,
    futureFunded = 0;
  const fundedRows = new Set();
  const today = Utilities.formatDate(now, TZ, "yyyy-MM");

  const balanceDate = dateIso_(balanceRow[2]);
  const balanceAt = (account, day) => {
    if (day > todayDay) return null;
    const anchor = bankSnapshots
      .filter((s) => s.account === account && s.as_of_day <= day)
      .sort((a, b) => a.as_of_day.localeCompare(b.as_of_day) || a.id - b.id)
      .at(-1);
    if (!anchor) {
      if (
        account === "Trade Republic" &&
        trProof &&
        !trProof.conflicts?.length &&
        day >= trProof.from
      )
        return (
          Math.round(
            movements
              .filter(
                (r) =>
                  String(r[4]) === account &&
                  String(r[7]) === "Eseguito" &&
                  dateIso_(r[1]) >= trProof.from &&
                  dateIso_(r[1]) <= day,
              )
              .reduce(
                (n, r) => n + Math.round(number_(r[3]) * 100),
                trProof.opening,
              ),
          ) / 100
        );
      return null;
    }
    const cents = bankEvents
      .filter(
        (e) =>
          e.account === account &&
          e.id > anchor.event_watermark &&
          e.day <= day &&
          !(e.absorbed_snapshot_id && anchor.id >= e.absorbed_snapshot_id),
      )
      .reduce((sum, e) => sum + e.delta_cents, anchor.amount_cents);
    return Math.round(cents) / 100;
  };
  const currentRevolut =
    balanceAt("Revolut", todayDay) ?? number_(balanceRow[1]);
  const currentAssets =
    balanceAt("Trade Republic", todayDay) ?? number_(assets[1][1]);
  const monthEnd = new Date(Date.UTC(year, month, 0))
    .toISOString()
    .slice(0, 10);
  const selectedDay =
    monthEnd > todayDay ? (key === today ? todayDay : null) : monthEnd;
  for (
    let movementIndex = 0;
    movementIndex < movements.length;
    movementIndex++
  ) {
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
    if (
      status === "Eseguito" &&
      type === "Trasferimento" &&
      account === "Trade Republic" &&
      counterpart === "Revolut" &&
      amount < 0
    ) {
      if (competence === key) {
        funded -= amount;
        fundedRows.add(number_(row[19]));
        if (actual && actual < key) prepaid -= amount;
      }
      if (actual === key && competence && competence > key)
        futureFunded -= amount;
    }
    const cashflowMonth = actual || String(row[20] || "");
    if (
      ["Trade Republic", "Revolut"].includes(account) &&
      cashflowMonth &&
      cashflowMonth.slice(0, 4) === String(year) &&
      status === "Eseguito"
    ) {
      const m = Number(cashflowMonth.slice(5, 7)) - 1;
      if ((type === "Entrata" || isSalaryMovement(row)) && amount > 0) {
        yearly[m].income += amount;
        yearly[m].hasRecords = true;
        const salaryMovement = isSalaryMovement(row);
        const source = salaryMovement
          ? "Stipendio"
          : /interessi/i.test(category)
            ? "Interessi"
            : /rimbors/i.test(category)
              ? "Rimborsi"
              : "Altre entrate";
        incomeSources[source] = (incomeSources[source] || 0) + amount;
      }
      if (type === "Spesa" && amount < 0) {
        yearly[m].spent -= amount;
        yearly[m].hasRecords = true;
        const flowCategory = normalizedCategory(row);
        monthlyCategories[cashflowMonth][flowCategory] =
          (monthlyCategories[cashflowMonth][flowCategory] || 0) - amount;
        if (cashflowMonth === key)
          categories[flowCategory] = (categories[flowCategory] || 0) - amount;
      }
    }
    if (
      status === "Eseguito" &&
      type === "Spesa" &&
      amount <= -180 &&
      actual &&
      actual.slice(0, 4) === String(year) &&
      !(String(row[9]) === "S\u00ec" && number_(row[8]) > 1) &&
      !/prestito a yousra/i.test(String(row[11] || "")) &&
      !/AUTOSERVICE MB|KLARNA|SWAPPIE/i.test(String(row[2])) &&
      !/^(Affitto|Utenze|Palestra|Abbonamenti)$/i.test(category)
    ) {
      const importId = String(row[14] || "");
      const registeredExtra = extras.some(
        (e) =>
          e.status !== "Annullato" &&
          ((importId && e.note.includes(importId)) ||
            (e.total === -amount &&
              e.start === actual &&
              String(row[2]).length >= 5 &&
              e.name.toLowerCase().includes(String(row[2]).toLowerCase()))),
      );
      if (!registeredExtra)
        candidates.push({
          date: dateIso_(row[1]),
          name: String(row[2]),
          amount: -amount,
          category,
          account,
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
        counterpart,
      });
    }
  }
  const payroll = payrollRows
    .filter((r) => r[0] instanceof Date)
    .map((r) => ({
      month: monthOf_(r[0]),
      competence: String(r[1]),
      amount: number_(r[2]),
      bank: number_(r[3]),
      internal: number_(r[4]),
      status: String(r[5]),
      source: String(r[6]),
      note: String(r[7]),
    }));
  // Media dei dodici mesi di accredito, con mensilit\u00e0 aggiuntive accreditate.
  // I bonifici interni, i buoni pasto e il welfare non sono stipendio.
  const creditedSalary = new Map();
  for (const row of movements) {
    if (
      String(row[4]) !== "Trade Republic" ||
      String(row[7]) !== "Eseguito" ||
      (String(row[6]) !== "Entrata" && !isSalaryMovement(row)) ||
      number_(row[3]) <= 0
    )
      continue;
    if (!isSalaryMovement(row)) continue;
    const creditMonth = monthOf_(row[1]);
    if (creditMonth)
      creditedSalary.set(
        creditMonth,
        (creditedSalary.get(creditMonth) || 0) + number_(row[3]),
      );
  }
  for (const item of payroll) {
    if (
      item.status === "Ricostruito" &&
      !creditedSalary.has(item.month) &&
      item.amount > 0
    )
      creditedSalary.set(item.month, item.amount);
  }
  const latestMonth = today < key ? today : key;
  const salaryMonths = Array.from({ length: 12 }, (_, i) => {
    const d = new Date(
      Date.UTC(
        Number(latestMonth.slice(0, 4)),
        Number(latestMonth.slice(5, 7)) - i - 1,
        1,
      ),
    );
    return d.toISOString().slice(0, 7);
  });
  if (salaryMonths.every((m) => creditedSalary.has(m))) {
    salary =
      Math.round(
        (salaryMonths.reduce((sum, m) => sum + creditedSalary.get(m), 0) /
          12) *
          100,
      ) / 100;
    salaryWindow = {
      from: salaryMonths[11],
      to: salaryMonths[0],
      months: 12,
      source: "accrediti e cedolini ricostruiti",
    };
  }
  const isAutoReserve = (e) =>
    e.repeat === "Annuale" &&
    /^(Assicurazione auto|Bollo auto|Manutenzione auto)\b/i.test(e.name);
  const planMonth = (monthKey) =>
    (extraPlan?.allocations || []).filter(
      (a) =>
        a.month === monthKey &&
        a.status !== "Annullato" &&
        !(
          a.status === "Pagato" &&
          a.paid_date &&
          monthKey <= String(a.paid_date).slice(0, 7)
        ),
    );
  const planAuto = (a) =>
    /^(Assicurazione auto|Bollo auto|Manutenzione auto)\b/i.test(a.name);
  const hasAutoSchedule = extras.some(isAutoReserve);
  const activeExtras = (item) =>
    extras.filter(
      (e) =>
        (e.status === "Programmato" || e.status === "Anticipato") &&
        e.start &&
        e.start <= item.month &&
        (e.repeat === "Annuale" || e.end >= item.month),
    );
  for (const item of yearly) {
    const active = activeExtras(item),
      monthly = planMonth(item.month);
    item.carCommitments = extraPlan
      ? monthly
          .filter((a) => a.kind === "expense" && planAuto(a))
          .reduce((sum, a) => sum + a.amount_cents / 100, 0)
      : hasAutoSchedule
        ? active.filter(isAutoReserve).reduce((sum, e) => sum + e.quota, 0)
        : car;
    item.otherCommitments = extraPlan
      ? monthly
          .filter((a) => a.kind === "expense" && !planAuto(a))
          .reduce((sum, a) => sum + a.amount_cents / 100, 0)
      : active
          .filter((e) => !isAutoReserve(e))
          .reduce((sum, e) => sum + e.quota, 0);
    item.advanceOffset = extraPlan
      ? monthly
          .filter(
            (a) => a.kind === "budget_advance" && a.status === "Anticipato",
          )
          .reduce((sum, a) => sum + a.amount_cents / 100, 0)
      : 0;
    item.grossAdvanceOffset = item.advanceOffset;
    item.advanceOffset -= octoberAdvanceReconciliation(movements,item.month,todayDay,item.advanceOffset).returned;
    item.extraCommitments = item.carCommitments + item.otherCommitments;
    item.commitments =
      rent + item.carCommitments + utilityEstimates(baseRecurring,movements,item.month,todayDay,utilitySettings).filter(r=>r.treatment==="Vincolata").reduce((n,r)=>n+r.estimate,0) + item.otherCommitments;
    item.spendable = salary - item.commitments - item.advanceOffset;
    item.net = item.income - item.spent;
  }
  selectedTransactions.sort((a, b) => b.date.localeCompare(a.date));
  const absorbedNow = extras
    .filter((e) => e.status === "Anticipato" && e.start === key)
    .reduce((sum, e) => sum + e.total, 0);
  const absorbedFuture = extras
    .filter((e) => e.status === "Anticipato" && e.start > key)
    .reduce((sum, e) => sum + e.total, 0);
  const allowedRecurring = [
    "Elettricit\u00e0",
    "Gas",
    "Acqua",
    "Palestra",
    "Abbonamenti",
    "Benzina",
  ];
  const bankHistory = movements
    .filter(
      (r) =>
        r[1] instanceof Date &&
        r[6] === "Spesa" &&
        r[7] === "Eseguito" &&
        allowedRecurring.includes(String(r[5])) &&
        number_(r[3]) < 0,
    )
    .map((r) => ({
      date: dateIso_(r[1]),
      name: String(r[5]),
      paid: -number_(r[3]),
      note: String(r[11] || ""),
      months: Math.max(1, number_(r[8])),
    }));
  const welfare = recurringRows
    .filter((r) => String(r[1]) === "Benzina welfare")
    .map((r) => ({
      date: dateIso_(r[0]),
      name: "Benzina welfare",
      paid: number_(r[2]),
      note: String(r[3] || ""),
      months: 0,
    }));
  const history = bankHistory
    .concat(welfare)
    .sort((a, b) => b.date.localeCompare(a.date));
  const averages = recurring.map((r) => {
    const rows = bankHistory.filter((h) => h.name === r.name);
    return {
      name: r.name,
      count: rows.length,
      mean: rows.length
        ? rows.reduce((sum, h) => sum + h.paid, 0) /
          rows.reduce((sum, h) => sum + h.months, 0)
        : null,
    };
  });
  const selected = yearly[month - 1];
  revolut =
    salary -
    rent -
    selected.carCommitments -
    selected.otherCommitments -
    selected.advanceOffset;
  baseFree = revolut - reserved;
  // Le quote degli anticipi sono gi\u00e0 sottratte: escludi dal finanziamento
  // soltanto gli importi collegati e gi\u00e0 attribuiti a questo mese.
  const advanceFundingOffset = extraPlan
    ? planMonth(key)
        .filter(
          (a) => a.kind === "budget_advance" && a.status === "Anticipato",
        )
        .reduce(
          (sum, a) =>
            sum +
            Math.min(
              a.amount_cents,
              (extraPlan.links || [])
                .filter(
                  (l) =>
                    l.cycle_id === a.cycle_id &&
                    l.role === "budget_advance" &&
                    fundedRows.has(l.movement_source_row),
                )
                .reduce((cents, l) => cents + l.attributed_cents, 0),
            ) /
              100,
          0,
        )
    : 0;
  const fundedOutsideAdvance = Math.max(0, funded - advanceFundingOffset);
  const annualCosts = hasAutoSchedule
    ? activeExtras(selected)
        .filter(isAutoReserve)
        .map((e) => ({ name: e.name, monthly: e.quota, yearly: e.total }))
    : annualCostDefaults;
  const reservedNames = [
    "Elettricit\u00e0",
    "Gas",
    "Acqua",
    "Palestra",
    "Abbonamenti",
  ];
  const linkedPayments = new Set(
    (extraPlan?.links || [])
      .filter((l) => l.role === "payment")
      .map((l) => l.movement_source_row),
  );
  const coveredAdvanceRows = new Set([...octoberAdvanceReconciliation(movements,key,todayDay,selected.grossAdvanceOffset).covered].map(r=>Number(r[19])));
  const rawUsedFree = selectedTransactions
    .filter(
      (t) =>
        (t.account === "Revolut" || t.account === "Trade Republic") &&
        (t.type === "Spesa" || t.type === "Entrata") &&
        !linkedPayments.has(t.row) &&
        !coveredAdvanceRows.has(Number(t.row)) &&
        t.category !== "Affitto" &&
        !reservedNames.includes(t.category) &&
        !(
          t.type === "Entrata" &&
          !/rimbors|refund|storno/i.test(t.category + " " + t.name)
        ),
    )
    .reduce((sum, t) => sum - t.amount, 0);
  const borrowedThisMonth = extras
    .filter(
      (e) => e.status === "Anticipato" && e.start > key && e.paidAt === key,
    )
    .reduce((sum, e) => sum + e.total, 0);
  const usedFromFuture = Math.min(
    Math.max(0, rawUsedFree - selected.spendable),
    borrowedThisMonth,
  );
  const usedFree = rawUsedFree;
  const commitmentCategories = [
    { name: "Affitto", amount: rent },
    { name: "Auto, accantonamento", amount: selected.carCommitments },
    ...recurring
      .filter((r) => r.treatment === "Vincolata")
      .map((r) => ({ name: r.name, amount: r.estimate })),
    ...(extraPlan
      ? planMonth(key)
          .filter((a) => a.kind === "expense" && !planAuto(a))
          .map((a) => ({ name: a.name, amount: a.amount_cents / 100 }))
      : activeExtras(selected)
          .filter((e) => !isAutoReserve(e))
          .map((e) => ({ name: e.name, amount: e.quota }))),
  ].filter((x) => x.amount > 0);
  const currentRecurring=utilityEstimates(baseRecurring,movements,today,todayDay,utilitySettings);
  const currentSettlements=monthlyBudgetAmounts({salary,rent,recurring:currentRecurring,movements,
    month:today,todayDay,extraPlan,extras}).monthlyFixedSettlements;
  const recurringCommitments = currentRecurring
    .filter(r=>r.treatment==="Vincolata" && r.name!=="Benzina")
    .map(r=>{
      const settlement=currentSettlements.find(x=>x.name===r.name);
      return {name:r.name,estimate:r.estimate,paid:settlement?.paid||0,
        remaining:settlement ? 0 : r.estimate};
    });
  const rentSettlement=currentSettlements.find(x=>x.name==="Affitto"),rentPaid=rentSettlement?.paid||0;
  const currentExtraReserves = extraPlan
    ? planMonth(today).filter((a) => a.kind === "expense")
        .reduce((n,a) => n + a.amount_cents / 100,0)
    : activeExtras({month:today}).reduce((n,e) => n + e.quota,0);
  const currentCarFallback = !extraPlan && !hasAutoSchedule ? car : 0;
  const commitmentDetails = [
    ...recurringCommitments,
    {name:"Affitto",estimate:rent,paid:rentPaid,remaining:rentSettlement ? 0 : rent},
    {name:"Straordinarie e auto",estimate:currentExtraReserves + currentCarFallback,
      paid:0,remaining:currentExtraReserves + currentCarFallback},
  ];
  const committedCurrent = Math.round(commitmentDetails.reduce((n,r) => n+r.remaining,0)*100)/100;
  const currentSpendable =
    Math.round((currentAssets - committedCurrent) * 100) / 100;
  const monthlyBudget = monthlyBudgetAmounts({
    salary, rent, recurring, movements, month:key, todayDay, extraPlan, extras,
    carFallback: !extraPlan && !hasAutoSchedule ? car : 0,
  });
  if (lightweight)
    return {
      year,
      month,
      key,
      today,
      appVersion: APP_VERSION,
      updatedAt: Utilities.formatDate(new Date(), TZ, "dd/MM/yyyy HH:mm"),
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
        assetDate: dateIso_(assets[1][2]),
      },
      recurring,
      extras,
      transactions: selectedTransactions,
      candidates: [],
      extraPlan,
      categoryOptions: [],
    };
  const goalCell = budget[12] && budget[12][14];
  const goal =
    goalCell === "" || goalCell === null || goalCell === undefined
      ? null
      : number_(goalCell);
  const monthlySaving = Math.max(0, number_(budget[13] && budget[13][14]));
  const monthsRemaining = 12 - Number(Utilities.formatDate(now, TZ, "M"));
  const planning = {
    year: Number(Utilities.formatDate(now, TZ, "yyyy")),
    goal,
    monthlySaving,
    monthsRemaining,
    now: currentAssets,
    projection: currentAssets + monthlySaving * monthsRemaining,
  };
  Object.assign(
    planning,
    planningAmounts(currentAssets, goal, monthlySaving, monthsRemaining),
  );
  const snapshotDay = dateIso_(assets[1][2]);
  const anchorBalance = number_(assets[1][1]);
  const trMovements = movements
    .map((r, i) => ({
      date: dateIso_(r[1]),
      amount: number_(r[3]),
      account: String(r[4]),
      status: String(r[7]),
      source: String(r[13]),
      row: i + 2,
    }))
    .filter(
      (r) =>
        r.account === "Trade Republic" && r.status === "Eseguito" && r.date,
    );
  const firstTrDate = trMovements.reduce(
    (min, r) => (min && min < r.date ? min : r.date),
    "",
  );
  const snapshots = assetHistoryRows
    .filter((r) => r[0] instanceof Date && typeof r[1] === "number")
    .map((r) => ({
      date: dateIso_(r[0]),
      month: monthOf_(r[0]),
      amount: number_(r[1]),
      source: String(r[2] || "Rilevazione"),
    }));
  const wealthHistory = yearly.map((item) => {
    const following = new Date(
      Date.UTC(year, Number(item.month.slice(5)), 1),
    );
    const end = new Date(following.getTime() - 86400000)
      .toISOString()
      .slice(0, 10);
    const available =
      item.month <= today && firstTrDate && firstTrDate <= end;
    let estimate = null;
    if (available && snapshotDay) {
      if (end < snapshotDay)
        estimate =
          anchorBalance -
          trMovements
            .filter((r) => r.date > end && r.date <= snapshotDay)
            .reduce((n, r) => n + r.amount, 0);
      else
        estimate = balanceAt(
          "Trade Republic",
          end > todayDay && item.month === today ? todayDay : end,
        );
    }
    const measured = snapshots
      .filter((x) => x.month === item.month)
      .sort((a, b) => b.date.localeCompare(a.date))[0];
    return {
      month: item.month,
      estimated: estimate,
      measured: measured ? measured.amount : null,
      measuredDate: measured?.date || "",
    };
  });
  // Historical analytics are separate from budget and bank cash flow.

  /** Categoria risolta per i report, con fallback a quella importata. */
  function normalizedCategory(r) {
    return String(r[21] || r[5] || "Da classificare");
  }
  // Payslip competence is separate from actual bank credit dates and balances.
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
    "dic",
  ];
  const salaryHistory = payslipRows
    .flatMap((r) => {
      const match = String(r[0] || "")
        .trim()
        .toLowerCase()
        .match(/^([a-z]{3})\s+(\d{2}|\d{4})$/);
      if (
        !match ||
        !italianMonths.includes(match[1]) ||
        r[1] === null ||
        r[1] === ""
      )
        return [];
      const y =
        match[2].length === 2 ? 2000 + Number(match[2]) : Number(match[2]);
      const competence = ym_(y, italianMonths.indexOf(match[1]) + 1);
      if (competence > today) return [];
      return [
        {
          month: competence,
          base: number_(r[1]),
          additional: number_(r[5]),
          gross: number_(r[1]) + number_(r[5]),
        },
      ];
    })
    .sort((a, b) => a.month.localeCompare(b.month));
  const payrollGross = salaryHistory.reduce((n, r) => n + r.gross, 0);
  const taxRefund = salaryHistory.some((r) => r.month.startsWith("2025-"))
    ? 930
    : 0;
  const salaryHistoryTotal = payrollGross - taxRefund;
  const salaryHistoryYears = [
    ...new Set(salaryHistory.map((r) => r.month.slice(0, 4))),
  ].map((y) => ({
    year: Number(y),
    gross: salaryHistory
      .filter((r) => r.month.startsWith(y))
      .reduce((n, r) => n + r.gross, 0),
    refund: y === "2025" ? taxRefund : 0,
    salary:
      salaryHistory
        .filter((r) => r.month.startsWith(y))
        .reduce((n, r) => n + r.gross, 0) - (y === "2025" ? taxRefund : 0),
  }));
  const lifetimeMonths = new Map(),
    lifetimeSources = {},
    lifetimeExpenses = {},
    incomeAudit = [],
    expenseAudit = [],
    investmentGroups = new Map();
  for (const r of movements) {
    const day = dateIso_(r[1]),
      m = monthOf_(r[1]),
      amount = number_(r[3]),
      account = String(r[4]),
      type = String(r[6]);
    if (!day || day > todayDay || String(r[7]) !== "Eseguito") continue;
    if (!lifetimeMonths.has(m))
      lifetimeMonths.set(m, {
        month: m,
        income: 0,
        spent: 0,
        hasRecords: true,
      });
    const item = lifetimeMonths.get(m);
    if (
      account === "Trade Republic" &&
      type === "Investimento" &&
      !(amount > 0 && isSalaryMovement(r))
    ) {
      const text = String(r[2]),
        codes = [...text.matchAll(/\b[A-Z]{2}[A-Z0-9]{9}[0-9]\b/g)].map(
          (x) => x[0],
        ),
        isin = codes[0] || "Senza ISIN";
      const qtyMatch = text.match(/quantity:\s*([\d.]+)/i),
        qty = qtyMatch ? Number(qtyMatch[1]) : null;
      if (!investmentGroups.has(isin))
        investmentGroups.set(isin, {
          isin,
          bought: 0,
          sold: 0,
          buyQty: 0,
          sellQty: 0,
          invalid: false,
          lastDay: day,
          rows: [],
        });
      const g = investmentGroups.get(isin);
      g.lastDay = g.lastDay > day ? g.lastDay : day;
      g.rows.push({ date: day, name: text, amount, quantity: qty });
      if (amount < 0) {
        g.bought -= amount;
        g.buyQty += qty || 0;
      } else {
        g.sold += amount;
        g.sellQty += qty || 0;
      }
      if (
        codes.length !== 1 ||
        qty === null ||
        !Number.isFinite(qty) ||
        qty <= 0 ||
        (/buy trade|savings plan|ordine d'acquisto/i.test(text) &&
          amount > 0) ||
        (/sell trade/i.test(text) && amount < 0)
      )
        g.invalid = true;
    }
    if (
      account === "Trade Republic" &&
      (type === "Entrata" || isSalaryMovement(r)) &&
      amount > 0
    ) {
      const source = isSalaryMovement(r)
        ? "Stipendio"
        : /rimbors/i.test(String(r[5]) + " " + r[2])
          ? "Rimborsi"
          : /interess|interest|dividend/i.test(String(r[5]) + " " + r[2])
            ? "Interessi"
            : "Altre entrate";
      if (
        source !== "Stipendio" ||
        !salaryHistory.some((p) => p.month === m)
      ) {
        item.income += amount;
        lifetimeSources[source] = (lifetimeSources[source] || 0) + amount;
      }
      incomeAudit.push({ date: day, name: String(r[2]), amount, source });
    }

    const internal =
      type === "Trasferimento" &&
      (/Revolut|Trade Republic|IsyBank|EasyBank/i.test(String(r[10])) ||
        /ZEROUAL ANASS|ANASS ZEROUAL/i.test(String(r[2])));
    if (
      amount < 0 &&
      ["Revolut", "Trade Republic"].includes(account) &&
      ["Spesa", "Trasferimento"].includes(type) &&
      !internal
    ) {
      item.spent -= amount;
      const cat = normalizedCategory(r);
      lifetimeExpenses[cat] = (lifetimeExpenses[cat] || 0) - amount;
      expenseAudit.push({
        row: number_(r[19]),
        date: day,
        name: String(r[2]),
        amount: -amount,
        category: cat,
        account,
        estimated: false,
      });
    }
  }
  if (salaryHistory.length) {
    lifetimeSources.Stipendio =
      (lifetimeSources.Stipendio || 0) + salaryHistoryTotal;
    lifetimeSources["Rimborso 730"] = taxRefund;
    for (const r of salaryHistory) {
      if (!lifetimeMonths.has(r.month))
        lifetimeMonths.set(r.month, {
          month: r.month,
          income: 0,
          spent: 0,
          hasRecords: true,
        });
      lifetimeMonths.get(r.month).income += r.gross;
    }
  }
  for (const g of investmentGroups.values()) {
    const prices = g.rows
      .filter((r) => r.quantity > 0 && r.amount !== 0)
      .map((r) => Math.abs(r.amount) / r.quantity);
    // A large unit-price discontinuity indicates a balance/amount import error.
    if (prices.length > 1 && Math.max(...prices) / Math.min(...prices) > 10)
      g.invalid = true;
  }
  const investmentAudit = [...investmentGroups.values()].map((g) => ({
    ...g,
    net: Math.round((g.sold - g.bought) * 100) / 100,
    reconciled:
      !g.invalid &&
      g.buyQty > 0 &&
      Math.abs(g.buyQty - g.sellQty) <= Math.max(0.0001, g.buyQty * 0.000001),
  }));
  const investmentTotals = investmentAudit.reduce(
    (t, g) => ({
      bought: t.bought + g.bought,
      sold: t.sold + g.sold,
      net: t.net + g.net,
    }),
    { bought: 0, sold: 0, net: 0 },
  );
  // Only fully closed, quantity-matched instruments contribute a net result.
  const investmentConfirmed = investmentAudit
    .filter((g) => g.reconciled)
    .reduce((n, g) => n + g.net, 0);
  // Reconciled bank cash flow is not the same as realised investment performance.
  const investmentCashRows = movements.filter(
    (r) =>
      String(r[4]) === "Trade Republic" &&
      String(r[6]) === "Investimento" &&
      String(r[7]) === "Eseguito" &&
      dateIso_(r[1]) <= todayDay,
  );
  const investmentCashNet =
    investmentCashRows.reduce(
      (n, r) => n + Math.round(number_(r[3]) * 100),
      0,
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
    for (const g of investmentAudit.filter((g) => g.reconciled)) {
      const m = lifetimeMonths.get(g.lastDay.slice(0, 7));
      if (m) {
        if (g.net > 0) m.income += g.net;
        else m.spent -= g.net;
      }
      if (g.net > 0)
        lifetimeSources["Utili investimenti - parziale"] =
          (lifetimeSources["Utili investimenti - parziale"] || 0) + g.net;
      if (g.net < 0)
        lifetimeExpenses["Perdite investimenti - parziale"] =
          (lifetimeExpenses["Perdite investimenti - parziale"] || 0) - g.net;
    }
  }
  const lifetimeSeries = [...lifetimeMonths.values()]
    .sort((a, b) => a.month.localeCompare(b.month))
    .map((item) => {
      const end = new Date(
        Date.UTC(
          Number(item.month.slice(0, 4)),
          Number(item.month.slice(5)),
          0,
        ),
      )
        .toISOString()
        .slice(0, 10);
      let wealth = null;
      const target = end > todayDay ? todayDay : end;
      const recorded = snapshots
        .filter((x) => x.month === item.month && x.date <= target)
        .sort((a, b) => a.date.localeCompare(b.date))
        .at(-1);
      if (recorded) wealth = recorded.amount;
      if (
        trProof ||
        bankSnapshots.some(
          (x) => x.account === "Trade Republic" && x.as_of_day <= target,
        )
      )
        wealth = balanceAt("Trade Republic", target);
      if (item.month === today) wealth = currentAssets;
      const revolut = balanceAt("Revolut", target);
      const liquidWealth =
        item.month === today
          ? Math.round((currentAssets + currentRevolut) * 100) / 100
          : Number.isFinite(wealth) && Number.isFinite(revolut)
            ? Math.round((wealth + revolut) * 100) / 100
            : null;
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
      amount,
    })),
    expenses: Object.entries(lifetimeExpenses)
      .map(([name, amount]) => ({ name, amount, estimated: false }))
      .sort((a, b) => b.amount - a.amount),
    investmentCashNet,
    statement: trProof
      ? {
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
          cashflow: trProof.cashflow,
        }
      : null,
    salaryHistory,
    salaryHistoryYears,
    salaryHistoryTotal,
    taxRefund,
    salaryHistoryBasis: salaryHistory.length
      ? "cedolini per competenza"
      : "accrediti TR",
    expenseAudit,
    investmentAudit,
    investmentTotals,
    investmentConfirmed,
    salaryAverageReview:
      taxRefund > 0
        ? "Mese del rimborso 730 2025 da confermare; media da accrediti verificati conservata."
        : "",
    incomeAudit: incomeAudit.sort((a, b) => b.date.localeCompare(a.date)),
  };
  const databaseCategories =
    book
      .getSheetByName("Categorie finanziarie")
      .getRange("A1:A1")
      .getValues()[0][0] || [];
  lifetime.expenseGroups = databaseCategories.map((c) => ({
    id: c.id,
    name: c.name,
    members: [...c.members],
    amount: 0,
  }));
  const byDetail = new Map();
  for (const r of movements)
    byDetail.set(normalizedCategory(r), number_(r[22]) || 10);
  for (const c of lifetime.expenses) {
    const group =
      lifetime.expenseGroups.find((g) => g.id === byDetail.get(c.name)) ||
      lifetime.expenseGroups.find((g) => g.id === 10);
    if (!group) throw Error("Categorie finanziarie non inizializzate.");
    if (!group.members.includes(c.name)) group.members.push(c.name);
    group.amount += c.amount;
  }
  lifetime.expenseGroups = lifetime.expenseGroups
    .filter((g) => g.amount > 0)
    .map((g) => ({
      ...g,
      percentage: lifetime.spent
        ? Math.round((g.amount / lifetime.spent) * 100)
        : 0,
    }))
    .sort((a, b) => b.amount - a.amount);
  const bankAudit = ["Trade Republic", "Revolut"].map((account) => {
    const rows = movements.filter(
      (r) =>
        String(r[4]) === account &&
        String(r[7]) === "Eseguito" &&
        dateIso_(r[1]) &&
        dateIso_(r[1]) <= todayDay,
    );
    const dates = rows.map((r) => dateIso_(r[1])).sort();
    return {
      account,
      from: dates[0] || null,
      to: dates.at(-1) || null,
      count: rows.length,
      rawNet:
        Math.round(rows.reduce((n, r) => n + number_(r[3]), 0) * 100) / 100,
      balance: account === "Trade Republic" ? currentAssets : currentRevolut,
    };
  });
  const suspiciousTransfers = movements
    .filter(
      (r) =>
        String(r[4]) === "Trade Republic" &&
        String(r[6]) === "Trasferimento" &&
        String(r[7]) === "Eseguito" &&
        number_(r[3]) <= -2500,
    )
    .map((r) => ({
      row: number_(r[19]),
      date: dateIso_(r[1]),
      name: String(r[2]),
      amount: number_(r[3]),
      counterpart: String(r[10]),
    }));
  const creditedSalaryTotal = incomeAudit
    .filter((r) => r.source === "Stipendio")
    .reduce((n, r) => n + r.amount, 0);
  const cashTotal = currentAssets;
  lifetime.reconciliation = {
    status: "incomplete",
    cashTotal,
    tradeRepublic: currentAssets,
    revolut: currentRevolut,
    recordedFlowDifference:
      Math.round((lifetime.income - lifetime.spent) * 100) / 100,
    unexplainedDifference:
      Math.round((lifetime.income - lifetime.spent - cashTotal) * 100) / 100,
    // Comparison only: not a balancing expense, opening balance, or investment loss.
    openingBalanceKnown: false,
    creditedSalaryTotal,
    payslipSalaryWithoutTrCredit:
      Math.round((salaryHistoryTotal - creditedSalaryTotal) * 100) / 100,
    tradeRepublicStatementVerified: !!trProof && !trProof.conflicts?.length,
    missingAccounts: [
      "IsyBank / EasyBank: movimenti storici non disponibili",
    ],
    bankAudit,
    suspiciousTransfers,
  };
  const monthlyBreakdowns = Object.fromEntries(
    yearly.map((item) => {
      const all = Object.entries(monthlyCategories[item.month] || {})
        .filter((x) => x[1] > 0)
        .sort((a, b) => b[1] - a[1]);
      const total = all.reduce((n, x) => n + x[1], 0),
        top = all.slice(0, 5),
        other = all.slice(5).reduce((n, x) => n + x[1], 0);
      if (other) top.push(["Altre", other]);
      let position = 0;
      const items = top.map(([name, amount]) => {
        const start = position;
        position += total ? (amount / total) * 100 : 0;
        return {
          name,
          amount,
          start,
          end: position,
          bar: top[0]?.[1] ? Math.round((amount / top[0][1]) * 100) : 0,
        };
      });
      const commitments = [
        { name: "Affitto", amount: rent },
        { name: "Auto, accantonamento", amount: item.carCommitments },
        ...recurring
          .filter((r) => r.treatment === "Vincolata")
          .map((r) => ({ name: r.name, amount: r.estimate })),
        ...(extraPlan
          ? planMonth(item.month)
              .filter((a) => a.kind === "expense" && !planAuto(a))
              .map((a) => ({ name: a.name, amount: a.amount_cents / 100 }))
          : activeExtras(item)
              .filter((e) => !isAutoReserve(e))
              .map((e) => ({ name: e.name, amount: e.quota }))),
      ].filter((x) => x.amount > 0);
      return [
        item.month,
        { total, items, commitments, commitmentTotal: item.commitments },
      ];
    }),
  );
  for (const item of yearly) {
    const policy = monthlyBudgetAmounts({salary,
      rent:rentEstimate(number_(budget[2][14]),item.month,extraPlan?.rentSplit),
      recurring:utilityEstimates(baseRecurring,movements,item.month,todayDay,utilitySettings),
      movements,month:item.month,todayDay,extraPlan,extras,
      carFallback:hasAutoSchedule?0:car});
    item.budgetCommitments=policy.monthlyCommitted;
    item.monthlyRemaining=policy.monthlyRemaining;
  }
  const yearTotal = yearly.reduce(
    (o, m) => ({
      income: o.income + m.income,
      incomePayslip: o.incomePayslip + m.incomePayslip,
      spent: o.spent + m.spent,
      net: o.net + m.net,
      commitments: o.commitments + (m.budgetCommitments ?? m.commitments),
      spendable: 0,
    }),
    {
      income: 0,
      incomePayslip: 0,
      spent: 0,
      net: 0,
      commitments: 0,
      spendable: 0,
    },
  );
  return {
    year,
    month,
    key,
    appVersion: APP_VERSION,
    updatedAt: Utilities.formatDate(new Date(), TZ, "dd/MM/yyyy HH:mm"),
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
      assetMonthBalance: selectedDay
        ? balanceAt("Trade Republic", selectedDay)
        : null,
      assetDate: dateIso_(assets[1][2]),
      revolutBalance: currentRevolut,
      revolutMonthBalance: selectedDay
        ? balanceAt("Revolut", selectedDay)
        : null,
      balanceDate,
      usedFree,
      rawUsedFree,
      usedFromFuture,
      borrowedThisMonth,
      remainingBeforeAdvance: selected.spendable - rawUsedFree,
      budget: currentAssets,
      committedCurrent,
      recurringCommitments: commitmentDetails,
      remainingFree: currentSpendable,
    },
    lifetime,
    yearly,
    wealthHistory,
    snapshots,
    planning,
    incomeSources: Object.entries(incomeSources)
      .filter(([_, amount]) => amount > 0)
      .map(([name, amount]) => ({ name, amount, estimated: false }))
      .sort((a, b) => b.amount - a.amount),
    categories: Object.entries(categories)
      .filter(([_, amount]) => amount > 0)
      .map(([name, amount]) => ({ name, amount }))
      .sort((a, b) => b.amount - a.amount),
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
    dataNote:
      year === 2026
        ? "Gennaio-marzo: gli accrediti IsyBank ricostruiti dai cedolini servono solo alla media di riferimento. I bonifici verso Trade Republic restano trasferimenti interni, non entrate reali."
        : "",
  };


  /** Chiave anno-mese zero-padded. */
  function ym_(year, month) {
    return String(year) + "-" + ("0" + month).slice(-2);
  }

  /** Valida interi in un intervallo; usa il fallback per input non validi. */
  function boundedInteger_(value, min, max, fallback) {
    const n = Number(value);
    return Number.isInteger(n) && n >= min && n <= max ? n : fallback;
  }

  /** Conversione numerica tollerante degli import legacy; non usare per validare scritture. */
  function number_(value) {
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
  }

  /** Estrae il mese dalla rappresentazione data del workbook compatibile. */
  function monthOf_(date) { return dateIso_(date).slice(0, 7); }

  /** Data civile ISO della rappresentazione workbook. */
  function dateIso_(date) {
    return date instanceof Date && !Number.isNaN(date.getTime())
      ? date.toISOString().slice(0, 10)
      : "";
  }

}

const TR_STATEMENT_PROOF = {
  version: 2,
  from: "2025-08-01",
  to: "2026-09-29",
  opening: 0,
  closing: 662800,
  incoming: 10650637,
  outgoing: 9987837,
  rows: /** @type {Array<[string, string, number, number, string, string]>} */ ([
    ["TR-0001","2025-08-30",149870,149870,"Trasferimento","Incoming transfer from Anass Zeroual"],
    ["TR-0002","2025-08-30",155000,304870,"Trasferimento","Incoming transfer from Anass Zeroual"],
    ["TR-0003","2025-08-31",-317,304553,"Spesa","PENNY MARKET S.R.L."],
    ["TR-0004","2025-09-01",24,304577,"Entrata","Interest payment"],
    ["TR-0005","2025-09-01",-200666,103911,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 17.0"],
    ["TR-0006","2025-09-01",-9434,94477,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 0.799627"],
    ["TR-0007","2025-09-01",-35100,59377,"Investimento","Buy trade US67066G1040 NVIDIA CORP. DL-,001, quantity: 2.364864"],
    ["TR-0008","2025-09-01",-35100,24277,"Investimento","Buy trade US5949181045 MICROSOFT DL-,00000625, quantity: 0.810372"],
    ["TR-0009","2025-09-01",-530,23747,"Spesa","PASTICCERIA LE GINESTRE"],
    ["TR-0010","2025-09-02",400000,423747,"Trasferimento","Incoming transfer from ZEROUAL ANASS"],
    ["TR-0011","2025-09-02",-35000,388747,"Investimento","Buy trade IE00BGV5VN51 Xtrackers (IE) Plc - Xtrackers Artificial Intelligence & Big Data UCITS ETF 1C 1C, quantity: 2.504305"],
    ["TR-0012","2025-09-02",-32125,356622,"Investimento","Buy trade LU1834988609 MULTI UNITS LUXEMBOURG - Amundi STOXX Europe 600 Telecommunications UCITS ETF Acc, quantity: 7"],
    ["TR-0013","2025-09-02",-2875,353747,"Investimento","Buy trade LU1834988609 MULTI UNITS LUXEMBOURG - Amundi STOXX Europe 600 Telecommunications UCITS ETF Acc, quantity: 0.628415"],
    ["TR-0014","2025-09-02",-6838,346909,"Investimento","Buy trade LU0292104030 Xtrackers - Xtrackers MSCI Europe Communication Services Screened UCITS ETF 1C, quantity: 0.731024"],
    ["TR-0015","2025-09-02",-28162,318747,"Investimento","Buy trade LU0292104030 Xtrackers - Xtrackers MSCI Europe Communication Services Screened UCITS ETF 1C, quantity: 3"],
    ["TR-0016","2025-09-02",-35025,283722,"Investimento","Buy trade IE00B4LN9N13 iShares V plc - iShares S&P 500 Industrials Sector UCITS ETF USD (Acc), quantity: 32.0"],
    ["TR-0017","2025-09-02",-75,283647,"Investimento","Buy trade IE00B4LN9N13 iShares V plc - iShares S&P 500 Industrials Sector UCITS ETF USD (Acc), quantity: 0.068902"],
    ["TR-0018","2025-09-02",-23195,260452,"Investimento","Buy trade DE0007164600 SAP SE, quantity: 1.002604"],
    ["TR-0019","2025-09-02",-146,260306,"Investimento","Buy trade IT0005599938 FINCANTIERI SPA O.N., quantity: 0.075765"],
    ["TR-0020","2025-09-02",-3958,256348,"Investimento","Buy trade IT0005599938 FINCANTIERI SPA O.N., quantity: 2.0"],
    ["TR-0021","2025-09-02",-6297,250051,"Investimento","Buy trade XF000BTC0017 Bitcoin, quantity: 0.000645"],
    ["TR-0022","2025-09-05",-1767,248284,"Investimento","Buy trade IT0005599938 FINCANTIERI SPA O.N., quantity: 0.924235"],
    ["TR-0023","2025-09-05",-42162,206122,"Investimento","Buy trade IT0005599938 FINCANTIERI SPA O.N., quantity: 22.0"],
    ["TR-0024","2025-09-10",158800,364922,"Entrata","Incoming transfer from VAR4YOU S.R.L."],
    ["TR-0025","2025-09-11",-3768,361154,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 0.306291"],
    ["TR-0026","2025-09-11",-196916,164238,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 16.0"],
    ["TR-0027","2025-09-12",35634,199872,"Investimento","Sell trade US67066G1040 NVIDIA CORP. DL-,001, quantity: 2.364864"],
    ["TR-0028","2025-09-16",-500,199372,"Investimento","Savings plan execution DE000A0H08F7 iShares (DE) I InvAG mit TGV - iShares STOXX Europe 600 Construction & Materials UCITS ETF (DE) EUR (Dist), quantity: 0.058227"],
    ["TR-0029","2025-09-16",-5000,194372,"Investimento","Savings plan execution FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 0.402317"],
    ["TR-0030","2025-09-16",-500,193872,"Investimento","Savings plan execution IE00BKWQ0J47 SSGA SPDR ETFs Europe II plc - SPDR MSCI Europe Industrials UCITS ETF EUR, quantity: 0.012703"],
    ["TR-0031","2025-09-16",-2000,191872,"Investimento","Savings plan execution IE00BGV5VN51 Xtrackers (IE) Plc - Xtrackers Artificial Intelligence & Big Data UCITS ETF 1C 1C, quantity: 0.137835"],
    ["TR-0032","2025-09-16",-2000,189872,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.211438"],
    ["TR-0033","2025-09-23",-500,189372,"Investimento","Savings plan execution DE000A0H08F7 iShares (DE) I InvAG mit TGV - iShares STOXX Europe 600 Construction & Materials UCITS ETF (DE) EUR (Dist), quantity: 0.058823"],
    ["TR-0034","2025-09-23",-5000,184372,"Investimento","Savings plan execution FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 0.394508"],
    ["TR-0035","2025-09-23",-500,183872,"Investimento","Savings plan execution IE00BKWQ0J47 SSGA SPDR ETFs Europe II plc - SPDR MSCI Europe Industrials UCITS ETF EUR, quantity: 0.012721"],
    ["TR-0036","2025-09-23",-2000,181872,"Investimento","Savings plan execution IE00BGV5VN51 Xtrackers (IE) Plc - Xtrackers Artificial Intelligence & Big Data UCITS ETF 1C 1C, quantity: 0.133386"],
    ["TR-0037","2025-09-24",-10000,171872,"Trasferimento","Revolut**9398*"],
    ["TR-0038","2025-09-24",51265,223137,"Investimento","Sell trade IT0005599938 FINCANTIERI SPA O.N., quantity: 25"],
    ["TR-0039","2025-09-25",-643,222494,"Investimento","Buy trade IT0005599938 FINCANTIERI SPA O.N., quantity: 0.303689"],
    ["TR-0040","2025-09-25",-99557,122937,"Investimento","Buy trade IT0005599938 FINCANTIERI SPA O.N., quantity: 47.0"],
    ["TR-0041","2025-09-25",100330,223267,"Investimento","Sell trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 8.0"],
    ["TR-0042","2025-09-25",11940,235207,"Investimento","Sell trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 0.951371"],
    ["TR-0043","2025-09-25",211690,446897,"Investimento","Sell trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 17"],
    ["TR-0044","2025-09-26",35043,481940,"Investimento","Sell trade IE00B4LN9N13 iShares V plc - iShares S&P 500 Industrials Sector UCITS ETF USD (Acc), quantity: 32.0"],
    ["TR-0045","2025-09-26",76,482016,"Investimento","Sell trade IE00B4LN9N13 iShares V plc - iShares S&P 500 Industrials Sector UCITS ETF USD (Acc), quantity: 0.068902"],
    ["TR-0046","2025-09-26",-243357,238659,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 19.0"],
    ["TR-0047","2025-09-26",-6743,231916,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 0.526673"],
    ["TR-0048","2025-09-29",-60000,171916,"Trasferimento","Revolut**9398*"],
    ["TR-0049","2025-09-29",6692,178608,"Investimento","Sell trade LU0292104030 Xtrackers - Xtrackers MSCI Europe Communication Services Screened UCITS ETF 1C, quantity: 0.731024"],
    ["TR-0050","2025-09-29",27362,205970,"Investimento","Sell trade LU0292104030 Xtrackers - Xtrackers MSCI Europe Communication Services Screened UCITS ETF 1C, quantity: 3"],
    ["TR-0051","2025-09-29",22429,228399,"Investimento","Sell trade DE0007164600 SAP SE, quantity: 1.002604"],
    ["TR-0052","2025-09-29",-227127,1272,"Investimento","Buy trade IT0004764699 BRUNELLO CUCINELLI, quantity: 25"],
    ["TR-0053","2025-09-30",35424,36696,"Investimento","Sell trade US5949181045 MICROSOFT DL-,00000625, quantity: 0.810372"],
    ["TR-0054","2025-10-01",223,36919,"Entrata","Interest payment"],
    ["TR-0055","2025-10-02",6171,43090,"Investimento","Sell trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 0.478045"],
    ["TR-0056","2025-10-02",115567,158657,"Investimento","Sell trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 9"],
    ["TR-0057","2025-10-02",665,159322,"Investimento","Sell trade IT0005599938 FINCANTIERI SPA O.N., quantity: 0.303689"],
    ["TR-0058","2025-10-02",243527,402849,"Investimento","Sell trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 19.0"],
    ["TR-0059","2025-10-02",101979,504828,"Investimento","Sell trade IT0005599938 FINCANTIERI SPA O.N., quantity: 47.0 Savings plan execution DE000A0H08F7 iShares (DE) I InvAG mit TGV -"],
    ["TR-0060","2025-10-02",-200,504628,"Investimento","iShares STOXX Europe 600 Construction & Materials UCITS ETF (DE) EUR (Dist), quantity: 0.023820"],
    ["TR-0061","2025-10-02",-2500,502128,"Investimento","Ordine d'acquisto sui private market"],
    ["TR-0062","2025-10-02",25,502153,"Investimento","Bonus 1% Private Markets"],
    ["TR-0063","2025-10-02",-25,502128,"Investimento","Ordine d'acquisto sui private market"],
    ["TR-0064","2025-10-02",-300,501828,"Investimento","Savings plan execution IE00BKWQ0J47 SSGA SPDR ETFs Europe II plc - SPDR MSCI Europe Industrials UCITS ETF EUR, quantity: 0.007434"],
    ["TR-0065","2025-10-02",-2000,499828,"Investimento","Savings plan execution IE00BGV5VN51 Xtrackers (IE) Plc - Xtrackers Artificial Intelligence & Big Data UCITS ETF 1C 1C, quantity: 0.132590"],
    ["TR-0066","2025-10-02",-1000,498828,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.099900"],
    ["TR-0067","2025-10-03",-263363,235465,"Investimento","Buy trade IT0005599938 FINCANTIERI SPA O.N., quantity: 100"],
    ["TR-0068","2025-10-03",262900,498365,"Investimento","Sell trade IT0005599938 FINCANTIERI SPA O.N., quantity: 100"],
    ["TR-0069","2025-10-03",-92042,406323,"Investimento","Buy trade IT0004729759 SESA S.P.A., quantity: 10"],
    ["TR-0070","2025-10-07",-56,406267,"Spesa","Stamp Duty Tax (Portfolio)"],
    ["TR-0071","2025-10-07",92050,498317,"Investimento","Sell trade IT0004729759 SESA S.P.A., quantity: 10"],
    ["TR-0072","2025-10-08",-20000,478317,"Trasferimento","Revolut**9398*"],
    ["TR-0073","2025-10-08",-233183,245134,"Investimento","Buy trade IT0004764699 BRUNELLO CUCINELLI, quantity: 25"],
    ["TR-0074","2025-10-08",31544,276678,"Investimento","Sell trade LU1834988609 MULTI UNITS LUXEMBOURG - Amundi STOXX Europe 600 Telecommunications UCITS ETF Acc, quantity: 7.0"],
    ["TR-0075","2025-10-08",2841,279519,"Investimento","Sell trade LU1834988609 MULTI UNITS LUXEMBOURG - Amundi STOXX Europe 600 Telecommunications UCITS ETF Acc, quantity: 0.628415"],
    ["TR-0076","2025-10-08",-690400,-410881,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 50 Savings plan execution DE000A0H08F7 iShares (DE) I InvAG mit TGV -"],
    ["TR-0077","2025-10-09",-200,-411081,"Investimento","iShares STOXX Europe 600 Construction & Materials UCITS ETF (DE) EUR (Dist), quantity: 0.023721"],
    ["TR-0078","2025-10-09",-300,-411381,"Investimento","Savings plan execution IE00BKWQ0J47 SSGA SPDR ETFs Europe II plc - SPDR MSCI Europe Industrials UCITS ETF EUR, quantity: 0.007397"],
    ["TR-0079","2025-10-09",-2000,-413381,"Investimento","Savings plan execution IE00BGV5VN51 Xtrackers (IE) Plc - Xtrackers Artificial Intelligence & Big Data UCITS ETF 1C 1C, quantity: 0.130463"],
    ["TR-0080","2025-10-09",-1000,-414381,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.097637"],
    ["TR-0081","2025-10-10",150000,-264381,"Entrata","Incoming transfer from VAR4YOU S.R.L."],
    ["TR-0082","2025-10-10",469239,204858,"Investimento","Sell trade IT0004764699 BRUNELLO CUCINELLI, quantity: 50"],
    ["TR-0083","2025-10-13",-3400,201458,"Investimento","Buy trade IT0005438046 SECO S.P.A., quantity: 10"],
    ["TR-0084","2025-10-15",3,201461,"Entrata","Cash Dividend for ISIN DE000A0H08F7"],
    ["TR-0085","2025-10-15",-100333,101128,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 7"],
    ["TR-0086","2025-10-16",-5000,96128,"Investimento","Ordine d'acquisto sui private market"],
    ["TR-0087","2025-10-16",-2500,93628,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.249053"],
    ["TR-0088","2025-10-17",-47331,46297,"Spesa","taptap send Sell trade DE000A0H08F7 iShares (DE) I InvAG mit TGV - iShares STOXX"],
    ["TR-0089","2025-10-17",1291,47588,"Investimento","Europe 600 Construction & Materials UCITS ETF (DE) EUR (Dist), quantity: 0.164591"],
    ["TR-0090","2025-10-17",1483,49071,"Investimento","Sell trade IE00BKWQ0J47 SSGA SPDR ETFs Europe II plc - SPDR MSCI Europe Industrials UCITS ETF EUR, quantity: 0.040255"],
    ["TR-0091","2025-10-17",3140,52211,"Investimento","Sell trade IT0005438046 SECO S.P.A., quantity: 10"],
    ["TR-0092","2025-10-17",44612,96823,"Investimento","Sell trade IE00BGV5VN51 Xtrackers (IE) Plc - Xtrackers Artificial Intelligence & Big Data UCITS ETF 1C 1C, quantity: 3.038579"],
    ["TR-0093","2025-10-17",-428590,-331767,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 30"],
    ["TR-0094","2025-10-20",-445300,-777067,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 30"],
    ["TR-0095","2025-10-21",-96140,-873207,"Investimento","Buy trade US0231351067 AMAZON.COM INC. DL-,01, quantity: 5"],
    ["TR-0096","2025-10-21",824897,-48310,"Investimento","Sell trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 57"],
    ["TR-0097","2025-10-23",-2500,-50810,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.246451"],
    ["TR-0098","2025-10-23",-141800,-192610,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 10"],
    ["TR-0099","2025-10-23",877509,684899,"Investimento","Sell trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 60"],
    ["TR-0100","2025-10-24",139380,824279,"Investimento","Sell trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 10"],
    ["TR-0101","2025-10-24",-80030,744249,"Investimento","Buy trade IT0003132476 ENI S.P.A., quantity: 50"],
    ["TR-0102","2025-10-24",96630,840879,"Investimento","Sell trade US0231351067 AMAZON.COM INC. DL-,01, quantity: 5"],
    ["TR-0103","2025-10-28",-42092,798787,"Investimento","Buy trade IT0004729759 SESA S.P.A., quantity: 5"],
    ["TR-0104","2025-10-29",79760,878547,"Investimento","Sell trade IT0003132476 ENI S.P.A., quantity: 50"],
    ["TR-0105","2025-10-30",-10000,868547,"Trasferimento","Revolut**9398*"],
    ["TR-0106","2025-11-01",423,868970,"Entrata","Interest payment"],
    ["TR-0107","2025-11-03",-5000,863970,"Investimento","Ordine d'acquisto sui private market"],
    ["TR-0108","2025-11-03",-2500,861470,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.232991"],
    ["TR-0109","2025-11-07",-10000,851470,"Trasferimento","Revolut**9398*"],
    ["TR-0110","2025-11-10",161300,1012770,"Entrata","Incoming transfer from VAR4YOU S.R.L."],
    ["TR-0111","2025-11-10",-2500,1010270,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.240015"],
    ["TR-0112","2025-11-14",41800,1052070,"Investimento","Sell trade IT0004729759 SESA S.P.A., quantity: 5"],
    ["TR-0113","2025-11-17",-5000,1047070,"Investimento","Ordine d'acquisto sui private market"],
    ["TR-0114","2025-11-17",-2500,1044570,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.247133"],
    ["TR-0115","2025-11-19",-10000,1034570,"Trasferimento","Revolut**9398*"],
    ["TR-0116","2025-11-22",-10000,1024570,"Trasferimento","Revolut**9398*"],
    ["TR-0117","2025-11-24",-10000,1014570,"Trasferimento","Revolut**9398*"],
    ["TR-0118","2025-11-24",-2500,1012070,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.251686"],
    ["TR-0119","2025-11-28",-10000,1002070,"Trasferimento","Revolut**9398*"],
    ["TR-0120","2025-12-01",1185,1003255,"Entrata","Interest payment"],
    ["TR-0121","2025-12-02",-93,1003162,"Investimento","Savings plan execution XF000BTC0017 Bitcoin, quantity: 0.000012"],
    ["TR-0122","2025-12-02",-5000,998162,"Investimento","Ordine d'acquisto sui private market"],
    ["TR-0123","2025-12-02",-2500,995662,"Investimento","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.243285"],
    ["TR-0124","2025-12-04",-5000,990662,"Trasferimento","Revolut**9398*null"],
    ["TR-0125","2025-12-07",-5000,985662,"Trasferimento","Revolut**9398*null"],
    ["TR-0126","2025-12-07",4927,990589,"Investimento","Sell trade XF000BTC0017 Bitcoin, quantity: 0.000657"],
    ["TR-0127","2025-12-07",-990500,89,"Trasferimento","Outgoing transfer for ZEROUAL ANASS (IT65V0338501601100000876641)"],
    ["TR-0128","2025-12-08",21601,21690,"Investimento","Sell trade IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 2.119589"],
    ["TR-0129","2025-12-10",163100,184790,"Entrata","Incoming transfer from VAR ENGINEERING S.R.L. (IT65D0103037830000004004166)"],
    ["TR-0130","2025-12-10",-184790,0,"Trasferimento","Outgoing transfer for ZEROUAL ANASS (IT65V0338501601100000876641)"],
    ["TR-0131","2025-12-15",712,712,"Entrata","Tax Credit"],
    ["TR-0132","2025-12-15",-712,0,"Spesa","Tax Optimisation"],
    ["TR-0133","2025-12-23",712,712,"Entrata","Tax Optimisation"],
    ["TR-0134","2026-01-01",244,956,"Entrata","Interest payment"],
    ["TR-0135","2026-01-12",-4,952,"Spesa","Stamp Duty Tax (Portfolio)"],
    ["TR-0136","2026-01-21",1342747,1343699,"Trasferimento","Incoming transfer from ZEROUAL ANASS (IT65V0338501601100000876641)"],
    ["TR-0137","2026-01-21",-493840,849859,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 30.0"],
    ["TR-0138","2026-01-21",-6260,843599,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.380362"],
    ["TR-0139","2026-01-26",-493245,350354,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 29.0"],
    ["TR-0140","2026-01-26",-6884,343470,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.404845"],
    ["TR-0141","2026-01-27",8336,351806,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.494542"],
    ["TR-0142","2026-01-27",740859,1092665,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 44.0"],
    ["TR-0143","2026-01-28",5017,1097682,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.290665"],
    ["TR-0144","2026-01-28",258814,1356496,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 15.0"],
    ["TR-0145","2026-01-28",-899000,457496,"Spesa","Outgoing transfer for AUTOSERVICE MB SRL (IT76X0306951611100000012845)"],
    ["TR-0146","2026-01-29",-2460,455036,"Spesa","ASPIT MILANO SUD -null"],
    ["TR-0147","2026-01-29",-270,454766,"Spesa","MISER DIREZ.ENTRATA -null"],
    ["TR-0148","2026-01-29",-399,454367,"Spesa","AUTOGRILL 0310null"],
    ["TR-0149","2026-01-29",-56000,398367,"Spesa","AUTOSERVICE MBnull"],
    ["TR-0150","2026-01-30",-16,398351,"Spesa","Tax Recalculation FR0013416716 Physical Gold (Invoice No.: 39de-6171)"],
    ["TR-0151","2026-01-30",-20000,378351,"Trasferimento","REVOLUT**9398*null"],
    ["TR-0152","2026-02-01",295,378646,"Entrata","Interest payment"],
    ["TR-0153","2026-02-03",-132200,246446,"Spesa","Outgoing transfer for ASSICURAZIONI GIANNELLI SOCIETA' A RESPONSABILITA' LIMITATA (IT78H0832537960000000218810)"],
    ["TR-0154","2026-02-05",-25,246421,"Investimento","Detrazione bonus 1% Private Markets"],
    ["TR-0155","2026-02-05",7758,254179,"Investimento","Sell trade LU3176111881 EQT Nexus ELTIF, quantity: 0.750000"],
    ["TR-0156","2026-02-06",-20000,234179,"Trasferimento","Revolut**9398*null"],
    ["TR-0157","2026-02-06",-1880,232299,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.11387"],
    ["TR-0158","2026-02-06",-198208,34091,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 12.0"],
    ["TR-0159","2026-02-10",167200,201291,"Trasferimento","Incoming transfer from ZEROUAL ANASS (IT65V0338501601100000876641)"],
    ["TR-0160","2026-02-10",-7040,194251,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.419147"],
    ["TR-0161","2026-02-10",-168060,26191,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 10.0"],
    ["TR-0162","2026-02-16",66648,92839,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 4.0"],
    ["TR-0163","2026-02-16",13252,106091,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.794151"],
    ["TR-0164","2026-02-17",4,106095,"Entrata","Cancellation Stamp Duty Tax (Portfolio)"],
    ["TR-0165","2026-02-18",-44,106051,"Spesa","Stamp Duty Tax (Portfolio)"],
    ["TR-0166","2026-02-20",-80000,26051,"Spesa","ALLIANZ"],
    ["TR-0167","2026-02-27",-10000,16051,"Trasferimento","Revolut**9398*"],
    ["TR-0168","2026-03-01",98,16149,"Entrata","Interest payment"],
    ["TR-0169","2026-03-04",-10000,6149,"Trasferimento","Revolut**9398*"],
    ["TR-0170","2026-03-04",17258,23407,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 1.0"],
    ["TR-0171","2026-03-04",12276,35683,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.708136"],
    ["TR-0172","2026-03-05",-20000,15683,"Trasferimento","REVOLUT**9398*"],
    ["TR-0173","2026-03-06",9940,25623,"Investimento","Sell trade LU3176111881 EQT Nexus ELTIF, quantity: 0.959495"],
    ["TR-0174","2026-03-07",-6,25617,"Spesa","Tax Recalculation FR0013416716 Physical Gold (Invoice No.: 29a6-4fa9)"],
    ["TR-0175","2026-03-07",-15000,10617,"Trasferimento","REVOLUT**9398*"],
    ["TR-0176","2026-03-10",146100,156717,"Trasferimento","Incoming transfer from ZEROUAL ANASS (IT65V0338501601100000876641)"],
    ["TR-0177","2026-03-10",-15251,141466,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.859259"],
    ["TR-0178","2026-03-10",-17849,123617,"Investimento","Buy trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 1.0"],
    ["TR-0179","2026-03-10",-97967,25650,"Investimento","Buy trade JE00B1VS3333 WITR MET.SEC.Z07/UN.XAG, quantity: 14.0"],
    ["TR-0180","2026-03-10",-2133,23517,"Investimento","Buy trade JE00B1VS3333 WITR MET.SEC.Z07/UN.XAG, quantity: 0.305128"],
    ["TR-0181","2026-03-13",-5000,18517,"Trasferimento","Revolut**9398*"],
    ["TR-0182","2026-03-29",-1000,17517,"Trasferimento","Revolut**9398*"],
    ["TR-0183","2026-04-01",24,17541,"Entrata","Interest payment"],
    ["TR-0184","2026-04-02",-192,17349,"Spesa","PENNY MARKET S.R.L."],
    ["TR-0185","2026-04-03",-14808,2541,"Trasferimento","REVOLUT**9398*"],
    ["TR-0186","2026-04-09",-190,2351,"Spesa","Stamp Duty Tax (Portfolio)"],
    ["TR-0187","2026-04-10",156500,158851,"Entrata","Incoming transfer from VAR ENGINEERING S.R.L. (IT65D0103037830000004004166)"],
    ["TR-0188","2026-04-10",-3520,155331,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 0.218905"],
    ["TR-0189","2026-04-10",-96580,58751,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 6.0"],
    ["TR-0190","2026-04-11",-35000,23751,"Trasferimento","REVOLUT**9398*"],
    ["TR-0191","2026-04-19",-20000,3751,"Trasferimento","REVOLUT**9398*"],
    ["TR-0192","2026-04-27",-3750,1,"Trasferimento","Revolut**8413*"],
    ["TR-0193","2026-04-27",2400,2401,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 0.1574"],
    ["TR-0194","2026-04-29",-2400,1,"Trasferimento","Revolut**8413*"],
    ["TR-0195","2026-05-01",13,14,"Entrata","Interest payment"],
    ["TR-0196","2026-05-08",4903,4917,"Investimento","Sell trade LU3176111881 EQT Nexus ELTIF, quantity: 0.473411"],
    ["TR-0197","2026-05-09",-4917,0,"Trasferimento","Revolut**8413*"],
    ["TR-0198","2026-05-11",169400,169400,"Entrata","Incoming transfer from VAR ENGINEERING S.R.L. (IT65D0103037830000004004166)"],
    ["TR-0199","2026-05-11",-25100,144300,"Investimento","Buy trade US60770K1079 MODERNA INC. DL-,0001, quantity: 5.120852"],
    ["TR-0200","2026-05-11",-10100,134200,"Investimento","Buy trade US98980L1017 ZOOM COMMUNIC. A DL -,001, quantity: 1.072041"],
    ["TR-0201","2026-05-11",-4800,129400,"Investimento","Buy trade NL0010273215 ASML HOLDING EO -,09, quantity: 0.035237"],
    ["TR-0202","2026-05-12",-49400,80000,"Trasferimento","Revolut**8413*"],
    ["TR-0203","2026-05-23",-10000,70000,"Trasferimento","Revolut**8413*"],
    ["TR-0204","2026-05-31",-1000,69000,"Trasferimento","Revolut**8413*"],
    ["TR-0205","2026-06-01",67,69067,"Entrata","Interest payment"],
    ["TR-0206","2026-06-02",-45000,24067,"Trasferimento","Revolut**8413*"],
    ["TR-0207","2026-06-02",6200,30267,"Entrata","Incoming transfer from ALLIANZ DIRECT S.P.A. (IT50O0358901600010570015482)"],
    ["TR-0208","2026-06-03",10151,40418,"Investimento","Sell trade US98980L1017 ZOOM COMMUNIC. A DL -,001, quantity: 1.072041"],
    ["TR-0209","2026-06-03",-20100,20318,"Investimento","Buy trade NL0010273215 ASML HOLDING EO -,09, quantity: 0.137098"],
    ["TR-0210","2026-06-10",174000,194318,"Entrata","Incoming transfer from VAR ENGINEERING S.R.L. (IT65D0103037830000004004166)"],
    ["TR-0211","2026-06-11",-5100,189218,"Investimento","Buy trade US7731211089 ROCKET LAB CORP. DL-,0001, quantity: 0.5291"],
    ["TR-0212","2026-06-12",-100100,89118,"Investimento","Buy trade NL0010273215 ASML HOLDING EO -,09, quantity: 0.614326"],
    ["TR-0213","2026-06-12",-50100,39018,"Investimento","Buy trade US7731211089 ROCKET LAB CORP. DL-,0001, quantity: 4.681647"],
    ["TR-0214","2026-06-12",2155,41173,"Investimento","Sell trade US7731211089 ROCKET LAB CORP. DL-,0001, quantity: 0.210747"],
    ["TR-0215","2026-06-12",53200,94373,"Investimento","Sell trade US7731211089 ROCKET LAB CORP. DL-,0001, quantity: 5"],
    ["TR-0216","2026-06-13",-500,93873,"Spesa","Republic Card"],
    ["TR-0217","2026-06-13",-1100,92773,"Spesa","Outgoing transfer for Mattia Savasta (IT02E0311502801000000040243)"],
    ["TR-0218","2026-06-13",23000,115773,"Trasferimento","Incoming transfer from Anass Zeroual (IT21S0366901600765418204795)"],
    ["TR-0219","2026-06-16",22844,138617,"Investimento","Sell trade US60770K1079 MODERNA INC. DL-,0001, quantity: 5.120852"],
    ["TR-0220","2026-06-16",-34,138583,"Spesa","PENNY MARKET S.R.L."],
    ["TR-0221","2026-06-16",-28,138555,"Spesa","UNICOOP EMPOLI"],
    ["TR-0222","2026-06-16",125467,264022,"Investimento","Sell trade NL0010273215 ASML HOLDING EO -,09, quantity: 0.786661"],
    ["TR-0223","2026-06-18",-100,263922,"Spesa","IRIS PALESTRE"],
    ["TR-0224","2026-06-18",-649,263273,"Spesa","MC DONALD S"],
    ["TR-0225","2026-06-18",-5847,257426,"Spesa","BEYFIN"],
    ["TR-0226","2026-06-19",-1000,256426,"Trasferimento","Revolut**8413*"],
    ["TR-0227","2026-06-19",-80,256346,"Spesa","ASPIT PRATO EST -"],
    ["TR-0228","2026-06-19",-100,256246,"Spesa","ASPIT FI SCANDICCI -"],
    ["TR-0229","2026-06-19",-50000,206246,"Trasferimento","Revolut**8413*"],
    ["TR-0230","2026-06-19",-80,206166,"Spesa","ASPIT FIRENZE OVEST -"],
    ["TR-0231","2026-06-19",-500,205666,"Spesa","PEZLXJOQOH COFFEE VENDING"],
    ["TR-0232","2026-06-20",-3714,201952,"Spesa","Klarna*Swappie"],
    ["TR-0233","2026-06-22",133600,335552,"Entrata","Incoming transfer from VAR ENGINEERING S.R.L. (IT65D0103037830000004004166)"],
    ["TR-0234","2026-06-23",-194,335358,"Spesa","PENNY MARKET S.R.L."],
    ["TR-0235","2026-06-24",-598,334760,"Spesa","UNICOOP EMPOLI"],
    ["TR-0236","2026-06-24",-1000,333760,"Spesa","MUHAMMAD IMRAN"],
    ["TR-0237","2026-06-25",-7216,326544,"Spesa","Klarna*Back Market"],
    ["TR-0238","2026-06-26",-99,326445,"Spesa","APPLE.COM/BILL"],
    ["TR-0239","2026-06-26",-500,325945,"Spesa","GLVGWFPSME COFFEE VENDING"],
    ["TR-0240","2026-06-29",-100,325845,"Spesa","IRIS PALESTRE"],
    ["TR-0241","2026-07-01",241,326086,"Entrata","Interest payment"],
    ["TR-0242","2026-07-01",-500,325586,"Spesa","CTQRWBWRLM COFFEE VENDING"],
    ["TR-0243","2026-07-02",-130,325456,"Spesa","UNICOOP-EMPOLI"],
    ["TR-0244","2026-07-04",-243,325213,"Spesa","UNICOOP EMPOLI"],
    ["TR-0245","2026-07-06",-937,324276,"Spesa","WWW.AMAZON.* WO8M20PW5"],
    ["TR-0246","2026-07-06",-327,323949,"Spesa","PENNY MARKET S.R.L."],
    ["TR-0247","2026-07-07",-1499,322450,"Spesa","Sepa Direct Debit transfer to AMAZON PAYMENTS EUROPE S.C.A. AMAZON PAYMENTS EUROPE SCA (IT09I0302101600007020282020)"],
    ["TR-0248","2026-07-07",-1699,320751,"Spesa","Sepa Direct Debit transfer to AMAZON PAYMENTS EUROPE S.C.A. AMAZON PAYMENTS EUROPE SCA (IT09I0302101600007020282020)"],
    ["TR-0249","2026-07-07",-3218,317533,"Spesa","Sepa Direct Debit transfer to AMAZON PAYMENTS EUROPE S.C.A. AMAZON PAYMENTS EUROPE SCA (IT09I0302101600007020282020)"],
    ["TR-0250","2026-07-07",-999,316534,"Spesa","Sepa Direct Debit transfer to AMAZON PAYMENTS EUROPE S.C.A. AMAZON PAYMENTS EUROPE SCA (IT09I0302101600007020282020)"],
    ["TR-0251","2026-07-07",-1299,315235,"Spesa","Sepa Direct Debit transfer to AMAZON PAYMENTS EUROPE S.C.A. AMAZON PAYMENTS EUROPE SCA (IT09I0302101600007020282020)"],
    ["TR-0252","2026-07-07",-500,314735,"Spesa","LGITIKKRMT COFFEE VENDING"],
    ["TR-0253","2026-07-07",-1241,313494,"Spesa","UNICOOP EMPOLI"],
    ["TR-0254","2026-07-08",-569,312925,"Spesa","Sepa Direct Debit transfer to AMAZON PAYMENTS EUROPE S.C.A. AMAZON PAYMENTS EUROPE SCA (IT09I0302101600007020282020)"],
    ["TR-0255","2026-07-08",-959,311966,"Spesa","Sepa Direct Debit transfer to AMAZON PAYMENTS EUROPE S.C.A. AMAZON PAYMENTS EUROPE SCA (IT09I0302101600007020282020)"],
    ["TR-0256","2026-07-08",-2900,309066,"Spesa","Sepa Direct Debit transfer to AMAZON PAYMENTS EUROPE S.C.A. AMAZON PAYMENTS EUROPE SCA (IT09I0302101600007020282020)"],
    ["TR-0257","2026-07-08",-141,308925,"Spesa","CONAD"],
    ["TR-0258","2026-07-08",-1000,307925,"Spesa","WWW.UNOMOBILE.IT"],
    ["TR-0259","2026-07-09",-249,307676,"Spesa","Amazon Prime"],
    ["TR-0260","2026-07-09",-200,307476,"Spesa","Stamp Duty Tax (Portfolio)"],
    ["TR-0261","2026-07-10",177200,484676,"Entrata","Incoming transfer from VAR ENGINEERING S.R.L. (IT65D0103037830000004004166)"],
    ["TR-0262","2026-07-10",-544,484132,"Spesa","UNICOOP EMPOLI"],
    ["TR-0263","2026-07-13",-517,483615,"Spesa","EUROSPIN"],
    ["TR-0264","2026-07-14",-853,482762,"Spesa","AMAZON* V60KJ42A5"],
    ["TR-0265","2026-07-14",-1000,481762,"Spesa","MUHAMMAD IMRAN"],
    ["TR-0266","2026-07-15",-500,481262,"Spesa","DVXOOCHVKH COFFEE VENDING"],
    ["TR-0267","2026-07-15",-333,480929,"Spesa","PENNY MARKET S.R.L."],
    ["TR-0268","2026-07-16",-11415,469514,"Spesa","WWW.COMPUTERGROSS.IT"],
    ["TR-0269","2026-07-16",-2200,467314,"Spesa","APPLE.COM/BILL"],
    ["TR-0270","2026-07-17",-600,466714,"Spesa","GELATERIA INNOCENTI DI VE"],
    ["TR-0271","2026-07-20",-737,465977,"Spesa","D+"],
    ["TR-0272","2026-07-22",-294,465683,"Spesa","UNICOOP EMPOLI"],
    ["TR-0273","2026-07-22",-196,465487,"Spesa","UNICOOP EMPOLI"],
    ["TR-0274","2026-07-23",-3890,461597,"Spesa","PAGOPA APPLEPAY NEXI"],
    ["TR-0275","2026-07-24",7216,468813,"Entrata","Klarna*Back Market"],
    ["TR-0276","2026-07-24",7288,476101,"Trasferimento","Incoming transfer from Anass Zeroual (IT21S0366901600765418204795)"],
    ["TR-0277","2026-07-24",-500,475601,"Spesa","SLTEGHTAPU COFFEE VENDING"],
    ["TR-0278","2026-07-26",-99,475502,"Spesa","APPLE.COM/BILL"],
    ["TR-0279","2026-07-26",-3634,471868,"Spesa","Klarna*FitActive Emp"],
    ["TR-0280","2026-07-27",-173200,298668,"Spesa","Outgoing transfer for Ginevra Lassi (IT85D0623037831000035704509)"],
    ["TR-0281","2026-07-28",-789,297879,"Spesa","UNICOOP EMPOLI"],
    ["TR-0282","2026-07-28",-4500,293379,"Spesa","Outgoing transfer for Andrea Gorini (IT05D0366901600871222109176)"],
    ["TR-0283","2026-07-29",-500,292879,"Spesa","YYHIXBRYZF COFFEE VENDING"],
    ["TR-0284","2026-07-31",-316,292563,"Spesa","PENNY MARKET S.R.L."],
    ["TR-0285","2026-08-01",565,293128,"Entrata","Interest payment"],
    ["TR-0286","2026-08-01",-9038,284090,"Spesa","D156 Santa Croce sull"],
    ["TR-0287","2026-08-02",-3067,281023,"Spesa","Grazie da OBI"],
    ["TR-0288","2026-08-02",-50000,231023,"Trasferimento","Revolut**8413*"],
    ["TR-0289","2026-08-02",-3035,227988,"Spesa","UNICOOP EMPOLI"],
    ["TR-0290","2026-08-02",-9,227979,"Spesa","UNICOOP EMPOLI"],
    ["TR-0291","2026-08-03",-4949,223030,"Spesa","WWW.AMAZON.* S34XY60N5"],
    ["TR-0292","2026-08-04",-10425,212605,"Spesa","AMAZON* RG5CB2V95"],
    ["TR-0293","2026-08-04",-3499,209106,"Spesa","AMZN Mktp IT*SM6Q14SK5"],
    ["TR-0294","2026-08-04",-2432,206674,"Spesa","Amazon.it*XK8SE3JO5"],
    ["TR-0295","2026-08-04",-6198,200476,"Spesa","AMZN Mktp IT*G383854T5"],
    ["TR-0296","2026-08-07",71604,272080,"Investimento","Sell trade JE00B1VS3333 WITR MET.SEC.Z07/UN.XAG, quantity: 14.305128"],
    ["TR-0297","2026-08-07",352610,624690,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 23.951494"],
    ["TR-0298","2026-08-09",-249,624441,"Spesa","Amazon Prime"],
    ["TR-0299","2026-08-10",164700,789141,"Entrata","Incoming transfer from VAR ENGINEERING S.R.L. (IT65D0103037830000004004166)"],
    ["TR-0300","2026-08-10",10800,799941,"Entrata","Incoming transfer from CASSA DI ASSISTENZA BISALUS (IT49F0326811300052801533970)"],
    ["TR-0301","2026-08-11",-10800,789141,"Trasferimento","Revolut**8413*"],
    ["TR-0302","2026-08-14",-3749,785392,"Spesa","Taptap Send EU"],
    ["TR-0303","2026-08-14",-2000,783392,"Trasferimento","Revolut**8413*"],
    ["TR-0304","2026-08-15",3499,786891,"Entrata","AMZN Mktp IT"],
    ["TR-0305","2026-08-15",-3000,783891,"Trasferimento","Revolut**8413*"],
    ["TR-0306","2026-08-15",-4090,779801,"Spesa","IKEA ITALIA ECO"],
    ["TR-0307","2026-08-16",1999,781800,"Entrata","AMAZON* RG5CB2V95"],
    ["TR-0308","2026-08-17",-400127,381673,"Investimento","Buy trade FR0013416716 AMUNDI PHYSICAL GOLD ETC (C), quantity: 26.59044"],
    ["TR-0309","2026-08-18",-14338,367335,"Spesa","Klarna* LaRedoute Ita"],
    ["TR-0310","2026-08-20",4949,372284,"Entrata","WWW.AMAZON.* S34XY60N5"],
    ["TR-0311","2026-08-20",403676,775960,"Investimento","Sell trade FR0013416716 AMUNDIPHME ETC Z 2118, quantity: 26.59044"],
    ["TR-0312","2026-08-21",-100093,675867,"Investimento","Buy trade IE00B4ND3602 ISHARES PHYSICAL GOLD, quantity: 13.032712"],
    ["TR-0313","2026-08-23",-10000,665867,"Trasferimento","Revolut**8413*"],
    ["TR-0314","2026-08-24",-100087,565780,"Investimento","Buy trade IE00B4ND3602 ISHARES PHYSICAL GOLD, quantity: 12.964283"],
    ["TR-0315","2026-08-24",100151,665931,"Investimento","Sell trade IE00B4ND3602 ISHARES PHYSICAL GOLD, quantity: 12.998497"],
    ["TR-0316","2026-08-24",-50103,615828,"Investimento","Buy trade IE00B4ND3602 ISHARES PHYSICAL GOLD, quantity: 6.43832"],
    ["TR-0317","2026-08-24",49900,665728,"Investimento","Sell trade IE00B4ND3602 ISHARES PHYSICAL GOLD, quantity: 6.460783"],
    ["TR-0318","2026-08-26",-99,665629,"Spesa","APPLE.COM/BILL"],
    ["TR-0319","2026-08-26",-3634,661995,"Spesa","KLARNA* FITACTIVE EMP"],
    ["TR-0320","2026-08-29",-60000,601995,"Trasferimento","Revolut**8413*"],
    ["TR-0321","2026-08-29",-10000,591995,"Trasferimento","Revolut**8413*"],
    ["TR-0322","2026-08-31",95981,687976,"Investimento","Sell trade IE00B4ND3602 iShares Physical Gold ETC, quantity: 12.976035"],
    ["TR-0323","2026-09-01",813,688789,"Entrata","Interest payment"],
    ["TR-0324","2026-09-04",-55000,633789,"Spesa","Outgoing transfer for Ginevra Lassi (IT85D0623037831000035704509)"],
    ["TR-0325","2026-09-06",-20000,613789,"Trasferimento","Revolut**8413*"],
    ["TR-0326","2026-09-10",173900,787689,"Entrata","Incoming transfer from VAR ENGINEERING S.R.L. (IT65D0103037830000004004166)"],
    ["TR-0327","2026-09-17",-6473,781216,"Spesa","Klarna* pagoPA"],
    ["TR-0328","2026-09-18",-15488,765728,"Spesa","Outgoing transfer for ABAIN COMPONENTS SL (ES0921002258120200673144)"],
    ["TR-0329","2026-09-23",-6454,759274,"Spesa","Outgoing transfer for CONDOMINIO VIA SALAIOLA DA 47 F A 47 M EMPOLI (IT17C0623037833000046732812)"],
    ["TR-0330","2026-09-24",-6474,752800,"Spesa","KLARNA* PAGOPA"],
    ["TR-0331","2026-09-24",-90000,662800,"Trasferimento","Revolut**8413* DEL SALDO"]
  ]).map(([id, day, amount, balance, type, description]) => ({id, day, amount, balance, type, description})),
  fixes: /** @type {Array<[number, string, string, string, number, number, number|null]>} */ ([
    [1045,"TR-0077","2025-10-09","iShares STOXX Europe 600 Construction & Materials UCITS ETF (DE) EUR (Dist), quantity: 0.023721",411081,-200,null],
    [1046,"TR-0078","2025-10-09","Savings plan execution IE00BKWQ0J47 SSGA SPDR ETFs Europe II plc - SPDR MSCI Europe Industrials UCITS ETF EUR, quantity: 0.007397",411381,-300,null],
    [1047,"TR-0079","2025-10-09","Savings plan execution IE00BGV5VN51 Xtrackers (IE) Plc - Xtrackers Artificial Intelligence & Big Data UCITS ETF 1C 1C, quantity: 0.130463",413381,-2000,null],
    [1048,"TR-0080","2025-10-09","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.097637",414381,-1000,null],
    [1063,"TR-0095","2025-10-21","Buy trade US0231351067 AMAZON.COM INC. DL-,01, quantity: 5",873207,-96140,null],
    [1079,"TR-0111","2025-11-10","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.240015",-1010270,-2500,null],
    [1081,"TR-0113","2025-11-17","Ordine d'acquisto sui private market",-1047070,-5000,null],
    [1082,"TR-0114","2025-11-17","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.247133",-1044570,-2500,null],
    [1083,"TR-0115","2025-11-19","Revolut**9398*",-1034570,-10000,null],
    [1084,"TR-0116","2025-11-22","Revolut**9398*",-1024570,-10000,null],
    [1085,"TR-0117","2025-11-24","Revolut**9398*",-1014570,-10000,null],
    [1086,"TR-0118","2025-11-24","Savings plan execution IE00BM67HT60 Xtrackers (IE) Plc - Xtrackers MSCI World Information Technology UCITS ETF 1C, quantity: 0.251686",-1012070,-2500,null],
    [1087,"TR-0119","2025-11-28","Revolut**9398*",-1002070,-10000,null],
    [1089,"TR-0121","2025-12-02","Savings plan execution XF000BTC0017 Bitcoin, quantity: 0.000012",-1003162,-93,null]
  ]).map(([row, id, day, description, before, after, monthly_before]) => ({row, id, day, description, before, after, monthly_before})),
  classifications: /** @type {Array<[string, string, string, number]>} */ ([
    ["TR-0131","2025-12-15","Tax Credit",712],
    ["TR-0133","2025-12-23","Tax Optimisation",712],
    ["TR-0164","2026-02-17","Cancellation Stamp Duty Tax (Portfolio)",4],
    ["TR-0275","2026-07-24","Klarna*Back Market",7216],
    ["TR-0304","2026-08-15","AMZN Mktp IT",3499],
    ["TR-0307","2026-08-16","AMAZON* RG5CB2V95",1999],
    ["TR-0310","2026-08-20","WWW.AMAZON.* S34XY60N5",4949]
  ]).map(([id, day, description, amount]) => ({id, day, description, amount})),
  cashflow: {"Trasferimento":{"in":2391205,"out":1929365},"Spesa":{"in":0,"out":1626093},"Entrata":{"in":1822809,"out":0},"Investimento":{"in":6436623,"out":6432379}}
};
const trRepairJobs = new WeakMap();

/** Inizializza/verifica la riconciliazione TR importata; preserva il marcatore storico. */
async function ensureTrStatement(env) {
  if (trRepairJobs.has(env.DB)) return trRepairJobs.get(env.DB);
  const job = (async () => {
    const found = await env.DB.prepare(
      "SELECT values_json FROM source_rows WHERE sheet='Estratto TR verificato' AND row_number=1",
    ).first();
    if (found && JSON.parse(found.values_json)?.[0]?.version === 2) return;
    const rows = (
      await env.DB.prepare(
        "SELECT * FROM movements WHERE account='Trade Republic'",
      ).all()
    ).results;
    const byId = new Map(rows.map((r) => [r.import_id, r]));
    const tasks = [],
      conflicts = [];
    for (const f of TR_STATEMENT_PROOF.fixes) {
      const r = byId.get(f.id);
      if (
        !r ||
        iso(r.actual_date) !== f.day ||
        r.description !== f.description
      ) {
        conflicts.push(f.id);
        continue;
      }
      const cents = Math.round(r.amount * 100);
      if (cents === f.after) continue;
      if (cents !== f.before) {
        conflicts.push(f.id);
        continue;
      }
      tasks.push(
        env.DB.prepare(
          `UPDATE movements SET amount=?,monthly_share=CASE WHEN monthly_share=amount THEN ? ELSE monthly_share END,
    notes=COALESCE(notes,'')||' [Importo corretto da estratto TR 2026-09-29]'
    WHERE source_row=? AND import_id=? AND account='Trade Republic' AND ROUND(amount*100)=? AND substr(actual_date,1,10)=? AND description=?`,
        ).bind(
          f.after / 100,
          f.after / 100,
          r.source_row,
          f.id,
          f.before,
          f.day,
          f.description,
        ),
      );
    }
    for (const f of TR_STATEMENT_PROOF.classifications) {
      const r = byId.get(f.id);
      if (
        !r ||
        iso(r.actual_date) !== f.day ||
        r.description !== f.description ||
        Math.round(r.amount * 100) !== f.amount
      ) {
        conflicts.push(f.id);
        continue;
      }
      if (r.movement_type === "Spesa")
        tasks.push(
          env.DB.prepare(
            `UPDATE movements SET movement_type='Entrata',category=CASE WHEN instr(COALESCE(notes,''),'[Categoria manuale]')>0 THEN category ELSE 'Rimborsi' END WHERE source_row=? AND import_id=? AND movement_type='Spesa' AND ROUND(amount*100)=?`,
          ).bind(r.source_row, f.id, f.amount),
        );
    }
    const stored = { ...TR_STATEMENT_PROOF, conflicts };
    tasks.push(
      env.DB.prepare(
        "INSERT OR REPLACE INTO source_rows(sheet,row_number,values_json) VALUES ('Estratto TR verificato',1,?)",
      ).bind(JSON.stringify([stored])),
    );
    await env.DB.batch(tasks);
  })();
  trRepairJobs.set(env.DB, job);
  try {
    await job;
  } catch (e) {
    trRepairJobs.delete(env.DB);
    throw e;
  }
}

const FINANCE_MANUAL_CATEGORIES = ["Alimentari", "Ristorazione", "Casa", "Affitto", "Condominio", "Arredamento e casa", "Utenze", "Elettricità", "Gas", "Acqua", "Abbonamenti", "Auto", "Assicurazione", "Bollo", "Manutenzione auto", "Benzina", "Shopping", "Salute", "Palestra", "Dentista", "Farmaci e visite", "Svago", "Viaggi", "Altro", "Stipendio", "Interessi", "Rimborsi"];

const FINANCE_CATEGORY_SEED = {
  categories: [
    {
      id: 1,
      name: "Auto e trasporti",
      members: ["Auto", "Benzina", "Trasporti", "Pedaggi"],
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
        "Elettricita",
      ],
    },
    {
      id: 3,
      name: "Shopping e tecnologia",
      members: ["Shopping", "Elettronica"],
    },
    { id: 4, name: "Alimentari", members: ["Alimentari"] },
    { id: 5, name: "Ristorazione", members: ["Ristorazione"] },
    {
      id: 6,
      name: "Salute e benessere",
      members: ["Salute", "Palestra", "Cura personale", "Sport"],
    },
    {
      id: 7,
      name: "Tempo libero",
      members: ["Viaggi", "Svago", "Abbonamenti"],
    },
    {
      id: 8,
      name: "Trasferimenti a terzi",
      members: ["Trasferimenti a terzi", "Famiglia"],
    },
    {
      id: 9,
      name: "Imposte e commissioni",
      members: ["Imposte", "Imposte e servizi", "Commissioni", "Imposte e commissioni"],
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
        "Rimborsi",
      ],
    },
  ],
  rules: [
    {
      id: 1,
      pattern:
        "IT85D0623037831000035704509|affitt|caparr|cauzion|contanti destinati alle spese di agenzia",
      label: "Affitto e ingresso casa",
    },
    {
      id: 2,
      pattern:
        "beyfin|\\besso\\b|\\bq8\\b|enilive|\\beni\\b|ip italiana petroli|ok petrol|desideri carburanti|new gas network",
      label: "Benzina",
    },
    {
      id: 3,
      pattern: "iris palest|iris societa sportiva|fitactive",
      label: "Palestra",
    },
    { id: 4, pattern: "etrurialucegas|regione.*utenze", label: "Utenze" },
    {
      id: 5,
      pattern:
        "laredoute|la.?redoute|maisons du|\\bikea\\b|\\bobi\\b|brico io|abain components",
      label: "Arredamento e casa",
    },
    {
      id: 6,
      pattern: "computer.?gross|media.?world|swappie|back.?market",
      label: "Elettronica",
    },
    {
      id: 7,
      pattern:
        "unomobile|uno.?mobile|iliad|\\btim\\b|chatgpt|signulous|linkedin|fastweb|google play|apple.com|goread|brazethemes|\\binwi\\b",
      label: "Abbonamenti",
    },
    { id: 8, pattern: "taptap", label: "Trasferimenti a terzi" },
    {
      id: 9,
      pattern: "cupsolidale|farmac|pharma|dr\\.?max|odontoiatr|receptor chem",
      label: "Salute",
    },
    { id: 10, pattern: "decathlon", label: "Sport" },
    {
      id: 11,
      pattern: "parrucch|salone 198|tmt parrucchiere",
      label: "Cura personale",
    },
    {
      id: 12,
      pattern:
        "trainline|trenitalia|flixbus|malta public transport|tussam|s.bahn|valletta ferry|\\bbolt\\b",
      label: "Trasporti",
    },
    {
      id: 13,
      pattern:
        "ipertosano|macelleria|jaouda market|supermarket|\\bspar\\b|pam panorama|\\bcondis\\b|berry pantry|arkadia foodstore",
      label: "Alimentari",
    },
    {
      id: 14,
      pattern:
        "aliexpress|sonny bono|alcott|zalando|vinted|duty.free|gold shop",
      label: "Shopping",
    },
    {
      id: 15,
      pattern:
        "bistrot|pizzer|pinsa|caff[e\\u00e8]|coffee|cornett|taverna|pastizzer|past[ie]cc|mc.?donald|illy spa|cioccolat|my chef|porca vacca|\\bvyta\\b|angolo divino|buffet empoli",
      label: "Ristorazione",
    },
    {
      id: 16,
      pattern: "aviation muse|real alc.zar|orto botanico|zoo berlin|planetice",
      label: "Svago",
    },
    {
      id: 17,
      pattern: "comune.*pagop|comune di san miniato|universita",
      label: "Imposte e servizi",
    },
    {
      id: 18,
      pattern: "autostrade|autoroutes|aspit|miser direz",
      label: "Pedaggi",
    },
    {
      id: 19,
      pattern:
        "imperiale moto|autogamma|carfax|autoservice|allianz|assicurazioni",
      label: "Auto",
    },
  ],
};
const categorySchemaJobs = new WeakMap();
const movementCategoryFingerprint = (r) =>
  [r.category, r.description, r.merchant, r.notes]
    .map((x) => String(x || ""))
    .join(String.fromCharCode(31));

/** Schema e classificazione incrementale; fingerprint evita ricalcoli non necessari. */
async function ensureFinanceCategories(env) {
  if (!categorySchemaJobs.has(env.DB)) {
    const job = (async () => {
      await env.DB.batch([
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS financial_categories(id INTEGER PRIMARY KEY CHECK(id BETWEEN 1 AND 10),name TEXT NOT NULL UNIQUE,sort_order INTEGER NOT NULL)",
        ),
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS financial_category_mappings(detail_category TEXT PRIMARY KEY,category_id INTEGER NOT NULL REFERENCES financial_categories(id))",
        ),
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS financial_category_rules(id INTEGER PRIMARY KEY,pattern TEXT NOT NULL,detail_category TEXT NOT NULL,priority INTEGER NOT NULL)",
        ),
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS movement_financial_categories(movement_source_row INTEGER PRIMARY KEY REFERENCES movements(source_row) ON DELETE CASCADE,category_id INTEGER NOT NULL REFERENCES financial_categories(id),detail_category TEXT NOT NULL,source_category TEXT NOT NULL,source_fingerprint TEXT NOT NULL)",
        ),
        env.DB.prepare(
          "CREATE INDEX IF NOT EXISTS idx_movement_financial_category ON movement_financial_categories(category_id)",
        ),
      ]);
      const statements = [];
      for (const c of FINANCE_CATEGORY_SEED.categories) {
        statements.push(
          env.DB.prepare(
            "INSERT OR IGNORE INTO financial_categories(id,name,sort_order) VALUES (?,?,?)",
          ).bind(c.id, c.name, c.id),
        );
        for (const m of c.members)
          statements.push(
            env.DB.prepare(
              "INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) VALUES (?,?)",
            ).bind(m, c.id),
          );
      }
      for (const r of FINANCE_CATEGORY_SEED.rules)
        statements.push(
          env.DB.prepare(
            "INSERT OR IGNORE INTO financial_category_rules(id,pattern,detail_category,priority) VALUES (?,?,?,?)",
          ).bind(r.id, r.pattern, r.label, r.id),
        );
      const seedState = await env.DB.prepare(
        "SELECT COUNT(*) n FROM financial_categories",
      ).first();
      if (!seedState.n) await env.DB.batch(statements);
      await env.DB.batch([
        ...[["Assicurazione",1],["Bollo",1],["Manutenzione auto",1],["Condominio",2],["Dentista",6],["Farmaci e visite",6]].map(([name,id])=>env.DB.prepare("INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) VALUES (?,?)").bind(name,id)),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_rules_update AFTER UPDATE ON financial_category_rules BEGIN DELETE FROM movement_financial_categories; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_rules_insert AFTER INSERT ON financial_category_rules BEGIN DELETE FROM movement_financial_categories; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_rules_delete AFTER DELETE ON financial_category_rules BEGIN DELETE FROM movement_financial_categories; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_mapping_update AFTER UPDATE ON financial_category_mappings BEGIN DELETE FROM movement_financial_categories WHERE detail_category=OLD.detail_category OR detail_category=NEW.detail_category; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_mapping_insert AFTER INSERT ON financial_category_mappings BEGIN DELETE FROM movement_financial_categories WHERE detail_category=NEW.detail_category; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_mapping_delete AFTER DELETE ON financial_category_mappings BEGIN DELETE FROM movement_financial_categories WHERE detail_category=OLD.detail_category; END",
        ),
      ]);
      const categoryUpgrade = await env.DB.prepare(
        "SELECT value FROM os_meta WHERE key='finance_categories_1136'",
      ).first();
      if (!categoryUpgrade) {
        const edits = [];
        const upgrades = [
          [
            "veer g|a domani|la fortuna empoli|breasy|red garter|tokyo club|havana club|noa sardinian winery|ta zaren|briciole",
            "Ristorazione",
          ],
          ["el alamein", "Alimentari"],
          ["caddy.s", "Cura personale"],
          ["gamelife|tiktok", "Svago"],
          ["souvenir occitan|avolta", "Shopping"],
          ["abaco s[.]p[.]a|biglietteria piazza", "Trasporti"],
          ["rosa.?s garden", "Arredamento e casa"],
          ["dedem", "Shopping"],
        ];
        for (let i = 0; i < upgrades.length; i++)
          edits.push(
            env.DB.prepare(
              "INSERT OR IGNORE INTO financial_category_rules(id,pattern,detail_category,priority) VALUES (?,?,?,?)",
            ).bind(113600 + i, upgrades[i][0], upgrades[i][1], 70 + i),
          );
        edits.push(
          env.DB.prepare(
            "INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) VALUES ('Pagamenti non dettagliati',10)",
          ),
        );
        edits.push(
          env.DB.prepare(
            "INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) VALUES ('Elettricit\u00e0',2)",
          ),
        );
        edits.push(
          env.DB.prepare(
            "UPDATE financial_categories SET name='Altre spese' WHERE id=10 AND name='Da classificare'",
          ),
        );
        edits.push(
          env.DB.prepare(
            "DELETE FROM movement_financial_categories WHERE detail_category='Da classificare'",
          ),
        );
        edits.push(
          env.DB.prepare(
            "INSERT INTO os_meta(key,value) VALUES ('finance_categories_1136','1')",
          ),
        );
        await env.DB.batch(edits);
      }
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
      `SELECT m.* FROM movements m LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row WHERE c.movement_source_row IS NULL OR c.source_fingerprint<>COALESCE(m.category,'')||char(31)||COALESCE(m.description,'')||char(31)||COALESCE(m.merchant,'')||char(31)||COALESCE(m.notes,'')`,
    ).all(),
    env.DB.prepare(
      "SELECT * FROM financial_category_rules ORDER BY priority,id",
    ).all(),
    env.DB.prepare("SELECT * FROM financial_category_mappings").all(),
  ]);
  if (!changed.results.length) return;
  const compiled = rules.results.map((r) => ({
    ...r,
    regex: new RegExp(r.pattern, "i"),
  }));
  const map = new Map(
    mappings.results.map((r) => [r.detail_category, r.category_id]),
  );
  const statements = [];
  for (const r of changed.results) {
    let detail = String(r.category || "Altro").trim();
    if (!String(r.notes || "").includes("[Categoria manuale]")) {
      const text = [r.description, r.merchant, r.notes].join(" ");
      const rule = compiled.find((x) => x.regex.test(text));
      if (rule) detail = rule.detail_category;
      else if (detail === "Casa") detail = "Arredamento e casa";
      else if (
        /^(Altro|Altre spese|Altri movimenti|Da classificare)$/i.test(detail)
      )
        detail = "Pagamenti non dettagliati";
      if (
        /^(Apple|Google)$/i.test(String(r.description || "")) &&
        Math.abs(Number(r.amount)) < 20
      )
        detail = "Abbonamenti";
    }
    statements.push(
      env.DB.prepare(
        "INSERT OR REPLACE INTO movement_financial_categories(movement_source_row,category_id,detail_category,source_category,source_fingerprint) VALUES (?,?,?,?,?)",
      ).bind(
        r.source_row,
        map.get(detail) || 10,
        detail,
        String(r.category || ""),
        movementCategoryFingerprint(r),
      ),
    );
  }
  for (let i = 0; i < statements.length; i += 50)
    await env.DB.batch(statements.slice(i, i + 50));
}

/** Proiezione pura di obiettivo e risparmio; non modifica movimenti o saldi. */
function planningAmounts(now, goal, monthlySaving, monthsRemaining) {
  const base = goal === null ? 0 : Math.max(1, goal, now);
  return {
    now,
    goal,
    monthlySaving,
    monthsRemaining,
    projection: Math.round((now + monthlySaving * monthsRemaining) * 100) / 100,
    surplusNow: goal === null ? null : Math.max(0, now - goal),
    projectedSurplus:
      goal === null
        ? null
        : Math.max(0, now + monthlySaving * monthsRemaining - goal),
    covered:
      goal === null ? 0 : (Math.max(0, Math.min(goal, now)) / base) * 100,
    surplus: goal === null ? 0 : (Math.max(0, now - goal) / base) * 100,
    missing: goal === null ? null : Math.max(0, goal - now),
  };
}

/** Validazione condivisa per impostazioni e proiezione, con gli stessi limiti. */
function planningInputs(target, monthly) {
  const goal = target === "" || target === null ? null : Number(target),
    saving = Number(monthly);
  if (
    (goal !== null && (!Number.isFinite(goal) || goal < 0 || goal > 1e6)) ||
    !Number.isFinite(saving) ||
    saving < 0 ||
    saving > 1e5
  )
    throw Error("Importi non validi.");
  return {goal, saving};
}

/** Legge il saldo TR corrente e restituisce la proiezione validata. */
async function getPlanningProjection(env, target, monthly) {
  const {goal, saving} = planningInputs(target, monthly);
  const day = nowDay();
  const snap = await env.DB.prepare(
    "SELECT * FROM account_balance_snapshots WHERE account='Trade Republic' AND as_of_day<=? ORDER BY as_of_day DESC,id DESC LIMIT 1",
  )
    .bind(day)
    .first();
  let now;
  if (snap) {
    const events = await env.DB.prepare(
      "SELECT COALESCE(SUM(delta_cents),0) delta FROM account_balance_events WHERE account='Trade Republic' AND id>? AND day<=? AND NOT (absorbed_snapshot_id IS NOT NULL AND absorbed_snapshot_id<=?)",
    )
      .bind(snap.event_watermark, day, snap.id)
      .first();
    now = (snap.amount_cents + Number(events.delta)) / 100;
  } else {
    const row = await env.DB.prepare(
      "SELECT values_json FROM source_rows WHERE sheet='Patrimonio' AND row_number=2",
    ).first();
    if (!row) throw Error("Saldo TR non disponibile.");
    now = Number(JSON.parse(row.values_json)[1]);
  }
  return planningAmounts(now, goal, saving, 12 - Number(day.slice(5, 7)));
}

const ALLOWED_RECURRING = [
  "Condominio",
  "Elettricit\u00e0",
  "Gas",
  "Acqua",
  "Palestra",
  "Abbonamenti",
  "Benzina",
];
const MOVEMENT_COLUMNS =
  "source_row budget_date actual_date description amount account category movement_type status competence_months baseline counterparty_account notes merchant source_name import_id budget_month competence_end monthly_share actual_month transfer_id".split(
    " ",
  );
const EXTRAS_COLUMNS =
  "source_row name total start_month month_count monthly_share end_month status payment_account paid_date notes repeat_rule".split(
    " ",
  );
const CONFIG_PAGE = `<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Importa impostazioni</title><style>body{background:#000000;color:#f2f5f9;font:16px system-ui;margin:0;padding:25px}main{max-width:560px;margin:auto}button,input{font:inherit;padding:10px;margin:8px 0}p{line-height:1.5;color:#b5c3d0}</style><main><h1>Completa la migrazione</h1><p>I movimenti sono gi\u00e0 nel database. Importa impostazioni, saldi, stipendi e storico dal file di configurazione. Questa operazione aggiorna le righe importate.</p><input type="file" id="file" accept=".json,application/json"><br><button id="send">Importa configurazione</button><p id="status"></p><a href="/">Apri app</a></main><script>document.querySelector('#send').onclick=async e=>{const s=document.querySelector('#status'),f=document.querySelector('#file').files[0];if(!f){s.textContent='Scegli il file JSON.';return}e.target.disabled=true;try{let rows=JSON.parse(await f.text());if(!Array.isArray(rows))throw Error('File non valido');for(let i=0;i<rows.length;i+=20){let r=await fetch('/api/import-config',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(rows.slice(i,i+20))});if(!r.ok)throw Error(await r.text());s.textContent='Righe importate: '+Math.min(i+20,rows.length)+'/'+rows.length}s.textContent='Configurazione importata. Apri app.'}catch(x){s.textContent='Errore: '+x.message}finally{e.target.disabled=false}}</script></html>`;
const INITIAL_TASKS = [
  ["Imparare spagnolo o francese", "action", "todo", null, "ANASS.md - corsi"],
  ["Provare un corso di ballo", "action", "todo", null, "ANASS.md - corsi"],
  [
    "Fare l\u2019ISEE e welfare",
    "action",
    "todo",
    "2026-09-25",
    "ANASS.md - Attivo",
  ],
  ["Scaffale scarpe fai da te", "action", "todo", null, "ANASS.md - Attivo"],
  ["Coperta", "action", "todo", null, "ANASS.md - Attivo"],
  ["Riparazione carrozzeria auto", "action", "todo", null, "ANASS.md - Attivo"],
  [
    "Quality real leather boots, belt, jacket",
    "wishlist",
    "todo",
    null,
    "ANASS.md - Attivo",
  ],
  ["Vendere l\u2019anello", "action", "todo", null, "ANASS.md - Non urgenti"],
  ["Wi-Fi", "action", "todo", null, "ANASS.md - Non urgenti"],
  [
    "Poster usato, mercatino dell\u2019usato e framed + cornici",
    "wishlist",
    "todo",
    null,
    "ANASS.md - Non urgenti",
  ],
  [
    "Piante per il terrazzo",
    "wishlist",
    "todo",
    null,
    "ANASS.md - Non urgenti",
  ],
  ["Fotocamera", "wishlist", "todo", null, "ANASS.md - Non urgenti"],
  ["Led letto gialli", "wishlist", "todo", null, "ANASS.md - Non urgenti"],
  ["Led sopra la cucina", "wishlist", "todo", null, "ANASS.md - Non urgenti"],
  [
    "Air Quality/CO2 monitor",
    "wishlist",
    "todo",
    null,
    "ANASS.md - Non urgenti",
  ],
  [
    "Preventivi per apparecchio",
    "action",
    "todo",
    null,
    "ANASS.md - L\u2019odontoiatria Empoli, Frau, Dental Clinique",
  ],
  ["Titanfall 2", "games", "todo", null, "ANASS.md - Giochi"],
  ["Trepang 2", "games", "todo", null, "ANASS.md - Giochi"],
  ["Resident Evil 4 Remake", "games", "todo", null, "ANASS.md - Giochi"],
  ["Max Payne 3", "games", "todo", null, "ANASS.md - Giochi"],
  ["Attached - Amir Levine", "books", "todo", null, "ANASS.md - Libri"],
];
const LOGIN_PAGE = `<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#111111"><link rel="manifest" href="/manifest.webmanifest"><link rel="apple-touch-icon" href="/apple-touch-icon.png"><meta name="apple-mobile-web-app-capable" content="yes"><title>Life OS \u00b7 Accesso</title><style>*{box-sizing:border-box}body{min-height:100dvh;display:grid;place-items:center;margin:0;background:#000000;color:#f0f4fa;font:16px system-ui;padding:18px}main{width:min(370px,100%);padding:27px;border:1px solid #344159;border-radius:18px;background:#1b2534}h1{margin:0 0 8px;font-size:24px}p{color:#b1bfd0;line-height:1.45}label{display:block;margin:16px 0 6px}input,button{width:100%;padding:13px;font:inherit;border-radius:9px}input{border:1px solid #54647c;background:#121d2b;color:white}button{border:0;margin-top:20px;background:#7790e6;color:#0e1623;font-weight:700}small{color:#ffaaa9}body{background:radial-gradient(ellipse at 50% 0%,#3d3d3d66,transparent 65%),#111111;color:#f3f3f1;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}main{background:#1c1c1c;border:1px solid #ffffff10;border-radius:28px;padding:30px}h1{font-size:32px;letter-spacing:-.04em}p,label{color:#a6a6a3;font-size:13px}input{background:#131313;border:1px solid #ffffff15;border-radius:14px;min-height:48px}button{border-radius:24px;min-height:48px;color:#fff;background:linear-gradient(145deg,#e9d9bb55,#7aaeff20),#447dc7c9;border:1px solid #e9d9bb55;box-shadow:inset 0 1px #ffffff25;font-weight:550}input:focus-visible,button:focus-visible{outline:2px solid #d6bd91;outline-offset:3px}small{color:#ff9da4}</style><main><h1>Life OS</h1><form id="login"><label>Nome utente</label><input name="user" autocomplete="username" value="nas" required><label>Password</label><input name="password" type="password" autocomplete="current-password" required><button>Accedi</button></form><p><small id="error"></small></p></main><script>document.querySelector('#login').onsubmit=async e=>{e.preventDefault();const f=e.target,b=f.querySelector('button'),box=document.querySelector('#error');b.disabled=true;box.textContent='';try{let r=await fetch('/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({user:f.elements.namedItem('user').value,password:f.elements.namedItem('password').value})});if(!r.ok)throw Error('Credenziali non valide.');location.href='/'}catch(x){box.textContent=x.message;b.disabled=false}}</script></html>`;
const noCache = {
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
};
const response = (value, status = 200) =>
  Response.json(value, { status, headers: noCache });
const fail = (message, status = 400) =>
  new Response(message, { status, headers: noCache });
const icon = (b64) =>
  new Response(
    Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)),
    {
      headers: {
        "content-type": "image/png",
        "cache-control": "public, max-age=86400",
      },
    },
  );
const encode64 = (x) =>
  btoa(String.fromCharCode(...x))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
const decode64 = (x) =>
  Uint8Array.from(
    atob(
      x
        .replace(/-/g, "+")
        .replace(/_/g, "/")
        .padEnd(Math.ceil(x.length / 4) * 4, "="),
    ),
    (c) => c.charCodeAt(0),
  );

/** Deriva una chiave HMAC dal secret di deploy, mai incorporato nel codice. */
async function cookieKey(secret) {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/** Cookie firmato, Secure, HttpOnly e SameSite Strict con scadenza di 30 giorni. */
async function sessionCookie(secret) {
  const payload = encode64(
    new TextEncoder().encode(
      JSON.stringify({ exp: Date.now() + 30 * 86400000 }),
    ),
  );
  const signature = encode64(
    new Uint8Array(
      await crypto.subtle.sign(
        "HMAC",
        await cookieKey(secret),
        new TextEncoder().encode(payload),
      ),
    ),
  );
  return `liquidita_session=${payload}.${signature}; Path=/; Max-Age=2592000; Secure; HttpOnly; SameSite=Strict`;
}

/** Verifica firma e scadenza del cookie; input malformati falliscono chiusi. */
async function validSession(req, secret) {
  const match = (req.headers.get("cookie") || "").match(
    /(?:^|;\s*)liquidita_session=([^;]+)/,
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
        new TextEncoder().encode(body),
      ),
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

/** Compatibilità Basic auth; confronto digest senza uscita anticipata sui byte. */
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
  let enc = new TextEncoder(),
    [a, b] = await Promise.all([
      crypto.subtle.digest("SHA-256", enc.encode(parts.join(":"))),
      crypto.subtle.digest("SHA-256", enc.encode(secret)),
    ]);
  let diff = 0,
    x = new Uint8Array(a),
    y = new Uint8Array(b);
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}
const date = (s) =>
  s
    ? new Date(
        s.length === 7
          ? s + "-01T12:00:00Z"
          : s.length === 10
            ? s + "T12:00:00Z"
            : s + "Z",
      )
    : null;
const iso = (s) => String(s || "").slice(0, 10);
const month = (s) => iso(s).slice(0, 7);
const nowDay = () =>
  new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Europe/Rome",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
const planYear = (value) => {
  const y = Number(value);
  return Number.isInteger(y) && y >= 2024 && y <= 2035
    ? y
    : Number(nowDay().slice(0, 4));
};
const validAmount = (value, max = 1e6) => {
  let n = Number(value);
  if (!Number.isFinite(n) || n <= 0 || n > max)
    throw Error("Importo non valido.");
  return n;
};
const validCents = (value) => {
  const n = validAmount(value),
    c = Math.round(n * 100);
  if (!Number.isSafeInteger(c) || c < 1 || Math.abs(c / 100 - n) > 0.00000001)
    throw Error("Usa importi con massimo due decimali.");
  return c;
};
const validDate = (value) => {
  if (
    typeof value !== "string" ||
    !/^20\d\d-\d\d-\d\d$/.test(value) ||
    !Number.isFinite(new Date(value).getTime()) ||
    new Date(value).toISOString().slice(0, 10) !== value
  )
    throw Error("Data non valida.");
  return value;
};

/** Adattatore record D1 -> colonne workbook. Non riordinare senza aggiornare il motore. */
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
    r.financial_category_id,
  ];
}

/** Adattatore straordinaria D1 -> colonne workbook storiche. */
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
    r.repeat_rule,
  ].map((v, i) => ([2, 5, 8].includes(i) ? date(v) : v));
}

/** Emula letture del foglio usando D1, preservando source_row anche con buchi. */
function sheetBook(config, movements, extras) {
  let sheets = new Map();
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
    ["Storico patrimonio", [0]],
  ]) {
    let rows = sheets.get(name) || [];
    for (let r of rows)
      if (r)
        for (let i of indices)
          if (
            r[i] &&
            typeof r[i] === "string" &&
            /^20\d\d-\d\d-\d\d/.test(r[i])
          )
            r[i] = date(r[i]);
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
            let column = (s) =>
              [...s].reduce((v, c) => v * 26 + c.charCodeAt(0) - 64, 0);
            first = column(match[1]);
            width = column(match[3]) - first + 1;
          } else {
            [start, first, height, width] = args;
          }
          return {
            getValues: () =>
              Array.from({ length: height }, (_, i) =>
                Array.from(
                  { length: width },
                  (_, j) => rows[start + i - 1]?.[first + j - 1] ?? "",
                ),
              ),
          };
        },
      };
    },
  };
}

/** Legge D1, calcola il modello e aggiunge analytics solo per richieste complete. */
async function loadFinance(env, year, monthNumber, lightweight = false) {
  await ensureTrStatement(env);
  await ensureBudgetPolicies(env);
  if (!lightweight) await ensureFinanceCategories(env);
  const [m, e, c, snapshots, events, categoryRows, categoryMappings, utilityConfig] =
    await Promise.all([
      env.DB.prepare(
        lightweight
          ? "SELECT * FROM movements ORDER BY source_row"
          : "SELECT m.*,c.detail_category resolved_category,c.category_id financial_category_id FROM movements m LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row ORDER BY m.source_row",
      ).all(),
      env.DB.prepare("SELECT * FROM extraordinary ORDER BY source_row").all(),
      env.DB.prepare(
        "SELECT sheet,row_number,values_json FROM source_rows ORDER BY sheet,row_number",
      ).all(),
      env.DB.prepare(
        "SELECT * FROM account_balance_snapshots ORDER BY id",
      ).all(),
      env.DB.prepare("SELECT * FROM account_balance_events ORDER BY id").all(),
      lightweight
        ? Promise.resolve({ results: [] })
        : env.DB.prepare(
            "SELECT * FROM financial_categories ORDER BY sort_order,id",
          ).all(),
      lightweight
        ? Promise.resolve({ results: [] })
        : env.DB.prepare("SELECT * FROM financial_category_mappings").all(),
      env.DB.prepare("SELECT value FROM os_meta WHERE key='utility_estimates_v1'").first(),
    ]);
  const config = [
    ...c.results,
    {sheet:"Stime utenze",row_number:1,values_json:JSON.stringify([utilityConfig?.value?JSON.parse(utilityConfig.value):{}])},
    {
      sheet: "Categorie finanziarie",
      row_number: 1,
      values_json: JSON.stringify([
        categoryRows.results.map((c) => ({
          ...c,
          members: categoryMappings.results
            .filter((m) => m.category_id === c.id)
            .map((m) => m.detail_category),
        })),
      ]),
    },
  ];
  if (!config.some((r) => r.sheet === "Budget"))
    throw Error("Apri /setup e importa liquidita-4.0-config.json.");
  const plan = await getExtraPlan(env, planYear(year));
  plan.budgetPolicies=(await env.DB.prepare("SELECT p.*,m.description,m.amount,m.actual_date,m.status FROM movement_budget_policies p JOIN movements m ON m.source_row=p.movement_source_row").all()).results;
  const condo=(await env.DB.prepare("SELECT value FROM os_meta WHERE key='condominium_estimates_v1'").first())?.value;
  plan.condominiumSettings=condo?JSON.parse(condo):{base:0,changes:[{month:"2026-10",value:25}]};
  // Nas confirmed that the legacy 575 includes 25 condo, now shown separately.
  // Persist once, rather than subtracting every future condo estimate from rent.
  await env.DB.prepare("INSERT OR IGNORE INTO os_meta(key,value) SELECT 'rent_condominium_split_v1158',? WHERE EXISTS(SELECT 1 FROM source_rows WHERE sheet='Budget' AND row_number=3 AND ROUND(CAST(json_extract(values_json,'$[14]') AS REAL)*100)=57500)").bind(JSON.stringify({fromMonth:"2026-10",sourceAmount:575,rent:550})).run();
  const rentSplit=await env.DB.prepare("SELECT value FROM os_meta WHERE key='rent_condominium_split_v1158'").first();
  plan.rentSplit=rentSplit?.value?JSON.parse(rentSplit.value):null;
  const currentYear = Number(nowDay().slice(0,4));
  if (planYear(year) !== currentYear) {
    const currentPlan = await getExtraPlan(env,currentYear);
    plan.allocations.push(...currentPlan.allocations);
    // links are already read globally by getExtraPlan.
  }
  const result = computeFinance(
    sheetBook(config, m.results, e.results),
    year,
    monthNumber,
    plan,
    snapshots.results,
    events.results,
    lightweight,
  );
  attachSavingsPlanning(result, c.results, nowDay());
  result.forecastHistory = forecastCashHistory(m.results, plan, nowDay());
  if (!lightweight) {
    const y=Number(nowDay().slice(0,4));
    const nextPlan=await getExtraPlan(env,y+1);
    const cycles=new Map([...plan.allocations,...nextPlan.allocations].map(a=>[a.cycle_id+":"+a.month,a]));
    result.forecastPlan={...plan,allocations:[...cycles.values()]};
  }
  if (lightweight) return result;

  await env.DB.prepare(
    "CREATE TABLE IF NOT EXISTS financial_reporting_adjustments(id TEXT PRIMARY KEY,label TEXT NOT NULL,amount_cents INTEGER NOT NULL CHECK(amount_cents>=0),as_of_day TEXT NOT NULL,method TEXT NOT NULL)",
  ).run();
  const gap = Math.max(
    0,
    Math.round(
      (result.lifetime.income -
        result.lifetime.spent -
        result.summary.totalAssets) *
        100,
    ),
  );
  await env.DB.prepare(
    "INSERT OR IGNORE INTO financial_reporting_adjustments(id,label,amount_cents,as_of_day,method) VALUES ('legacy_spending','Spese storiche non dettagliate',?,?, 'Stima autorizzata: redditi documentati meno spese registrate meno liquidita rilevata alla data della stima')",
  )
    .bind(gap, new Date().toISOString().slice(0, 10))
    .run();
  const adjustment = await env.DB.prepare(
    "SELECT * FROM financial_reporting_adjustments WHERE id='legacy_spending'",
  ).first();
  result.lifetime.recordedSpent = result.lifetime.spent;
  result.lifetime.historicalSpendingEstimate = {
    ...adjustment,
    amount: adjustment.amount_cents / 100,
  };
  if (adjustment.amount_cents > 0) {
    const amount = adjustment.amount_cents / 100;
    result.lifetime.spent =
      Math.round((result.lifetime.spent + amount) * 100) / 100;
    result.lifetime.expenses.push({
      name: adjustment.label,
      amount,
      estimated: true,
    });
    const group =
      result.lifetime.expenseGroups.find((g) => g.id === 10) ||
      result.lifetime.expenseGroups.find((g) =>
        g.members.includes("Pagamenti non dettagliati"),
      );
    if (group) {
      group.amount = Math.round((group.amount + amount) * 100) / 100;
      group.members.push(adjustment.label);
    }
    result.lifetime.expenseGroups.sort((a, b) => b.amount - a.amount);
    for (const group of result.lifetime.expenseGroups)
      group.percentage = Math.round(
        (group.amount / result.lifetime.spent) * 100,
      );
    result.lifetime.expenseAudit.push({
      row: null,
      date: "Storico",
      name: adjustment.label,
      amount,
      category: adjustment.label,
      account: "Conti precedenti",
      estimated: true,
    });
  }
  result.extraPlan = plan;
  result.categoryOptions = [...FINANCE_MANUAL_CATEGORIES];
  return result;
}

/** Esportazione paginata di righe finanziarie per manutenzione autenticata. */
async function getFinanceRaw(env, offset) {
  await ensureTrStatement(env);
  const n = Number(offset);
  if (!Number.isInteger(n) || n < 0 || n > 100000 || n % 50 !== 0)
    throw Error("Pagina non valida.");
  const movements = (
    await env.DB.prepare(
      "SELECT * FROM movements ORDER BY source_row LIMIT 50 OFFSET ?",
    )
      .bind(n)
      .all()
  ).results;
  return { movements };
}

/** Metadati/configurazione per la manutenzione autenticata. */
async function getFinanceMeta(env) {
  await ensureTrStatement(env);
  const [count, extras, config, snapshots, events] = await Promise.all([
    env.DB.prepare("SELECT COUNT(*) AS total FROM movements").first(),
    env.DB.prepare("SELECT * FROM extraordinary ORDER BY source_row").all(),
    env.DB.prepare(
      "SELECT sheet,row_number,values_json FROM source_rows ORDER BY sheet,row_number",
    ).all(),
    env.DB.prepare("SELECT * FROM account_balance_snapshots ORDER BY id").all(),
    env.DB.prepare("SELECT * FROM account_balance_events ORDER BY id").all(),
  ]);
  return {
    total: count.total,
    extras: extras.results,
    config: config.results,
    bankSnapshots: snapshots.results,
    bankEvents: events.results,
  };
}

/** Aggiorna una riga JSON della configurazione legacy; errore se manca. */
async function updateSheetRow(env, sheet, rowNumber, change) {
  const found = await env.DB.prepare(
    "SELECT values_json FROM source_rows WHERE sheet=? AND row_number=?",
  )
    .bind(sheet, rowNumber)
    .first();
  if (!found)
    throw Error(
      "Configurazione non importata: " + sheet + " riga " + rowNumber,
    );
  const values = JSON.parse(found.values_json);
  change(values);
  await env.DB.prepare(
    "UPDATE source_rows SET values_json=? WHERE sheet=? AND row_number=?",
  )
    .bind(JSON.stringify(values), sheet, rowNumber)
    .run();
}

/** Invia la stima della voce selezionata; il server valida nome e intervallo. */
async function saveEstimate(env, name, value) {
  if(name==="Condominio"){
    const n=Number(value);if(!Number.isFinite(n)||n<0||n>1000||Math.abs(Math.round(n*100)/100-n)>1e-8)throw Error("Stima non valida: usa massimo due decimali.");
    const stored=await env.DB.prepare("SELECT value FROM os_meta WHERE key='condominium_estimates_v1'").first();
    const settings=stored?.value?JSON.parse(stored.value):{base:0,changes:[{month:"2026-10",value:25}]},month=nowDay().slice(0,7);
    settings.changes=[...(settings.changes||[]).filter(x=>x.month!==month),{month,value:Math.round(n*100)/100}];
    await env.DB.prepare("INSERT INTO os_meta(key,value) VALUES ('condominium_estimates_v1',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value").bind(JSON.stringify(settings)).run();return true;
  }
  const index = {
    "Elettricit\u00e0": 2,
    Gas: 3,
    Acqua: 4,
    Palestra: 5,
    Abbonamenti: 6,
    Benzina: 7,
  }[name];
  if (!index) throw Error("Voce non valida.");
  let n = Number(value);
  if (!Number.isFinite(n) || n < 0 || n > 1000 || Math.abs(Math.round(n*100)/100-n)>1e-8)
    throw Error("Stima non valida: usa massimo due decimali.");
  if(["Elettricità","Gas","Acqua"].includes(name)) {
    const stored=await env.DB.prepare("SELECT value FROM os_meta WHERE key='utility_estimates_v1'").first();
    const settings=stored?.value?JSON.parse(stored.value):{};
    const prior=await env.DB.prepare("SELECT values_json FROM source_rows WHERE sheet='Budget' AND row_number=?").bind(index).first();
    const config=settings[name]||{base:Number(prior?JSON.parse(prior.values_json)[1]:n)||0,changes:[]};
    const month=nowDay().slice(0,7);
    config.changes=[...(config.changes||[]).filter(x=>x.month!==month),{month,value:n}];settings[name]=config;
    const path='$."'+name+'"',encoded=JSON.stringify(config);
    await env.DB.prepare("INSERT INTO os_meta(key,value) VALUES ('utility_estimates_v1',json_set('{}',?,json(?))) ON CONFLICT(key) DO UPDATE SET value=json_set(os_meta.value,?,json(?))").bind(path,encoded,path,encoded).run();
  } else await updateSheetRow(env, "Budget", index, (row) => (row[1] = n));
  return true;
}




/** Registra il delta del movimento appena inserito, identificato da import_id univoco. */
function insertedBalanceEvent(env, importId, absorbedId = null) {
  return env.DB.prepare(
    `INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row,absorbed_snapshot_id)
  SELECT account,substr(actual_date,1,10),CAST(ROUND(amount*100) AS INTEGER),source_row,?
  FROM movements WHERE import_id=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')`,
  ).bind(absorbedId, importId);
}

/** Recupera e valida un source_row esistente prima delle operazioni di modifica. */
async function getMovement(env, id) {
  if (!Number.isInteger(id) || id < 2) throw Error("Movimento non valido.");
  const row = await env.DB.prepare("SELECT * FROM movements WHERE source_row=?")
    .bind(id)
    .first();
  if (!row) throw Error("Movimento non trovato. Aggiorna la pagina.");
  await ensureBudgetPolicies(env);
  const policy=await env.DB.prepare("SELECT * FROM movement_budget_policies WHERE movement_source_row=?").bind(id).first();
  return {...row,budgetTreatment:policy?.treatment || "auto",recoveryMonths:policy?JSON.parse(policy.recovery_json).map(q=>q.month).join(", "):"",recoveryAmount:policy?JSON.parse(policy.recovery_json).reduce((n,q)=>n+q.amount_cents,0)/100:0};
}

/** Trova la seconda riga di un trasferimento; rifiuta abbinamenti ambigui. */
async function findMirror(env, row) {
  if (row.transfer_id) {
    const pair = (
      await env.DB.prepare("SELECT * FROM movements WHERE transfer_id=?")
        .bind(row.transfer_id)
        .all()
    ).results;
    const other = pair.find((x) => x.source_row !== row.source_row);
    if (
      pair.length !== 2 ||
      !other ||
      row.movement_type !== "Trasferimento" ||
      other.movement_type !== "Trasferimento" ||
      other.account !== row.counterparty_account ||
      other.counterparty_account !== row.account ||
      Math.abs(other.amount + row.amount) >= 0.005
    )
      throw Error("Trasferimento non coerente: nessuna modifica applicata.");
    return other;
  }
  if (
    row.movement_type !== "Trasferimento" ||
    row.source_name !== "App 4.0" ||
    !row.counterparty_account
  )
    return null;
  const rows = (
    await env.DB.prepare(
      "SELECT * FROM movements WHERE source_row<>? AND transfer_id IS NULL AND movement_type='Trasferimento' AND source_name='App 4.0' AND account=? AND counterparty_account=? AND actual_date=? AND ABS(amount+?)<0.005",
    )
      .bind(
        row.source_row,
        row.counterparty_account,
        row.account,
        row.actual_date,
        row.amount,
      )
      .all()
  ).results;
  // Existing app-created pairs have different import IDs. Only use a unique match.
  if (rows.length !== 1)
    throw Error(
      "Trasferimento storico ambiguo o incompleto: nessuna modifica applicata.",
    );
  return rows[0];
}

/** Aggiorna movimento, eventuale speculare e delta conto nello stesso batch. */
async function saveMovementEdit(env, input) {
  const old = await getMovement(env, Number(input?.row));
  if (
    ![
      "Spesa",
      "Entrata",
      "Trasferimento",
      "Investimento",
      "Da verificare",
    ].includes(old.movement_type)
  )
    throw Error("Tipo storico non modificabile da questa schermata.");
  const type = String(input.type || "");
  if (
    ![
      "Spesa",
      "Entrata",
      "Rimborso",
      "Trasferimento",
      "Investimento",
      "Da verificare",
    ].includes(type)
  )
    throw Error("Tipo non valido.");
  const account = String(input.account || "");
  if (!["Revolut", "Trade Republic", "IsyBank"].includes(account))
    throw Error("Conto non valido.");
  let counterpart =
    type === "Trasferimento" ? String(input.counterpart || "") : "";
  if (
    type === "Trasferimento" &&
    (!["Revolut", "Trade Republic", "IsyBank"].includes(counterpart) ||
      counterpart === account)
  )
    throw Error("Conto di destinazione non valido.");
  const name = String(input.name || "")
      .trim()
      .slice(0, 120),
    day = validDate(input.date),
    amount = validCents(input.amount) / 100;
  if (!name || day > nowDay()) throw Error("Descrizione o data non valida.");
  const months = Number(input.months ?? 1);
  if (!Number.isInteger(months) || months < 1 || months > 12)
    throw Error("Mesi coperti non validi.");
  const category =
    type === "Trasferimento"
      ? "Altro"
      : String(input.category || "Altro")
          .trim()
          .slice(0, 60);
  const signed =
    type === "Rimborso" || type === "Entrata"
      ? amount
      : ["Investimento", "Da verificare", "Trasferimento", "Spesa"].includes(
            type,
          ) &&
          old.movement_type === type &&
          old.amount > 0 && !String(old.notes||"").startsWith("Rimborso / restituzione:")
        ? amount
        : -amount;
  const end =
    new Date(
      Date.UTC(
        Number(day.slice(0, 4)),
        Number(day.slice(5, 7)) - 1 + months,
        0,
      ),
    )
      .toISOString()
      .slice(0, 7) + "-01";
  const mirror = await findMirror(env, old);
  const linked = (
    await env.DB.prepare(
      `SELECT DISTINCT cycle_id FROM extraordinary_movement_links
  WHERE movement_source_row IN (${mirror ? "?,?" : "?"})`,
    )
      .bind(
        ...(mirror ? [old.source_row, mirror.source_row] : [old.source_row]),
      )
      .all()
  ).results;
  if (
    linked.length &&
    (account !== old.account ||
      (mirror && counterpart !== old.counterparty_account))
  )
    throw Error(
      "Un conto \u00e8 collegato a una straordinaria: scollega prima il movimento.",
    );
  const settlement=linked.length?await env.DB.prepare("SELECT * FROM extraordinary_settlements WHERE movement_source_row=?").bind(old.source_row).first():null;
  if(linked.length){
    const attributed=await env.DB.prepare("SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE movement_source_row=?").bind(old.source_row).first();
    const required=Number(attributed.n)-(settlement?Math.min(settlement.actual_cents,settlement.planned_cents):0)+(settlement?Math.min(Math.round(-signed*100),settlement.planned_cents):0);
    if(type!==old.movement_type || signed>=0 || Math.round(-signed*100)<required)throw Error("Scollega il piano prima di ridurre l’importo attribuito o cambiare il tipo.");
  }
  const query =
    "UPDATE movements SET actual_date=?,budget_date=?,description=?,amount=?,account=?,category=?,movement_type=?,counterparty_account=?,merchant=?,competence_months=?,budget_month=?,competence_end=?,monthly_share=?,actual_month=?,transfer_id=?,notes=? WHERE source_row=?";
  const sameSchedule =
    String(old.actual_date || "").slice(0, 10) === day &&
    Number(old.competence_months || 1) === months;
  const budgetMonth =
    sameSchedule && old.budget_month
      ? old.budget_month
      : day.slice(0, 7) + "-01";
  const competenceEnd =
    sameSchedule && old.competence_end ? old.competence_end : end;
  const primary = env.DB.prepare(query).bind(
    day,
    sameSchedule && old.budget_date ? old.budget_date : day,
    name,
    signed,
    account,
    category,
    type === "Rimborso" ? "Spesa" : type,
    counterpart,
    name,
    months,
    budgetMonth,
    competenceEnd,
    type === "Spesa" ? -signed / months : null,
    day.slice(0, 7) + "-01",
    type === "Trasferimento" ? old.transfer_id : null,
    (type==="Rimborso"?"Rimborso / restituzione: ":"")+String(old.notes||"").replace(/^Rimborso \/ restituzione:\s*/,""),
    old.source_row,
  );
  const policyInput=input.budgetTreatment===undefined?{...input,budgetTreatment:type==="Spesa"?old.budgetTreatment:"auto",recoveryMonths:old.recoveryMonths,recoveryAmount:Math.min(old.recoveryAmount||amount,amount)}:input;
  const policy=validatedBudgetPolicy(policyInput,amount,day,type);
  if(policy.treatment==="recovery" && signed>=0)throw Error("Un rimborso non può creare un recupero di spesa.");
  if(linked.length && policy.treatment==="recovery")throw Error("Questo movimento è già coperto da un piano. Scollegalo prima di creare un recupero.");
  const operations = [primary,budgetPolicyStatement(env,old.source_row,policy),env.DB.prepare("UPDATE movements SET notes=CASE WHEN instr(COALESCE(notes,''),'[Categoria manuale]')>0 THEN notes ELSE COALESCE(notes,'')||' [Categoria manuale]' END WHERE source_row=?").bind(old.source_row)];
  if(settlement){
    const nextCents=Math.round(-signed*100),attribute=Math.min(nextCents,settlement.planned_cents);
    const linkUpdate=env.DB.prepare("UPDATE extraordinary_movement_links SET attributed_cents=? WHERE cycle_id=? AND movement_source_row=?").bind(attribute,settlement.cycle_id,old.source_row);
    if(attribute<=Math.min(settlement.actual_cents,settlement.planned_cents))operations.unshift(linkUpdate);else operations.push(linkUpdate);
    operations.push(env.DB.prepare("UPDATE extraordinary_settlements SET actual_cents=? WHERE movement_source_row=?").bind(nextCents,old.source_row));
  }
  const changed = [
    { old, next: { account, actual_date: day, amount: signed } },
  ];
  if (mirror) {
    if (type === "Trasferimento") {
      operations.push(
        env.DB.prepare(query).bind(
          day,
          day,
          "Trasferimento da " + account,
          -signed,
          counterpart,
          "Altro",
          "Trasferimento",
          account,
          "Trasferimento da " + account,
          months,
          budgetMonth,
          competenceEnd,
          null,
          day.slice(0, 7) + "-01",
          old.transfer_id,
          mirror.notes||"",
          mirror.source_row,
        ),
      );
      changed.push({
        old: mirror,
        next: { account: counterpart, actual_date: day, amount: -signed },
      });
    } else {
      operations.push(
        env.DB.prepare("DELETE FROM movements WHERE source_row=?").bind(
          mirror.source_row,
        ),
      );
      changed.push({ old: mirror, next: null });
    }
  } else if (
    type === "Trasferimento" &&
    old.movement_type !== "Trasferimento"
  ) {
    // Reclassifying an imported row does not invent a bank movement on another account.
    // An app-created transfer is instead created as a pair by saveTransaction.
  }
  const balanceOperations=[];
  for(const item of changed){
    balanceOperations.push(env.DB.prepare("INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row) SELECT account,substr(actual_date,1,10),-CAST(ROUND(amount*100) AS INTEGER),source_row FROM movements WHERE source_row=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')").bind(item.old.source_row));
    if(item.next && ["Revolut","Trade Republic"].includes(item.next.account))balanceOperations.push(env.DB.prepare("INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row) SELECT ?,?,?,source_row FROM movements WHERE source_row=? AND status='Eseguito'").bind(item.next.account,item.next.actual_date,Math.round(item.next.amount*100),item.old.source_row));
  }
  operations.unshift(...balanceOperations);
  for (const link of linked)
    operations.push(
      env.DB.prepare(
        `UPDATE extraordinary SET status=(
   SELECT status FROM extraordinary_cycles WHERE id=?),paid_date=(
   SELECT MAX(m.actual_date) FROM extraordinary_movement_links l JOIN movements m
   ON m.source_row=l.movement_source_row WHERE l.cycle_id=?)
   WHERE source_row=(SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?)`,
      ).bind(link.cycle_id, link.cycle_id, link.cycle_id),
    );
  await env.DB.batch(operations);
  return true;
}

/** Elimina movimento e speculare con storno condizionato atomico, una sola volta. */
async function deleteMovement(env, id) {
  const old = await getMovement(env, Number(id));
  const mirror = await findMirror(env, old);
  const rows = [old, ...(mirror ? [mirror] : [])];
  const linked = (
    await env.DB.prepare(
      `SELECT DISTINCT cycle_id FROM extraordinary_movement_links
   WHERE movement_source_row IN (${rows.map(() => "?").join(",")})`,
    )
      .bind(...rows.map((r) => r.source_row))
      .all()
  ).results;
  await env.DB.batch([
    // Reverse only rows that STILL exist, inside the same atomic batch as DELETE.
    // Two simultaneous delete requests must not credit the account twice.
    ...rows.map((r) =>
      env.DB.prepare(
        `INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row)
    SELECT account,substr(actual_date,1,10),-CAST(ROUND(amount*100) AS INTEGER),source_row
    FROM movements WHERE source_row=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')`,
      ).bind(r.source_row),
    ),
    ...rows.map((r) =>
      env.DB.prepare(
        "DELETE FROM extraordinary_movement_links WHERE movement_source_row=?",
      ).bind(r.source_row),
    ),
    ...rows.map(r=>env.DB.prepare("DELETE FROM movement_budget_policies WHERE movement_source_row=?").bind(r.source_row)),
    ...rows.map(r=>env.DB.prepare("DELETE FROM extraordinary_settlements WHERE movement_source_row=?").bind(r.source_row)),
    ...rows.map((r) =>
      env.DB.prepare("DELETE FROM movements WHERE source_row=?").bind(
        r.source_row,
      ),
    ),
    ...linked.flatMap((x) => syncExtraStatusStatements(env, x.cycle_id)),
    ...linked.map((x) =>
      env.DB.prepare(
        `UPDATE extraordinary SET status=(
    SELECT status FROM extraordinary_cycles WHERE id=?),
    paid_date=(SELECT MAX(m.actual_date) FROM extraordinary_movement_links l
      JOIN movements m ON m.source_row=l.movement_source_row WHERE l.cycle_id=?)
    WHERE source_row=(SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?)`,
      ).bind(x.cycle_id, x.cycle_id, x.cycle_id),
    ),
  ]);
  return { deleted: mirror ? 2 : 1 };
}
// Schema readiness is per D1 binding; concurrent cold starts share one promise.
const lifeSchemaJobs = new WeakMap();

/** Condivide l’inizializzazione per binding D1; un errore consente un nuovo tentativo. */
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

/** Migrazioni idempotenti e seed storici protetti da os_meta; non resettare i marcatori. */
async function initializeLife(env) {
  await env.DB.batch([
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_meta (key TEXT PRIMARY KEY,value TEXT NOT NULL)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_tasks (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,list_kind TEXT NOT NULL DEFAULT 'action',status TEXT NOT NULL DEFAULT 'todo',due_date TEXT,scheduled_date TEXT,notes TEXT NOT NULL DEFAULT '',import_key TEXT UNIQUE,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,completed_at TEXT)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_categories (key TEXT PRIMARY KEY,label TEXT NOT NULL COLLATE NOCASE UNIQUE,position INTEGER NOT NULL DEFAULT 0)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_shifts (day TEXT PRIMARY KEY,kind TEXT NOT NULL,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_events (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,day TEXT NOT NULL,start_time TEXT,end_time TEXT,location TEXT NOT NULL DEFAULT '',notes TEXT NOT NULL DEFAULT '',created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_event_repeat (event_id INTEGER PRIMARY KEY,frequency TEXT NOT NULL,until_day TEXT)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_routines (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,position INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_routine_checks (routine_id INTEGER NOT NULL,day TEXT NOT NULL,checked_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY(routine_id,day))",
    ),
  ]);
  await env.DB.batch(
    [
      ["action", "Attivit\u00e0", 0],
      ["wishlist", "Desideri", 1],
      ["games", "Giochi", 2],
      ["books", "Letture", 3],
    ].map(([key, label, position]) =>
      env.DB.prepare(
        "INSERT OR IGNORE INTO os_categories(key,label,position) SELECT ?,?,? WHERE NOT EXISTS (SELECT 1 FROM os_meta WHERE key='deleted_category:'||?)",
      ).bind(key, label, position,key),
    ),
  );
  const seeded = await env.DB.prepare(
    "SELECT value FROM os_meta WHERE key='anass_import_20260926'",
  ).first();
  if (!seeded) {
    await env.DB.batch(
      INITIAL_TASKS.map(([title, list_kind, status, due_date, notes], i) =>
        env.DB.prepare(
          "INSERT OR IGNORE INTO os_tasks(title,list_kind,status,due_date,notes,import_key) VALUES (?,?,?,?,?,?)",
        ).bind(
          title,
          list_kind,
          status,
          due_date,
          notes,
          "anass-20260926-" + i,
        ),
      ),
    );
    await env.DB.prepare(
      "INSERT OR IGNORE INTO os_meta(key,value) VALUES ('anass_import_20260926','21')",
    ).run();
  }
  if (
    !(await env.DB.prepare(
      "SELECT value FROM os_meta WHERE key='routine_seed_v1'",
    ).first())
  ) {
    await env.DB.batch([
      env.DB.prepare(
        "INSERT INTO os_routines(title,position) SELECT 'Creatina',0 WHERE NOT EXISTS(SELECT 1 FROM os_meta WHERE key='routine_seed_v1')",
      ),
      env.DB.prepare(
        "INSERT INTO os_routines(title,position) SELECT 'Integratori',1 WHERE NOT EXISTS(SELECT 1 FROM os_meta WHERE key='routine_seed_v1')",
      ),
      env.DB.prepare(
        "INSERT OR IGNORE INTO os_meta(key,value) VALUES ('routine_seed_v1','1')",
      ),
    ]);
  }
  // One-time import from the September screenshot. Future edits are never reset.
  const shiftImport = "shifts_screenshot_202609";
  if (
    !(await env.DB.prepare("SELECT value FROM os_meta WHERE key=?")
      .bind(shiftImport)
      .first())
  ) {
    const codes =
      "R M M M P R P P R N N N R R P P F F F R P R M M R M M M R M".split(" ");
    const kinds = {
      M: "morning",
      P: "afternoon",
      N: "night",
      R: "rest",
      F: "holiday",
    };
    await env.DB.batch([
      ...codes.map((code, i) =>
        env.DB.prepare(
          "INSERT INTO os_shifts(day,kind) SELECT ?,? WHERE NOT EXISTS(SELECT 1 FROM os_meta WHERE key=?) ON CONFLICT(day) DO UPDATE SET kind=excluded.kind,updated_at=CURRENT_TIMESTAMP",
        ).bind(
          "2026-09-" + String(i + 1).padStart(2, "0"),
          kinds[code],
          shiftImport,
        ),
      ),
      env.DB.prepare(
        "INSERT OR IGNORE INTO os_meta(key,value) VALUES (?,?)",
      ).bind(shiftImport, "30"),
    ]);
  }
  // Older exports predate task ordering and occurrence exceptions.
  const columns = (await env.DB.prepare("PRAGMA table_info(os_tasks)").all())
    .results;
  if (!columns.some((column) => column.name === "sort_order")) {
    try {
      await env.DB.prepare(
        "ALTER TABLE os_tasks ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0",
      ).run();
    } catch (error) {
      const fresh = (await env.DB.prepare("PRAGMA table_info(os_tasks)").all())
        .results;
      if (!fresh.some((column) => column.name === "sort_order")) throw error;
    }
  }
  // Completion retains the originating section. Existing done rows belong to Active.
  if (!columns.some((column) => column.name === "section_status")) {
    try {
      await env.DB.prepare("ALTER TABLE os_tasks ADD COLUMN section_status TEXT NOT NULL DEFAULT 'todo'").run();
    } catch (error) {
      const fresh = (await env.DB.prepare("PRAGMA table_info(os_tasks)").all()).results;
      if (!fresh.some((column) => column.name === "section_status")) throw error;
    }
  }
  await env.DB.batch([
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_event_occurrences(event_id INTEGER NOT NULL,day TEXT NOT NULL,status TEXT NOT NULL,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY(event_id,day))",
    ),
    env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_os_tasks_list_order ON os_tasks(list_kind,status,sort_order,id)",
    ),
    env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_os_events_day ON os_events(day)",
    ),
  ]);
}
const validMonthKey = (s) =>
  typeof s === "string" && /^20\d\d-(0[1-9]|1[0-2])$/.test(s);
const validClock = (s) =>
  s === null ||
  s === "" ||
  (typeof s === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(s));

/** Espande ricorrenze in [low, high); 29/30/31 slittano all’ultimo giorno valido. */
function expandEvents(rows, low, high) {
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

/** Legge attività, turni e occorrenze; la home esclude eventi fatti o saltati. */
async function lifeRead(env, focus) {
  await ensureLife(env);
  const base = validMonthKey(focus) ? focus : nowDay().slice(0, 7);
  const first = new Date(base + "-01T12:00:00Z");
  const low = new Date(
    Date.UTC(first.getUTCFullYear(), first.getUTCMonth() - 1, 1),
  )
    .toISOString()
    .slice(0, 10);
  const high = new Date(
    Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 2, 1),
  )
    .toISOString()
    .slice(0, 10);
  const today = nowDay(),
    end = new Date(Date.parse(today + "T12:00:00Z") + 6 * 86400000)
      .toISOString()
      .slice(0, 10),
    clock = new Intl.DateTimeFormat("en-GB", {
      timeZone: "Europe/Rome",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).format(new Date());
  const [tasks, categories, shifts, events, routines, occurrences] =
    await Promise.all([
      env.DB.prepare(
        "SELECT * FROM os_tasks ORDER BY CASE status WHEN 'todo' THEN 0 WHEN 'waiting' THEN 1 ELSE 2 END,sort_order,id",
      ).all(),
      env.DB.prepare(
        "SELECT * FROM os_categories ORDER BY position,label",
      ).all(),
      env.DB.prepare(
        "SELECT * FROM os_shifts WHERE (day>=? AND day<?) OR day=? OR day=? ORDER BY day",
      )
        .bind(
          low,
          high,
          today,
          new Date(Date.parse(today + "T12:00:00Z") + 86400000)
            .toISOString()
            .slice(0, 10),
        )
        .all(),
      env.DB.prepare(
        "SELECT e.*,r.frequency,r.until_day FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.day<? ORDER BY e.day",
      )
        .bind(high)
        .all(),
      env.DB.prepare(
        "SELECT r.id,r.title,r.position,CASE WHEN c.routine_id IS NULL THEN 0 ELSE 1 END AS checked FROM os_routines r LEFT JOIN os_routine_checks c ON c.routine_id=r.id AND c.day=? ORDER BY r.position,r.id",
      )
        .bind(today)
        .all(),
      env.DB.prepare(
        "SELECT event_id,day,status FROM os_event_occurrences",
      ).all(),
    ]);
  const all = await env.DB.prepare(
    "SELECT e.*,r.frequency,r.until_day FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.day<=?",
  )
    .bind(end)
    .all();
  const next = new Date(Date.parse(end + "T12:00:00Z") + 86400000)
    .toISOString()
    .slice(0, 10);
  const statusMap = new Map(
    occurrences.results.map((o) => [o.event_id + ":" + o.day, o.status]),
  );
  const state = (e) => ({
    ...e,
    occurrence_status: statusMap.get(e.id + ":" + e.day) || "open",
  });
  return {
    tasks: tasks.results,
    categories: categories.results,
    shifts: shifts.results,
    events: expandEvents(events.results, low, high)
      .map(state)
      .filter((e) => e.occurrence_status !== "skipped"),
    upcomingEvents: expandEvents(all.results, today, next)
      .map(state)
      .filter(
        (e) =>
          e.occurrence_status === "open" &&
          (e.day > today || !e.start_time || e.start_time >= clock),
      )
      .slice(0, 3),
    routines: routines.results,
    today,
    month: base,
  };
}

/** Dispatch validato delle operazioni Life OS; tutte le query usano bind. */
async function lifeAction(env, method, args) {
  const x = args[0];
  if (method === "getLifeData") return lifeRead(env, x);
  await ensureLife(env);
  if (method === "setRoutineCheck") {
    const id = Number(x?.id),
      checked = x?.checked;
    if (!Number.isInteger(id) || id < 1 || typeof checked !== "boolean")
      throw Error("Routine non valida.");
    if (x.day !== nowDay())
      throw Error(
        "\u00c8 iniziato un nuovo giorno. Aggiorna la routine e riprova.",
      );
    if (
      !(await env.DB.prepare("SELECT id FROM os_routines WHERE id=?")
        .bind(id)
        .first())
    )
      throw Error("Routine non trovata.");
    if (checked)
      await env.DB.prepare(
        "INSERT OR IGNORE INTO os_routine_checks(routine_id,day) VALUES (?,?)",
      )
        .bind(id, nowDay())
        .run();
    else
      await env.DB.prepare(
        "DELETE FROM os_routine_checks WHERE routine_id=? AND day=?",
      )
        .bind(id, nowDay())
        .run();
    return true;
  }
  if (method === "saveRoutine") {
    const title = String(x?.title || "")
        .trim()
        .slice(0, 60),
      id = Number(x?.id || 0);
    if (!title) throw Error("Inserisci un nome.");
    if (!Number.isInteger(id) || id < 0) throw Error("Routine non valida.");
    if (id) {
      const result = await env.DB.prepare(
        "UPDATE os_routines SET title=? WHERE id=?",
      )
        .bind(title, id)
        .run();
      if (result.meta.changes !== 1) throw Error("Routine non trovata.");
      return true;
    }
    const count = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM os_routines",
    ).first();
    if (count.n >= 8)
      throw Error("Massimo 8 routine: mantieni solo quelle essenziali.");
    await env.DB.prepare("INSERT INTO os_routines(title,position) VALUES (?,?)")
      .bind(title, count.n)
      .run();
    return true;
  }
  if (method === "deleteRoutine") {
    const id = Number(x);
    if (!Number.isInteger(id) || id < 1) throw Error("Routine non valida.");
    await env.DB.batch([
      env.DB.prepare("DELETE FROM os_routine_checks WHERE routine_id=?").bind(
        id,
      ),
      env.DB.prepare("DELETE FROM os_routines WHERE id=?").bind(id),
    ]);
    return true;
  }
  if (method === "addCategory") {
    const label = String(x?.label || "")
      .trim()
      .slice(0, 40);
    if (!label) throw Error("Indica un nome per la categoria.");
    const duplicate = await env.DB.prepare(
      "SELECT key FROM os_categories WHERE label=? COLLATE NOCASE",
    )
      .bind(label)
      .first();
    if (duplicate) throw Error("Questa categoria esiste gi\u00e0.");
    const key = "custom-" + crypto.randomUUID(),
      position = (
        await env.DB.prepare(
          "SELECT COALESCE(MAX(position),0)+1 AS n FROM os_categories",
        ).first()
      ).n;
    await env.DB.prepare(
      "INSERT INTO os_categories(key,label,position) VALUES (?,?,?)",
    )
      .bind(key, label, position)
      .run();
    return { key, label };
  }
  if (method === "deleteCategory") {
    const key=String(x?.key||""),destination=String(x?.destination||"");
    if(!key || key===destination)throw Error("Scegli una categoria diversa per le attività.");
    const rows=(await env.DB.prepare("SELECT key FROM os_categories").all()).results;
    if(rows.length<2 || !rows.some(r=>r.key===key) || !rows.some(r=>r.key===destination))throw Error("Categoria non valida.");
    await env.DB.batch([
      env.DB.prepare("UPDATE os_tasks SET list_kind=? WHERE list_kind=?").bind(destination,key),
      env.DB.prepare("INSERT OR REPLACE INTO os_meta(key,value) VALUES (?, '1')").bind("deleted_category:"+key),
      env.DB.prepare("DELETE FROM os_categories WHERE key=?").bind(key)
    ]);
    return true;
  }
  if (method === "renameCategory") {
    const key = String(x?.key || ""),
      label = String(x?.label || "")
        .trim()
        .slice(0, 40);
    if (!label) throw Error("Indica un nome per la categoria.");
    const r = await env.DB.prepare(
      "UPDATE os_categories SET label=? WHERE key=?",
    )
      .bind(label, key)
      .run();
    if (r.meta.changes !== 1) throw Error("Categoria non trovata.");
    return true;
  }
  if (method === "reorderCategories") {
    const keys = x?.keys,
      current = (
        await env.DB.prepare("SELECT key FROM os_categories").all()
      ).results.map((r) => r.key);
    if (
      !Array.isArray(keys) ||
      keys.length !== current.length ||
      new Set(keys).size !== keys.length ||
      keys.some((k) => !current.includes(k))
    )
      throw Error("Le categorie sono cambiate: ricarica e riprova.");
    await env.DB.batch(
      keys.map((key, position) =>
        env.DB.prepare("UPDATE os_categories SET position=? WHERE key=?").bind(
          position,
          key,
        ),
      ),
    );
    return true;
  }
  if (method === "reorderTasks") {
    const category = String(x?.category || ""),
      ids = x?.ids;
    if (
      !Array.isArray(ids) ||
      ids.length > 500 ||
      !ids.every((id) => Number.isInteger(id) && id > 0) ||
      new Set(ids).size !== ids.length
    )
      throw Error("Ordine non valido.");
    const rows = (
      await env.DB.prepare(
        "SELECT id FROM os_tasks WHERE list_kind=? AND status='todo' ORDER BY sort_order,id",
      )
        .bind(category)
        .all()
    ).results;
    if (rows.length !== ids.length || rows.some((r) => !ids.includes(r.id)))
      throw Error("La lista \u00e8 cambiata. Aggiorna e riprova.");
    if (ids.length)
      await env.DB.batch(
        ids.map((id, i) =>
          env.DB.prepare(
            "UPDATE os_tasks SET sort_order=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND list_kind=? AND status='todo'",
          ).bind(i + 1, id, category),
        ),
      );
    return true;
  }
  if (method === "deleteCompletedTasks") {
    const category = String(x?.category || "");
    if (
      !(await env.DB.prepare("SELECT key FROM os_categories WHERE key=?")
        .bind(category)
        .first())
    )
      throw Error("Categoria non trovata.");
    await env.DB.prepare(
      "DELETE FROM os_tasks WHERE list_kind=? AND status='done'",
    )
      .bind(category)
      .run();
    return true;
  }
  if (method === "saveTask") {
    const title = String(x?.title || "")
        .trim()
        .slice(0, 160),
      notes = String(x?.notes || "")
        .trim()
        .slice(0, 1000),
      kind = String(x?.list_kind || "action");
    if (
      !title ||
      !(await env.DB.prepare("SELECT key FROM os_categories WHERE key=?")
        .bind(kind)
        .first())
    )
      throw Error("Attivit\u00e0 o categoria non valida.");
    const due = x.due_date ? validDate(x.due_date) : null,
      scheduled = x.scheduled_date ? validDate(x.scheduled_date) : null;
    if (x.id) {
      const id = Number(x.id);
      if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
      const r = await env.DB.prepare(
        "UPDATE os_tasks SET title=?,list_kind=?,sort_order=CASE WHEN list_kind=? THEN sort_order ELSE (SELECT COALESCE(MAX(sort_order),0)+1 FROM os_tasks WHERE list_kind=?) END,notes=?,due_date=?,scheduled_date=?,updated_at=CURRENT_TIMESTAMP WHERE id=?",
      )
        .bind(title, kind, kind, kind, notes, due, scheduled, id)
        .run();
      if (r.meta.changes !== 1) throw Error("Attivit\u00e0 non trovata.");
      return true;
    }
    await env.DB.prepare(
      "INSERT INTO os_tasks(title,list_kind,notes,due_date,scheduled_date,sort_order) VALUES (?,?,?,?,?,(SELECT COALESCE(MAX(sort_order),0)+1 FROM os_tasks WHERE list_kind=?))",
    )
      .bind(title, kind, notes, due, scheduled, kind)
      .run();
    return true;
  }
  if (method === "setTaskStatus") {
    const id = Number(x?.id),
      status = String(x?.status || "");
    if (
      !Number.isInteger(id) ||
      id < 1 ||
      !["todo", "waiting", "done"].includes(status)
    )
      throw Error("Stato non valido.");
    const r = await env.DB.prepare(
      "UPDATE os_tasks SET section_status=CASE WHEN ?='done' THEN CASE WHEN status='waiting' THEN 'waiting' WHEN status='todo' THEN 'todo' ELSE section_status END ELSE ? END,status=?,completed_at=CASE WHEN ?='done' THEN COALESCE(completed_at,strftime('%Y-%m-%dT%H:%M:%SZ','now')) ELSE NULL END,updated_at=CURRENT_TIMESTAMP WHERE id=?",
    )
      .bind(status, status, status, status, id)
      .run();
    if (r.meta.changes !== 1) throw Error("Attivit\u00e0 non trovata.");
    return true;
  }
  if (method === "deleteTask") {
    const id = Number(x);
    if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
    await env.DB.prepare("DELETE FROM os_tasks WHERE id=?").bind(id).run();
    return true;
  }
  if (method === "paintShift") {
    const day = validDate(x?.day),
      kind = String(x?.kind || "");
    if (kind === "erase") {
      await env.DB.prepare("DELETE FROM os_shifts WHERE day=?").bind(day).run();
      return true;
    }
    if (!["morning", "afternoon", "night", "holiday", "rest"].includes(kind))
      throw Error("Turno non valido.");
    await env.DB.prepare(
      "INSERT INTO os_shifts(day,kind) VALUES (?,?) ON CONFLICT(day) DO UPDATE SET kind=excluded.kind,updated_at=CURRENT_TIMESTAMP",
    )
      .bind(day, kind)
      .run();
    return true;
  }
  if (method === "saveEvent") {
    const title = String(x?.title || "")
        .trim()
        .slice(0, 140),
      day = validDate(x?.day),
      start = x?.start_time || null,
      end = x?.end_time || null;
    if (!title || !validClock(start) || !validClock(end) || (end && !start))
      throw Error("Evento o orario non valido.");
    const place = String(x?.location || "")
        .trim()
        .slice(0, 160),
      notes = String(x?.notes || "")
        .trim()
        .slice(0, 1000);
    const frequency = x.frequency || "none",
      until = x.until_day ? validDate(x.until_day) : null;
    if (
      !["none", "weekly", "monthly", "yearly"].includes(frequency) ||
      (until && until < day)
    )
      throw Error("Ricorrenza o data finale non valida.");
    if (x.id) {
      const id = Number(x.id);
      if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
      const old = await env.DB.prepare(
        "SELECT e.day,r.frequency FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.id=?",
      )
        .bind(id)
        .first();
      if (!old) throw Error("Evento non trovato.");
      if (old.day !== day || old.frequency !== frequency) {
        const exceptions = await env.DB.prepare(
          "SELECT COUNT(*) AS n FROM os_event_occurrences WHERE event_id=?",
        )
          .bind(id)
          .first();
        if (exceptions.n)
          throw Error(
            "Questa serie ha occorrenze segnate: per conservare la storia usa Modifica da qui o riaprile prima di cambiare la regola.",
          );
      }
      await env.DB.batch([
        env.DB.prepare(
          "UPDATE os_events SET title=?,day=?,start_time=?,end_time=?,location=?,notes=?,updated_at=CURRENT_TIMESTAMP WHERE id=?",
        ).bind(title, day, start, end, place, notes, id),
        env.DB.prepare(
          "INSERT INTO os_event_repeat(event_id,frequency,until_day) VALUES (?,?,?) ON CONFLICT(event_id) DO UPDATE SET frequency=excluded.frequency,until_day=excluded.until_day",
        ).bind(id, frequency, until),
      ]);
      return true;
    }
    await env.DB.batch([
      env.DB.prepare(
        "INSERT INTO os_events(title,day,start_time,end_time,location,notes) VALUES (?,?,?,?,?,?)",
      ).bind(title, day, start, end, place, notes),
      env.DB.prepare(
        "INSERT INTO os_event_repeat(event_id,frequency,until_day) VALUES (last_insert_rowid(),?,?)",
      ).bind(frequency, until),
    ]);
    return true;
  }
  if (method === "setEventOccurrence") {
    const id = Number(x?.id),
      day = validDate(x?.day),
      status = String(x?.status || "");
    if (
      !Number.isInteger(id) ||
      id < 1 ||
      !["open", "done", "skipped"].includes(status)
    )
      throw Error("Occorrenza non valida.");
    const event = await env.DB.prepare(
      "SELECT e.*,r.frequency,r.until_day FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.id=?",
    )
      .bind(id)
      .first();
    const next = new Date(Date.parse(day + "T12:00:00Z") + 86400000)
      .toISOString()
      .slice(0, 10);
    if (!event || !expandEvents([event], day, next).some((e) => e.day === day))
      throw Error("Questa occorrenza non esiste.");
    if (status === "open")
      await env.DB.prepare(
        "DELETE FROM os_event_occurrences WHERE event_id=? AND day=?",
      )
        .bind(id, day)
        .run();
    else
      await env.DB.prepare(
        "INSERT INTO os_event_occurrences(event_id,day,status) VALUES (?,?,?) ON CONFLICT(event_id,day) DO UPDATE SET status=excluded.status,updated_at=CURRENT_TIMESTAMP",
      )
        .bind(id, day, status)
        .run();
    return true;
  }
  if (method === "splitEventSeries") {
    const id = Number(x?.id),
      from = validDate(x?.split_from),
      day = validDate(x?.day);
    if (!Number.isInteger(id) || id < 1) throw Error("Serie non valida.");
    const original = await env.DB.prepare(
      "SELECT e.*,r.frequency,r.until_day FROM os_events e JOIN os_event_repeat r ON r.event_id=e.id WHERE e.id=?",
    )
      .bind(id)
      .first();
    if (
      !original ||
      !["weekly", "monthly", "yearly"].includes(original.frequency)
    )
      throw Error("La ricorrenza non esiste.");
    const following = new Date(Date.parse(from + "T12:00:00Z") + 86400000)
      .toISOString()
      .slice(0, 10);
    const instances = expandEvents([original], original.day, following);
    if (!instances.some((e) => e.day === from))
      throw Error("La data scelta non appartiene alla serie.");
    const previous = instances.filter((e) => e.day < from).at(-1)?.day || "";
    if (day <= previous)
      throw Error("La nuova data deve seguire la precedente occorrenza.");
    const title = String(x?.title || "")
        .trim()
        .slice(0, 140),
      start = x?.start_time || null,
      end = x?.end_time || null;
    const frequency = String(x?.frequency || "none"),
      until = x?.until_day ? validDate(x.until_day) : null;
    if (
      !title ||
      !validClock(start) ||
      !validClock(end) ||
      (end && !start) ||
      !["none", "weekly", "monthly", "yearly"].includes(frequency) ||
      (until && until < day)
    )
      throw Error("Nuova scadenza non valida.");
    const futureExceptions = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM os_event_occurrences WHERE event_id=? AND day>=?",
    )
      .bind(id, from)
      .first();
    if (futureExceptions.n)
      throw Error(
        "Ci sono occorrenze gi\u00e0 completate o saltate da questa data: riaprile prima di modificare la serie.",
      );
    const oldEnd = new Date(Date.parse(from + "T12:00:00Z") - 86400000)
      .toISOString()
      .slice(0, 10);
    const place = String(x?.location || "")
        .trim()
        .slice(0, 160),
      notes = String(x?.notes || "")
        .trim()
        .slice(0, 1000);
    await env.DB.batch([
      env.DB.prepare(
        "UPDATE os_event_repeat SET until_day=? WHERE event_id=?",
      ).bind(oldEnd, id),
      env.DB.prepare(
        "INSERT INTO os_events(title,day,start_time,end_time,location,notes) VALUES (?,?,?,?,?,?)",
      ).bind(title, day, start, end, place, notes),
      env.DB.prepare(
        "INSERT INTO os_event_repeat(event_id,frequency,until_day) VALUES (last_insert_rowid(),?,?)",
      ).bind(frequency, until),
    ]);
    return true;
  }
  if (method === "deleteEvent") {
    const id = Number(x);
    if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
    await env.DB.batch([
      env.DB.prepare("DELETE FROM os_event_occurrences WHERE event_id=?").bind(
        id,
      ),
      env.DB.prepare("DELETE FROM os_event_repeat WHERE event_id=?").bind(id),
      env.DB.prepare("DELETE FROM os_events WHERE id=?").bind(id),
    ]);
    return true;
  }
  throw Error("Operazione non disponibile.");
}

/** Registra movimento e delta in batch; trasferimenti in coppia, snapshot assorbiti espliciti. */
async function saveTransaction(env, input) {
  await ensureBudgetPolicies(env);
  if (
    !input ||
    !["Spesa", "Entrata", "Rimborso", "Trasferimento"].includes(input.type)
  )
    throw Error("Tipo non valido.");
  const closingTransfer = input.type === "Trasferimento" && input.account === "Revolut" && input.counterpart === "Trade Republic";
  if (input.account !== "Trade Republic" && !closingTransfer)
    throw Error("Il conto operativo è Trade Republic.");
  if (input.type === "Trasferimento" && !closingTransfer)
    throw Error("È disponibile solo il trasferimento finale da Revolut a Trade Republic.");
  let amount = validCents(input.amount) / 100,
    day = validDate(input.date),
    name = String(input.name || "")
      .trim()
      .slice(0, 120);
  if (day > nowDay()) throw Error("Per spese future usa Straordinarie.");
  if (!name) throw Error("Indica una descrizione.");
  const policy=validatedBudgetPolicy(input,amount,day,input.type);
  const requestId=String(input.requestId || crypto.randomUUID());
  if(!/^[a-zA-Z0-9-]{8,80}$/.test(requestId))throw Error("Identificativo richiesta non valido.");
  const fingerprint=JSON.stringify({type:input.type,amount,day,name,account:input.account,category:input.category||"Altro",months:input.months||1,counterpart:input.counterpart||"",note:input.note||"",snapshot:!!input.includedInSnapshot,policy});
  const previous=await env.DB.prepare("SELECT fingerprint FROM finance_write_requests WHERE id=?").bind(requestId).first();
  if(previous){if(previous.fingerprint!==fingerprint)throw Error("Richiesta già usata con dati diversi. Riapri il modulo.");return true;}
  let covered = Number(input.months ?? 1);
  if (!Number.isInteger(covered) || covered < 1 || covered > 12)
    throw Error("Mesi coperti non validi.");
  if (
    input.type === "Trasferimento" &&
    (!["Revolut", "Trade Republic"].includes(input.counterpart) ||
      input.counterpart === input.account)
  )
    throw Error("Indica un altro conto.");
  let absorbedId = null;
  if (input.includedInSnapshot) {
    if (input.type === "Trasferimento")
      throw Error(
        "Per un trasferimento usa i due conti, non la spunta dello snapshot.",
      );
    const snapshot = await env.DB.prepare(
      "SELECT id,as_of_day FROM account_balance_snapshots WHERE account=? ORDER BY as_of_day DESC,id DESC LIMIT 1",
    )
      .bind(input.account)
      .first();
    if (!snapshot || day > snapshot.as_of_day)
      throw Error("Questa data non \u00e8 precedente al saldo rilevato.");
    absorbedId = snapshot.id;
  }
  let signed = ["Spesa", "Trasferimento"].includes(input.type)
    ? -amount
    : amount;
  let category =
    input.type === "Trasferimento"
      ? "Altro"
      : String(input.category || "Altro")
          .trim()
          .slice(0, 60);
  let actual = day.slice(0, 7),
    start = day.slice(0, 7) + "-01";
  let end =
    new Date(
      Date.UTC(
        Number(day.slice(0, 4)),
        Number(day.slice(5, 7)) - 1 + covered,
        0,
      ),
    )
      .toISOString()
      .slice(0, 7) + "-01";
  let r = {
    budget_date: day,
    actual_date: day,
    description: name,
    amount: signed,
    account: input.account,
    category,
    movement_type: input.type === "Rimborso" ? "Spesa" : input.type,
    status: "Eseguito",
    competence_months: covered,
    baseline: "No",
    counterparty_account:
      input.type === "Trasferimento" ? input.counterpart : "",
    notes:
      (input.type === "Rimborso" ? "Rimborso / restituzione: " : "") +
      String(input.note || "").slice(0, 200)+" [Categoria manuale]",
    merchant: name,
    source_name: "App 4.0",
    import_id: "APP-" + requestId,
    budget_month: start,
    competence_end: end,
    monthly_share: input.type === "Spesa" ? amount / covered : null,
    actual_month: start,
    transfer_id: input.type === "Trasferimento" ? crypto.randomUUID() : null,
  };
  const claim=env.DB.prepare("INSERT OR IGNORE INTO finance_write_requests(id,fingerprint) VALUES (?,?)").bind(requestId,fingerprint);
  const insertOnce=(movement)=>env.DB.prepare(`INSERT INTO movements (source_row,${MOVEMENT_COLUMNS.slice(1).join(",")}) SELECT MAX((SELECT COALESCE(MAX(source_row),1) FROM movements),(SELECT COALESCE(MAX(movement_source_row),1) FROM account_balance_events))+1,${MOVEMENT_COLUMNS.slice(1).map(()=>"?").join(",")} WHERE NOT EXISTS (SELECT 1 FROM movements WHERE import_id=?) AND EXISTS (SELECT 1 FROM finance_write_requests WHERE id=? AND fingerprint=?)`).bind(...MOVEMENT_COLUMNS.slice(1).map(k=>movement[k]??null),movement.import_id,requestId,fingerprint);
  const eventOnce=(id,snapshot=null)=>env.DB.prepare(`INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row,absorbed_snapshot_id) SELECT account,substr(actual_date,1,10),CAST(ROUND(amount*100) AS INTEGER),source_row,? FROM movements m WHERE import_id=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic') AND NOT EXISTS(SELECT 1 FROM account_balance_events WHERE movement_source_row=m.source_row)`).bind(snapshot,id);
  const ops=[claim,insertOnce(r),eventOnce(r.import_id,absorbedId)];
  if(input.type==="Trasferimento"){
    const other={...r,description:"Trasferimento da "+input.account,amount,account:input.counterpart,category:"Altro",counterparty_account:input.account,import_id:r.import_id+"-PAIR",monthly_share:null};
    ops.push(insertOnce(other),eventOnce(other.import_id));
  }else{
    ops.push(env.DB.prepare("INSERT OR IGNORE INTO movement_budget_policies(movement_source_row,treatment,recovery_json) SELECT source_row,?,? FROM movements WHERE import_id=?").bind(policy.treatment,JSON.stringify(policy.recovery),r.import_id));
  }
  await env.DB.batch(ops);
  const committed=await env.DB.prepare("SELECT fingerprint FROM finance_write_requests WHERE id=?").bind(requestId).first();
  if(committed.fingerprint!==fingerprint)throw Error("Richiesta già usata con dati diversi. Riapri il modulo.");
  return true;
}

/** Materializza cicli annuali idempotenti e legge quote del periodo selezionato. */
async function getExtraPlan(env, year) {
  await ensureBudgetPolicies(env);
  const y = planYear(year);
  // Materialize the requested and previous annual cycle so January/February
  // can still see a cycle whose twelve months began in the prior year.
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
      AND requested.y>=CAST(substr(e.start_month,1,4) AS INTEGER)`,
    ).bind(y - 1, y),
    env.DB.prepare(
      `WITH RECURSIVE seq(n) AS
    (SELECT 0 UNION ALL SELECT n+1 FROM seq WHERE n<11)
    INSERT OR IGNORE INTO extraordinary_allocations(cycle_id,month,amount_cents)
    SELECT c.id,substr(date(c.start_month||'-01','+'||seq.n||' months'),1,7),
      CAST(c.total_cents/12 AS INTEGER)+CASE WHEN seq.n<c.total_cents%12 THEN 1 ELSE 0 END
    FROM extraordinary_cycles c JOIN extraordinary e ON e.source_row=c.extraordinary_source_row,seq
    WHERE e.repeat_rule='Annuale' AND c.start_month>=? AND c.start_month<?`,
    ).bind(y - 1 + "-01", y + 1 + "-01"),
  ]);
  const [allocations, links] = await Promise.all([
    env.DB.prepare(
      `SELECT a.cycle_id,a.month,a.amount_cents,c.kind,c.status,e.name,
    c.extraordinary_source_row,c.start_month,c.end_month,c.total_cents,e.payment_account,e.paid_date FROM extraordinary_allocations a
    JOIN extraordinary_cycles c ON c.id=a.cycle_id
    JOIN extraordinary e ON e.source_row=c.extraordinary_source_row
    WHERE a.month>=? AND a.month<? ORDER BY a.month,e.name`,
    )
      .bind(y + "-01", y + 1 + "-01")
      .all(),
    env.DB.prepare(
      `SELECT l.cycle_id,l.movement_source_row,l.attributed_cents,l.role,
    m.actual_date,m.account,m.amount FROM extraordinary_movement_links l
    JOIN movements m ON m.source_row=l.movement_source_row`,
    ).all(),
  ]);
  const settlements=await env.DB.prepare("SELECT * FROM extraordinary_settlements").all();
  return {allocations:allocations.results,links:links.results,settlements:settlements.results};
}

/** Valida l’ID e recupera il ciclo straordinario. */
async function getExtraCycle(env, id) {
  await ensureBudgetPolicies(env);
  if(!Number.isInteger(id)||id<1)throw Error("Ciclo non valido.");
  const cycle = await env.DB.prepare(
    "SELECT * FROM extraordinary_cycles WHERE id=?",
  )
    .bind(id)
    .first();
  if (!cycle)
    throw Error(
      "Ciclo straordinario non trovato. Applica prima la migrazione.",
    );
  return cycle;
}

/** Completa il ciclo con nome, conto, regola e pagamenti attribuiti. */
async function getExtraCycleDetail(env, id) {
  const cycle = await getExtraCycle(env, id);
  const [extra, linked] = await Promise.all([
    env.DB.prepare(
      "SELECT name,notes,payment_account,repeat_rule FROM extraordinary WHERE source_row=?",
    )
      .bind(cycle.extraordinary_source_row)
      .first(),
    env.DB.prepare(
      "SELECT COALESCE(SUM(attributed_cents),0) total FROM extraordinary_movement_links WHERE cycle_id=?",
    )
      .bind(id)
      .first(),
  ]);
  if (!extra) throw Error("Voce straordinaria non trovata.");
  return {
    ...cycle,
    name: extra.name,
    notes: extra.notes,
    account: extra.payment_account,
    repeat: extra.repeat_rule,
    linked_cents: linked.total,
  };
}

/** Modifica il piano e distribuisce centesimi esatti; non scende sotto il già pagato. */
async function updateExtraPlan(env, input) {
  const id = Number(input?.cycleId);
  if (!Number.isSafeInteger(id) || id < 1) throw Error("Ciclo non valido.");
  const cycle = await getExtraCycleDetail(env, id);
  const cents = validCents(input?.amount),
    start = String(input?.month || ""),
    end = String(input?.endMonth || "");
  if (
    !/^20\d\d-(0[1-9]|1[0-2])$/.test(start) ||
    !/^20\d\d-(0[1-9]|1[0-2])$/.test(end)
  )
    throw Error("Mese non valido.");
  const months =
    (Number(end.slice(0, 4)) - Number(start.slice(0, 4))) * 12 +
    Number(end.slice(5)) -
    Number(start.slice(5)) +
    1;
  if (months < 1 || months > 60) throw Error("Durata non valida.");
  if (cents < Number(cycle.linked_cents))
    throw Error(
      "Il totale non pu\u00f2 essere inferiore ai pagamenti gi\u00e0 collegati.",
    );
  const annual = cycle.repeat === "Annuale";
  if (annual && (start !== cycle.start_month || months !== 12))
    throw Error(
      "Per un ciclo annuale puoi modificare il totale; il periodo resta quello della ricorrenza.",
    );
  const name = String(input?.name || "")
    .trim()
    .slice(0, 100);
  const account = String(input?.account || "");
  if (
    !name ||
    (cycle.kind === "budget_advance"
      ? account !== cycle.account
      : !["Revolut", "Trade Republic"].includes(account))
  )
    throw Error("Voce o conto non valido.");
  const note = String(input?.note || "").slice(0, 200);
  const shares = Array.from(
    { length: months },
    (_, i) => Math.floor(cents / months) + (i < cents % months ? 1 : 0),
  );
  const allocations = shares.map((amount, i) => {
    const date = new Date(
      Date.UTC(Number(start.slice(0, 4)), Number(start.slice(5)) - 1 + i, 1),
    );
    return env.DB.prepare(
      "INSERT INTO extraordinary_allocations(cycle_id,month,amount_cents) VALUES (?,?,?)",
    ).bind(id, date.toISOString().slice(0, 7), amount);
  });
  const operations = [
    env.DB.prepare(
      "UPDATE extraordinary_cycles SET start_month=?,end_month=?,total_cents=? WHERE id=?",
    ).bind(start, end, cents, id),
    env.DB.prepare(
      "DELETE FROM extraordinary_allocations WHERE cycle_id=?",
    ).bind(id),
    ...allocations,
  ];
  if (!annual)
    operations.push(
      env.DB.prepare(
        `UPDATE extraordinary SET name=?,total=?,start_month=?,month_count=?,monthly_share=?,end_month=?,payment_account=?,notes=? WHERE source_row=?`,
      ).bind(
        name,
        cents / 100,
        start + "-01",
        months,
        cents / 100 / months,
        end + "-01",
        account,
        note,
        cycle.extraordinary_source_row,
      ),
    );
  else
    operations.push(
      env.DB.prepare(
        "UPDATE extraordinary SET name=?,payment_account=?,notes=? WHERE source_row=?",
      ).bind(name, account, note, cycle.extraordinary_source_row),
    );
  operations.push(
    ...(annual
      ? syncExtraStatusStatements(env, id).slice(0, 1)
      : syncExtraStatusStatements(env, id)),
  );
  await env.DB.batch(operations);
  return { cycleId: id, months, total_cents: cents };
}

/** Prepara aggiornamenti stato da importi collegati; non riattiva piani annullati. */
function syncExtraStatusStatements(env, cycleId) {
  return [
    env.DB.prepare(
      `UPDATE extraordinary_cycles SET status=CASE
   WHEN status='Annullato' THEN 'Annullato'
   WHEN EXISTS(SELECT 1 FROM extraordinary_settlements s JOIN movements m ON m.source_row=s.movement_source_row WHERE s.cycle_id=extraordinary_cycles.id) THEN 'Pagato'
   WHEN (SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=?)
     >=total_cents THEN CASE WHEN kind='budget_advance' THEN 'Anticipato' ELSE 'Pagato' END
   WHEN status IN ('Pagato','Anticipato','Da riconciliare') THEN 'Da riconciliare'
   ELSE status END WHERE id=?`,
    ).bind(cycleId, cycleId),
    env.DB.prepare(
      `UPDATE extraordinary SET status=(SELECT status FROM extraordinary_cycles WHERE id=?),
   paid_date=(SELECT MAX(m.actual_date) FROM extraordinary_movement_links l
     JOIN movements m ON m.source_row=l.movement_source_row WHERE l.cycle_id=?)
   WHERE source_row=(SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?)`,
    ).bind(cycleId, cycleId, cycleId),
  ];
}

/** Attribuisce centesimi di un movimento esistente a un ciclo; nessun nuovo addebito. */
async function linkExtraMovement(env, input) {
  const cycleId = Number(input?.cycleId),
    movementId = Number(input?.movementId);
  const cents = validCents(input?.amount);
  if (
    !Number.isInteger(cycleId) ||
    !Number.isInteger(movementId) ||
    !Number.isSafeInteger(cents)
  )
    throw Error("Collegamento non valido.");
  const cycle = await getExtraCycle(env, cycleId);
  const movement=await getMovement(env,movementId);
  if(movement.status!=="Eseguito" || Number(movement.amount)>=0 || movement.movement_type!==(cycle.kind==="budget_advance"?"Trasferimento":"Spesa") || !["Trade Republic","Revolut"].includes(movement.account))throw Error("Movimento non compatibile con il piano.");
  if(movement.budgetTreatment==="recovery")throw Error("Il movimento ha già un recupero: rimuovilo prima di collegare il piano.");
  const existing=await env.DB.prepare("SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE movement_source_row=?").bind(movementId).first();
  const paid=await env.DB.prepare("SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE cycle_id=?").bind(cycleId).first();
  if(["Annullato","Pagato"].includes(cycle.status) || cents+Number(existing.n)>Math.round(-movement.amount*100) || cents+Number(paid.n)>cycle.total_cents)throw Error("Importo già attribuito o superiore al residuo del piano.");
  const role = cycle.kind === "budget_advance" ? "budget_advance" : "payment";
  const result=await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO extraordinary_movement_links
   (cycle_id,movement_source_row,attributed_cents,role)
   SELECT ?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM extraordinary_movement_links WHERE cycle_id=? AND movement_source_row=?)
   AND (SELECT CAST(ROUND(-amount*100) AS INTEGER) FROM movements WHERE source_row=?)-(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE movement_source_row=?)>=?
   AND (SELECT total_cents FROM extraordinary_cycles WHERE id=? AND status NOT IN ('Annullato','Pagato'))-(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=?)>=?
   AND NOT EXISTS(SELECT 1 FROM movement_budget_policies WHERE movement_source_row=? AND treatment='recovery')`,
    ).bind(cycleId,movementId,cents,role,cycleId,movementId,movementId,movementId,cents,cycleId,cycleId,cents,movementId),
    ...syncExtraStatusStatements(env, cycleId),
  ]);
  if(result[0].meta.changes!==1)throw Error("Il movimento o il piano è cambiato: ricarica prima di collegarlo.");
  return true;
}

/** Rimuove l’attribuzione e ricalcola lo stato; non elimina il movimento bancario. */
async function unlinkExtraMovement(env, input) {
  const cycleId = Number(input?.cycleId),
    movementId = Number(input?.movementId);
  if (!Number.isInteger(cycleId) || !Number.isInteger(movementId))
    throw Error("Collegamento non valido.");
  await getExtraCycle(env, cycleId);
  await env.DB.batch([
    env.DB.prepare(
      "DELETE FROM extraordinary_movement_links WHERE cycle_id=? AND movement_source_row=?",
    ).bind(cycleId, movementId),
    env.DB.prepare("DELETE FROM extraordinary_settlements WHERE cycle_id=? AND movement_source_row=?").bind(cycleId,movementId),
    ...syncExtraStatusStatements(env, cycleId),
  ]);
  return true;
}

/** Pagamento atomico condizionato al residuo; due richieste simultanee non duplicano l’addebito. */
async function recordExtraPayment(env, input) {
  const cycleId = Number(input?.cycleId),
    cycle = await getExtraCycle(env, cycleId);
  if (cycle.kind !== "expense" || cycle.status === "Annullato")
    throw Error("Questa voce non \u00e8 pagabile.");
  const cents = validCents(input?.amount),
    amount = cents / 100,
    day = validDate(input?.date);
  const linked = (
    await env.DB.prepare(
      "SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE cycle_id=?",
    )
      .bind(cycleId)
      .first()
  ).n;
  if(cycle.status==="Pagato" || linked>=cycle.total_cents){
    const prior=await env.DB.prepare("SELECT actual_cents FROM extraordinary_settlements WHERE cycle_id=?").bind(cycleId).first();
    if(prior && prior.actual_cents!==cents)throw Error("Questo ciclo è già pagato con un importo diverso. Correggi il movimento esistente.");
    return {alreadyPaid:true};
  }
  const expectedRemaining=cycle.total_cents-linked,attributed=Math.min(cents,expectedRemaining);
  if (day > nowDay()) throw Error("La data del pagamento \u00e8 futura.");
  const account = String(input?.account || ""),
    name = String(input?.name || "")
      .trim()
      .slice(0, 120);
  if (account !== "Trade Republic" || !name)
    throw Error("Conto o descrizione non validi.");
  const extra = await env.DB.prepare(
    "SELECT name FROM extraordinary WHERE source_row=?",
  )
    .bind(cycle.extraordinary_source_row)
    .first();
  const month = day.slice(0, 7) + "-01",
    importId = "APP-" + crypto.randomUUID();
  const r = {
    budget_date: day,
    actual_date: day,
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
    budget_month: month,
    competence_end: month,
    monthly_share: amount,
    actual_month: month,
  };
  const columns = MOVEMENT_COLUMNS.slice(1);
  const insert = env.DB.prepare(
    `INSERT INTO movements (source_row,${columns.join(",")})
   SELECT MAX((SELECT COALESCE(MAX(source_row),1) FROM movements),(SELECT COALESCE(MAX(movement_source_row),1) FROM account_balance_events))+1,${columns.map(() => "?").join(",")} WHERE EXISTS (SELECT 1 FROM extraordinary_cycles c WHERE c.id=? AND c.status NOT IN ('Annullato','Pagato') AND NOT EXISTS(SELECT 1 FROM extraordinary_settlements WHERE cycle_id=c.id) AND c.total_cents-(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=c.id)=?)`,
  ).bind(...columns.map((k) => r[k] ?? null), cycleId, expectedRemaining);
  const batch = await env.DB.batch([
    insert,
    insertedBalanceEvent(env, importId),
    env.DB.prepare(
      `INSERT INTO extraordinary_movement_links
   (cycle_id,movement_source_row,attributed_cents,role)
   SELECT ?,source_row,?,'payment' FROM movements WHERE import_id=?`,
    ).bind(cycleId, attributed, importId),
    env.DB.prepare("INSERT OR IGNORE INTO extraordinary_settlements(cycle_id,movement_source_row,planned_cents,actual_cents) SELECT ?,source_row,?,? FROM movements WHERE import_id=?").bind(cycleId,expectedRemaining,cents,importId),
    ...syncExtraStatusStatements(env, cycleId),
    env.DB.prepare(
      "UPDATE extraordinary SET payment_account=? WHERE source_row=? AND EXISTS(SELECT 1 FROM movements WHERE import_id=?)",
    ).bind(account, cycle.extraordinary_source_row, importId),
  ]);
  if(batch[0].meta.changes!==1){
    const current=await env.DB.prepare("SELECT c.status,c.total_cents,(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=c.id) linked_cents FROM extraordinary_cycles c WHERE c.id=?").bind(cycleId).first();
    if(!current || current.status==="Annullato" || (current.status!=="Pagato" && current.linked_cents<current.total_cents))throw Error("Il piano è cambiato durante il pagamento. Aggiorna la pagina e verifica l’importo prima di riprovare.");
    const prior=await env.DB.prepare("SELECT actual_cents FROM extraordinary_settlements WHERE cycle_id=?").bind(cycleId).first();
    if(prior && prior.actual_cents!==cents)throw Error("Questo ciclo è già pagato con un importo diverso. Correggi il movimento esistente.");
    return {alreadyPaid:true};
  }
  return {movementId:batch[0].meta.last_row_id};
}

/** Crea piano, ciclo e quote; la creazione non muove denaro. */
async function saveExtra(env, input) {
  await ensureBudgetPolicies(env);
  let name = String(input?.name || "")
      .trim()
      .slice(0, 100),
    cents = validCents(input?.amount),
    total = cents / 100,
    start = String(input?.month || ""),
    end = String(input?.endMonth || "");
  if (
    !/^20\d\d-(0[1-9]|1[0-2])$/.test(start) ||
    !/^20\d\d-(0[1-9]|1[0-2])$/.test(end) ||
    !name
  )
    throw Error("Voce o mese non valido.");
  let months =
    (Number(end.slice(0, 4)) - Number(start.slice(0, 4))) * 12 +
    Number(end.slice(5)) -
    Number(start.slice(5)) +
    1;
  if (months < 1 || months > 60) throw Error("Durata non valida.");
  if (
    !["Previsto", "Programmato", "Annullato"].includes(input.status) ||
    input.account !== "Trade Republic"
  )
    throw Error(
      "Crea la voce come Programmato; per Pagato o Anticipato collega un movimento.",
    );
  if (input.repeat === "Annuale" && months !== 12)
    throw Error("Annuale richiede 12 mesi inclusi.");
  let value = {
    name,
    total,
    start_month: start + "-01",
    month_count: months,
    monthly_share: total / months,
    end_month: end + "-01",
    status: input.status,
    payment_account: input.account,
    paid_date: null,
    notes: String(input.note || "").slice(0, 200),
    repeat_rule: input.repeat === "Annuale" ? "Annuale" : "No",
  };
  const requestId=String(input.requestId || crypto.randomUUID());
  if(!/^[a-zA-Z0-9-]{8,80}$/.test(requestId))throw Error("Identificativo richiesta non valido.");
  const fingerprint=JSON.stringify(value),previous=await env.DB.prepare("SELECT * FROM finance_extra_requests WHERE id=?").bind(requestId).first();
  if(previous){if(previous.fingerprint!==fingerprint)throw Error("Richiesta già usata con dati diversi. Riapri il modulo.");return {row:previous.source_row};}
  const columns=EXTRAS_COLUMNS.slice(1);
  await env.DB.batch([
    env.DB.prepare(`INSERT INTO extraordinary(source_row,${columns.join(",")}) SELECT MAX((SELECT COALESCE(MAX(source_row),1) FROM extraordinary),(SELECT COALESCE(MAX(source_row),1) FROM finance_extra_requests))+1,${columns.map(()=>"?").join(",")} WHERE NOT EXISTS(SELECT 1 FROM finance_extra_requests WHERE id=?)`).bind(...columns.map(k=>value[k]??null),requestId),
    env.DB.prepare("INSERT OR IGNORE INTO finance_extra_requests(id,source_row,fingerprint) SELECT ?,MAX(source_row),? FROM extraordinary WHERE NOT EXISTS(SELECT 1 FROM finance_extra_requests WHERE id=?)").bind(requestId,fingerprint,requestId),
    env.DB.prepare("INSERT OR IGNORE INTO extraordinary_cycles(extraordinary_source_row,start_month,end_month,total_cents,kind,status) SELECT source_row,?,?,?,'expense',? FROM finance_extra_requests WHERE id=? AND fingerprint=?").bind(start,end,cents,input.status,requestId,fingerprint),
    env.DB.prepare(`WITH RECURSIVE seq(n) AS (SELECT 0 UNION ALL SELECT n+1 FROM seq WHERE n+1<?)
      INSERT OR IGNORE INTO extraordinary_allocations(cycle_id,month,amount_cents)
      SELECT c.id,substr(date(?,'+'||seq.n||' months'),1,7),CAST(?/? AS INTEGER)+CASE WHEN seq.n<?%? THEN 1 ELSE 0 END
      FROM extraordinary_cycles c JOIN finance_extra_requests r ON r.source_row=c.extraordinary_source_row,seq WHERE r.id=? AND r.fingerprint=? AND c.start_month=?`).bind(months,start+"-01",cents,months,cents,months,requestId,fingerprint,start)
  ]);
  const result=await env.DB.prepare("SELECT * FROM finance_extra_requests WHERE id=?").bind(requestId).first();
  if(result.fingerprint!==fingerprint)throw Error("Richiesta già usata con dati diversi. Riapri il modulo.");
  return {row:result.source_row};
}

/** Compatibilità cambio stato storico con controllo dello stato precedente. */
async function setExtraStatus(env, row, previous, next, paidDate) {
  if (
    !Number.isInteger(row) ||
    row < 2 ||
    !["Previsto", "Programmato", "Pagato", "Anticipato", "Annullato"].includes(
      next,
    )
  )
    throw Error("Stato non valido.");
  if (next === "Pagato" || next === "Anticipato")
    throw Error(
      "Per segnare pagata o anticipata una voce, collega il movimento bancario.",
    );
  const cycle = await env.DB.prepare(
    "SELECT id FROM extraordinary_cycles WHERE extraordinary_source_row=? ORDER BY id DESC LIMIT 1",
  )
    .bind(row)
    .first();
  if (!cycle) throw Error("Applica prima la migrazione delle straordinarie.");
  const linked = await env.DB.prepare(
    "SELECT 1 FROM extraordinary_movement_links WHERE cycle_id=? LIMIT 1",
  )
    .bind(cycle.id)
    .first();
  if (linked)
    throw Error(
      "La voce ha movimenti collegati: scollegali prima di cambiarne lo stato.",
    );
  const result = await env.DB.batch([
    env.DB.prepare(
      "UPDATE extraordinary SET status=? WHERE source_row=? AND status=?",
    ).bind(next, row, previous),
    env.DB.prepare(
      "UPDATE extraordinary_cycles SET status=? WHERE id=? AND status=?",
    ).bind(next, cycle.id, previous),
  ]);
  if (result[0].meta.changes !== 1 || result[1].meta.changes !== 1)
    throw Error("La voce \u00e8 stata modificata: ricarica la pagina.");
  return true;
}

/** Paga il residuo del ciclo dal conto previsto; già pagato è idempotente. */
async function markExtraPaid(env, input) {
  const c = await getExtraCycleDetail(env, Number(input?.cycleId));
  if (c.status === "Pagato" || c.linked_cents >= c.total_cents)
    return { alreadyPaid: true };
  return recordExtraPayment(env, {
    cycleId: c.id,
    amount: (c.total_cents - c.linked_cents) / 100,
    account: "Trade Republic",
    name: c.name,
    date: nowDay(),
  });
}

/** Annulla la pianificazione; conserva movimenti e denaro già speso. */
async function cancelExtraCycle(env, input) {
  const c = await getExtraCycleDetail(env, Number(input?.cycleId));
  await env.DB.batch([
    env.DB.prepare(
      "UPDATE extraordinary_cycles SET status='Annullato' WHERE id=?",
    ).bind(c.id),
    ...(c.repeat === "Annuale"
      ? []
      : [
          env.DB.prepare(
            "UPDATE extraordinary SET status='Annullato' WHERE source_row=?",
          ).bind(c.extraordinary_source_row),
        ]),
  ]);
  return true;
}

/** Elimina solo pianificazioni annullate prive di pagamenti collegati. */
async function deleteExtraPlan(env, input) {
  const c = await getExtraCycleDetail(env, Number(input?.cycleId));
  const linked = await env.DB.prepare(
    "SELECT 1 FROM extraordinary_movement_links l JOIN extraordinary_cycles c ON c.id=l.cycle_id WHERE c.extraordinary_source_row=? LIMIT 1",
  )
    .bind(c.extraordinary_source_row)
    .first();
  if (linked)
    throw Error(
      "I pagamenti sono nello storico: puoi annullare il piano, ma non eliminarlo.",
    );
  if (c.status !== "Annullato")
    throw Error("Annulla la voce prima di eliminarla.");
  await env.DB.batch([
    env.DB.prepare(
      "DELETE FROM extraordinary_allocations WHERE cycle_id IN (SELECT id FROM extraordinary_cycles WHERE extraordinary_source_row=?)",
    ).bind(c.extraordinary_source_row),
    env.DB.prepare(
      "DELETE FROM extraordinary_cycles WHERE extraordinary_source_row=?",
    ).bind(c.extraordinary_source_row),
    env.DB.prepare("DELETE FROM extraordinary WHERE source_row=?").bind(
      c.extraordinary_source_row,
    ),
  ]);
  return true;
}

/** Cambia solo categoria con marcatore manuale, preservando importo e saldo. */
async function classifyMovement(env, id, category) {
  id = Number(id);
  category = String(category || "").trim();
  if (!Number.isSafeInteger(id) || id < 1 || !category || category.length > 80)
    throw Error("Categoria non valida.");
  const current = await env.DB.prepare(
    "SELECT source_row FROM movements WHERE source_row=?",
  )
    .bind(id)
    .first();
  if (!current) throw Error("Movimento non trovato.");
  await env.DB.prepare(
    "UPDATE movements SET category=?,notes=CASE WHEN instr(COALESCE(notes,''),'[Categoria manuale]')>0 THEN notes ELSE COALESCE(notes,'')||' [Categoria manuale]' END WHERE source_row=?",
  )
    .bind(category, id)
    .run();
  return true;
}

/** Whitelist RPC di letture e scritture; nessuna esecuzione di nomi arbitrari. */
async function writeAction(env, method, args) {
  if (
    [
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
      "deleteRoutine",
    ].includes(method)
  )
    return lifeAction(env, method, args);
  switch (method) {
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
        requestId:x.requestId,
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
      const {goal: target, saving: monthly} = planningInputs(args[0], args[1]);
      // Older workbook exports stop at row 12. Create optional settings without
      // rewriting unrelated cells, and commit both values in one D1 transaction.
      const existing = await env.DB.prepare(
        "SELECT row_number,values_json FROM source_rows WHERE sheet='Budget' AND row_number IN (13,14)",
      ).all();
      const rows = new Map(
        existing.results.map((r) => [r.row_number, JSON.parse(r.values_json)]),
      );
      const statements = [
          [13, target],
          [14, monthly],
        ].map(([rowNumber, value]) => {
          const row = rows.get(rowNumber) || Array(15).fill("");
          row[14] = value;
          return env.DB.prepare(
            "INSERT INTO source_rows(sheet,row_number,values_json) VALUES ('Budget',?,?) ON CONFLICT(sheet,row_number) DO UPDATE SET values_json=excluded.values_json",
          ).bind(rowNumber, JSON.stringify(row));
        });
      if (args.length >= 3) {
        const savingsTarget = Number(args[2]);
        if (!Number.isFinite(savingsTarget) || savingsTarget <= 0 || savingsTarget > 1000000) throw Error("Obiettivo non valido.");
        statements.push(env.DB.prepare("INSERT INTO source_rows(sheet,row_number,values_json) VALUES ('LifeOS Settings',1,?) ON CONFLICT(sheet,row_number) DO UPDATE SET values_json=excluded.values_json").bind(JSON.stringify([Math.round(savingsTarget*100)/100])));
      }
      await env.DB.batch(statements);
      return true;
    }
    case "saveRevolutSnapshot":
      throw Error("Revolut è un conto storico. Aggiorna il saldo Trade Republic.");
    case "saveAssetBalance":
      throw Error("Il saldo si aggiorna attraverso i movimenti; la modifica manuale è disattivata.");
    default:
      throw Error("Operazione non disponibile.");
  }
}
/** HTTP boundary: public icons, authenticated HTML/API, same-origin POST validation. */
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url),
      path = url.pathname;
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
              type: "image/png",
            },
          ],
        },
        {
          headers: {
            "content-type": "application/manifest+json",
            "cache-control": "public, max-age=86400",
          },
        },
      );
    // ACCESS_EMAIL switches authentication to Cloudflare Access. A missing Access
    // context then fails closed, even if an old password or cookie is supplied.
    const accessEmail = String(env.ACCESS_EMAIL || "")
      .trim()
      .toLowerCase();
    if (accessEmail) {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(accessEmail))
        return fail("Configura ACCESS_EMAIL con il tuo indirizzo Google.", 503);
      if (!ctx?.access)
        return fail(
          "Attiva Cloudflare Access su questo Worker e accedi con Google.",
          403,
        );
      let identity;
      try {
        identity = await ctx.access.getIdentity();
      } catch {
        return fail("Identit\u00e0 Cloudflare Access non disponibile.", 403);
      }
      if (String(identity?.email || "").toLowerCase() !== accessEmail)
        return fail("Questo account Google non \u00e8 autorizzato.", 403);
    } else {
      if (request.method === "GET" && path === "/login")
        return new Response(LOGIN_PAGE, {
          headers: {
            ...noCache,
            "content-type": "text/html; charset=utf-8",
            "x-frame-options": "DENY",
            "content-security-policy":
              "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'",
          },
        });
      if (!env.APP_PASSWORD || env.APP_PASSWORD.length < 24)
        return fail(
          "Configura il Secret APP_PASSWORD di almeno 24 caratteri.",
          503,
        );
      if (request.method === "POST" && path === "/auth/login") {
        if (request.headers.get("origin") !== url.origin)
          return fail("Origine non valida.", 403);
        if (Number(request.headers.get("content-length") || 0) > 2000)
          return fail("Richiesta troppo grande.", 413);
        let input;
        try {
          input = await request.json();
        } catch {
          return fail("JSON non valido.", 400);
        }
        if (
          input?.user !== "nas" ||
          typeof input.password !== "string" ||
          input.password.length > 1000 ||
          input.password !== env.APP_PASSWORD
        )
          return fail("Credenziali non valide.", 401);
        return new Response("{}", {
          headers: {
            ...noCache,
            "content-type": "application/json",
            "set-cookie": await sessionCookie(env.APP_PASSWORD),
          },
        });
      }
      if (
        !(await validSession(request, env.APP_PASSWORD)) &&
        !(await checkPassword(request, env.APP_PASSWORD))
      ) {
        if (request.method === "GET")
          return new Response(null, {
            status: 302,
            headers: { ...noCache, location: "/login" },
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
            "content-security-policy":
              "default-src 'self' data:; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://api.open-meteo.com",
          },
        });
      if (path === "/setup")
        return new Response(CONFIG_PAGE, {
          headers: {
            ...noCache,
            "content-type": "text/html; charset=utf-8",
            "x-frame-options": "DENY",
            "content-security-policy":
              "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'",
          },
        });
      return fail("Non trovato.", 404);
    }
    if (request.method !== "POST") return fail("Metodo non disponibile.", 405);
    if (request.headers.get("origin") !== url.origin)
      return fail("Origine non valida.", 403);
    if (path === "/api/import-config") {
      if (Number(request.headers.get("content-length") || 0) > 150000)
        return fail("Blocco troppo grande.", 413);
      let rows;
      try {
        rows = await request.json();
      } catch {
        return fail("JSON non valido.", 400);
      }
      if (
        !Array.isArray(rows) ||
        rows.length < 1 ||
        rows.length > 20 ||
        rows.some(
          (r) =>
            !r ||
            typeof r.sheet !== "string" ||
            r.sheet.length > 60 ||
            !Number.isInteger(r.row_number) ||
            r.row_number < 1 ||
            r.row_number > 5000 ||
            typeof r.values_json !== "string" ||
            r.values_json.length > 100000,
        )
      )
        return fail("Dati non validi.", 400);
      await env.DB.prepare(
        "CREATE TABLE IF NOT EXISTS source_rows (sheet TEXT NOT NULL,row_number INTEGER NOT NULL,values_json TEXT NOT NULL,PRIMARY KEY(sheet,row_number))",
      ).run();
      await env.DB.batch(
        rows.map((r) =>
          env.DB.prepare(
            "INSERT OR REPLACE INTO source_rows(sheet,row_number,values_json) VALUES (?,?,?)",
          ).bind(r.sheet, r.row_number, r.values_json),
        ),
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
      if (
        [
          "classifyMovement",
          "editMovement",
          "deleteMovement",
          "saveTransaction",
          "saveRecurringPayment",
          "recordExtraPayment",
          "markExtraPaid",
          "setExtraStatus",
        ].includes(method)
      )
        await ensureFinanceCategories(env);
      return response(result);
    } catch (e) {
      return fail(String(e.message || e), 400);
    }
  },
};
