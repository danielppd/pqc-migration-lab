# E3: latência e segmentos sob rede emulada

Mede tempo de handshake TLS 1.3 e número de segmentos TCP para cada grupo de
troca de chaves, variando **RTT, perda de pacotes e MTU** com `tc netem`. Testa
a hipótese [H3](../../docs/content/docs/artigo/pergunta-e-hipoteses.mdx): sem perda
o híbrido não adiciona RTT, e a penalidade só aparece com perda ou MTU reduzida.

## Arquitetura

Dois containers Docker (`e3-servidor`, `e3-cliente`) numa rede bridge dedicada
(`172.30.0.0/24`), ambos com **OpenSSL 3.5.9** (Debian trixie; conhece
X25519MLKEM768). O netem é aplicado **nas duas pontas** em runtime (precisa de
`NET_ADMIN`). O cliente cronometra o handshake e conta segmentos TCP com tcpdump.

```
run.sh (host)
  ├─ docker compose up           sobe os dois containers
  ├─ servidor.sh                 openssl s_server, 4 grupos, cert ECDSA P-256
  ├─ netem.sh IFACE rtt perda mtu   aplica em servidor e cliente
  └─ medir-handshake.sh          por repeticao: cronometra + conta segmentos
```

## Requisitos

- **Docker Desktop rodando** (no macOS o daemon vive numa VM LinuxKit).
- Nada mais no host: toda a medição acontece dentro dos containers.

## Como rodar

```bash
cd experiments/e3-rede
./run.sh            # piloto: RTT 20ms, perda {0,1}%, MTU {1500,1280}, 3 reps, 2 grupos
./run.sh full       # matriz completa: RTT {20,100}, perda {0,1,3}, MTU {1500,1280}, 30 reps, 4 grupos
python3 analise.py resultados/e3-piloto.csv
```

## Duas descobertas de método (plataforma macOS)

<!-- Estas duas valem para o texto do artigo: medir em rede virtualizada tem
     armadilhas que mudam o resultado se ignoradas. -->

1. **Offload de checksum quebra o netem.** Na rede virtualizada do Docker Desktop,
   o checksum TCP é calculado por offload, tarde. O netem atrasa/reordena pacotes
   com o checksum ainda não preenchido, o par os descarta e o handshake **nunca
   completa** (trava em "Connecting to"). `netem.sh` desliga o offload com
   `ethtool -K eth0 {tx,rx,tso,gso,gro} off` antes de aplicar o netem. Sem isso,
   nenhuma condição com delay funciona.

2. **Contar segmentos com tcpdump em subshell não interativo.** `tcpdump -w arquivo`
   em background + `kill` não esvaziava o buffer a tempo dentro de `docker exec -T`,
   e a contagem dava zero. A versão que funciona conta linhas numa janela de tempo:
   `timeout N tcpdump -l "tcp port 4433" | wc -l`.

## Resultado do piloto (RTT 20ms, 3 reps)

Segmentos TCP (mediana), que é o mecanismo central da H3:

| MTU | x25519 | X25519MLKEM768 |
|-----|--------|----------------|
| 1500 | 16 | **18** |
| 1280 | 16 | **20** |

O híbrido usa mais segmentos (ClientHello de ~1,4 KB), e com **MTU 1280** sobe
para 20: o ClientHello passa a ocupar mais de um segmento, como o `e3-rede.mdx`
previu. Com 0% de perda e MTU 1500 os tempos de híbrido e base são
indistinguíveis dentro do IC, consistente com a H3.

## O que ainda falta (não é a rodada final)

- Rodar `./run.sh full` (30 reps, 4 grupos, RTT 20 e 100, perda 0/1/3) para os
  números finais com IC estreito.
- **Aleatorizar a ordem** das condições (hoje a matriz roda em ordem fixa).
- O relógio é do `s_client` (inclui setup de processo). Para isolar só o
  handshake de rede, a opção é instrumentar com o harness do E2 sobre socket real.
