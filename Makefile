.PHONY: check test docs

check:
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell vessel bin)/moc $(shell vessel sources) --check

all: check-strict

check-strict:
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell vessel bin)/moc $(shell vessel sources) -Werror --check

test:
	make -C test/module
	make -C test/integration

docs:
	$(shell vessel bin)/mo-doc