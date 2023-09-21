.PHONY: check test docs

moc_version = 0.10.0

check:
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell mocv bin $(moc_version))/moc $(shell mops sources) --check

all: check-strict

check-strict:
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell mocv bin $(moc_version))/moc $(shell mops sources) -Werror --check

test:
	mops test
	make -C test/integration

docs:
	$(shell mocv bin $(moc_version))/mo-doc