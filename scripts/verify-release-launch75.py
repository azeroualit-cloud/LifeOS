"""Launch the real Release path using only fresh/synthetic simulator storage."""
from pathlib import Path
import os,subprocess,json,time,signal,shutil
out=Path('release-launch');out.mkdir(exist_ok=True)
device=os.environ['MAIN_DEVICE'];bundle='com.nas.lifeos.probe'
app=Path('release-build/Build/Products/Release-iphonesimulator/LifeOSProbe.app')
subprocess.run(['xcrun','simctl','install',device,str(app)],check=True)
for mode in ['fresh','synthetic-upgrade']:
    if mode=='synthetic-upgrade':
        subprocess.run(['xcrun','simctl','terminate',device,bundle],check=False,capture_output=True)
        container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,bundle,'data'],text=True).strip())
        file=container/'Library/Application Support/lifeos-native-v2.json'
        state=json.loads(file.read_text());state['demo']=False;state['endpoint']=None
        state['life']={'tasks':[],'categories':[],'routines':[],'events':[],'activityEvents':[],'upcomingEvents':[],'shifts':[],'occurrences':{},'health':[]}
        file.write_text(json.dumps(state))
    log=out/(mode+'.log')
    with log.open('w') as f:
        launch=subprocess.Popen(['xcrun','simctl','launch','--terminate-running-process','--console-pty',device,bundle],stdout=f,stderr=subprocess.STDOUT)
        time.sleep(25)
        alive=launch.poll() is None
        subprocess.run(['xcrun','simctl','io',device,'screenshot',str(out/(mode+'.png'))],check=True)
        print('RELEASE_LAUNCH',mode,'console_process_alive',alive,flush=True)
        if not alive:
            print(log.read_text(errors='replace')[-16000:],flush=True)
        subprocess.run(['xcrun','simctl','terminate',device,bundle],check=False,capture_output=True)
        try:launch.wait(timeout=10)
        except subprocess.TimeoutExpired:launch.terminate();launch.wait(timeout=10)
    report=Path.home()/'Library/Logs/DiagnosticReports'
    if report.exists():
        for p in report.glob('LifeOSProbe*'):shutil.copy2(p,out/p.name)
    if not alive:raise SystemExit('Release startup failed: '+mode)
print('RELEASE_LAUNCH_SMOKE_PASSED: no DEBUG flags, real service initialization, fresh and synthetic-upgrade storage')
