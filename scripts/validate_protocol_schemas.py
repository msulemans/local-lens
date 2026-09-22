#!/usr/bin/env python3
"""Validate protocol v1 schemas and their parity with the Swift core.

Uses only the Python standard library. Checks:

1. every schema file is valid JSON and declares JSON Schema 2020-12 with a
   unique ``$id``;
2. every expected definition exists in the frozen surface;
3. every ``$ref`` resolves to a local or urn-located definition;
4. the wire enums (``run_status``, ``research_mode``, ``evidence_relation``)
   equal the raw values declared in ``Sources/LocalLensCore/Domain.swift``.

Any mismatch exits non-zero. Run via ``make validate-schemas``.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROTOCOL_DIR = ROOT / "schemas" / "protocol" / "v1"
DOMAIN_SWIFT = ROOT / "Sources" / "LocalLensCore" / "Domain.swift"

ENUM_PAIRS = {
    "run_status": "RunStatus",
    "research_mode": "ResearchMode",
    "evidence_relation": "EvidenceRelation",
}

EXPECTED_DEFS = {
    "urn:local-lens:protocol:v1:entities": [
        "run_status",
        "research_mode",
        "evidence_relation",
        "research_run",
        "search_hit",
        "source",
        "snapshot",
        "passage",
        "claim",
        "evidence_link",
        "citation",
        "comparison_value",
        "comparison_row",
        "research_result",
        "run_event",
        "persisted_run",
    ],
    "urn:local-lens:protocol:v1:commands": [
        "instance_id",
        "start_run",
        "cancel_run",
        "command_envelope",
    ],
    "urn:local-lens:protocol:v1:events": [
        "run_event_envelope",
        "event_envelope",
    ],
    "urn:local-lens:protocol:v1:errors": [
        "error_code",
        "error_envelope",
    ],
}


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def load_schemas() -> dict[str, dict]:
    schemas: dict[str, dict] = {}
    for path in sorted(PROTOCOL_DIR.glob("*.json")):
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            fail(f"{path.name} is not valid JSON: {error}")
        if doc.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
            fail(f"{path.name} must declare JSON Schema 2020-12")
        schema_id = doc.get("$id")
        if not schema_id:
            fail(f"{path.name} has no $id")
        if schema_id in schemas:
            fail(f"duplicate $id: {schema_id}")
        schemas[schema_id] = {"path": path.name, "doc": doc}
    if not schemas:
        fail(f"no protocol schemas found in {PROTOCOL_DIR}")
    return schemas


def walk_refs(node: object):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "$ref" and isinstance(value, str):
                yield value
            else:
                yield from walk_refs(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk_refs(item)


def resolve(ref: str, schemas: dict[str, dict], current_doc: dict) -> None:
    target_id, _, pointer = ref.partition("#")
    if target_id:
        if target_id not in schemas:
            fail(f"$ref target not found: {ref}")
        node: object = schemas[target_id]["doc"]
    else:
        node = current_doc
    for token in (part for part in pointer.split("/") if part):
        token = token.replace("~1", "/").replace("~0", "~")
        if not isinstance(node, dict) or token not in node:
            fail(f"$ref does not resolve: {ref}")
        node = node[token]


def swift_enum_values(source: str, name: str) -> list[str]:
    match = re.search(rf"public enum {name}\b.*?\n\}}", source, re.S)
    if not match:
        fail(f"enum {name} not found in {DOMAIN_SWIFT.name}")
    values: list[str] = []
    for case in re.finditer(
        r"case ([A-Za-z_][A-Za-z0-9_]*)(?: = \"([^\"]+)\")?", match.group(0)
    ):
        values.append(case.group(2) if case.group(2) else case.group(1))
    if not values:
        fail(f"enum {name} declares no cases")
    return values


def main() -> None:
    schemas = load_schemas()

    for schema_id, expected in EXPECTED_DEFS.items():
        if schema_id not in schemas:
            fail(f"missing schema: {schema_id}")
        defs = schemas[schema_id]["doc"].get("$defs", {})
        for name in expected:
            if name not in defs:
                fail(f"{schema_id} lacks $defs/{name}")

    for entry in schemas.values():
        for ref in walk_refs(entry["doc"]):
            resolve(ref, schemas, entry["doc"])

    entities = schemas["urn:local-lens:protocol:v1:entities"]["doc"]["$defs"]
    swift_source = DOMAIN_SWIFT.read_text(encoding="utf-8")
    for schema_name, swift_name in ENUM_PAIRS.items():
        schema_values = entities[schema_name]["enum"]
        swift_values = swift_enum_values(swift_source, swift_name)
        if schema_values != swift_values:
            fail(
                f"{schema_name} does not match {swift_name}\n"
                f"  schema: {schema_values}\n"
                f"  swift:  {swift_values}"
            )

    summary = ", ".join(
        f"{name}={len(entities[name]['enum'])}" for name in ENUM_PAIRS
    )
    print(f"protocol v1 schemas conform; Swift parity holds ({summary})")


if __name__ == "__main__":
    main()
