"""Add health/shift APIs to the existing Worker without copying its historical data.

The repository keeps its original Worker template. Only this code-only extension
and the readable UI are new sources; the assembled Worker stays in ignored dist/.
"""
from pathlib import Path


def replace_once(source, before, after):
    if source.count(before) != 1:
        raise ValueError("Worker template differs: review the backend before building.")
    return source.replace(before, after, 1)


def apply_backend_extensions(source):
    if "const healthSchemaJobs =" in source:
        raise ValueError("Use the original Worker template, not the generated dist/ output.")
    source = replace_once(source, '    month: base,\n', '    month: base,\n    shiftCalendar: await shiftCalendarStatus(env, base),\n    health: await healthData(env),\n')
    # Archive the removed task feature without continuing its former automatic cleanup.
    source = replace_once(source, '''  await env.DB.prepare(
    "DELETE FROM os_tasks WHERE status='done' AND completed_at IS NOT NULL AND strftime('%s',completed_at)<=strftime('%s','now','-5 days')",
  ).run();
''', '')
    extensions = Path(__file__).with_name('backend-extensions.mjs').read_text()
    source = replace_once(source, '/** HTTP boundary:', extensions + '/** HTTP boundary:')
    source = replace_once(source, '    if (request.method === "GET" && path === "/apple-touch-icon.png")', '''    const shiftFeed = /^\\/calendar\\/turni\\/([a-f0-9]{64})\\.ics$/.exec(path);
    if (shiftFeed) return serveShiftCalendar(request, env, shiftFeed[1]);
    if (request.method === "GET" && path === "/apple-touch-icon.png")''')
    source = replace_once(source, '    try {\n      if (method === "getPlanningProjection")', '''    try {
      if (method === "getHealthData") return response(await healthData(env));
      if (method === "saveHealthEntry") return response(await saveHealthEntry(env, args[0]));
      if (["getShiftCalendar", "publishShiftCalendar", "rotateShiftCalendarLink"].includes(method))
        return response(await shiftCalendarAction(env, method, args[0]));
      if (method === "getPlanningProjection")''')
    return source
