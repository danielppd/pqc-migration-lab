/*
 * E2: tempo de CPU do handshake TLS 1.3 por grupo de troca de chaves.
 *
 * Mede o custo de COMPUTACAO do handshake, nao de rede. Cliente e servidor
 * rodam NO MESMO PROCESSO e trocam bytes por um par de BIO em memoria
 * (BIO_s_mem), sem socket TCP. Isso evita syscalls, loopback e agendamento
 * do kernel, que estao na escala de ms e esconderiam a diferenca de us entre
 * os grupos, que e justamente o que queremos medir (ver docs e2-cpu.mdx).
 *
 * Para cada grupo e cada repeticao: cria um SSL de cliente e um de servidor,
 * dirige o handshake ate concluir (SSL_do_handshake dos dois lados, bombeando
 * os BIO), cronometra com relogio monotonico de alta resolucao e imprime um
 * CSV em stdout: grupo,repeticao,nanos.
 *
 * A analise estatistica (descartar aquecimento, mediana, IC 95% por bootstrap)
 * fica no script analise.py, sobre este CSV. Aqui so se mede e se emite o dado
 * cru, um numero por handshake.
 *
 * Compilar: ver Makefile (precisa de OpenSSL >= 3.5, aqui 3.6 do Homebrew).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>

/* Condicoes do experimento, na mesma ordem e nomes do E1. */
static const char *GRUPOS[] = {
    "x25519",             /* linha de base classica */
    "MLKEM768",           /* pos-quantico puro */
    "X25519MLKEM768",     /* hibrido implantado (foco da pergunta) */
    "SecP256r1MLKEM768",  /* variacao hibrida */
};
static const int N_GRUPOS = sizeof(GRUPOS) / sizeof(GRUPOS[0]);

static void morrer(const char *msg) {
    fprintf(stderr, "ERRO: %s\n", msg);
    ERR_print_errors_fp(stderr);
    exit(1);
}

/*
 * Gera um certificado autoassinado ECDSA P-256 em memoria, igual ao E1:
 * a AUTENTICACAO permanece classica, so a troca de chaves varia. Assim o
 * custo medido isola a troca de chaves, nao mistura o custo da assinatura.
 */
static void gerar_cert_p256(EVP_PKEY **chave_out, X509 **cert_out) {
    EVP_PKEY *chave = EVP_EC_gen("P-256");
    if (!chave) morrer("EVP_EC_gen P-256");

    X509 *cert = X509_new();
    if (!cert) morrer("X509_new");

    X509_set_version(cert, 2); /* v3 */
    ASN1_INTEGER_set(X509_get_serialNumber(cert), 1);
    X509_gmtime_adj(X509_getm_notBefore(cert), 0);
    X509_gmtime_adj(X509_getm_notAfter(cert), 60L * 60 * 24 * 2); /* 2 dias */
    X509_set_pubkey(cert, chave);

    X509_NAME *nome = X509_get_subject_name(cert);
    X509_NAME_add_entry_by_txt(nome, "CN", MBSTRING_ASC,
                               (const unsigned char *)"localhost", -1, -1, 0);
    X509_set_issuer_name(cert, nome); /* autoassinado: issuer == subject */

    if (!X509_sign(cert, chave, EVP_sha256())) morrer("X509_sign");

    *chave_out = chave;
    *cert_out = cert;
}

/*
 * Dirige um handshake completo entre dois objetos SSL ligados por BIO de
 * memoria. Retorna 0 em sucesso. Bombeia os bytes de um lado para o outro
 * ate que ambos considerem o handshake concluido.
 */
static int handshake(SSL *cli, SSL *srv, BIO *cli_wbio, BIO *srv_wbio,
                     BIO *cli_rbio, BIO *srv_rbio) {
    char buf[8192];
    for (int passo = 0; passo < 64; passo++) {
        int rc_cli = SSL_do_handshake(cli);
        int rc_srv = SSL_do_handshake(srv);

        /* Erros reais (nao WANT_READ/WANT_WRITE) abortam. */
        if (rc_cli <= 0) {
            int e = SSL_get_error(cli, rc_cli);
            if (e != SSL_ERROR_WANT_READ && e != SSL_ERROR_WANT_WRITE) return -1;
        }
        if (rc_srv <= 0) {
            int e = SSL_get_error(srv, rc_srv);
            if (e != SSL_ERROR_WANT_READ && e != SSL_ERROR_WANT_WRITE) return -1;
        }

        /* Cliente -> servidor */
        int n = BIO_read(cli_wbio, buf, sizeof(buf));
        while (n > 0) {
            if (BIO_write(srv_rbio, buf, n) != n) return -1;
            n = BIO_read(cli_wbio, buf, sizeof(buf));
        }
        /* Servidor -> cliente */
        n = BIO_read(srv_wbio, buf, sizeof(buf));
        while (n > 0) {
            if (BIO_write(cli_rbio, buf, n) != n) return -1;
            n = BIO_read(srv_wbio, buf, sizeof(buf));
        }

        if (SSL_is_init_finished(cli) && SSL_is_init_finished(srv)) return 0;
    }
    return -1; /* nao convergiu */
}

/* Relogio monotonico de alta resolucao, em nanossegundos. */
static long long agora_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

