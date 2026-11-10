#!/usr/bin/env python3
"""統一檢查（第九輪 P0）：平行跑、可快取、輸出一行結論。check_all.sh 是它的入口。

用法：GODOT=<godot> python3 tools/check.py [--out 資料夾] [--quick] [--no-cache] [--jobs N] [--only 名稱,...]
  --quick     改動時用：載入、框架、UI、金標準 30 場、字串、字型
  --no-cache  驗收用：全部重跑（快取只在改動時省時間）
環境變數 GOLDEN_N、COMPAT_N 和舊版相同。
快取鍵＝引擎版本＋該步驟腳本的 preload 相依樹＋資料檔的內容雜湊；細節在 <out>/summary.json。
"""
import argparse, concurrent.futures as cf, hashlib, json, os, re, shutil, subprocess, sys, time, uuid
from pathlib import Path

GAME = Path(__file__).resolve().parent.parent
EXPECT = "4.6.2.stable"
ERR = re.compile(r"SCRIPT ERROR|Parse Error|Compile Error|Failed to load script")
PRE = re.compile(r'(?:preload|load)\(\s*"res://([^"]+\.(?:gd|json|csv))"|^extends\s+"res://([^"]+\.gd)"', re.M)   # V1.1（Codex v110-impl #3）：也追繼承鏈
TEST_DONE = re.compile(r"^—— ([1-9]\d*) 通過 / 0 失敗", re.M)
# 這些組會碰存檔（固定檔名、靜態狀態），放同一個行程
STATEFUL = ["fantasy", "rules", "save", "ui", "modes", "v16"]


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def deps(entry: str, seen=None) -> set:
    seen = set() if seen is None else seen
    if entry in seen or not (GAME / entry).is_file():
        return seen
    seen.add(entry)
    if entry.endswith(".gd"):
        for m in PRE.findall((GAME / entry).read_text(encoding="utf-8", errors="ignore")):
            deps(m[0] or m[1], seen)
    return seen


def key_of(ver: str, entries: list, extra_dirs: list) -> str:
    files = set()
    for e in entries:
        deps(e, files)
    for d in extra_dirs:
        p = GAME / d
        if p.is_dir():
            files |= {str(x.relative_to(GAME)).replace("\\", "/") for x in p.rglob("*") if x.is_file() and x.suffix != ".import"}
        elif p.is_file():
            files.add(d)
    h = hashlib.sha256(ver.encode())
    for f in sorted(files):
        h.update(f.encode())
        h.update(sha(GAME / f).encode())
    return h.hexdigest()[:20]


def suite_map() -> dict:
    """run_tests.gd 的 FILES（JSON 相容）＋別名 new＝units。"""
    src = (GAME / "tests/run_tests.gd").read_text(encoding="utf-8")
    m = re.search(r"^const FILES := (\{.*\})$", src, re.M)
    files = json.loads(m.group(1)) if m else {}
    if "units" in files:
        files["new"] = files["units"]
    return files


FULL_GOLDEN = False


