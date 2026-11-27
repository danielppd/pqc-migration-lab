#!/usr/bin/env bash
# Validacao cruzada do E1: mede os mesmos bytes de handshake, mas forcando o
# OpenSSL a usar a implementacao do liboqs via oqs-provider, em vez da nativa.
#
# Objetivo: mostrar que o custo em bytes (ClientHello/ServerHello) e o MESMO
# nas duas implementacoes, logo nao e artefato do OpenSSL nativo. Fortalece H1.
#
# NAO altera a instalacao de referencia: o oqs-provider e carregado SOB DEMANDA
# por -provider na linha de comando. O .dylib e o liboqs ficam em oqs/lib/,
# autocontidos (rpath = @loader_path). O OpenSSL continua sendo o 3.6 do Homebrew.
#
# Uso: ./validacao-cruzada-oqs.sh

set -euo pipefail

OPENSSL="${OPENSSL:-/opt/homebrew/opt/openssl@3.6/bin/openssl}"
DIR="$(cd "$(dirname "$0")" && pwd)"
export OPENSSL_MODULES="$DIR/oqs/lib"
PROV=(-provider oqsprovider -provider default)
PORT=14455
# So os grupos pos-quanticos/hibridos: o x25519 classico nao passa pelo oqs-provider.
GRUPOS="MLKEM768 X25519MLKEM768 SecP256r1MLKEM768"
WORK="$(mktemp -d)"
trap 'kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$WORK"' EXIT

if [ ! -f "$DIR/oqs/lib/oqsprovider.dylib" ]; then
  echo "ERRO: oqs/lib/oqsprovider.dylib ausente. Veja o README (como compilar)." >&2
  exit 1
fi

echo "# $("$OPENSSL" version)"
echo "# oqs-provider: $(OPENSSL_MODULES="$DIR/oqs/lib" "$OPENSSL" list -providers "${PROV[@]}" 2>/dev/null | awk '/OQS Provider/{getline; print $2}')"

# Mesmo certificado FIXO do E1 (ECDSA P-256), reusado para nao introduzir
# variacao de bytes entre execucoes.
CERT_DIR="$DIR/cert"
if [ ! -f "$CERT_DIR/c.pem" ]; then
  mkdir -p "$CERT_DIR"
  "$OPENSSL" req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$CERT_DIR/k.pem" -out "$CERT_DIR/c.pem" -subj "/CN=localhost" -days 3650 2>/dev/null
fi

"$OPENSSL" s_server -accept "$PORT" -cert "$CERT_DIR/c.pem" -key "$CERT_DIR/k.pem" -tls1_3 \
  "${PROV[@]}" -groups "$(echo "$GRUPOS" | tr ' ' ':')" -www -quiet >/dev/null 2>&1 &
SERVER_PID=$!
disown "$SERVER_PID"
sleep 1

echo "grupo,client_hello_B,server_hello_B,bytes_cliente_total,bytes_servidor_total"
for G in $GRUPOS; do
  SAIDA="$(echo | "$OPENSSL" s_client -connect "localhost:$PORT" -tls1_3 \
            "${PROV[@]}" -groups "$G" -msg 2>&1)"

  echo "$SAIDA" | awk -v g="$G" '
    /^>>> TLS 1.3, Handshake \[length/ { n = hex($6); cli += n; if ($0 ~ /ClientHello/) ch = n }
    /^<<< TLS 1.3, Handshake \[length/ { n = hex($6); srv += n; if ($0 ~ /ServerHello/) sh = n }
    function hex(s,   i, c, v) { gsub(/[^0-9a-fA-F]/, "", s); v = 0
      for (i = 1; i <= length(s); i++) { c = index("0123456789abcdef", tolower(substr(s, i, 1))) - 1; v = v * 16 + c }
      return v }
    END { printf "%s,%d,%d,%d,%d\n", g, ch, sh, cli, srv }'
done
