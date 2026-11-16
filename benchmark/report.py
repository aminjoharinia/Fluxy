"""Turns results/summary.json into the report files:

- results/report/results.csv    one row per library and scenario
- results/report/libraries.csv  library names, versions, how they notify
- results/report/scenarios.csv  what each scenario does
- results/report/machine.csv    where it ran
- results/RESULTS.md            the same numbers as Markdown tables
"""
import csv
import json
import os
import subprocess
import sys

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
summary = json.load(open(os.path.join(root, "results", "summary.json")))
out = os.path.join(root, "results", "report")
os.makedirs(out, exist_ok=True)

# Mirrors scenarioInfos in bench_kit/lib/src/harness.dart (normal size).
SCENARIOS = [
    ("create", "Create + dispose", "core", "value",
     "1,000 reactive values, one listener each, then disposed."),
    ("write", "Write, 1 listener", "core", "write",
     "10,000 writes to one value with one listener."),
    ("fanout", "Fan-out", "core", "write",
     "100 writes to one value with 1,000 listeners."),
    ("subscribe", "Subscribe + unsubscribe, shared", "core", "listener",
     "1,000 listeners subscribe to one value and unsubscribe in a scattered order, with a write in between."),
    ("wide", "Wide derived", "core", "write",
     "1,000 sources summed by one derived value; each source written once, the sum read after every write."),
    ("chain", "Deep chain", "core", "write",
     "A chain of 100 derived values; 1,000 writes to the root, the end read after every write."),
    ("diamond", "Diamond", "core", "write",
     "a -> b, c -> d = b + c with a listener; 1,000 writes. Also counts glitches: the listener seeing a d that does not match a."),
    ("batch", "Batch update", "core", "round",
     "100 sources and a derived sum with a listener; 100 rounds that change every source (batched where the library can), then read the sum."),
    ("mount", "Mount + unmount", "widget", "widget",
     "Mount 1,000 reactive widgets (each subscribing to its own value), one frame, then unmount them, one frame."),
    ("mountShared", "Mount + unmount, shared value", "widget", "widget",
     "Mount 1,000 reactive widgets that all read the same value, one frame, then unmount them, one frame."),
    ("rebuildAll", "Rebuild all", "widget", "widget",
     "Write all 1,000 values, then one frame that rebuilds all 1,000 widgets."),
    ("rebuildOne", "Rebuild one", "widget", "frame",
     "Write one of 1,000 values, then one frame that must rebuild exactly that widget."),
]

METRICS = ["listenerCallsPerWrite", "glitchesPerWrite", "recomputesPerWrite", "listenerCallsPerRound",
           "bytesPerValue", "bytesPerListener"]

with open(os.path.join(out, "results.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["library", "libraryName", "scenario", "ok", "medianUs", "p25Us", "p75Us",
                "minUs", "samples", "opsPerRun", "nsPerOp", "error"] + METRICS)
    for lib in summary["libraries"]:
        for r in lib["results"]:
            m = r.get("metrics") or {}
            w.writerow([lib["key"], lib["library"], r["id"], "yes" if r["ok"] else "no",
                        r.get("medianUs", ""), r.get("p25Us", ""), r.get("p75Us", ""),
                        r.get("minUs", ""), r.get("samples", ""), r.get("opsPerRun", ""),
                        round(r["nsPerOp"], 1) if r.get("ok") else "", r.get("error", "")]
                       + [m.get(k, "") for k in METRICS])

with open(os.path.join(out, "libraries.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["library", "libraryName", "versions", "notifies", "notes", "runs", "mode"])
    for lib in summary["libraries"]:
        versions = ", ".join(f"{k} {v}" for k, v in lib["versions"].items()) or "this repo"
        w.writerow([lib["key"], lib["library"], versions,
                    "async (streams / scheduled)" if lib["asyncNotify"] else "sync",
                    lib["notes"], lib["runs"], lib["mode"]])

with open(os.path.join(out, "scenarios.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["scenario", "title", "group", "opLabel", "description"])
    for row in SCENARIOS:
        w.writerow([row[0], row[1], row[2], row[3], row[4]])

flutter = ""
try:
    flutter = subprocess.check_output(["flutter", "--version"], text=True).splitlines()[0].split(" • https")[0]
except Exception:
    pass
m = summary["machine"]
m["os"] = m.get("os", "").replace("Version ", "macOS ")
with open(os.path.join(out, "machine.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["cpu", "cores", "os", "dart", "flutter"])
    w.writerow([m.get("cpu", ""), m.get("cpus", ""), m.get("os", ""),
                m.get("dart", "").split(" (")[0], flutter])


def fmt(us):
    if us >= 1000000:
        return f"{us / 1000000:.2f} s"
    if us >= 1000:
        return f"{us / 1000:.2f} ms"
    return f"{us} µs"


libs = summary["libraries"]
lines = ["# Benchmark results", "",
         f"{m.get('cpu', '')}, {m.get('os', '')}, {flutter}. Release (AOT) macOS builds; "
         "median time per run, best of %d runs per library. Lower is better; "
         "**bold** is the fastest." % max(l["runs"] for l in libs), "",
         "| Scenario | " + " | ".join(l["library"] for l in libs) + " |",
         "|---|" + "---|" * len(libs)]
for sid, title, *_ in SCENARIOS:
    cells = []
    vals = {}
    for l in libs:
        r = next((x for x in l["results"] if x["id"] == sid), None)
        vals[l["key"]] = r
    best = min((r["medianUs"] for r in vals.values() if r and r["ok"]), default=None)
    for l in libs:
        r = vals[l["key"]]
        if not r or not r["ok"]:
            cells.append("failed")
        else:
            t = fmt(r["medianUs"])
            cells.append(f"**{t}**" if r["medianUs"] == best else t)
    lines.append(f"| {title} | " + " | ".join(cells) + " |")
lines += ["", "## Correctness", "",
          "| Library | Diamond: listener calls / write | glitches / write | d recomputes / write | Batch: listener calls / round |",
          "|---|---|---|---|---|"]
for l in libs:
    d = next((x for x in l["results"] if x["id"] == "diamond"), {}).get("metrics", {})
    b = next((x for x in l["results"] if x["id"] == "batch"), {}).get("metrics", {})
    lines.append(f"| {l['library']} | {d.get('listenerCallsPerWrite', '')} | {d.get('glitchesPerWrite', '')} | "
                 f"{d.get('recomputesPerWrite', '')} | {b.get('listenerCallsPerRound', '')} |")
lines += ["", "## Memory", "",
          "Growth of the process's resident memory while 200,000 values are created, then while each gets one "
          "listener (lowest of the runs; a rough figure).", "",
          "| Library | Bytes / value | Bytes / listener |", "|---|---|---|"]
for l in libs:
    mm = next((x for x in l["results"] if x["id"] == "memory"), {}).get("metrics", {})
    lines.append(f"| {l['library']} | {mm.get('bytesPerValue', '')} | {mm.get('bytesPerListener', '')} |")
lines += ["", "Library versions: " + "; ".join(
    f"{l['library']} ({', '.join(f'{k} {v}' for k, v in l['versions'].items()) or 'this repo'})" for l in libs), ""]
open(os.path.join(root, "results", "RESULTS.md"), "w").write("\n".join(lines))
print("wrote results/report/*.csv and results/RESULTS.md")
