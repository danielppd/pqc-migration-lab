#!/usr/bin/env python3
"""
Analise do E3 (latencia e segmentos sob rede emulada).

Le o CSV do run.sh (rtt_ms,perda_pct,mtu,grupo,repeticao,ms,segmentos_tcp) e,
por condicao (rtt, perda, mtu, grupo), reporta mediana do tempo (ms), mediana
de segmentos TCP e IC 95% do tempo por bootstrap.

Depois, para cada (rtt, perda, mtu), mostra o delta de mediana do hibrido
X25519MLKEM768 sobre a base x25519, que e o numero central da H3: o hibrido
adiciona RTT? So biblioteca padrao.

Uso: python3 analise.py resultados/e3-piloto.csv
"""

import argparse
import csv
import random
import statistics
from collections import OrderedDict, defaultdict

BASE = "x25519"
HIBRIDO = "X25519MLKEM768"


def ler(caminho):
    linhas = []
    with open(caminho, newline="") as f:
        for r in csv.DictReader(f):
            linhas.append({
                "rtt": int(r["rtt_ms"]), "perda": int(r["perda_pct"]),
                "mtu": int(r["mtu"]), "grupo": r["grupo"],
                "ms": float(r["ms"]), "segs": int(r["segmentos_tcp"]),
            })
    return linhas


def ic95(amostra, n_boot, rng):
    if len(amostra) < 2:
        return (amostra[0], amostra[0]) if amostra else (0.0, 0.0)
    meds = []
    n = len(amostra)
    for _ in range(n_boot):
        meds.append(statistics.median(amostra[rng.randrange(n)] for _ in range(n)))
    meds.sort()
    return meds[int(0.025 * n_boot)], meds[int(0.975 * n_boot)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--bootstrap", type=int, default=10000)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    linhas = ler(args.csv)

    # Agrupa por (rtt, perda, mtu, grupo).
    grupos = defaultdict(lambda: {"ms": [], "segs": []})
    for r in linhas:
        k = (r["rtt"], r["perda"], r["mtu"], r["grupo"])
        grupos[k]["ms"].append(r["ms"])
        grupos[k]["segs"].append(r["segs"])

    print("rtt_ms,perda_pct,mtu,grupo,n,ms_mediana,ms_ic95_lo,ms_ic95_hi,segs_mediana")
    med_por_cond = {}
    for k in sorted(grupos):
        ms = grupos[k]["ms"]
        segs = grupos[k]["segs"]
        m = statistics.median(ms)
        lo, hi = ic95(ms, args.bootstrap, rng)
        med_por_cond[k] = m
        print(f"{k[0]},{k[1]},{k[2]},{k[3]},{len(ms)},"
              f"{m:.3f},{lo:.3f},{hi:.3f},{statistics.median(segs):.1f}")

    # Delta hibrido vs base, por (rtt, perda, mtu).
    print(f"\n# H3: delta de mediana {HIBRIDO} - {BASE} (ms), por condicao")
    print("rtt_ms,perda_pct,mtu,delta_ms")
    condicoes = sorted({(k[0], k[1], k[2]) for k in grupos})
    for (rtt, perda, mtu) in condicoes:
        kb = (rtt, perda, mtu, BASE)
        kh = (rtt, perda, mtu, HIBRIDO)
        if kb in med_por_cond and kh in med_por_cond:
            d = med_por_cond[kh] - med_por_cond[kb]
            print(f"{rtt},{perda},{mtu},{d:+.3f}")


if __name__ == "__main__":
    main()
