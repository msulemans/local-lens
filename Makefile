.PHONY: bootstrap validate-manifest build verify run

bootstrap:
	@swift --version
	@swift package describe >/dev/null
	@echo "Local Lens toolchain is ready."

validate-manifest:
	@python3 scripts/validate_project_manifest.py

build:
	swift build

verify:
	swift test

run:
	swift run LocalLensApp
