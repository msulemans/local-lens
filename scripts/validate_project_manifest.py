#!/usr/bin/env python3
"""Validate the Local Lens handoff without third-party dependencies."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "project.json"


def fail(message: str) -> None:
    raise ValueError(message)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"{path.relative_to(ROOT)}: {error}")


def check_type(value: Any, expected: str, location: str) -> None:
    checks = {
        "object": lambda item: isinstance(item, dict),
        "array": lambda item: isinstance(item, list),
        "string": lambda item: isinstance(item, str),
        "integer": lambda item: isinstance(item, int) and not isinstance(item, bool),
        "number": lambda item: isinstance(item, (int, float)) and not isinstance(item, bool),
        "boolean": lambda item: isinstance(item, bool),
        "null": lambda item: item is None,
    }
    check = checks.get(expected)
    if check is None:
        fail(f"{location}: validator does not support schema type {expected!r}")
    if not check(value):
        fail(f"{location}: expected {expected}, got {type(value).__name__}")


def validate(value: Any, schema: dict[str, Any], location: str = "project.json") -> None:
    expected_type = schema.get("type")
    if expected_type:
        check_type(value, expected_type, location)

    if isinstance(value, dict):
        required = schema.get("required", [])
        missing = [key for key in required if key not in value]
        if missing:
            fail(f"{location}: missing required keys: {', '.join(missing)}")

        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            unknown = sorted(set(value) - set(properties))
            if unknown:
                fail(f"{location}: unknown keys: {', '.join(unknown)}")

        for key, child_schema in properties.items():
            if key in value:
                validate(value[key], child_schema, f"{location}.{key}")

    if isinstance(value, list):
        minimum = schema.get("minItems")
        if minimum is not None and len(value) < minimum:
            fail(f"{location}: needs at least {minimum} items")
        if schema.get("uniqueItems"):
            encoded = [json.dumps(item, sort_keys=True) for item in value]
            if len(encoded) != len(set(encoded)):
                fail(f"{location}: items must be unique")
        child_schema = schema.get("items")
        if child_schema:
            for index, child in enumerate(value):
                validate(child, child_schema, f"{location}[{index}]")

    if isinstance(value, str) and "pattern" in schema:
        if re.search(schema["pattern"], value) is None:
            fail(f"{location}: does not match {schema['pattern']!r}")


def validate_project_invariants(manifest: dict[str, Any]) -> None:
    authority = manifest["authority_order"]
    if authority[:2] != ["LOCAL_BROWSER_STATE.md", "project.json"]:
        fail("authority_order must begin with LOCAL_BROWSER_STATE.md and project.json")

    state = manifest["current_state"]
    task = manifest["next_task"]
    milestone = state["next_milestone"]
    if not task["id"].startswith(f"{milestone}."):
        fail("next_task.id must belong to current_state.next_milestone")

    for relative_path in state.get("unverified_wip", []):
        if not (ROOT / relative_path).exists():
            fail(f"unverified WIP path does not exist: {relative_path}")

    reuse = manifest["reuse"]["primary_source"]
    if reuse["license_status"].startswith("blocked") and not any(
        "licence" in item.lower() for item in task["prerequisites"]
    ):
        fail("a blocked reuse licence must remain an explicit next-task prerequisite")

    for relative_path in manifest["handoff_protocol"]["read_first"]:
        if not (ROOT / relative_path).exists():
            fail(f"handoff read_first path does not exist: {relative_path}")


def main() -> int:
    try:
        manifest = load_json(MANIFEST_PATH)
        schema_ref = manifest.get("$schema")
        if not isinstance(schema_ref, str) or not schema_ref.startswith("./"):
            fail("project.json.$schema must be a repository-relative path")
        schema_path = (ROOT / schema_ref).resolve()
        if ROOT not in schema_path.parents:
            fail("project.json.$schema escapes the repository")
        schema = load_json(schema_path)
        validate(manifest, schema)
        validate_project_invariants(manifest)
    except (KeyError, TypeError, ValueError) as error:
        print(f"manifest validation failed: {error}", file=sys.stderr)
        return 1

    print("project.json conforms to its schema and handoff invariants.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
