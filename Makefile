PLUGIN_DIR ?= $(HOME)/.config/omarchy/plugins/huacnlee.which-key

.PHONY: test validate dev

test:
	bash tests/test_install.sh
	bash tests/test_bindings.sh
	node tests/test_model.js
	node tests/test_settings.js
	bash tests/test_source.sh
	bash tests/test_lifecycle.sh

validate:
	omarchy plugin validate .
	git diff --check

# Sync this working tree into the local plugin directory so the running shell
# picks up in-progress changes. The shell reloads plugin code on save; the
# rescan is a best-effort nudge for anything it misses.
dev:
	@test -f manifest.json || { printf 'run make dev from the plugin repo root\n' >&2; exit 1; }
	@mkdir -p "$(PLUGIN_DIR)"
	rsync -a --delete --exclude '.git/' --exclude '.github/' ./ "$(PLUGIN_DIR)/"
	omarchy-shell -q shell rescanPlugins
	@printf 'synced to %s\n' "$(PLUGIN_DIR)"
