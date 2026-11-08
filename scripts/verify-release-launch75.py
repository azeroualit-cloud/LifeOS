"""Launch the real Release path using only fresh/synthetic simulator storage.

The final-validation workflow supplies a fresh simulator and a separate fixture
simulator after the full test suite. Keep these checks optional because older
compatibility workflows use this script without those separate simulators.
"""
from pathlib import Path
import argparse
import os,subprocess,json,time,shutil,datetime
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fresh-only', action='store_true')
args = parser.parse_args()
out=Path('release-launch');out.mkdir(exist_ok=True)
device=os.environ['MAIN_DEVICE'];fresh_device=os.environ.get('FRESH_DEVICE',device);bundle='com.nas.lifeos.probe'
test_device=os.environ.get('FINAL_VALIDATION_TEST_DEVICE')
if test_device and (device==test_device or fresh_device==test_device or fresh_device==device):
    raise SystemExit('Release startup checks require separate full-suite, fresh, and fixture simulators')
app=Path('release-build/Build/Products/Release-iphonesimulator/LifeOSProbe.app')
for target_device in dict.fromkeys((fresh_device,device)):
    subprocess.run(['xcrun','simctl','install',target_device,str(app)],check=True)
modes=['fresh']
if not args.fresh_only:
    modes.extend(['synthetic-upgrade', 'synthetic-populated-upgrade'])
    if os.environ.get('LIFEOS_RELEASE_SESSION_FIXTURE') == '1':
        modes.append('synthetic-session-upgrade')
for mode in modes:
    target_device=fresh_device if mode=='fresh' else device
    if mode!='fresh':
        subprocess.run(['xcrun','simctl','terminate',target_device,bundle],check=False,capture_output=True)
        container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',target_device,bundle,'data'],text=True).strip())
        file=container/'Library/Application Support/lifeos-native-v2.json'
        state=json.loads(file.read_text());state['demo']=False;state['endpoint']=None
        state['life']={'tasks':[],'categories':[],'routines':[],'events':[],'activityEvents':[],'upcomingEvents':[],'shifts':[],'occurrences':{},'health':[]}
        if mode=='synthetic-populated-upgrade':
            today=datetime.date.today().isoformat()
            event={'id':101,'title':'Synthetic existing appointment','day':today,'start_time':'23:59','frequency':'none','occurrence_status':'open'}
            state['life'].update({'today':today,'tasks':[{'id':102,'title':'Synthetic existing task','status':'todo','list_kind':'action'}],
                'events':[event],'upcomingEvents':[event],'activityEvents':[event],
                'shifts':[{'day':today,'kind':'morning'}],
                'health':[{'day':(datetime.date.today()-datetime.timedelta(days=i+1)).isoformat(),'weight_kg':80+i*0.02,'calories':2400} for i in range(31)]})
        if mode=='synthetic-session-upgrade':
            state['endpoint']='https://release-startup.lifeos.invalid'
            state['pending']=[]
        file.write_text(json.dumps(state))
    log=out/(mode+'.log')
    with log.open('w') as f:
        launch=subprocess.Popen(['xcrun','simctl','launch','--terminate-running-process','--console-pty',target_device,bundle],stdout=f,stderr=subprocess.STDOUT)
        time.sleep(25)
        alive=launch.poll() is None
        subprocess.run(['xcrun','simctl','io',target_device,'screenshot',str(out/(mode+'.png'))],check=True)
        print('RELEASE_LAUNCH',mode,'console_process_alive',alive,flush=True)
        if not alive:
            print(log.read_text(errors='replace')[-16000:],flush=True)
        subprocess.run(['xcrun','simctl','terminate',target_device,bundle],check=False,capture_output=True)
        try:launch.wait(timeout=10)
        except subprocess.TimeoutExpired:launch.terminate();launch.wait(timeout=10)
    report=Path.home()/'Library/Logs/DiagnosticReports'
    if report.exists():
        for p in report.glob('LifeOSProbe*'):shutil.copy2(p,out/p.name)
    if not alive:raise SystemExit('Release startup failed: '+mode)
print('RELEASE_LAUNCH_SMOKE_PASSED: no DEBUG flags, real services; cases='+','.join(modes))
