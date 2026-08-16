# libneoconv / neoconv - MAME Neo Geo romset to TerraOnion .neo converter
#
# Targets:
#   all       - build libneoconv.a and the neoconv CLI
#   test      - run the synthetic round-trip and recipe smoke tests
#   asan      - rebuild CLI with ASan/UBSan
#   regen     - regenerate crypto ports and game DB from the MAME tree
#   clean

CC       ?= cc
AR       ?= ar
CFLAGS   ?= -O2
CFLAGS   += $(EXTRA_CFLAGS)
CFLAGS   += -std=c99 -Wall -Wextra -Wno-unused-parameter \
	    -Iinclude -Isrc -Isrc/crypt -Iminiz
MAMEDIR  ?= ref/mame

LIB_SRCS := src/neoconv.c src/regions.c src/recipes.c src/neowrite.c \
            src/zipio.c src/games_db.c src/meta_db.c \
            $(wildcard src/crypt/nc_*.c)
MZ_SRCS  := miniz/miniz.c
CLI_SRCS := cli/neoconv.c

LIB_OBJS := $(LIB_SRCS:.c=.o)
TP_OBJS  := $(MZ_SRCS:.c=.o)

all: libneoconv.a neoconv

shared: CFLAGS += -fPIC -fvisibility=hidden -DNEOCONV_SHARED -DNEOCONV_BUILD
shared: clean $(LIB_OBJS) $(TP_OBJS)
	$(CC) $(CFLAGS) -shared -o libneoconv.so $(LIB_OBJS) $(TP_OBJS)

libneoconv.a: $(LIB_OBJS)
	$(AR) rcs $@ $^

neoconv: $(CLI_SRCS) libneoconv.a $(TP_OBJS)
	$(CC) $(CFLAGS) -o $@ $(CLI_SRCS) libneoconv.a $(TP_OBJS)

HEADERS := include/neoconv.h src/neoconv_internal.h src/crypt/crypt.h \
           src/crypt/crypt_protos.h miniz/miniz.h

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

# third_party/miniz.c triggers warnings not worth chasing
third_party/miniz.o: miniz/miniz.c
	$(CC) $(CFLAGS) -w -c -o $@ $<

asan: clean
	$(MAKE) EXTRA_CFLAGS="-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer" all

regen:
	python3 tools/port_crypto.py $(MAMEDIR)/src/devices/bus/neogeo src/crypt
	python3 tools/gendb.py $(MAMEDIR)/src/mame/snk/neogeo.cpp src/games_db.c
	python3 tools/gen_meta.py data/known_good.tsv -o src/meta_db.c

tests/api_test: tests/api_test.c libneoconv.a $(TP_OBJS)
	$(CC) $(CFLAGS) -o $@ tests/api_test.c libneoconv.a $(TP_OBJS)

clean:
	rm -f $(LIB_OBJS) $(TP_OBJS) libneoconv.a libneoconv.so neoconv

.PHONY: all shared asan regen test clean
