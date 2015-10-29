PROGS = pngs2mp4

CC = clang

CFLAGS = -mmacosx-version-min=10.7
CFLAGS += -Os
CFLAGS += -framework Foundation
CFLAGS += -framework AppKit
CFLAGS += -framework CoreMedia
CFLAGS += -framework CoreVideo
CFLAGS += -framework AVFoundation
CFLAGS += -D USE_COLORS

DEBUG = -D DEBUG

all: $(PROGS)

.c:
	clang $(CFLAGS) -o $@ $@.c

debug:
	clang $(DEBUG) $(CFLAGS) -o $@ $@.c

clean:
	rm -f $(PROGS)

install:
	cp $(PROGS) ~/bin/

