#!/usr/bin/env python3
"""Summarise ChronoStatSvc CPU output for the cumulative parameter scan.

Reads the per-chunk chrono tables written by submit_param_scan.sh
(param_scan_10f/chrono_<config>_<tag>_<chunk>.txt), and for each of the 5
configurations averages the per-event CPU over the ten 100-event chunk runs.

Each [Algo:Execute] block gives:
    cpu_user_mean = <mean CPU per event, microseconds>
    cpu_user_nbr  = <number of Execute calls = events in that run>
So a chunk's per-event CPU is cpu_user_mean / 1e6 seconds; the table reports the
mean over the ten chunks +/- the chunk-to-chunk standard deviation.

Usage:  python3 analyze_chrono_param_scan.py [SCANDIR] [--md out.md]
"""
import glob
import math
import os
import re
import sys

SCANDIR = "/global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy/param_scan_10f"
MDOUT = None
args = sys.argv[1:]
if "--md" in args:
    i = args.index("--md")
    MDOUT = args[i + 1]
    del args[i:i + 2]
if args:
    SCANDIR = args[0]

# (config index, tag) in cumulative order -- must match submit_param_scan.sh
CONFIGS = [(0, "nominal"), (1, "outlier25"), (2, "branchstop"), (3, "fourD"), (4, "doublet0p1")]
# chrono block name -> table column label; "Total" (sum of all blocks) is added separately
ALGOS = [("Reconstructor", "CKF"), ("Deduper", "Dedup"), ("Filterer", "Filter")]
US_TO_S = 1e-6


def parse_chrono(path):
    """{algo: (cpu_user_mean_us, cpu_user_nbr)} for every [Algo:Execute] block."""
    out = {}
    with open(path) as fh:
        txt = fh.read()
    for m in re.finditer(r"\[(\w+):Execute\](.*?)(?=\n\[|\Z)", txt, re.S):
        name, body = m.group(1), m.group(2)
        mean = re.search(r"cpu_user_mean\s*=\s*([0-9.eE+-]+)", body)
        nbr = re.search(r"cpu_user_nbr\s*=\s*([0-9]+)", body)
        if mean:
            out[name] = (float(mean.group(1)), int(nbr.group(1)) if nbr else 0)
    return out


def stat(vals):
    """(mean, sample std) of a list; std=0 for a single value, nan for empty."""
    n = len(vals)
    if n == 0:
        return float("nan"), float("nan")
    mean = sum(vals) / n
    if n == 1:
        return mean, 0.0
    var = sum((v - mean) ** 2 for v in vals) / (n - 1)
    return mean, math.sqrt(var)


def cell(mean, std):
    if mean != mean:  # nan
        return "-"
    return f"{mean:.3g} ± {std:.2g}"


rows = []
for cfg, tag in CONFIGS:
    files = sorted(glob.glob(os.path.join(SCANDIR, f"chrono_{cfg}_{tag}_*.txt")))
    per_algo = {a: [] for a, _ in ALGOS}
    totals, nevts = [], []
    for f in files:
        blocks = parse_chrono(f)
        for a, _ in ALGOS:
            if a in blocks:
                per_algo[a].append(blocks[a][0] * US_TO_S)
        totals.append(sum(v[0] for v in blocks.values()) * US_TO_S)
        if "Reconstructor" in blocks:
            nevts.append(blocks["Reconstructor"][1])
    rows.append(dict(cfg=cfg, tag=tag, nchunks=len(files), nevts=nevts,
                     per_algo=per_algo, totals=totals))

# --- build the markdown table ------------------------------------------------
head = ["Config", "Chunks", "Events/chunk"] + [lbl + " [s/evt]" for _, lbl in ALGOS] + ["Total reco [s/evt]"]
lines = ["| " + " | ".join(head) + " |",
         "|" + "|".join(["---"] * len(head)) + "|"]
for r in rows:
    ev = "/".join(sorted({str(n) for n in r["nevts"]})) if r["nevts"] else "-"
    cells = [f"{r['cfg']} {r['tag']}", str(r["nchunks"]), ev]
    for a, _ in ALGOS:
        cells.append(cell(*stat(r["per_algo"][a])))
    cells.append(cell(*stat(r["totals"])))
    lines.append("| " + " | ".join(cells) + " |")

table = "\n".join(lines)
missing = [f"{r['cfg']}_{r['tag']} ({r['nchunks']}/10)" for r in rows if r["nchunks"] != 10]
note = ""
if missing:
    note = "\n\n> Incomplete configs (chunks found): " + ", ".join(missing)

print(f"# Chrono CPU summary  ({SCANDIR})\n")
print("Per-event CPU, averaged over the ten 100-event chunks (mean +/- chunk-to-chunk std).\n")
print(table + note)

if MDOUT:
    with open(MDOUT, "w") as fh:
        fh.write(f"# Chrono CPU summary\n\n`{SCANDIR}`\n\n"
                 "Per-event CPU, averaged over the ten 100-event chunks "
                 "(mean ± chunk-to-chunk std).\n\n" + table + note + "\n")
    print(f"\n[wrote {MDOUT}]")
