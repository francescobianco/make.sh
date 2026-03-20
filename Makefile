
push:
	@git add .
	@git commit -am "Small amends" || true
	@git push


clean:
	@rm -fr lib target

build: clean
	@mush build

