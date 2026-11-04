"""Dark faction grave economy study:
1) Optimal total grave goal (2, 3, 4, 5, 6, 8)
2) Optimal max graves per lane (lane-cap: 1, 2, 3, 4)
"""
import concurrent.futures as cf
import json, os, pathlib, subprocess, time, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
RUN = ROOT / ".runtime/grave-study"
SNAP = ROOT / ".runtime/economy-study/snapshot"
USERDATA = RUN / "userdata"

def run_job(job):
    lord, goal, lane_cap, rep = job
    out_dir = RUN / f"rep-{rep}"
    out_dir.mkdir(parents=True, exist_ok=True)
    p = out_dir / f"{lord}-g{goal}-lc{lane_cap}.jsonl"
    log = out_dir / f"{lord}-g{goal}-lc{lane_cap}.log"
    
    env = os.environ.copy()
    env["APPDATA"] = str(USERDATA)
    cmd = [
        "godot_console", "--headless", "--path", str(SNAP),
        "-s", "tools/economy_experiment.gd", "--",
        f"--lord={lord}", f"--goal={goal}", f"--lane-cap={lane_cap}",
        f"--repeat={rep}", f"--out={p}",
        "--opponents=3", "--opponent-picks=iron,underworld,mage"
    ]
    r = subprocess.run(cmd, cwd=SNAP, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8", errors="replace", timeout=600)
    log.write_text(r.stdout, encoding="utf-8")
    if r.returncode != 0 or "SCRIPT ERROR" in r.stdout:
        raise RuntimeError(f"{lord}/g{goal}/lc{lane_cap}: {r.stdout[-1500:]}")
    rows = [json.loads(s) for s in p.read_text(encoding="utf-8").splitlines() if s.strip()]
    if len(rows) != 6:
        raise RuntimeError(f"incomplete: {len(rows)}")
    return rows

def main():
    RUN.mkdir(parents=True, exist_ok=True)
    USERDATA.mkdir(parents=True, exist_ok=True)
    
    # 1. Total Grave Goals (lane_cap=99)
    # 2. Lane Caps (test lane_cap in [1, 2, 3, 4] with goal=4)
    jobs = []
    lords = ["underworld", "vampire"]
    
    # Repeat rounds 0, 1, 2
    for rep in range(3):
        # Total goal study (lane_cap=99)
        for lord in lords:
            for goal in [2, 3, 4, 5, 6, 8]:
                jobs.append((lord, goal, 99, rep))
        # Lane cap study (test cap 1, 2, 3, 4 with goal 4)
        for lord in lords:
            for cap in [1, 2, 3, 4]:
                jobs.append((lord, 4, cap, rep))
                
    total_jobs = len(jobs)
    print(f"Total jobs: {total_jobs} ({total_jobs * 6} matches). Running with 8 workers...", flush=True)
    started = time.monotonic()
    all_results = []
    
    with cf.ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(run_job, j) for j in jobs]
        for f in cf.as_completed(futures):
            res = f.result()
            all_results.extend(res)
            print(f"Completed {len(all_results)}/{total_jobs * 6} matches ({time.monotonic()-started:.1f}s)", flush=True)
            
    combined = RUN / "dark_study_combined.jsonl"
    combined.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in all_results), encoding="utf-8")
    print(f"ALL DONE! Saved {len(all_results)} results to {combined}", flush=True)

if __name__ == "__main__":
    main()
