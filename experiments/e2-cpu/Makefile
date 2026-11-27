# Harness do E2. Precisa de OpenSSL >= 3.5 (aqui o 3.6 do Homebrew).
# O openssl de fabrica do macOS e LibreSSL e NAO serve.
#
#   make            compila o harness
#   make piloto     roda um piloto curto (poucas reps) para validar o metodo
#   make clean      remove o binario

OPENSSL_PREFIX ?= /opt/homebrew/opt/openssl@3.6

CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra -std=c11 -I$(OPENSSL_PREFIX)/include
LDFLAGS ?= -L$(OPENSSL_PREFIX)/lib
LDLIBS  ?= -lssl -lcrypto

harness: harness.c
	$(CC) $(CFLAGS) -o $@ harness.c $(LDFLAGS) $(LDLIBS)

piloto: harness
	./harness -n 50

clean:
	rm -f harness

.PHONY: piloto clean
