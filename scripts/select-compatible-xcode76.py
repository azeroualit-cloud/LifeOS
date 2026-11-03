"""Use a pre-27.2 Foundation overlay for early iOS 27.2 device betas."""
from pathlib import Path
import json,os,re,subprocess
available=[]
for path in Path('/Applications').glob('Xcode_*.app'):
    match=re.fullmatch(r'Xcode_([0-9.]+).app',path.name)
    if match:available.append((tuple(map(int,match[1].split('.'))),path))
print('INSTALLED_XCODES', [p.name for _,p in available],flush=True)
preferred=[item for item in available if item[0][:2]==(27,0)]
compatible=preferred or [item for item in available if item[0][0]==26]
assert compatible,'A compatible Xcode 27.0 or 26.x toolchain is required; do not silently use 27.2'
version,path=max(compatible,key=lambda item:item[0]);developer=str(path/'Contents/Developer')
env=dict(os.environ,DEVELOPER_DIR=developer)
sdk=subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-version'],text=True,env=env).strip()
parts=tuple(map(int,sdk.split('.')))
assert parts[0]==26 or parts[:2]==(27,0),('Incompatible Foundation overlay SDK',sdk)
with open(os.environ['GITHUB_ENV'],'a') as file:file.write('DEVELOPER_DIR='+developer+'\nCOMPAT_SDK_VERSION='+sdk+'\n')
print('COMPATIBILITY_TOOLCHAIN',path.name,'SDK',sdk,flush=True)