def plan(a) -> list:
    gn = int(os.environ.get("GOLDEN_N", "1000"))
    cn = int(os.environ.get("COMPAT_N", "1000"))
    t = "tests/run_tests.gd"
    suites = [f"tests/suites/{x.stem}.gd" for x in (GAME / "tests/suites").glob("*.gd")]
    data = ["data", "tests/golden"]
    st = []

    def gd(name, script, args, ok, entries=None, dirs=None):
        st.append({"name": name, "kind": "gd", "script": script, "args": args, "ok": ok,
                   "entries": entries or [script], "dirs": data if dirs is None else dirs})

    sim_only = ["tests/golden"]   # V1.1 E1：純模擬的工具不讀 data/（已查：相依樹與字面路徑都沒有），改字串不必重跑

    def shards(name, script, args, ok, m):
        for k in range(m):
            gd(f"{name}{k}", script, args + [f"--shard={k}/{m}"], ok, dirs=sim_only)

    files = suite_map()

    def test(name, only):
        # V1.1 E1：快取鍵只含這一步會跑到的測試組（以前是全部 suites，改一個測試檔全部重跑）
        groups = set()
        for k in only.split(","):
            k = k.lstrip("-")
            if k in files:
                groups.add(k)
            else:
                groups |= {g for g, fns in files.items() if k in fns}
        if "harness" in groups or not groups:
            ent = suites   # 框架測試會載入每個測試組
        else:
            ent = [f"tests/suites/{g}.gd" for g in sorted(groups)]
        gd(name, t, [f"--only={only}"], TEST_DONE.pattern, [t, "tests/test_base.gd"] + ent, data + ["fonts"])

    if a.quick:
        test("t_harness", "harness,anim")
        test("t_ui", "ui")
        test("t_v16", "v16")
        gd("golden", "tools/golden.gd", ["--n=30"], r'^GOLDEN \{.*"ok":true')
    else:
        for s in ["maps", "anim", "units", "free", "content", "harness"]:
            test(f"t_{s}", s)
        # 最慢的幾項各開一個行程（都不碰存檔）；其他留在原組
        test("t_golden", "test_golden")
        test("t_determinism", "test_determinism_and_mirror")
        test("t_core", "core,-test_golden,-test_determinism_and_mirror")
        test("t_sandbox", "test_sandbox_v5")
        # V1.1 E1：t_stateful 是關鍵路徑（845 秒）。不寫存檔的慢測試拆成各自的行程（三星解有鎖存檔、另兩個不碰存檔）
        for nm, fn in [("t_star", "test_star_solutions"), ("t_fmirror", "test_fantasy_mirror_v8"), ("t_events", "test_event_routes")]:
            test(nm, fn)
        # V1.6 #4：存檔組再拆兩個行程，各用自己的存檔前綴（rules、save 內部自訂的前綴互不重疊）
        skip = ",-test_sandbox_v5,-test_star_solutions,-test_fantasy_mirror_v8,-test_event_routes"
        gd("t_stateful", "tests/run_tests.gd", ["--only=rules,save" + skip, "--prefix=ta_"], TEST_DONE.pattern, ["tests/run_tests.gd", "tests/test_base.gd"] + [f"tests/suites/{g}.gd" for g in STATEFUL], data + ["fonts"])
        gd("t_stateful2", "tests/run_tests.gd", ["--only=fantasy,ui,modes,v16" + skip, "--prefix=tb_"], TEST_DONE.pattern, ["tests/run_tests.gd", "tests/test_base.gd"] + [f"tests/suites/{g}.gd" for g in STATEFUL], data + ["fonts"])
        shards("mirror", "tools/mirror_100.gd", [], r"^MIRROR100 100/100", 4)
        # V1.1 E1：最慢的兩組各切 8 片（每片太長，最後幾分鐘只剩少數工作在跑）
        global FULL_GOLDEN
        FULL_GOLDEN = gn >= 20   # 完整 golden 步驟涵蓋測試裡的前 20 場
        shards("golden", "tools/golden.gd", [f"--n={gn}"], r'^GOLDEN \{.*"ok":true', 8)
        shards("compat", "tools/compat.gd", [f"--n={cn}"], r'^COMPAT \{.*"ok":true', 8)
        gd("sealcodes", "tools/seal_codes.gd", [], r'^SEALCODES \{"n":40,"ok":true', dirs=sim_only)
        shards("goldenfree", "tools/golden_free.gd", [], r'^GOLDENFREE \{.*"ok":true', 3)
        shards("goldenv8", "tools/golden_v8.gd", [], r'^GOLDENV8 \{.*"ok":true', 3)
        shards("goldenmap", "tools/golden_map.gd", [], r'^GOLDENMAP \{.*"ok":true', 3)
        gd("orbit", "tools/orbit_detect.gd", [], r"^ORBIT cav_battles=", dirs=sim_only)
    for name, py in [("strings", "check_strings.py"), ("assets", "check_assets.py"), ("font", "check_font_coverage.py")]:
        if a.quick and name == "assets":
            continue
        st.append({"name": name, "kind": "py", "script": f"tools/{py}", "dirs": ["data", "scripts", "fonts", "art", "audio", "licenses", f"tools/{py}"], "entries": []})
    return st


