// Exact small excerpts from the supplied Worker 11.63. Reference only.
// This is not the complete Worker or a deployable entrypoint.

/** Registra il delta del movimento appena inserito, identificato da import_id univoco. */
function insertedBalanceEvent(env, importId, absorbedId = null) {
  return env.DB.prepare(
    `INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row,absorbed_snapshot_id)
  SELECT account,substr(actual_date,1,10),CAST(ROUND(amount*100) AS INTEGER),source_row,?
  FROM movements WHERE import_id=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')`,
  ).bind(absorbedId, importId);
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
