"""Context-guarded patch of live Life OS; preserve unrelated modules, bindings and secrets."""
from pathlib import Path
import importlib.util,re
spec=importlib.util.spec_from_file_location('deploy_base',Path(__file__).with_name('deploy-lifeos-61.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
module=Path('backend/activities/activities.mjs').read_text().replace('export async function','async function')
def transform(source,_patches):
    if '// LIFEOS_UNIFIED_ACTIVITIES_68' in source:
        expected='// LIFEOS_UNIFIED_ACTIVITIES_68\n'+module+'\n'
        if not source.startswith(expected):raise RuntimeError('Versione unificazione live diversa: nessuna sostituzione automatica.')
        return source
    substitutions=[
      (r'if \(method === "getLifeData"\) return lifeRead\(env, x\);','if (method === "getLifeData") return enrichActivities(env.DB, await lifeRead(env, x));'),
      (r'(await ensureLife\(env\);\s*)(if \(method === "setRoutineCheck"\))',r'\1if (method === "saveActivity") return saveActivity(env.DB, x);\n  \2'),
      (r'("saveTask",\s*"setEventOccurrence")','"saveActivity",\n      \\1'),
    ]
    for pattern,replacement in substitutions:
        source,count=re.subn(pattern,replacement,source)
        if count!=1:raise RuntimeError('Contesto attività live inatteso; nessuna distribuzione automatica.')
    # Both schema fields are required by the existing reminder implementation.
    if not all(field in source for field in ['scheduled_time', 'section_status', 'activityEvents']):raise RuntimeError('Il server non contiene la migrazione orari della build 61.')
    return '// LIFEOS_UNIFIED_ACTIVITIES_68\n'+module+'\n'+source
base.transform=transform
if __name__=='__main__':base.main()
