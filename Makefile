
push:
	@convcommit -a -p

clean:
	@rm -fr lib target

build: clean
	@mush build