def kill_marker(godot: str, marker: str) -> None:
    """WSL 的子行程被殺只砍外層，Windows 上的 Godot 還活著：用命令列裡的記號收掉。"""
    if godot.endswith(".exe") and shutil.which("powershell.exe"):
        ps = ("Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | "
              f"Where-Object {{ $_.CommandLine -like '*{marker}*' }} | ForEach-Object {{ Stop-Process -Id $_.ProcessId -Force }}")
        subprocess.run(["powershell.exe", "-NoProfile", "-Command", ps], capture_output=True, timeout=60)


def godot_cmd(godot: str, args: list, marker: str) -> list:
    return [godot] + args + ([] if "--" in args else ["--"]) + [f"--ntb-run={marker}"]


def run_step(s, godot, out, timeout, marker):
    os.environ["PYTHONUTF8"] = "1"
    os.environ["NTB_FULL_GOLDEN"] = "1" if FULL_GOLDEN else "0"   # 這一輪有完整 golden 步驟時，測試裡的 20 場抽查就不重複跑
    if "NTB_FULL_GOLDEN" not in os.environ.get("WSLENV", ""):
        os.environ["WSLENV"] = (os.environ.get("WSLENV", "") + ":NTB_FULL_GOLDEN").lstrip(":")   # WSL 呼叫 Windows 版 Godot 時環境變數要列在 WSLENV 才會傳過去
    log = out / f"{s['name']}.log"
    t0 = time.time()
    if s["kind"] == "py":
        cmd = [sys.executable, str(GAME / s["script"])]
    else:
        cmd = godot_cmd(godot, ["--headless", "--path", ".", "--script", f"res://{s['script']}", "--"] + s["args"], marker)
    try:
        with open(log, "wb") as f:
            rc = subprocess.run(cmd, cwd=GAME, stdout=f, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, timeout=timeout).returncode
    except subprocess.TimeoutExpired:
        kill_marker(godot, marker)
        return {"name": s["name"], "ok": False, "why": f"逾時 {timeout}s", "sec": time.time() - t0}
    txt = log.read_text(encoding="utf-8", errors="ignore")
    why = ""
    if rc != 0:
        why = f"exit {rc}"
    elif s["kind"] == "gd":
        if ERR.search(txt):
            why = "有腳本錯誤"
        elif not re.search(s["ok"], txt, re.M):
            why = "沒有完成標記"
    return {"name": s["name"], "ok": not why, "why": why, "sec": time.time() - t0}


