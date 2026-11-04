"""Paired economy-cap experiment; freezes source and never edits production balance."""
import concurrent.futures as cf
import hashlib,json,os,pathlib,shutil,subprocess,time,argparse
ROOT=pathlib.Path(__file__).resolve().parents[1]
LORDS=['lion','iron','harvest','adventure','underworld','vampire','mage','rune']
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--workers',type=int,default=8);ap.add_argument('--repeat',type=int,default=0);ap.add_argument('--goals',default='2,3,4,6,8,10');ap.add_argument('--selection');args=ap.parse_args()
    run=ROOT/'.runtime/economy-study';snap=run/'snapshot';out=run/f'round-{args.repeat}'
    out.mkdir(parents=True,exist_ok=True)
    if not snap.exists():
        (snap/'tools').mkdir(parents=True)
        files=list(ROOT.glob('*.gd'))+[ROOT/'tools/economy_experiment.gd',ROOT/'tools/economy_experiment_battle.gd']
        manifest={}
        for p in files:
            rel=p.relative_to(ROOT);shutil.copy2(p,snap/rel);manifest[str(rel)]=hashlib.sha256(p.read_bytes()).hexdigest()
        (snap/'project.godot').write_text('config_version=5\n\n[application]\nconfig/name="Economy Experiment"\n',encoding='utf-8')
        (run/'manifest.json').write_text(json.dumps({'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'files':manifest},indent=2),encoding='utf-8')
    goals=list(map(int,args.goals.split(',')))
    selection=json.loads(pathlib.Path(args.selection).read_text()) if args.selection else {l:goals for l in LORDS}
    jobs=[(lord,g) for lord,gs in selection.items() for g in gs]
    def work(job):
        lord,goal=job;p=out/f'{lord}-{goal}.jsonl';log=out/f'{lord}-{goal}.log'
        env=os.environ.copy();env['APPDATA']=str(run/'userdata')
        cmd=['godot_console','--headless','--path',str(snap),'-s','tools/economy_experiment.gd','--',f'--lord={lord}',f'--goal={goal}',f'--repeat={args.repeat}',f'--out={p}','--opponents=3','--opponent-picks=iron,underworld,mage']
        r=subprocess.run(cmd,cwd=snap,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace',timeout=600)
        log.write_text(r.stdout,encoding='utf-8')
        if r.returncode or 'SCRIPT ERROR' in r.stdout:raise RuntimeError(f'{lord}/{goal}: {r.stdout[-1500:]}')
        rows=[json.loads(s) for s in p.read_text().splitlines() if s.strip()]
        if len(rows)!=6: raise RuntimeError(f'{lord}/{goal}: incomplete {len(rows)}')
        return rows
    started=time.monotonic();results=[]
    with cf.ThreadPoolExecutor(args.workers) as pool:
        futures=[pool.submit(work,j) for j in jobs]
        for f in cf.as_completed(futures):
            results.extend(f.result())
            (out/'combined.jsonl').write_text(''.join(json.dumps(r,ensure_ascii=False)+'\n' for r in results),encoding='utf-8')
            print(f'{len(results)}/{len(jobs)*6} matches; {time.monotonic()-started:.0f}s',flush=True)
    print('DONE',flush=True)
if __name__=='__main__':main()
