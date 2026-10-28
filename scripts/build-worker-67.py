from pathlib import Path
base=Path('manual/build-63/worker.js').read_text()
helper=Path('backend/expense-routing/routing.mjs').read_text().replace('export function createExpenseRouting','function createExpenseRouting',1)
prefix, base = base.split('function octoberAdvanceReconciliation',1)
base = 'function octoberAdvanceReconciliation' + base
base=base.replace('// backend/worker/entry.mjs',helper+'\nconst expenseRouting = createExpenseRouting({ PlanError, balance, command, completePayment, completePaymentDeletion, fingerprint, requestKey, month, cycleKey });\n\n// backend/worker/entry.mjs')
base=base.replace('if (!METHODS[method] && method !== "getMovement"','if (!["getExpenseRouting", "getExpenseRequestStatus", "changeExpenseDestination", "cancelExpenseRequest"].includes(method) && !METHODS[method] && method !== "getMovement"',1)
needle='      if (method === "getMovement") {'
insert='''      const routingContext = { input: args[0] ?? {}, repository, service, db:env.DB, today, recordTransaction, env };
      if (method === "getExpenseRouting") return json(await expenseRouting.preview(routingContext));
      if (method === "getExpenseRequestStatus") return json(await expenseRouting.status(routingContext));
      if (method === "cancelExpenseRequest") return json(await expenseRouting.cancel(routingContext));
      if (method === "changeExpenseDestination") return json(await expenseRouting.change(routingContext));
      if (method === "saveTransaction" && args[0]?.expenseRoutingVersion === 1) return json(await expenseRouting.save(routingContext));
'''
assert base.count(needle)==1;base=base.replace(needle,insert+needle)
base=base.replace('    cashName: input.originalName ?','    cashIncludedInSnapshot: input.originalIncludedInSnapshot === true,\n    cashNote: String(input.originalNote || "").slice(0,1000),\n    cashName: input.originalName ?',1)
base=base.replace('      name: p.cashName || plan.name,','      name: p.cashName || plan.name,\n      note: p.cashNote,\n      includedInSnapshot: p.cashIncludedInSnapshot,',1)
base=base.replace('          note: "Piano " + p.planId','          note: p.note ?? ""',1)
base=base.replace('          budgetTreatment: "savings",\n          note: p.note', '          budgetTreatment: "savings",\n          includedInSnapshot: p.includedInSnapshot,\n          note: p.note',1)
base=base.replace('Object.values(state.payments).some((p) => p.movementId === existingMovementId || p.existingMovementId === existingMovementId)', 'Object.values(state.payments).some((p) => p.status !== "deleted" && (p.movementId === existingMovementId || p.existingMovementId === existingMovementId))')
base=base.replace('Object.values(state.payments).some((p) => p.movementId === r.source_row || p.existingMovementId === r.source_row)', 'Object.values(state.payments).some((p) => p.status !== "deleted" && (p.movementId === r.source_row || p.existingMovementId === r.source_row))')
base=base.replace('Object.values(state.payments).some((p) => p.movementId === movementId || p.existingMovementId === movementId || row?.import_id === "APP-" + p.requestId)', 'Object.values(state.payments).some((p) => p.status !== "deleted" && (p.movementId === movementId || p.existingMovementId === movementId || row?.import_id === "APP-" + p.requestId))')
Path('manual/build-67/worker.js').write_text(prefix+base)
print('Generated Worker 67 with the existing private configuration unchanged.')
