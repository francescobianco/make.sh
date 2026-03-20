.PHONY: all clean

all: output.txt
	echo "all done"

output.txt: input.txt
	cp input.txt output.txt
	echo "generated output.txt"

input.txt:
	echo "source content" > input.txt

clean:
	rm -f input.txt output.txt
