#!/usr/bin/env bash
# Aplica (ou limpa) condicoes de rede na interface do container com tc netem.
# Precisa de NET_ADMIN (concedido no docker-compose.yml).
#
# Uso:
#   netem.sh IFACE RTT_MS PERDA_PCT MTU     aplica
#   netem.sh IFACE clear                    remove netem e volta MTU 1500
#
# RTT e aplicado como metade do delay em CADA ponta (servidor e cliente),
# para que o RTT total seja RTT_MS. Quem chama aplica o mesmo delay nos dois.
# Aqui, por simplicidade, cada container recebe delay = RTT_MS/2.

set -euo pipefail

IFACE="${1:?uso: netem.sh IFACE RTT_MS PERDA_PCT MTU | IFACE clear}"

# Sempre parte do zero: remove qualquer qdisc netem previo (ignora se nao havia).
tc qdisc del dev "$IFACE" root 2>/dev/null || true

if [ "${2:-}" = "clear" ]; then
  ip link set dev "$IFACE" mtu 1500
  echo "netem limpo em $IFACE, MTU 1500"
  exit 0
fi

RTT_MS="${2:?faltou RTT_MS}"
PERDA_PCT="${3:?faltou PERDA_PCT}"
MTU="${4:?faltou MTU}"

# IMPORTANTE (Docker Desktop no macOS): a rede do container e virtualizada e o
# checksum e calculado por offload, tarde. O netem atrasa/reordena pacotes com
# o checksum ainda nao preenchido, e o par os DESCARTA: o handshake nunca
# completa (trava em "Connecting to"). Desligar o offload de checksum/segmentacao
# resolve. Sem isto, nenhuma condicao com delay funciona. Ver README (limitacao).
if command -v ethtool >/dev/null 2>&1; then
  for off in tx rx tso gso gro; do ethtool -K "$IFACE" "$off" off >/dev/null 2>&1 || true; done
fi

# Metade do RTT em cada ponta.
DELAY_MS=$(awk "BEGIN { printf \"%.3f\", $RTT_MS / 2 }")

tc qdisc add dev "$IFACE" root netem \
   delay "${DELAY_MS}ms" \
   loss "${PERDA_PCT}%"

ip link set dev "$IFACE" mtu "$MTU"

echo "netem em $IFACE: delay ${DELAY_MS}ms (RTT total ${RTT_MS}ms), perda ${PERDA_PCT}%, MTU ${MTU}"
tc qdisc show dev "$IFACE"
