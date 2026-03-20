.PHONY: all silent mixed

CFLAGS = -Wall -O2
CC = gcc

all:
	echo "compiler: $(CC)"
	echo "flags: $(CFLAGS)"
	echo "done"

silent:
	@echo "silent: this line has no echo prefix"
	@echo "compiler: $(CC)"

mixed:
	echo "visible line"
	@echo "hidden line"
	echo "another visible"