/* Um handshake cronometrado para um grupo ja configurado nos contextos. */
static long long um_handshake(SSL_CTX *ctx_cli, SSL_CTX *ctx_srv) {
    SSL *srv = SSL_new(ctx_srv);
    SSL *cli = SSL_new(ctx_cli);
    if (!srv || !cli) morrer("SSL_new");

    SSL_set_accept_state(srv);
    SSL_set_connect_state(cli);

    BIO *cli_rbio = BIO_new(BIO_s_mem());
    BIO *cli_wbio = BIO_new(BIO_s_mem());
    BIO *srv_rbio = BIO_new(BIO_s_mem());
    BIO *srv_wbio = BIO_new(BIO_s_mem());
    if (!cli_rbio || !cli_wbio || !srv_rbio || !srv_wbio) morrer("BIO_new");

    SSL_set_bio(cli, cli_rbio, cli_wbio); /* SSL assume posse dos BIO */
    SSL_set_bio(srv, srv_rbio, srv_wbio);

    long long t0 = agora_ns();
    int ok = handshake(cli, srv, cli_wbio, srv_wbio, cli_rbio, srv_rbio);
    long long t1 = agora_ns();
    if (ok != 0) morrer("handshake falhou");

    SSL_free(cli);
    SSL_free(srv);
    return t1 - t0;
}

/* Cria e configura um par de contextos (cliente/servidor) para um grupo. */
static void criar_contextos(const char *grupo, EVP_PKEY *chave, X509 *cert,
                            SSL_CTX **out_cli, SSL_CTX **out_srv) {
    SSL_CTX *ctx_srv = SSL_CTX_new(TLS_server_method());
    SSL_CTX *ctx_cli = SSL_CTX_new(TLS_client_method());
    if (!ctx_srv || !ctx_cli) morrer("SSL_CTX_new");

    SSL_CTX_set_min_proto_version(ctx_srv, TLS1_3_VERSION);
    SSL_CTX_set_max_proto_version(ctx_srv, TLS1_3_VERSION);
    SSL_CTX_set_min_proto_version(ctx_cli, TLS1_3_VERSION);
    SSL_CTX_set_max_proto_version(ctx_cli, TLS1_3_VERSION);

    if (!SSL_CTX_set1_groups_list(ctx_srv, grupo))
        morrer("set1_groups_list (servidor): grupo nao suportado?");
    if (!SSL_CTX_set1_groups_list(ctx_cli, grupo))
        morrer("set1_groups_list (cliente): grupo nao suportado?");

    if (SSL_CTX_use_certificate(ctx_srv, cert) != 1) morrer("use_certificate");
    if (SSL_CTX_use_PrivateKey(ctx_srv, chave) != 1) morrer("use_PrivateKey");
    SSL_CTX_set_verify(ctx_cli, SSL_VERIFY_NONE, NULL);

    *out_cli = ctx_cli;
    *out_srv = ctx_srv;
}

int main(int argc, char **argv) {
    long reps = 1000;         /* rodadas; cada rodada faz 1 handshake por grupo */
    unsigned int seed = 42;   /* semente da aleatorizacao, para reprodutibilidade */
    for (int a = 1; a + 1 < argc; a += 2) {
        if (strcmp(argv[a], "-n") == 0) reps = strtol(argv[a + 1], NULL, 10);
        else if (strcmp(argv[a], "-seed") == 0) seed = (unsigned int)strtoul(argv[a + 1], NULL, 10);
    }
    if (reps <= 0) reps = 1000;
    srandom(seed);

    EVP_PKEY *chave = NULL;
    X509 *cert = NULL;
    gerar_cert_p256(&chave, &cert);

    /* Um par de contextos por grupo, criado uma vez. */
    SSL_CTX *ctx_cli[N_GRUPOS], *ctx_srv[N_GRUPOS];
    for (int g = 0; g < N_GRUPOS; g++)
        criar_contextos(GRUPOS[g], chave, cert, &ctx_cli[g], &ctx_srv[g]);

    printf("grupo,repeticao,nanos\n");

    /*
     * Ordem ALEATORIZADA e INTERCALADA: a cada rodada, embaralha-se a ordem dos
     * grupos e faz-se um handshake de cada. Assim nenhuma condicao ocupa sempre
     * o inicio (frio) nem o fim (quente) da execucao, e qualquer deriva termica
     * ou de frequencia da maquina se distribui por todos os grupos, em vez de
     * virar uma diferenca sistematica entre eles. O descarte de aquecimento e a
     * estatistica ficam na analise, sobre este CSV.
     */
    int ordem[N_GRUPOS];
    for (int g = 0; g < N_GRUPOS; g++) ordem[g] = g;

    for (long i = 0; i < reps; i++) {
        /* Fisher-Yates: embaralha a ordem dos grupos nesta rodada. */
        for (int k = N_GRUPOS - 1; k > 0; k--) {
            int j = (int)(random() % (k + 1));
            int tmp = ordem[k]; ordem[k] = ordem[j]; ordem[j] = tmp;
        }
        for (int p = 0; p < N_GRUPOS; p++) {
            int g = ordem[p];
            long long ns = um_handshake(ctx_cli[g], ctx_srv[g]);
            printf("%s,%ld,%lld\n", GRUPOS[g], i, ns);
        }
    }

    for (int g = 0; g < N_GRUPOS; g++) {
        SSL_CTX_free(ctx_srv[g]);
        SSL_CTX_free(ctx_cli[g]);
    }
    EVP_PKEY_free(chave);
    X509_free(cert);
    return 0;
}
