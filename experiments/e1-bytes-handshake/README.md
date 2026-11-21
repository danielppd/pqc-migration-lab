# E1: bytes do handshake TLS 1.3

Mede o tamanho das mensagens de handshake para troca de chaves clássica (X25519) e pós-quântica/híbrida (ML-KEM).

Requer OpenSSL 3.5 ou superior. O macOS traz de fábrica um `openssl` em `/usr/bin/openssl` que é LibreSSL e não serve, porque não conhece ML-KEM. O script usa por padrão o OpenSSL instalado pelo Homebrew, em `/opt/homebrew/opt/openssl@3.6/bin/openssl`.

```bash
brew install openssl@3
./experimento-exploratorio.sh
```

Se o OpenSSL novo estiver em outro caminho, use `OPENSSL=/caminho/openssl ./experimento-exploratorio.sh`.
