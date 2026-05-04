#!/usr/bin/env bash
# Emit: package_manager, runtime
set -euo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel)}"
. "$(dirname "$0")/lib.sh"

pm="" pm_src=""
if   [ -f "$ROOT/pnpm-lock.yaml" ];   then pm="pnpm";  pm_src="pnpm-lock.yaml"
elif [ -f "$ROOT/yarn.lock" ];        then pm="yarn";  pm_src="yarn.lock"
elif [ -f "$ROOT/package-lock.json" ];then pm="npm";   pm_src="package-lock.json"
elif [ -f "$ROOT/bun.lockb" ];        then pm="bun";   pm_src="bun.lockb"
fi

runtime="" runtime_src=""
if [ -f "$ROOT/package.json" ]; then
  runtime="node"; runtime_src="package.json"
elif [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/requirements.txt" ]; then
  runtime="python"; runtime_src="$( [ -f "$ROOT/pyproject.toml" ] && echo pyproject.toml || echo requirements.txt )"
elif [ -f "$ROOT/go.mod" ]; then
  runtime="go"; runtime_src="go.mod"
elif [ -f "$ROOT/Cargo.toml" ]; then
  runtime="rust"; runtime_src="Cargo.toml"
fi

out="{}"
if [ -n "$pm" ]; then
  out=$(jq -s 'add' <(echo "$out") <(emit_detected package_manager "$pm" "$pm_src"))
else
  out=$(jq -s 'add' <(echo "$out") <(emit_missing package_manager "no lockfile found"))
fi
if [ -n "$runtime" ]; then
  out=$(jq -s 'add' <(echo "$out") <(emit_detected runtime "$runtime" "$runtime_src"))
else
  out=$(jq -s 'add' <(echo "$out") <(emit_missing runtime "no recognized manifest"))
fi
echo "$out"
