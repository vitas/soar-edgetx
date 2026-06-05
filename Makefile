.PHONY: lint test package verify clean install-widget sdcard

SDCARD ?=

lint:
	lua tools/lint.lua

test: package
	lua tests/run.lua

package:
	lua tools/package.lua

verify: lint test

clean:
	rm -rf dist/SDCARD/WIDGETS/SoarF5J

install-widget: package
	@test -n "$(SDCARD)" || (echo "Usage: make install-widget SDCARD=/path/to/sdcard" >&2; exit 2)
	@test -d "$(SDCARD)" || (echo "SDCARD does not exist: $(SDCARD)" >&2; exit 2)
	mkdir -p "$(SDCARD)/WIDGETS"
	rm -rf "$(SDCARD)/WIDGETS/SoarF5J"
	cp -R dist/SDCARD/WIDGETS/SoarF5J "$(SDCARD)/WIDGETS/"
	@echo "installed SoarF5J widget to $(SDCARD)/WIDGETS/SoarF5J"

sdcard: install-widget
