"""Assemble the existing Worker template, code-only backend extension and UI."""
from pathlib import Path
import json,re,subprocess,tempfile
from backend_update import apply_backend_extensions
base=Path(__file__).parent
source=apply_backend_extensions((base/'worker.mjs').read_text())
html=(base/'app.html').read_text()
source,count=re.subn(r'const APP_HTML = (".*");',lambda _: 'const APP_HTML = '+json.dumps(html,ensure_ascii=True)+';',source)
assert count==1, 'Expected exactly one APP_HTML'
with tempfile.TemporaryDirectory() as folder:
    for i,script in enumerate(re.findall(r'<script[^>]*>(.*?)</script>',html,re.S)):
        target=Path(folder)/f'ui-{i}.js';target.write_text(script)
        subprocess.run(['node','--check',str(target)],check=True)
output=base/'dist'/'worker.mjs'
output.parent.mkdir(exist_ok=True)
output.write_text(source)
subprocess.run(['node','--check',str(output)],check=True)
print('dist/worker.mjs and embedded scripts validated')
