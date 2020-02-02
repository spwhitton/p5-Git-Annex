.PHONY: CLEAN
clean:
	rm -rf Git-Annex-*

.PHONY: dist
dist:
	dzil build

.PHONY: test
test:
	prove --lib
