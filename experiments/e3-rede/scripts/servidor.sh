#!/usr/bin/env bash
# Sobe o servidor TLS 1.3 do E3, aceitando os 4 grupos do estudo.
# Gera um certificado ECDSA P-256 de teste (autenticacao classica, igual E1/E2).
# Fica em primeiro plano; o container o mantem vivo.

set -euo pipefail

PORT="${PORT:-4433}"
GRUPOS="x25519:MLKEM768:X25519MLKEM768:SecP256r1MLKEM768"
WORK="$(mktemp -d)"

echo "# servidor: $(openssl version)"

openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout "$WORK/k.pem" -out "$WORK/c.pem" -subj "/CN=localhost" -days 2 2>/dev/null

# -www responde algo trivial e encerra; util para o cliente fechar a conexao.
# -naccept 0 = aceita indefinidamente (muitas conexoes do cliente medidor).
exec openssl s_server -accept "$PORT" -cert "$WORK/c.pem" -key "$WORK/k.pem" \
  -tls1_3 -groups "$GRUPOS" -www -quiet
