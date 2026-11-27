# Imagem do E3: servidor e cliente usam a MESMA imagem.
# Debian trixie traz OpenSSL 3.5.9 (>= 3.5), que conhece X25519MLKEM768.
# Escolhido um release estavel (nao alpine:edge) para reprodutibilidade.
FROM debian:trixie-slim

# openssl: handshake TLS 1.3 com os grupos pos-quanticos
# iproute2: tc/netem para emular RTT, perda e MTU
# tcpdump:  contar segmentos TCP do handshake
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openssl iproute2 tcpdump ethtool iputils-ping ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Scripts montados em runtime via volume (ver docker-compose.yml); nada a copiar.
WORKDIR /e3
CMD ["sleep", "infinity"]
