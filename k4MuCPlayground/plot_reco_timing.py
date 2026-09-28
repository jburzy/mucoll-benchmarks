#!/usr/bin/env python3
"""Plot per-event reconstruction CPU time vs the seed-level time cut.

Parses the ASCII Chrono tables written by the timing benchmark job
(submit_reco_timing.sh -> ChronoStatSvc.AsciiStatsOutputFile), one file per cut:

    <bench-dir>/chrono_<TAG>.txt      TAG in {noCut, t0p10, t0p15, t0p20, t0p25}

Each file is an INI-like dump with one section per (algorithm, phase), e.g.

    [Reconstructor:Execute]
    cpu_user_total = 1.53660000e+08     # microseconds, summed over all events
    cpu_user_mean  = 1.53660000e+08     # microseconds, per Execute call == per event
    cpu_user_RMS   = 0.00000000e+00
    cpu_user_nbr   = 20                 # number of Execute calls == n events

For each cut we take cpu_<metric>_mean (already per-event) of the requested
algorithm section(s), convert us -> s, and plot it against the numeric cut value.
"noCut" has no numeric cut, so it is drawn as a horizontal reference line.

Only the reco (Reconstructor / CKF) Execute time is plotted.

Usage:
    python3 plot_reco_timing.py                         # defaults below
    python3 plot_reco_timing.py --bench-dir /path/timing_bench --out timing.png
    python3 plot_reco_timing.py --metric cpu_real       # wall time instead of user CPU
"""
import argparse
import os
import sys

import matplotlib
matplotlib.use("Agg")            # headless (no X on the compute/login nodes)
import matplotlib.pyplot as plt
import numpy as np

# TAG -> numeric seed-time cut in ns. None marks the "no cut" reference run.
CUTS = [
    ("noCut", None),
    ("t0p10", 0.10),
    ("t0p15", 0.15),
    ("t0p20", 0.20),
    ("t0p25", 0.25),
]

US_TO_S = 1.0e-6                 # Chrono values are microseconds


def parse_chrono(path):
    """Parse one ASCII Chrono file into {section: {key: float}}."""
    sections = {}
    cur = None
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            if line.startswith("[") and line.endswith("]"):
                cur = line[1:-1]
                sections[cur] = {}
            elif "=" in line and cur is not None:
                key, _, val = line.partition("=")
                try:
                    sections[cur][key.strip()] = float(val.strip())
                except ValueError:
                    pass          # non-numeric field, ignore
    return sections


def per_event(sections, section, metric):
    """Return (mean, stderr) per-event time in seconds for one section.

    mean  = cpu_<metric>_mean            (already per Execute call)
    stderr= cpu_<metric>_RMS / sqrt(N)   (uncertainty on the mean)
    Missing section/fields -> (nan, 0).
    """
    d = sections.get(section)
    if not d:
        return float("nan"), 0.0
    mean = d.get(metric + "_mean", float("nan")) * US_TO_S
    rms = d.get(metric + "_RMS", 0.0) * US_TO_S
    n = d.get(metric + "_nbr", 0.0)
    stderr = rms / np.sqrt(n) if n > 0 else 0.0
    return mean, stderr


def main():
    default_bench = "/global/cfs/cdirs/m5197/jburzyns/4DTrackingStudy/timing_bench"
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bench-dir", default=default_bench,
                    help="directory holding chrono_<TAG>.txt (default: %(default)s)")
    ap.add_argument("--out", default="reco_timing_vs_cut.png",
                    help="output image path (default: %(default)s)")
    ap.add_argument("--metric", default="cpu_user",
                    choices=["cpu_user", "cpu_system", "cpu_real"],
                    help="which Chrono metric to plot (default: %(default)s)")
    args = ap.parse_args()

    SECTION = "Reconstructor:Execute"   # the reco (CKF) algorithm -- the only thing plotted

    # Load every available cut file.
    data = {}   # tag -> parsed sections
    for tag, _cut in CUTS:
        path = os.path.join(args.bench_dir, "chrono_%s.txt" % tag)
        if os.path.exists(path):
            data[tag] = parse_chrono(path)
        else:
            print("WARNING: missing %s -- skipping this cut" % path, file=sys.stderr)

    if not data:
        sys.exit("ERROR: no chrono_<TAG>.txt files found in %s" % args.bench_dir)

    numeric = [(tag, cut) for tag, cut in CUTS if cut is not None and tag in data]
    xs = np.array([cut for _tag, cut in numeric])

    ys = np.array([per_event(data[tag], SECTION, args.metric)[0] for tag, _c in numeric])
    es = np.array([per_event(data[tag], SECTION, args.metric)[1] for tag, _c in numeric])

    fig, ax = plt.subplots(figsize=(7.0, 5.0))
    ax.errorbar(xs, ys, yerr=es, marker="o", capsize=3, color="C0",
                label="reco (Reconstructor)")

    # noCut reference line
    if "noCut" in data:
        y0, _ = per_event(data["noCut"], SECTION, args.metric)
        if np.isfinite(y0):
            ax.axhline(y0, color="C0", ls="--", lw=1.2, alpha=0.7,
                       label="reco, no cut")

    ax.set_xlabel("Seed hit-pair max |Δt| cut  [ns]")
    ax.set_ylabel("Reco CPU time per event  [s]   (%s)" % args.metric)
    ax.set_title("Reconstruction CPU time vs seed time cut  (20-event benchmark)")
    ax.grid(True, alpha=0.3)
    ax.legend(loc="best")
    fig.tight_layout()
    fig.savefig(args.out, dpi=150)
    print("Wrote %s" % args.out)

    # Also echo the parsed numbers so they're usable without opening the plot.
    v0 = per_event(data["noCut"], SECTION, args.metric)[0] if "noCut" in data else float("nan")
    print("\n%-14s %10s %s" % ("series", "noCut[s]",
                               "  ".join("%.2f[s]" % c for _t, c in numeric)))
    print("%-14s %10.3f %s" % ("reco", v0,
                               "  ".join("%7.3f" % v for v in ys)))


if __name__ == "__main__":
    main()
