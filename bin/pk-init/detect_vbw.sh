#!/usr/bin/env bash
# Emit: backend (vbw if .vbw-planning/ exists, else needs_input)
set -euo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel)}"
. "$(dirname "$0")/lib.sh"

if [ -d "$ROOT/.vbw-planning" ]; then
  emit_detected backend "vbw" ".vbw-planning/ present"
else
  emit_needs_input backend '["vbw","native"]' ".vbw-planning/ not present; pick backend (vbw=full agent pipeline, native=in-context)"
fi
