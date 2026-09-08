#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${repo_root}/generated/abi"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "${scratch_dir}"' EXIT

cd "${repo_root}"
idris2 --build idaptik-ums.ipkg
"${repo_root}/build/exec/idaptik-ums-abi-gen" c > "${scratch_dir}/idaptik_ums.h"
"${repo_root}/build/exec/idaptik-ums-abi-gen" level-compat > "${scratch_dir}/idaptik_ums_level.h"
"${repo_root}/build/exec/idaptik-ums-abi-gen" symbols > "${scratch_dir}/SYMBOLS"

if [ "${1:-}" = "--check" ]; then
  cmp "${scratch_dir}/idaptik_ums.h" "${output_dir}/idaptik_ums.h"
  cmp "${scratch_dir}/idaptik_ums_level.h" "${output_dir}/idaptik_ums_level.h"
  cmp "${scratch_dir}/SYMBOLS" "${output_dir}/SYMBOLS"
else
  mkdir -p "${output_dir}"
  install -m 0644 "${scratch_dir}/idaptik_ums.h" "${output_dir}/idaptik_ums.h"
  install -m 0644 "${scratch_dir}/idaptik_ums_level.h" "${output_dir}/idaptik_ums_level.h"
  install -m 0644 "${scratch_dir}/SYMBOLS" "${output_dir}/SYMBOLS"
fi
