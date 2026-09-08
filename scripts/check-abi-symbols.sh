#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
expected_file="${repo_root}/generated/abi/SYMBOLS"
shared_library="${repo_root}/ffi/zig/zig-out/lib/libidaptik_ums.so"
static_library="${repo_root}/ffi/zig/zig-out/lib/libidaptik_ums.a"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "${scratch_dir}"' EXIT

command -v nm >/dev/null || { echo "error: nm is required for compiled ABI symbol verification" >&2; exit 1; }
test -f "${expected_file}" || { echo "error: generated ABI symbol manifest is missing" >&2; exit 1; }
test -f "${shared_library}" || { echo "error: shared library is missing; run the pinned Zig build first" >&2; exit 1; }
test -f "${static_library}" || { echo "error: static library is missing; run the pinned Zig build first" >&2; exit 1; }

sort -u "${expected_file}" > "${scratch_dir}/expected"
nm -D --defined-only --format=posix "${shared_library}" |
  awk '{print $1}' |
  grep -E '^(idaptik_|ipc_)' |
  sort -u > "${scratch_dir}/shared"
nm --defined-only --format=posix "${static_library}" |
  awk '{print $1}' |
  sort -u > "${scratch_dir}/static"

if ! cmp "${scratch_dir}/expected" "${scratch_dir}/shared"; then
  echo "error: generated header symbols and shared-library C exports differ" >&2
  exit 1
fi

if ! comm -23 "${scratch_dir}/expected" "${scratch_dir}/static" > "${scratch_dir}/static-missing"; then
  echo "error: unable to compare generated and static-library symbols" >&2
  exit 1
fi
if [ -s "${scratch_dir}/static-missing" ]; then
  echo "error: generated ABI symbols missing from static library:" >&2
  sed 's/^/  /' "${scratch_dir}/static-missing" >&2
  exit 1
fi

echo "compiled ABI symbols match generated manifest ($(wc -l < "${scratch_dir}/expected") exports)"
