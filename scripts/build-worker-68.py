from pathlib import Path
base=Path('manual/build-67/worker.js').read_text()
module=Path('backend/activities/activities.mjs').read_text().replace('export async function','async function')
base=base.replace('if (method === "getLifeData") return lifeRead(env, x);','if (method === "getLifeData") return enrichActivities(env.DB, await lifeRead(env, x));')
needle='  await ensureLife(env);\n  if (method === "setRoutineCheck")'
assert needle in base
base=base.replace(needle,'  await ensureLife(env);\n  if (method === "saveActivity") return saveActivity(env.DB, x);\n  if (method === "setRoutineCheck")',1)
base=base.replace('    "saveTask",','    "saveActivity",\n    "saveTask",')
p=Path('manual/build-68/worker.js');p.parent.mkdir(parents=True,exist_ok=True);p.write_text(module+'\n'+base)
