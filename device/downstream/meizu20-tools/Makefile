# ringlight — status LED ring effects for Meizu 20 (dual SY7808)
# modular: one effect = src/eff_<name>.c + one line in src/effects.c
CC ?= gcc
CFLAGS ?= -O2 -Wall
PREFIX ?= /usr/local

BIN := ringlight
SRC := $(wildcard src/*.c)
HDR := src/core.h src/effects.h

$(BIN): $(SRC) $(HDR)
	$(CC) $(CFLAGS) -o $@ $(SRC)

install: $(BIN)
	install -Dm755 $(BIN) $(DESTDIR)$(PREFIX)/bin/$(BIN)

clean:
	rm -f $(BIN)

.PHONY: install clean
