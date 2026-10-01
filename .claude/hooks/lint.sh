#!/usr/bin/env bash
# PostToolUse(Write|Edit): lint the single file that was just written.
#
#   0 = clean, 2 = feed stderr back to Claude so it fixes the problem.
# Any other non-zero is a warning the model never sees.

set -uo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null \
  || (cd "$(dirname "$0")/../.." && pwd))"
cd "$ROOT" || exit 0

# This repo pins its ansible tooling in ./venv (README: python3 -mvenv venv),
# and an agent shell does not run with that venv activated, so without this the
# gate fails on a missing ansible-lint rather than on anything in the code.
if [ -d "$ROOT/venv/bin" ]; then
  export PATH="$ROOT/venv/bin:$PATH"
fi

INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')"
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

case "$FILE" in
  "$ROOT"/*) REL="${FILE#"$ROOT"/}" ;;
  *) exit 0 ;;
esac

# Vendored collections are not ours to lint.
case "$REL" in
  ansible/collections/*) exit 0 ;;
esac

case "$REL" in
  ansible/*.yml|ansible/*.yaml)
    # ansible.cfg lives in ansible/ and sets collections_path, so lint from
    # there or every module resolves as unknown.
    if ! OUT="$(cd ansible && ansible-lint "${REL#ansible/}" 2>&1)"; then
      printf 'ansible-lint failed on %s:\n%s\n' "$REL" "$OUT" >&2
      exit 2
    fi
    ;;
  *.tf)
    command -v terraform >/dev/null 2>&1 && terraform fmt "$FILE" >/dev/null 2>&1
    if ! OUT="$(tflint --chdir="$(dirname "$FILE")" 2>&1)"; then
      printf 'tflint failed on %s:\n%s\n' "$REL" "$OUT" >&2
      exit 2
    fi
    ;;
  *.sh|up|deploy-to-libvirt)
    if ! OUT="$(shellcheck "$FILE" 2>&1)"; then
      printf 'shellcheck failed on %s:\n%s\n' "$REL" "$OUT" >&2
      exit 2
    fi
    ;;
esac

exit 0
