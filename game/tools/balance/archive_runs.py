#!/usr/bin/env python3
"""實驗分片封存（第七輪 J1）：python3 game/tools/archive_runs.py [--verify-only]
docs/balance-runs/<實驗>/ 裡的 jsonl 分片打包成 shards.tar.gz，旁邊寫 archive.manifest（檔數、雜湊、來源 commit、還原指令）。
驗證可以完整還原（逐檔比對位元組）才刪散檔；報表、log、summary 留在外面。
還原：tar xzf shards.tar.gz（在該實驗資料夾裡），報表工具就能照舊重算。"""
import glob, hashlib, io, json, os, subprocess, sys, tarfile
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "balance-runs")
tot = 0
dirs = sorted(dp for dp, _, _ in os.walk(root))
for d in dirs:
    files = sorted(f for f in os.listdir(d) if f.endswith(".jsonl"))
    tarp = os.path.join(d, "shards.tar.gz")
    if "--verify-only" in sys.argv:
        if os.path.exists(tarp):
            m = json.load(open(os.path.join(d, "archive.manifest"), encoding="utf-8"))
            assert hashlib.sha256(open(tarp, "rb").read()).hexdigest() == m["sha256"], d
            with tarfile.open(tarp) as t:
                assert len(t.getnames()) == m["files"], d
            tot += m["files"]
        continue
    if not files:
        continue
    rel = os.path.relpath(d, os.path.join(root, "..", ".."))
    commit = subprocess.run(["git", "log", "-1", "--format=%h", "--", rel], capture_output=True, text=True).stdout.strip()
    with tarfile.open(tarp, "w:gz", compresslevel=9) as t:
        for f in files:
            t.add(os.path.join(d, f), arcname=f)
    with tarfile.open(tarp) as t:
        for f in files:
            if t.extractfile(f).read() != open(os.path.join(d, f), "rb").read():
                sys.exit("還原比對不符：%s/%s" % (d, f))
    sha = hashlib.sha256(open(tarp, "rb").read()).hexdigest()
    json.dump({"run": os.path.basename(d), "files": len(files), "sha256": sha, "source_commit": commit,
               "restore": "cd %s && tar xzf shards.tar.gz" % rel.replace("\\", "/")}, open(os.path.join(d, "archive.manifest"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for f in files:
        os.remove(os.path.join(d, f))
    tot += len(files)
print("分片 %d 檔已封存／驗證" % tot)
