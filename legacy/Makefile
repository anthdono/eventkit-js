.PHONY: install
install: 
	@# XXX Implement package manager variation
	@echo 'Installing node dependencies'	
	@npm install


.PHONY: build
build:
	@echo 'Building native lib.'
	@cd ./native && swift build

.PHONY: run
run:
	@# XXX Not implemented
	@echo 'Nothing to run.'

.PHONY: test
test:
	ts-node ./tests/test.ts


.PHONY: runtests
runtests: install build
	@# XXX Implement package manager variation
	@echo 'Running jest tests'	
	@npm exec jest --debug
	# @echo 'Running non-jest tests'	
	# ts-node tests/nonJestTests.ts

.PHONY: clean
clean:
	@echo 'Removing ./dist'
	@rm -r ./dist

.PHONY: realclean
realclean:
	@echo 'Not implemented'

	# XXX rm?
	# native/.build
	# native/.swiftpm
	# node_modules




