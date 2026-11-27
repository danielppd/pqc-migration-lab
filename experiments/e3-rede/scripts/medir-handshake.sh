#!/usr/bin/env bash
# Roda DENTRO do container cliente. Para um grupo e um numero de repeticoes:
#   - para cada repeticao, cronometra um handshake TLS 1.3 completo contra o
#     servidor e conta os segmentos TCP capturados por tcpdump nessa janela;
#   - imprime CSV: grupo,repeticao,ms,segmentos_tcp.
#
# O netem ja deve ter sido aplicado nos dois containers antes de chamar isto.
#
# Uso: medir-handshake.sh SERVIDOR_IP PORT GRUPO REPS IFACE

set -euo pipefail

SRV_IP="${1:?servidor ip}"
PORT="${2:?port}"
GRUPO="${3:?grupo}"
REPS="${4:?reps}"
IFACE="${5:?iface}"
RTT_HINT_MS="${6:-20}"  # dimensiona a janela do tcpdump (RTT alto -> janela maior)

for ((i = 0; i < REPS; i++)); do
  SEGFILE="$(mktemp)"
  # tcpdump em modo linha (-l) conta os segmentos TCP da porta durante uma
  # janela fixa, e wc -l grava o total. Abordagem com pipe + timeout em vez de
  # "-w arquivo + kill" porque, em subshell nao interativo (docker exec -T), o
  # sinal de kill nao chegava a tempo de esvaziar o buffer e a contagem dava 0.
  JANELA=$(awk "BEGIN { printf \"%d\", 3 + ($RTT_HINT_MS + 0) / 20 }" 2>/dev/null || echo 4)
  ( timeout "${JANELA}" tcpdump -i "$IFACE" -n -l "tcp port $PORT" 2>/dev/null \
      | wc -l > "$SEGFILE" ) &
  CONTADOR_PID=$!
  sleep 0.4  # deixa o tcpdump comecar antes do handshake

  # Um handshake: -brief encerra ao fim do handshake, sem esperar corpo HTTP.
  INICIO=$(date +%s%N)
  timeout 20 openssl s_client -connect "$SRV_IP:$PORT" -tls1_3 \
    -groups "$GRUPO" -brief </dev/null >/dev/null 2>&1 || true
  FIM=$(date +%s%N)

  wait "$CONTADOR_PID" 2>/dev/null || true

  MS=$(awk "BEGIN { printf \"%.3f\", ($FIM - $INICIO) / 1000000 }")
  SEGS=$(tr -d ' ' < "$SEGFILE")
  rm -f "$SEGFILE"

  echo "$GRUPO,$i,$MS,${SEGS:-0}"
done
