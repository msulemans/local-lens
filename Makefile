.PHONY: bootstrap validate-manifest validate-schemas gate build verify run

bootstrap:
	@swift --version
	@swift package describe >/dev/null
	@echo "Local Lens toolchain is ready."

validate-manifest:
	@python3 scripts/validate_project_manifest.py

validate-schemas:
	@python3 scripts/validate_protocol_schemas.py

gate: validate-manifest validate-schemas build verify

build:
	swift build

verify:
	swift test

run:
	swift run LocalLensApp
