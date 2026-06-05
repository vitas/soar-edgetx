.PHONY: lint test package verify clean

lint:
	lua tools/lint.lua

test:
	lua tests/run.lua

package:
	lua tools/package.lua

verify: lint test package

clean:
	rm -rf dist/WIDGETS/SoarF5J
