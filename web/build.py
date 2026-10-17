"""Embed the readable UI without changing the worker backend."""
from pathlib import Path
import json,re,subprocess,tempfile
base=Path(__file__).parent
source=(base/'worker.mjs').read_text()
html=(base/'app.html').read_text()
source,count=re.subn(r'const APP_HTML = (".*");',lambda _: 'const APP_HTML = '+json.dumps(html,ensure_ascii=True)+';',source)
assert count==1, 'Expected exactly one APP_HTML'
with tempfile.TemporaryDirectory() as folder:
    for i,script in enumerate(re.findall(r'<script[^>]*>(.*?)</script>',html,re.S)):
        target=Path(folder)/f'ui-{i}.js';target.write_text(script)
        subprocess.run(['node','--check',str(target)],check=True)
(base/'worker.mjs').write_text(source)
subprocess.run(['node','--check',str(base/'worker.mjs')],check=True)
print('Worker and embedded scripts validated')
