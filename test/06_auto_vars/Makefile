.PHONY: all clean

SRCS = foo.c bar.c

all: program
	echo "built $@"

program: main.o utils.o
	echo "linking $@ from $^"

main.o: main.c
	echo "compiling $< into $@"

utils.o: utils.c
	echo "compiling $< into $@"

main.c:
	echo "int main(){}" > $@

utils.c:
	echo "void util(){}" > $@

clean:
	rm -f *.o *.c program
