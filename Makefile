.PHONY: lint test package verify clean

lint:
	lua tools/lint.lua

test: package
	lua tests/run.lua

package:
	lua tools/package.lua

verify: lint test

clean:
	rm -rf dist/SDCARD
