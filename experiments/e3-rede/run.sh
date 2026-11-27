#!/usr/bin/env bash
# Orquestrador do E3, roda NO HOST (macOS). Sobe os containers, varre a matriz
# de condicoes de rede e grupos, aplica netem nas DUAS pontas e coleta o CSV.
#
# Matriz (ver e3-rede.mdx): RTT {20,100} x perda {0,1,3} x MTU {1500,1280}
# x grupo {x25519, X25519MLKEM768}. Por padrao mede so a base e o hibrido
# implantado (as 2 condicoes centrais); -g "..." troca a lista de grupos.
#
# Uso:
#   ./run.sh                 piloto: poucas reps, matriz reduzida
#   ./run.sh full            matriz completa, mais reps
#
# Pre-requisito: Docker Desktop rodando.

set -euo pipefail
cd "$(dirname "$0")"

MODO="${1:-piloto}"
SRV_IP="172.30.0.10"
CLI_IFACE="eth0"
SRV_IFACE="eth0"
PORT="4433"

if [ "$MODO" = "full" ]; then
  RTTS=(20 100); PERDAS=(0 1 3); MTUS=(1500 1280); REPS=30
  GRUPOS=(x25519 X25519MLKEM768 MLKEM768 SecP256r1MLKEM768)
else
  RTTS=(20); PERDAS=(0 1); MTUS=(1500 1280); REPS=3
  GRUPOS=(x25519 X25519MLKEM768)
fi

mkdir -p resultados
OUT="resultados/e3-${MODO}.csv"
echo "rtt_ms,perda_pct,mtu,grupo,repeticao,ms,segmentos_tcp" > "$OUT"

echo "== subindo containers =="
docker compose up -d --build

echo "== aguardando servidor TLS =="
docker compose exec -T servidor sh -c 'chmod +x scripts/*.sh' 2>/dev/null || true
docker compose exec -T cliente  sh -c 'chmod +x scripts/*.sh' 2>/dev/null || true
# servidor em background dentro do container
docker compose exec -d servidor sh -c "PORT=$PORT scripts/servidor.sh"
sleep 3

aplicar_netem() {
  local rtt="$1" perda="$2" mtu="$3"
  docker compose exec -T servidor scripts/netem.sh "$SRV_IFACE" "$rtt" "$perda" "$mtu" >/dev/null
  docker compose exec -T cliente  scripts/netem.sh "$CLI_IFACE" "$rtt" "$perda" "$mtu" >/dev/null
}

for rtt in "${RTTS[@]}"; do
  for perda in "${PERDAS[@]}"; do
    for mtu in "${MTUS[@]}"; do
      echo "== condicao: RTT=${rtt}ms perda=${perda}% MTU=${mtu} =="
      aplicar_netem "$rtt" "$perda" "$mtu"
      for grupo in "${GRUPOS[@]}"; do
        docker compose exec -T cliente \
          scripts/medir-handshake.sh "$SRV_IP" "$PORT" "$grupo" "$REPS" "$CLI_IFACE" "$rtt" \
          | while IFS= read -r linha; do
              echo "${rtt},${perda},${mtu},${linha}" >> "$OUT"
            done
      done
    done
  done
done

echo "== limpando netem =="
docker compose exec -T servidor scripts/netem.sh "$SRV_IFACE" clear >/dev/null || true
docker compose exec -T cliente  scripts/netem.sh "$CLI_IFACE" clear >/dev/null || true

echo "== pronto: $OUT =="
wc -l "$OUT"
