
default: test

.PHONY: pre
pre:
	npm ci

.PHONY: build
build:
	@echo "building.."
	./node_modules/.bin/node-gyp configure
	./node_modules/.bin/node-gyp build

.PHONY: test
test: build
	@echo "testing.."
	ts-node ./test/index.ts
