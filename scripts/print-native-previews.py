import base64,json,pathlib,subprocess,sys
compact = len(sys.argv) > 1 and sys.argv[1] == 'compact'
root = pathlib.Path('build/compact-screenshots') if compact else pathlib.Path('build/focused-screenshots') if pathlib.Path('build/focused-screenshots/manifest.json').exists() else pathlib.Path('build/screenshots')
prefix = 'compact-' if compact else ''
manifest = root/'manifest.json'
if not manifest.exists(): raise SystemExit(0)
def find(node,name):
    if isinstance(node,dict):
        values=[v for v in node.values() if isinstance(v,str)]
        if any(name in v for v in values):
            for v in values:
                if v.endswith('.png') and (root/v).is_file():return root/v
        for v in node.values():
            r=find(v,name)
            if r:return r
    elif isinstance(node,list):
        for v in node:
            r=find(v,name)
            if r:return r
data=json.loads(manifest.read_text())
for name in ['unified-activity-editor-dark','health-standardized-dark','compact-shift-palette-dark','dashboard-weekly-structure-dark','dashboard-grouped-events-dark','health-preview-light','health-preview-large-text','widget-informative-2x2-dark','calendar-fixed-day-pane-dark','calendar-on-tab-return','calendar-explicit-day-first-entry','calendar-palette-before-paint','calendar-date-unreachable','calendar-paint-palette','dashboard-week-80-and-shift-progress','finance-native-glass-actions']:
    source=find(data,name)
    if not source:continue
    dest=pathlib.Path('build')/(prefix+name+'.png')
    subprocess.run(['sips','-Z','900',str(source),'--out',str(dest)],check=True,stdout=subprocess.DEVNULL)
    encoded=base64.b64encode(dest.read_bytes()).decode()
    print('QA_IMAGE_START '+prefix+name)
    for i in range(0,len(encoded),16000):print('QA_IMAGE_DATA '+encoded[i:i+16000])
    print('QA_IMAGE_END '+prefix+name)
