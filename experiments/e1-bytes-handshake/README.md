# E1: bytes do handshake TLS 1.3

Mede o tamanho das mensagens de handshake para troca de chaves clássica (X25519) e pós-quântica/híbrida (ML-KEM).

Requer OpenSSL 3.5 ou superior. O macOS traz de fábrica um `openssl` em `/usr/bin/openssl` que é LibreSSL e não serve, porque não conhece ML-KEM. O script usa por padrão o OpenSSL instalado pelo Homebrew, em `/opt/homebrew/opt/openssl@3.6/bin/openssl`.

```bash
brew install openssl@3
./experimento-exploratorio.sh
```

O certificado (ECDSA P-256) é gerado uma única vez em `cert/` e reusado em toda
execução, para que a única variável entre condições seja o grupo de troca de
chaves. Com certificado fixo, ClientHello e ServerHello repetem byte a byte; o
total do servidor ainda oscila 1 a 2 bytes por causa do CertificateVerify (a
assinatura ECDSA do transcript tem tamanho DER variável, 78 a 80 bytes).

Se o OpenSSL novo estiver em outro caminho, use `OPENSSL=/caminho/openssl ./experimento-exploratorio.sh`.

## Validação cruzada com oqs-provider

O experimento principal usa a implementação **nativa** de ML-KEM do OpenSSL 3.6.
Para checar que os bytes não são artefato dessa implementação, o script
`validacao-cruzada-oqs.sh` repete a medição forçando o OpenSSL a usar o
**liboqs** via `oqs-provider`, carregado sob demanda (não altera a instalação de
referência). O `.dylib` do provider e o liboqs ficam em `oqs/lib/`, autocontidos.

```bash
./validacao-cruzada-oqs.sh
```

### Resultado: o key share bate, o resto é explicável

Comparando as extensões do ClientHello (grupo MLKEM768):

| Extensão | Nativo | oqs-provider |
|----------|--------|--------------|
| `key_share` | 1190 B | **1190 B** (igual) |
| `signature_algorithms` | 42 B | 192 B (+150) |

O **`key_share` é idêntico** nas duas implementações, e o ServerHello também
(1178/1210/1243 B nos três grupos). É o custo real da troca de chaves, o que a
[H1](../../docs/content/docs/artigo/pergunta-e-hipoteses.mdx) mede: **não é
artefato do OpenSSL nativo**.

A diferença de +150 B no ClientHello está **toda** na extensão
`signature_algorithms`: ao carregar, o oqs-provider anuncia assinaturas PQC
extras (ML-DSA etc.). Isso nada tem a ver com a troca de chaves e, aliás,
reforça a H1 (o custo vem do key share, não do resto). É o mesmo tipo de achado
dos "6 bytes" do experimento nativo: observar o tráfego real corrige a conta.

### Como o oqs-provider foi compilado

Não há fórmula no Homebrew. Foi compilado do fonte (oqs-provider `main`, ligado a
um liboqs do mesmo stream), contra o OpenSSL 3.6 do Homebrew. O `list -tls-groups`
do OpenSSL 3.6 falha com o provider ("Memory allocation"), mas o **handshake real
negocia os grupos normalmente**, que é o que a medição usa. Os binários em
`oqs/lib/` usam `@loader_path` no rpath, então rodam sem depender de onde foram
compilados.

