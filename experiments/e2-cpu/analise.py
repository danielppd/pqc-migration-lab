#!/usr/bin/env python3
"""
Analise estatistica do E2 (tempo de CPU do handshake).

Le o CSV cru do harness (grupo,repeticao,nanos) e, por grupo:
  - descarta as primeiras repeticoes (aquecimento);
  - reporta mediana;
  - reporta IC 95% da mediana por bootstrap de percentil.

Depois compara cada grupo pos-quantico/hibrido com a linha de base x25519
e confronta a diferenca de medianas com o limiar de 1 ms da hipotese H2.

So usa a biblioteca padrao (statistics, random, csv) de proposito: o harness
nao exige dependencias e a analise tambem nao, para o "um comando que regenera
tudo" da semana 5 permanecer simples.

Uso:
    python3 analise.py resultados/e2-piloto.csv
    python3 analise.py resultados/e2-piloto.csv --aquecimento 20 --bootstrap 10000
"""

import argparse
import csv
import random
import statistics
import sys
from collections import OrderedDict

BASE = "x25519"
LIMIAR_H2_MS = 1.0  # H2: diferenca de mediana abaixo de 1 ms em loopback


def ler(caminho):
    """Retorna OrderedDict grupo -> lista de nanos, preservando a ordem de 1a aparicao."""
    dados = OrderedDict()
    with open(caminho, newline="") as f:
        for linha in csv.DictReader(f):
            dados.setdefault(linha["grupo"], []).append(int(linha["nanos"]))
    return dados


def ic95_mediana_bootstrap(amostra, n_boot, rng):
    """IC 95% da mediana por bootstrap de percentil."""
    medianas = []
    n = len(amostra)
    for _ in range(n_boot):
        reamostra = [amostra[rng.randrange(n)] for _ in range(n)]
        medianas.append(statistics.median(reamostra))
    medianas.sort()
    lo = medianas[int(0.025 * n_boot)]
    hi = medianas[int(0.975 * n_boot)]
    return lo, hi


def ns_para_ms(x):
    return x / 1_000_000.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--aquecimento", type=int, default=20,
                    help="repeticoes iniciais descartadas por grupo (default 20)")
    ap.add_argument("--bootstrap", type=int, default=10000,
                    help="reamostragens do bootstrap (default 10000)")
    ap.add_argument("--seed", type=int, default=42,
                    help="semente do bootstrap, para reprodutibilidade")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    dados = ler(args.csv)

    if BASE not in dados:
        sys.exit(f"grupo de base '{BASE}' ausente no CSV")

    resumo = OrderedDict()
    print(f"# aquecimento descartado por grupo: {args.aquecimento} repeticoes")
    print(f"# bootstrap: {args.bootstrap} reamostragens, seed {args.seed}\n")
    print("grupo,n,mediana_ms,ic95_lo_ms,ic95_hi_ms")

    for grupo, amostra in dados.items():
        util = amostra[args.aquecimento:]
        if len(util) < 10:
            sys.exit(f"grupo '{grupo}': poucas repeticoes apos o aquecimento "
                     f"({len(util)}). Rode mais reps ou reduza --aquecimento.")
        med = statistics.median(util)
        lo, hi = ic95_mediana_bootstrap(util, args.bootstrap, rng)
        resumo[grupo] = (len(util), med, lo, hi)
        print(f"{grupo},{len(util)},{ns_para_ms(med):.4f},"
              f"{ns_para_ms(lo):.4f},{ns_para_ms(hi):.4f}")

    base_med = resumo[BASE][1]
    print(f"\n# H2: diferenca de mediana vs {BASE}, limiar {LIMIAR_H2_MS:.1f} ms")
    print("grupo,delta_mediana_ms,veredito_H2")
    for grupo, (_, med, _, _) in resumo.items():
        if grupo == BASE:
            continue
        delta_ms = ns_para_ms(med - base_med)
        veredito = "dentro (<1ms)" if abs(delta_ms) < LIMIAR_H2_MS else "REFUTA (>=1ms)"
        print(f"{grupo},{delta_ms:+.4f},{veredito}")


if __name__ == "__main__":
    main()
