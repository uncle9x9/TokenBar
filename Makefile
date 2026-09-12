DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
TMPDIR ?= $(PWD)/.build/tmp
CLANG_MODULE_CACHE_PATH ?= $(PWD)/.build/ModuleCache
CACHE_PATH ?= $(PWD)/.build/cache

export DEVELOPER_DIR
export TMPDIR
export CLANG_MODULE_CACHE_PATH

.PHONY: all build test verify package dmg run clean

all: test package

build:
	@mkdir -p $(TMPDIR) $(CLANG_MODULE_CACHE_PATH) $(CACHE_PATH)
	swift build --cache-path $(CACHE_PATH)

test:
	@mkdir -p $(TMPDIR) $(CLANG_MODULE_CACHE_PATH) $(CACHE_PATH)
	swift test --cache-path $(CACHE_PATH)

verify:
	@mkdir -p $(TMPDIR) $(CLANG_MODULE_CACHE_PATH) $(CACHE_PATH)
	swift run --cache-path $(CACHE_PATH) TokenBarVerify

package:
	@./Scripts/package_app.sh

dmg: package
	@./Scripts/create_dmg.sh

run: package
	@open dist/TokenBar.app

clean:
	@rm -rf .build dist
