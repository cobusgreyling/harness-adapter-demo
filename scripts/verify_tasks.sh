#!/usr/bin/env bash
# Sanity check for the task set: every task's tests must FAIL as shipped
# and PASS once the reference fix in solutions/ is applied.
# Needs: python3 with pytest.   Usage: scripts/verify_tasks.sh
set -u
export PYTHONDONTWRITEBYTECODE=1   # stale .pyc can mask a same-size edit made within the same second
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="${PYTHON:-python3}"
bad=0
for t in "$ROOT"/tasks/*/; do
  name="$(basename "$t")"
  tmp="$(mktemp -d)"
  cp -R "$t"/. "$tmp"/
  rm -f "$tmp/PROMPT.txt"
  if (cd "$tmp" && "$PY" -m pytest -q -p no:cacheprovider >/dev/null 2>&1); then
    echo "FAIL  $name: tests already pass before the fix"; bad=1
  else
    echo "ok    $name: fails before fix"
  fi
  cp -R "$ROOT/solutions/$name"/. "$tmp"/
  if (cd "$tmp" && "$PY" -m pytest -q -p no:cacheprovider >/dev/null 2>&1); then
    echo "ok    $name: passes with reference fix"
  else
    echo "FAIL  $name: still failing with reference fix"; bad=1
  fi
  rm -rf "$tmp"
done
exit $bad
