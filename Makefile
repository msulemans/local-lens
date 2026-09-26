.PHONY: bootstrap validate-manifest validate-schemas gate build verify run app dist verify-release demo reproduce

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

app:
	sh ./scripts/build_dev_app.sh

dist:
	sh ./scripts/build_release.sh
	sh ./scripts/verify_release.sh

verify-release:
	sh ./scripts/verify_release.sh

demo:
	sh ./scripts/run_demo.sh

reproduce:
	sh ./scripts/verify_clean_clone.sh
