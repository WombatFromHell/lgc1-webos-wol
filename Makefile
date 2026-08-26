VERSION := $(shell sed -n 's/^version = "\(.*\)"/\1/p' pyproject.toml)
ARTIFACT := lgc1-webos-wol-$(VERSION).zip
BUILD_DIR ?= dist
OUT := $(BUILD_DIR)/$(ARTIFACT)
EPOCH := 1

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +; \
	rm -rf \
	$(BUILD_DIR) \
	staging \
	.pytest_cache \
	.ruff_cache \
	.direnv \
	.pi \
	result* \
	.coverage

configure: clean
	uv venv --clear
	uv sync --frozen

run:
	uv run lgc1-wol.py

lint:
	uv run ty check ./; \
		uv run ruff check ./ --fix; \
	uv run pyright

prettier:
	prettier -c -w *.md

format: prettier
	uv run ruff check --select I ./ --fix; \
	uv run ruff format ./

quality: lint format

# Local deterministic build — run inside the flake dev shell
# (direnv auto-activates, or: nix develop -c make build)
build: clean
	@echo "Building $(ARTIFACT) (version $(VERSION))"
	mkdir -p $(BUILD_DIR) staging
	install -m 644 lgc1-wol.py staging/lgc1-wol.py
	install -m 644 lgc1-wold.py staging/lgc1-wold.py
	install -m 755 install.sh staging/install.sh
	install -m 644 LICENSE staging/LICENSE
	install -m 644 README.md staging/README.md
	find staging -exec touch -d "@$(EPOCH)" {} +
	(cd staging && find . \( -type d -o -type f \) | LC_ALL=C sort | zip -X -q -@ ../$(OUT))
	rm -rf staging
	cd $(BUILD_DIR) && sha256sum $(ARTIFACT) > $(ARTIFACT).sha256
	@echo "Built: $(OUT)"
	@echo "SHA256: $$(cat $(OUT).sha256 | cut -d' ' -f1)"

# Reproducible build via nix (see flake.nix)
build-nix: clean
	@echo "Building $(ARTIFACT) via Nix (version $(VERSION))"
	mkdir -p $(BUILD_DIR)
	# nix build . --out-link ./$(OUT)
	# enforce the most minimal substituters'
	nix build . --out-link ./$(OUT) --substituters "https://cache.nixos.org"
	cd $(BUILD_DIR) && sha256sum $(ARTIFACT) > $(ARTIFACT).sha256
	@echo "Built: $(OUT)"
	@echo "SHA256: $$(cat $(OUT).sha256 | cut -d' ' -f1)"

# CI entry point: reproducible nix build (used by the GitHub Actions workflow)
ci-nix: build-nix

.PHONY: clean configure lint prettier format quality run build build-nix ci-nix
.SILENT: clean configure lint prettier format quality run build build-nix
