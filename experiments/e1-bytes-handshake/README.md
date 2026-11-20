# E1: bytes do handshake TLS 1.3

Mede o tamanho das mensagens de handshake para troca de chaves clássica (X25519) e pós-quântica/híbrida (ML-KEM).

Requer OpenSSL 3.5 ou superior. O `openssl` do macOS é LibreSSL e não serve.

```bash
brew install openssl@3
./experimento-exploratorio.sh
```

Se o OpenSSL novo estiver em outro caminho, use `OPENSSL=/caminho/openssl ./experimento-exploratorio.sh`.
