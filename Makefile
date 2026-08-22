.PHONY: test validate

test:
	bash tests/test_install.sh
	bash tests/test_bindings.sh
	node tests/test_model.js
	bash tests/test_source.sh
	bash tests/test_lifecycle.sh

validate:
	omarchy plugin validate .
	git diff --check
