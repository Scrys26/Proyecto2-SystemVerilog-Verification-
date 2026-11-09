#!/usr/bin/env python3
"""Resume una corrida de VCS/UVM en un archivo de texto pequeno.

Uso:
  digest.py run  --log sim.log --out results/<nombre>.md [--seed N] [--args f.args]
                 [--urg urgReport/dashboard.txt] [--max-errors 20] [--context 30]
  digest.py regr --logs 'work/*/sim.log' --out results/regr_summary.csv

Solo usa la libreria estandar. Los formatos de URG y de log pueden variar con la
version de VCS: si algun regex no encuentra nada, ajustarlo aqui (unico lugar).
"""
import argparse
import csv
import glob
import os
import re
import subprocess
import sys

# --- Patrones (SSOT de formatos: se ajustan solo aqui) -----------------------
RE_REPORT = re.compile(r"^(UVM_(?:ERROR|FATAL|WARNING))\b.*?@\s*(\d+)\s*:\s*(.*)$")
RE_COUNT = re.compile(r"^\s*(UVM_(?:ERROR|FATAL|WARNING))\s*:\s*(\d+)")
RE_KNOB = re.compile(r"\[KNOBS\]")
RE_COV = re.compile(
    r"^\s*(line|cond|condition|branch|fsm|tgl|toggle|assert|group|functional)\b.*?"
    r"(\d+(?:\.\d+)?)\s*%?\s*$", re.IGNORECASE)


def read_lines(path):
    with open(path, errors="replace") as f:
        return f.read().splitlines()


def git_hash():
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], text=True,
            stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "desconocido"


def parse_log(lines):
    counts = {"UVM_ERROR": None, "UVM_FATAL": None, "UVM_WARNING": None}
    events = []  # (idx, severidad, tiempo, texto)
    knobs = []
    for i, ln in enumerate(lines):
        m = RE_REPORT.match(ln)
        if m and m.group(1) in ("UVM_ERROR", "UVM_FATAL"):
            events.append((i, m.group(1), m.group(2), ln.strip()))
        if RE_KNOB.search(ln):
            knobs.append(ln.strip())
        c = RE_COUNT.match(ln)
        if c:
            counts[c.group(1)] = int(c.group(2))  # el ultimo gana (resumen final)
    # Si no hay resumen UVM, contar a mano
    for sev in counts:
        if counts[sev] is None:
            counts[sev] = sum(1 for ln in lines if ln.startswith(sev))
    return counts, events, knobs


def parse_urg(path):
    if not path or not os.path.exists(path):
        return None
    out = []
    for ln in read_lines(path):
        m = RE_COV.match(ln)
        if m:
            out.append(f"{m.group(1)}: {m.group(2)} %")
    return out or ["(dashboard.txt sin lineas reconocidas: revisar RE_COV)"]


def cmd_run(a):
    lines = read_lines(a.log)
    counts, events, knobs = parse_log(lines)
    status = "PASS" if counts["UVM_ERROR"] == 0 and counts["UVM_FATAL"] == 0 else "FAIL"
    if not any(l.startswith("--- UVM Report Summary") or "UVM Report Summary" in l
               for l in lines):
        status = "INCOMPLETA (sin UVM Report Summary: posible cuelgue o abort)"

    o = []
    o.append(f"# Resumen de corrida: {status}")
    o.append(f"- commit: {git_hash()}")
    o.append(f"- semilla: {a.seed or 'no indicada'}")
    o.append(f"- args: {a.args or 'ninguno'}")
    o.append(f"- log: {os.path.basename(a.log)} ({len(lines)} lineas)")
    o.append(f"- UVM_ERROR={counts['UVM_ERROR']} UVM_FATAL={counts['UVM_FATAL']} "
             f"UVM_WARNING={counts['UVM_WARNING']}")
    o.append("\n## Knobs (E7)")
    o.extend(knobs if knobs else ["(no se encontro traza [KNOBS])"])

    o.append(f"\n## Primeros {a.max_errors} errores")
    if not events:
        o.append("(ninguno)")
    for _, sev, t, txt in events[:a.max_errors]:
        o.append(f"- t={t} {txt[:300]}")

    if events:
        i0 = events[0][0]
        lo, hi = max(0, i0 - a.context), min(len(lines), i0 + a.context + 1)
        o.append(f"\n## Contexto de la primera falla (lineas {lo+1}-{hi})")
        o.append("```")
        o.extend(l[:300] for l in lines[lo:hi])
        o.append("```")

    cov = parse_urg(a.urg)
    o.append("\n## Cobertura (URG)")
    o.extend(cov if cov else ["(sin dashboard.txt)"])

    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    with open(a.out, "w") as f:
        f.write("\n".join(o) + "\n")
    print(f"[digest] {status} -> {a.out}")
    return 0 if status == "PASS" else 1


def cmd_regr(a):
    rows = []
    for p in sorted(glob.glob(a.logs)):
        counts, _, _ = parse_log(read_lines(p))
        ok = counts["UVM_ERROR"] == 0 and counts["UVM_FATAL"] == 0
        rows.append([os.path.basename(os.path.dirname(p)) or p,
                     "PASS" if ok else "FAIL",
                     counts["UVM_ERROR"], counts["UVM_FATAL"], counts["UVM_WARNING"]])
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    with open(a.out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["corrida", "estado", "errors", "fatals", "warnings"])
        w.writerows(rows)
    fails = [r[0] for r in rows if r[1] == "FAIL"]
    print(f"[digest] {len(rows)} corridas, {len(fails)} fallidas -> {a.out}")
    if fails:
        print("[digest] fallidas:", ", ".join(fails[:20]))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--log", required=True)
    r.add_argument("--out", required=True)
    r.add_argument("--seed")
    r.add_argument("--args")
    r.add_argument("--urg")
    r.add_argument("--max-errors", type=int, default=20)
    r.add_argument("--context", type=int, default=30)
    g = sub.add_parser("regr")
    g.add_argument("--logs", required=True)
    g.add_argument("--out", required=True)
    a = ap.parse_args()
    return cmd_run(a) if a.cmd == "run" else cmd_regr(a)


if __name__ == "__main__":
    sys.exit(main())