def serial(godot, out, name, args, ok_re=None):
    log = out / f"{name}.log"
    with open(log, "wb") as f:
        rc = subprocess.run([godot] + args, cwd=GAME, stdout=f, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, timeout=900).returncode
    txt = log.read_text(encoding="utf-8", errors="ignore")
    if rc != 0 or ERR.search(txt) or (ok_re and not re.search(ok_re, txt, re.M)):
        return False
    return True


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")   # Windows 主控台預設不是 UTF-8，印中文會當掉
    p = argparse.ArgumentParser()
    p.add_argument("--out", default=str(GAME.parent / "build/tmp/check"))
    p.add_argument("--quick", action="store_true")
    p.add_argument("--no-cache", action="store_true")
    p.add_argument("--jobs", type=int, default=min(16, max(2, (os.cpu_count() or 4) - 4)))   # V1.1 E1：20 核心時開 16
    p.add_argument("--only", default="")
    p.add_argument("--timeout", type=int, default=2400)
    a = p.parse_args()
    godot = os.environ.get("GODOT", "godot")
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    cache = GAME.parent / "build/check-cache"
    cache.mkdir(parents=True, exist_ok=True)
    t0 = time.time()

    def fail(msg):
        print(f"CHECK FAIL：{msg}（記錄在 {out}）")
        return 1

    ver = subprocess.run([godot, "--version"], capture_output=True, text=True, stdin=subprocess.DEVNULL).stdout.strip()
    if not ver.startswith(EXPECT):
        if os.environ.get("ALLOW_GODOT_MISMATCH") != "1":
            return fail(f"Godot 版本是 {ver}，應該是 {EXPECT}")
        print(f"警告：Godot 版本 {ver} 不是 {EXPECT}，這次結果不能當驗收")
    marker = uuid.uuid4().hex[:10]
    if not (GAME / ".godot").is_dir() or a.no_cache:
        if not serial(godot, out, "import", ["--headless", "--path", ".", "--import"]):
            return fail("匯入失敗")
    # V1.1 E1：載入與啟動檢查改成和其他步驟一起平行跑（結果一樣要過，只是不再先排隊等）
    gate = cf.ThreadPoolExecutor(2)
    f_load = gate.submit(serial, godot, out, "load", ["--headless", "--path", ".", "--script", "res://tools/load_all.gd"], r"^LOADALL .*失敗 0：")
    f_boot = gate.submit(serial, godot, out, "boot", ["--headless", "--path", ".", "--", "--boot-check"], r"^BOOTOK")
    steps = plan(a)
    if a.only:
        want = a.only.split(",")
        steps = [s for s in steps if any(s["name"].startswith(w) for w in want)]
    res, todo = [], []
    for s in steps:
        s["key"] = key_of(ver + json.dumps(s.get("args", [])) + s["name"], s["entries"], s["dirs"])
        hit = cache / f"{s['name']}-{s['key']}.log"
        if not a.no_cache and hit.is_file():
            shutil.copy(hit, out / f"{s['name']}.log")
            res.append({"name": s["name"], "ok": True, "why": "", "sec": 0.0, "cached": True})
        else:
            todo.append(s)
    # V1.1 E1：最久的先開跑（用上一次的秒數；沒有紀錄的排前面），整體完工時間最短
    prev = {}
    for f in [out / "summary.json", GAME.parent / "build/tmp/check/summary.json"]:
        try:
            for r0 in json.loads(f.read_text(encoding="utf-8")).get("steps", []):
                if not r0.get("cached") and r0.get("sec", 0) > prev.get(r0["name"], 0):
                    prev[r0["name"]] = r0["sec"]
        except (OSError, ValueError):
            pass
    todo.sort(key=lambda s: -prev.get(s["name"], 10 ** 6))
    with cf.ThreadPoolExecutor(a.jobs) as ex:   # 載入／啟動檢查只佔前 20 秒，不另外扣名額
        futs = {ex.submit(run_step, s, godot, out, a.timeout, marker): s for s in todo}
        for fu in cf.as_completed(futs):
            r = fu.result()
            res.append(r)
            if r["ok"]:
                s = futs[fu]
                for old in cache.glob(f"{s['name']}-*.log"):
                    old.unlink()
                shutil.copy(out / f"{s['name']}.log", cache / f"{s['name']}-{s['key']}.log")
    if not f_load.result():
        return fail("有腳本載入失敗")
    if not f_boot.result():
        return fail("正式入口啟動失敗")
    gate.shutdown()
    tests, times = 0, []
    fp = ""
    for s in steps:
        lg = out / f"{s['name']}.log"
        if lg.is_file() and s["name"].startswith("t_"):
            txt = lg.read_text(encoding="utf-8", errors="ignore")
            m = TEST_DONE.search(txt)
            tests += int(m.group(1)) if m else 0
            times += [(n, int(ms)) for n, ms in re.findall(r"^TIME (\S+) (\d+)", txt, re.M)]
            m2 = re.search(r"^FINGERPRINT .*$", txt, re.M)
            fp = m2.group(0).strip() if m2 else fp
    if fp:
        (out / "fingerprint.txt").write_text(fp + "\n", encoding="utf-8", newline="\n")   # Windows 預設 CRLF，跨平台比對會假失敗
    wall = time.time() - t0
    bad = [r for r in res if not r["ok"]]
    times.sort(key=lambda x: -x[1])
    (out / "summary.json").write_text(json.dumps({"wall_sec": round(wall), "tests": tests, "fingerprint": fp, "jobs": a.jobs,
        "steps": sorted(res, key=lambda r: -r["sec"]), "slow_tests": times[:25]}, ensure_ascii=False, indent=1), encoding="utf-8")
    if bad:
        return fail("、".join(f"{r['name']}（{r['why']}）" for r in bad))
    cached = sum(1 for r in res if r.get("cached"))
    print(f"CHECK OK：{len(res)} 步（快取 {cached}）、測試 {tests} 項、{round(wall)} 秒｜{fp}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
