clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +; \
	rm -rf \
	$(BUILD_DIR) \
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

.PHONY: clean configure lint prettier format quality run
.SILENT: clean configure lint prettier format quality run
