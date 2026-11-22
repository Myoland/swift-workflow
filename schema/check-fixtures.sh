#!/usr/bin/env bash
# Checks schema/workflow.schema.json against the fixtures in Tests/Fixtures/WorkflowSchema:
# the schema must be valid draft 2020-12, every valid/ fixture must pass, every invalid/ fixture
# must fail with a schema error (not a YAML parse error).
# Needs check-jsonschema on PATH (CI pins the version).
set -euo pipefail

cd "$(dirname "$0")/.."
schema=schema/workflow.schema.json
fixtures=Tests/Fixtures/WorkflowSchema

check-jsonschema --check-metaschema "$schema"
check-jsonschema --schemafile "$schema" "$fixtures"/valid/*.yaml

status=0
for file in "$fixtures"/invalid/*.yaml; do
  report=$(check-jsonschema --schemafile "$schema" -o json "$file" || true)
  if ! python3 -c 'import json, sys; r = json.load(sys.stdin); sys.exit(0 if r["errors"] and not r["parse_errors"] else 1)' <<<"$report"; then
    echo "expected a schema error, got none: $file"
    status=1
  fi
done
[ "$status" -eq 0 ] && echo "ok -- $(ls "$fixtures"/invalid/*.yaml | wc -l) invalid fixtures rejected"
exit "$status"
