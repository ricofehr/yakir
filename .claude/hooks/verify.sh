#!/usr/bin/env bash
# Stop / SubagentStop / TeammateIdle: the real gate.
#
# Exit 2 blocks the stop and hands stderr back to the agent. The
# stop_hook_active guard stops that from becoming an infinite loop.
#
# Scoping: ansible-lint runs repo-wide because CI does and it is green. The
# shell and terraform checks run only on files this branch touched — `up`,
# `deploy-to-libvirt` and tf/libvirt carry pre-existing findings, and blocking
# every turn on debt an agent did not create either halts all work or pressures
# it into a "fix" that breaks a working deploy script.

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
if [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
  echo "ℹ️  [verify] Already blocked once this turn — letting the agent stop." >&2
  exit 0
fi

FAILED=""

# ── Files this branch touched (committed vs upstream, plus uncommitted) ──────
BASE="$(git merge-base HEAD origin/main 2>/dev/null || true)"
{
  [ -n "$BASE" ] && git diff --name-only "$BASE"...HEAD
  git status --porcelain | awk '{ $1=""; sub(/^ /,""); print }'
} 2>/dev/null | sort -u > /tmp/yakir-changed.$$
trap 'rm -f /tmp/yakir-changed.$$' EXIT

changed_matching() { grep -E "$1" /tmp/yakir-changed.$$ 2>/dev/null || true; }

# ── Ansible: repo-wide, hard gate ────────────────────────────────────────────
# Collections are gitignored and pinned in requirements.yml. Without them
# ansible-lint reports every module as unknown, which looks like 30 code
# defects and is really one missing install.
if ! compgen -G "ansible/collections/ansible_collections/*/*" >/dev/null 2>&1; then
  echo "📦 [verify] Installing pinned Ansible collections..."
  (cd ansible && ansible-galaxy collection install -r requirements.yml -p ./collections) \
    >/dev/null 2>&1 \
    || echo "⚠️  [verify] Collection install failed — module errors below are environmental." >&2
fi

echo "🔍 [verify] ansible-lint (profile: production)"
# ansible.cfg lives in ansible/ and sets collections_path; from the repo root
# every module resolves as unknown.
if ! OUT="$(cd ansible && ansible-lint 2>&1)"; then
  printf '%s\n' "$OUT" >&2
  FAILED="${FAILED}ansible-lint. "
fi

# ── Shell: changed files only ────────────────────────────────────────────────
# SC1091 is excluded: these scripts source venv/bin/activate, which does not
# exist until the venv is built. That is environmental, not a defect.
SH_CHANGED="$(changed_matching '(\.sh$|^up$|^deploy-to-libvirt$)')"
# Same treatment terraform gets below: gating on a linter that is not installed
# reports an environment gap as a code defect, and nothing can clear it.
if [ -n "$SH_CHANGED" ] && ! command -v shellcheck >/dev/null 2>&1; then
  echo "⚠️  [verify] shellcheck not installed — changed shell scripts skipped." >&2
  SH_CHANGED=""
fi
if [ -n "$SH_CHANGED" ]; then
  echo "🔍 [verify] shellcheck (changed scripts)"
  while IFS= read -r script; do
    [ -f "$script" ] || continue
    if ! OUT="$(shellcheck -e SC1091 "$script" 2>&1)"; then
      printf '%s\n' "$OUT" >&2
      FAILED="${FAILED}shellcheck on ${script}. "
    fi
  done <<< "$SH_CHANGED"
fi

# ── Terraform: changed directories only ──────────────────────────────────────
TF_CHANGED="$(changed_matching '\.tf$')"
if [ -n "$TF_CHANGED" ]; then
  echo "🔍 [verify] tflint (changed directories)"
  if ! command -v terraform >/dev/null 2>&1; then
    echo "⚠️  [verify] terraform not installed — fmt and validate skipped, tflint only." >&2
  fi
  while IFS= read -r dir; do
    [ -d "$dir" ] || continue
    command -v terraform >/dev/null 2>&1 && terraform fmt "$dir" >/dev/null 2>&1
    if ! OUT="$(tflint --chdir="$dir" 2>&1)"; then
      printf '%s\n' "$OUT" >&2
      FAILED="${FAILED}tflint in ${dir}. "
    fi
  done < <(while IFS= read -r f; do dirname "$f"; done <<< "$TF_CHANGED" | sort -u)
fi

if [ -n "$FAILED" ]; then
  echo "❌ [verify] ${FAILED}Fix the cause and re-run; do not relax the lint config." >&2
  exit 2
fi

echo "✅ [verify] ansible-lint clean; changed shell/terraform clean"

# Visible, non-blocking: debt that predates this branch.
echo "ℹ️  [verify] Known pre-existing debt (not gated): 29 tflint warnings in" \
     "tf/libvirt (deprecated interpolation/lookup); SC2034 in ./up." >&2
exit 0
