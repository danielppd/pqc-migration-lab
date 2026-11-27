# E2: tempo de CPU do handshake TLS 1.3

Mede o custo de **CPU** do handshake completo para cada grupo de troca de chaves:
`x25519` (base), `MLKEM768`, `X25519MLKEM768` e `SecP256r1MLKEM768`.

Variável independente: o grupo. Variável dependente: tempo do handshake. Linha de
base: `x25519`. Hipótese testada: [H2](../../docs/content/docs/artigo/pergunta-e-hipoteses.mdx).

## Decisão de método

O `e2-cpu.mdx` alerta: **não medir repetindo `openssl s_client` num loop**, porque
o custo de abrir um processo (ms) esconde a diferença de µs entre os grupos, e
`openssl s_time` não deixa escolher o grupo.

O harness contorna isso de dois jeitos:

1. **Mesmo processo.** Cliente e servidor são dois objetos `SSL` no mesmo processo;
   cada handshake só paga a computação, não `fork`/`exec`.
2. **BIO em memória, sem TCP.** Os dois lados trocam bytes por um par de `BIO_s_mem`,
   não por socket. Sem syscalls de rede nem agendamento de kernel entre as mensagens.
   Assim o tempo medido é o custo de CPU do handshake, que é o que a H2 pergunta.

A autenticação é mantida **clássica** (certificado ECDSA P-256, igual ao E1), para
isolar a troca de chaves.

## Requisitos

- OpenSSL **3.5 ou superior** (aqui 3.6 do Homebrew; o `openssl` de fábrica do macOS
  é LibreSSL e não serve). Headers e libs em `/opt/homebrew/opt/openssl@3.6`.
- Compilador C (clang da Apple serve) e Python 3 (só biblioteca padrão) para a análise.

## Como rodar

```bash
cd experiments/e2-cpu
make                       # compila o harness
make piloto                # piloto curto (50 reps/grupo), so para ver funcionar

# piloto registrado (200 reps/grupo) e analise:
./harness -n 200 > resultados/e2-piloto.csv
python3 analise.py resultados/e2-piloto.csv
```

Se o OpenSSL estiver em outro caminho: `make OPENSSL_PREFIX=/caminho`.

## Saída

- `harness` imprime CSV cru: `grupo,repeticao,nanos`, um handshake por linha. A
  cada rodada, a ordem dos grupos é embaralhada (Fisher-Yates, semente fixa
  `-seed`, default 42) e mede-se um handshake de cada grupo.
- `analise.py` descarta o aquecimento, reporta **mediana** e **IC 95% por bootstrap**
  por grupo, e confronta a diferença de medianas com o limiar de **1 ms** da H2.

## Resultado do piloto (200 rodadas, ordem aleatorizada, macOS arm64)

| Grupo | Mediana (ms) | IC 95% (ms) | Δ vs x25519 (ms) |
|-------|--------------|-------------|------------------|
| x25519 | 0,202 | 0,202–0,204 | — |
| MLKEM768 | 0,207 | 0,206–0,208 | +0,005 |
| X25519MLKEM768 | 0,277 | 0,276–0,278 | **+0,075** |
| SecP256r1MLKEM768 | 0,285 | 0,285–0,287 | +0,083 |

O híbrido X25519MLKEM768 adiciona cerca de **+0,075 ms** de CPU sobre a base, uma
ordem de grandeza abaixo do limiar de 1 ms: o piloto **sustenta a H2**. A diferença
entre grupos é de dezenas de microssegundos, muito abaixo de qualquer RTT realista.

## O que ainda falta (não é a rodada final)

Este é o **piloto** que o cronograma da semana 2 pede. A rodada final precisa, pelo
`e2-cpu.mdx`:

- repetir em **Linux**, onde dá para fixar frequência/turbo e isolar um núcleo
  (no macOS não dá — limitação já declarada em [riscos](../../docs/content/docs/artigo/riscos.mdx));
- validação cruzada em **Go `crypto/tls`** (2 das 4 condições) como robustez de stack.
