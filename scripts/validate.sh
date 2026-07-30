#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
cd "$repo_root"

python3 -m unittest discover -s tests -v
python3 src/topology.py validate --config config/topology.json
python3 src/topology.py render --config config/topology.json --output "$temporary/one.json"
python3 src/topology.py render --config config/topology.json --output "$temporary/two.json"
cmp "$temporary/one.json" "$temporary/two.json"
python3 -m json.tool config/topology.json >/dev/null

if command -v bicep >/dev/null 2>&1; then
  bicep build infra/main.bicep --outfile "$temporary/main.json"
elif command -v az >/dev/null 2>&1 &&
  AZURE_CONFIG_DIR="$temporary/az" az bicep version >/dev/null 2>&1; then
  AZURE_CONFIG_DIR="$temporary/az" az bicep build \
    --file infra/main.bicep --outfile "$temporary/main.json"
else
  echo "Bicep compiler unavailable; compile gate skipped locally." >&2
fi
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/validate.sh
fi
