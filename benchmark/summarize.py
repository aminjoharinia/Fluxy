"""Merges results/<lib>-<n>.json into results/summary.json (or, for a size
other than normal, results/<size>/<lib>-<n>.json into
results/<size>/summary.json).

For each library and scenario the best (lowest) median of the runs is kept:
the runs differ only by machine noise, so the lowest median is the closest
to the library's own cost. Library versions come from each app's
pubspec.lock.
"""
import glob
import json
import os
import platform
import re
import subprocess
import sys

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(__file__)
size = sys.argv[2] if len(sys.argv) > 2 else "normal"
results_dir = os.path.join(root, "results") if size == "normal" else os.path.join(root, "results", size)
order = ["fluxy", "getx5", "getx4", "riverpod", "bloc", "signals"]
packages = {
    "fluxy": [],
    "getx5": ["get"],
    "getx4": ["get"],
    "riverpod": ["riverpod", "flutter_riverpod"],
    "bloc": ["bloc", "flutter_bloc"],
    "signals": ["signals", "signals_core", "signals_flutter"],
}


def lock_versions(lib):
    path = os.path.join(root, "apps", lib, "pubspec.lock")
    text = open(path).read()
    out = {}
    for name in packages[lib]:
        m = re.search(r"\n  %s:\n(?:    .*\n)*?    version: \"([^\"]+)\"" % name, text)
        if m:
            out[name] = m.group(1)
    return out


def cpu():
    try:
        return subprocess.check_output(
            ["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip()
    except Exception:
        return platform.processor()


def better(r, best):
    # Memory is a one-shot figure: keep the run that grew the least.
    if r["id"] == "memory":
        return r["metrics"]["bytesPerValue"] < best["metrics"]["bytesPerValue"]
    return r["medianUs"] < best["medianUs"]


libraries = []
machine_info = {}
for lib in order:
    runs = [json.load(open(p)) for p in sorted(glob.glob(os.path.join(results_dir, f"{lib}-*.json")))]
    if not runs:
        continue
    merged = {}
    for run in runs:
        for r in run["results"]:
            best = merged.get(r["id"])
            if not r["ok"]:
                if best is None:
                    merged[r["id"]] = r
                continue
            if best is None or not best["ok"] or better(r, best):
                merged[r["id"]] = r
    first = runs[0]
    machine_info = {"os": first["os"], "dart": first["dart"], "cpus": first["cpus"]}
    libraries.append({
        "key": lib,
        "library": first["library"],
        "notes": first["notes"],
        "asyncNotify": first["asyncNotify"],
        "mode": first["mode"],
        "versions": lock_versions(lib),
        "runs": len(runs),
        "results": [merged[k] for k in merged],
    })

summary = {
    "size": size,
    "machine": {"cpu": cpu(), **machine_info},
    "libraries": libraries,
}
json.dump(summary, open(os.path.join(results_dir, "summary.json"), "w"), indent=2)
print("wrote", os.path.relpath(os.path.join(results_dir, "summary.json"), root), "for", ", ".join(l["key"] for l in libraries))
