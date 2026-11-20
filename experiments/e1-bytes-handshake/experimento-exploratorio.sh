#!/usr/bin/env bash
# Experimento exploratorio 1: tamanho das mensagens de handshake TLS 1.3
# para troca de chaves classica (X25519) vs pos-quantica/hibrida (ML-KEM).
#
# O que faz: sobe um servidor TLS local, conecta com cada grupo de troca de chaves
# e soma os bytes das mensagens de handshake em cada direcao.
# Requer OpenSSL >= 3.5 (o openssl do macOS e LibreSSL e NAO serve).
#   brew install openssl@3   (ou use /opt/homebrew/opt/openssl@3.6/bin/openssl)

set -euo pipefail

OPENSSL="${OPENSSL:-/opt/homebrew/opt/openssl@3.6/bin/openssl}"
PORT=14433
GROUPS_TESTADOS="X25519 MLKEM768 X25519MLKEM768 SecP256r1MLKEM768"
WORK="$(mktemp -d)"
trap 'kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$WORK"' EXIT

echo "# $("$OPENSSL" version)"

# Certificado autoassinado so para o teste (ECDSA P-256, ou seja, autenticacao CLASSICA).
"$OPENSSL" req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout "$WORK/k.pem" -out "$WORK/c.pem" -subj "/CN=localhost" -days 2 2>/dev/null

# Servidor aceita todos os grupos testados.
"$OPENSSL" s_server -accept "$PORT" -cert "$WORK/c.pem" -key "$WORK/k.pem" -tls1_3 \
  -groups "$(echo "$GROUPS_TESTADOS" | tr ' ' ':')" -www -quiet >/dev/null 2>&1 &
SERVER_PID=$!
disown "$SERVER_PID"   # evita a mensagem "Terminated" quando o trap encerrar o servidor
sleep 1

echo "grupo,client_hello_B,server_hello_B,bytes_cliente_total,bytes_servidor_total"
for G in $GROUPS_TESTADOS; do
  # -msg imprime cada mensagem de handshake com seu tamanho em hexadecimal.
  # '>>>' = enviado pelo cliente, '<<<' = recebido do servidor.
  SAIDA="$(echo | "$OPENSSL" s_client -connect "localhost:$PORT" -tls1_3 -groups "$G" -msg 2>&1)"

  echo "$SAIDA" | awk -v g="$G" '
    /^>>> TLS 1.3, Handshake \[length/ { n = hex($6); cli += n; if ($0 ~ /ClientHello/) ch = n }
    /^<<< TLS 1.3, Handshake \[length/ { n = hex($6); srv += n; if ($0 ~ /ServerHello/) sh = n }
    function hex(s,   i, c, v) { gsub(/[^0-9a-fA-F]/, "", s); v = 0
      for (i = 1; i <= length(s); i++) { c = index("0123456789abcdef", tolower(substr(s, i, 1))) - 1; v = v * 16 + c }
      return v }
    END { printf "%s,%d,%d,%d,%d\n", g, ch, sh, cli, srv }'
done
